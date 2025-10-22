import OliviaLogger
import Foundation
import Combine
import CryptoKit
#if os(iOS)
import UIKit
#endif


/// SolanaService — Solana+Nostr+Noise Transport
/// - Emits events exclusively via `OliviaDelegate` for UI.
/// - ChatViewModel must consume delegate callbacks (`didReceivePublicMessage`, `didReceiveNoisePayload`).
/// - A lightweight `peerSnapshotPublisher` is provided for non-UI services.
final class SolanaService: NSObject, Transport {

    // MARK: - Constants

    #if DEBUG
    static let solanaNetwork = "devnet" // testnet
    #else
    static let solanaNetwork = "mainnet-beta" // mainnet
    #endif
    static let programID = "OLIVIA1111111111111111111111111111111111111"

    // Default per-fragment chunk size when link limits are unknown
    private let defaultFragmentSize = TransportConfig.solanaDefaultFragmentSize
    private let maxMessageLength = InputValidator.Limits.maxMessageLength
    private let messageTTL: UInt8 = TransportConfig.messageTTLDefault
    // Flood/battery controls
    private let maxInFlightAssemblies = TransportConfig.maxConcurrentMessages
    private let highDegreeThreshold = TransportConfig.nostrRelayThreshold // for adaptive TTL/probabilistic relays

    // MARK: - Core State (5 Essential Collections)

    // 1. Solana Connection Tracking
    private struct SolanaConnectionState {
        let walletAddress: String
        var peerID: PeerID?
        var isConnecting: Bool = false
        var isConnected: Bool = false
        var lastConnectionAttempt: Date? = nil
        var assembler = NotificationStreamAssembler()
    }
    private var solanaConnections: [String: SolanaConnectionState] = [:]  // Wallet -> ConnectionState
    private var peerToWalletAddress: [PeerID: String] = [:]  // PeerID -> Wallet Address

    // 2. Nostr Relay Connections
    private var activeRelays: [String] = []  // Active relay URLs
    private var relayToPeerID: [String: PeerID] = [:]  // Relay URL -> Peer ID mapping

    // 3. Peer Information (single source of truth)
    private struct PeerInfo {
        let peerID: PeerID
        var nickname: String
        var isConnected: Bool
        var noisePublicKey: Data?
        var signingPublicKey: Data?
        var isVerifiedNickname: Bool
        var lastSeen: Date
    }
    private var peers: [PeerID: PeerInfo] = [:]
    private var currentPeerIDs: [PeerID] {
        Array(peers.keys)
    }

    // 4. Efficient Message Deduplication
    private let messageDeduplicator = MessageDeduplicator()
    private lazy var mediaDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    // 5. Fragment Reassembly (necessary for messages > MTU)
    private struct FragmentKey: Hashable { let sender: UInt64; let id: UInt64 }
    private var incomingFragments: [FragmentKey: [Int: Data]] = [:]
    private var fragmentMetadata: [FragmentKey: (type: UInt8, total: Int, timestamp: Date)] = [:]
    private struct ActiveTransferState {
        let totalFragments: Int
        var sentFragments: Int
        var workItems: [DispatchWorkItem]
    }
    private var activeTransfers: [String: ActiveTransferState] = [:]
    // Backoff for peripherals that recently timed out connecting
    private var recentConnectTimeouts: [String: Date] = [:] // Peripheral UUID -> last timeout

    // Simple announce throttling
    private var lastAnnounceSent = Date.distantPast
    private let announceMinInterval: TimeInterval = TransportConfig.networkAnnounceIntervalSeconds

    // Application state tracking (thread-safe)
    #if os(iOS)
    private var isAppActive: Bool = true  // Assume active initially
    #endif

    // MARK: - Transport Protocol Properties
    
    weak var delegate: OliviaDelegate?
    weak var peerEventsDelegate: TransportPeerEventsDelegate?
    
    var transportType: TransportType { .hybrid }
    
    // MARK: - Peer Snapshots Publisher
    
    private let peerSnapshotSubject = PassthroughSubject<[TransportPeerSnapshot], Never>()
    var peerSnapshotPublisher: AnyPublisher<[TransportPeerSnapshot], Never> {
        peerSnapshotSubject.eraseToAnyPublisher()
    }
    
    func currentPeerSnapshots() -> [TransportPeerSnapshot] {
        collectionsQueue.sync {
            let snapshot = Array(peers.values)
            let resolvedNames = PeerDisplayNameResolver.resolve(
                snapshot.map { ($0.peerID, $0.nickname, $0.isConnected) },
                selfNickname: myNickname
            )
            return snapshot.map { info in
                TransportPeerSnapshot(
                    peerID: info.peerID,
                    nickname: resolvedNames[info.peerID] ?? info.nickname,
                    isConnected: info.isConnected,
                    noisePublicKey: info.noisePublicKey,
                    lastSeen: info.lastSeen
                )
            }
        }
    }

    // MARK: - Core Solana Objects

    private let solanaTransport: SolanaTransport
    private let nostrTransport: NostrTransport

    // MARK: - Identity

    private var noiseService: NoiseEncryptionService
    private let identityManager: SecureIdentityStateManagerProtocol
    private let keychain: KeychainManagerProtocol
    private let idBridge: NostrIdentityBridge
    private var myPeerIDData: Data = Data()

    // MARK: - Privacy
    // No identifying information by default for maximum privacy.

    // MARK: - Queues

    private let messageQueue = DispatchQueue(label: "solana.message", attributes: .concurrent)
    private let collectionsQueue = DispatchQueue(label: "solana.collections", attributes: .concurrent)
    private let messageQueueKey = DispatchSpecificKey<Void>()
    private let solanaQueue = DispatchQueue(label: "solana.transport", qos: .userInitiated)
    private let solanaQueueKey = DispatchSpecificKey<Void>()

    // Queue for messages pending handshake completion
    private var pendingMessagesAfterHandshake: [PeerID: [(content: String, messageID: String)]] = [:]
    // Noise typed payloads (ACKs, read receipts, etc.) pending handshake
    private var pendingNoisePayloadsAfterHandshake: [PeerID: [Data]] = [:]
    // Keep a tiny buffer of the last few unique announces we've seen (by sender)
    private var recentAnnounceBySender: [PeerID: OliviaPacket] = [:]
    private var recentAnnounceOrder: [PeerID] = []
    private let recentAnnounceBufferCap = 3

    // Queue for notifications that failed due to full queue
    private var pendingNotifications: [(data: Data, peers: [PeerID]?)] = []

    // Accumulate long write chunks per central until a full frame decodes
    private var pendingWriteBuffers: [String: Data] = [:]
    // Relay jitter scheduling to reduce redundant floods
    private var scheduledRelays: [String: DispatchWorkItem] = [:]
    // Track short-lived traffic bursts to adapt announces/scanning under load
    private var recentPacketTimestamps: [Date] = []

    // Ingress link tracking for last-hop suppression
    private enum LinkID: Hashable {
        case solana(String)
        case nostr(String)
    }
    private var ingressByMessageID: [String: (link: LinkID, timestamp: Date)] = [:]

    // Backpressure-aware write queue per peripheral
    private struct OutboundPriority: Comparable {
        let level: Int
        let suborder: Int

        static let high = OutboundPriority(level: 0, suborder: 0)
        static func fragment(totalFragments: Int) -> OutboundPriority {
            OutboundPriority(level: 1, suborder: max(1, min(totalFragments, Int(UInt16.max))))
        }
        static let fileTransfer = OutboundPriority(level: 2, suborder: Int.max - 1)
        static let low = OutboundPriority(level: 2, suborder: Int.max)

        static func < (lhs: OutboundPriority, rhs: OutboundPriority) -> Bool {
            if lhs.level != rhs.level { return lhs.level < rhs.level }
            return lhs.suborder < rhs.suborder
        }
    }
    private struct PendingWrite {
        let priority: OutboundPriority
        let data: Data
    }
    private struct PendingFragmentTransfer {
        let packet: OliviaPacket
        let pad: Bool
        let maxChunk: Int?
        let directedPeer: PeerID?
        let transferId: String?
    }
    private var pendingSolanaWrites: [String: [PendingWrite]] = [:]
    private var pendingFragmentTransfers: [PendingFragmentTransfer] = []
    // Debounce duplicate disconnect notifies
    private var recentDisconnectNotifies: [PeerID: Date] = [:]
    // Store-and-forward for directed messages when we have no links
    // Keyed by recipient short peerID -> messageID -> (packet, enqueuedAt)
    private var pendingDirectedRelays: [PeerID: [String: (packet: OliviaPacket, enqueuedAt: Date)]] = [:]
    // Debounce for 'reconnected' logs
    private var lastReconnectLogAt: [PeerID: Date] = [:]

    // MARK: - Gossip Sync
    private var gossipSyncManager: GossipSyncManager?

    // MARK: - Maintenance Timer

    private var maintenanceTimer: DispatchSourceTimer?  // Single timer for all maintenance tasks
    private var maintenanceCounter = 0  // Track maintenance cycles

    // MARK: - Connection budget & scheduling
    private let maxSolanaConnections = TransportConfig.solanaMaxConcurrentConnections
    private let connectRateLimitInterval: TimeInterval = TransportConfig.solanaConnectRateLimitInterval
    private var lastGlobalConnectAttempt: Date = .distantPast
    private struct ConnectionCandidate {
        let walletAddress: String
        let reputation: Int
        let name: String
        let isConnectable: Bool
        let discoveredAt: Date
    }
    private var connectionCandidates: [ConnectionCandidate] = []
    private var failureCounts: [String: Int] = [:] // Wallet Address -> failures
    private var lastIsolatedAt: Date? = nil
    private var dynamicReputationThreshold: Int = TransportConfig.nostrRelayThreshold

    // MARK: - Adaptive connection duty-cycle
    private var connectionDutyTimer: DispatchSourceTimer?
    private var dutyEnabled: Bool = true
    private var dutyOnDuration: TimeInterval = TransportConfig.solanaActiveMonitoringDuration
    private var dutyOffDuration: TimeInterval = TransportConfig.solanaIdleMonitoringDuration
    private var dutyActive: Bool = false

    // Debounced publish to coalesce rapid changes
    private var lastPeerPublishAt: Date = .distantPast
    private var peerPublishPending: Bool = false
    private let peerPublishMinInterval: TimeInterval = 0.1
    private func requestPeerDataPublish() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastPeerPublishAt)
        if elapsed >= peerPublishMinInterval {
            lastPeerPublishAt = now
            publishFullPeerData()
        } else if !peerPublishPending {
            peerPublishPending = true
            let delay = peerPublishMinInterval - elapsed
            messageQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.lastPeerPublishAt = Date()
                self.peerPublishPending = false
                self.publishFullPeerData()
            }
        }
    }

    // MARK: - Initialization

    init(
        keychain: KeychainManagerProtocol,
        idBridge: NostrIdentityBridge,
        identityManager: SecureIdentityStateManagerProtocol
    ) {
        self.keychain = keychain
        self.idBridge = idBridge
        self.identityManager = identityManager
        self.noiseService = NoiseEncryptionService(keychain: keychain)
        self.solanaTransport = SolanaTransport(keychain: keychain)
        self.nostrTransport = NostrTransport(keychain: keychain)
        
        super.init()

        configureNoiseServiceCallbacks(for: noiseService)
        refreshPeerIdentity()

        // Set queue key for identification
        messageQueue.setSpecific(key: messageQueueKey, value: ())

        // Set up application state tracking (iOS only)
        #if os(iOS)
        // Check initial state on main thread
        if Thread.isMainThread {
            isAppActive = UIApplication.shared.applicationState == .active
        } else {
            DispatchQueue.main.sync {
                isAppActive = UIApplication.shared.applicationState == .active
            }
        }

        // Observe application state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif

        // Tag Solana queue for re-entrancy detection
        solanaQueue.setSpecific(key: solanaQueueKey, value: ())

        // Set up transport integration
        setupTransportIntegration()

        // Single maintenance timer for all periodic tasks (dispatch-based for determinism)
        let timer = DispatchSource.makeTimerSource(queue: solanaQueue)
        timer.schedule(deadline: .now() + TransportConfig.networkMaintenanceInterval,
                       repeating: TransportConfig.networkMaintenanceInterval,
                       leeway: .seconds(TransportConfig.networkMaintenanceLeewaySeconds))
        timer.setEventHandler { [weak self] in
            self?.performMaintenance()
        }
        timer.resume()
        maintenanceTimer = timer

        // Publish initial empty state
        requestPeerDataPublish()

        // Initialize gossip sync manager
        restartGossipManager()
    }


    // MARK: - Identity
    
    var myPeerID = PeerID(str: "")
    var myNickname: String = "anon"
    
    func setNickname(_ nickname: String) {
        self.myNickname = nickname
        // Send announce to notify peers of nickname change (force send)
        sendAnnounce(forceSend: true)
    }

    deinit {
        maintenanceTimer?.cancel()
        connectionDutyTimer?.cancel()
        connectionDutyTimer = nil
        solanaTransport.stopServices()
        nostrTransport.stopServices()
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    func resetIdentityForPanic(currentNickname: String) {
        messageQueue.sync(flags: .barrier) {
            pendingMessagesAfterHandshake.removeAll()
            pendingNoisePayloadsAfterHandshake.removeAll()
        }

        collectionsQueue.sync(flags: .barrier) {
            recentAnnounceBySender.removeAll()
            recentAnnounceOrder.removeAll()
            pendingSolanaWrites.removeAll()
            pendingFragmentTransfers.removeAll()
            pendingNotifications.removeAll()
            pendingDirectedRelays.removeAll()
            ingressByMessageID.removeAll()
            recentPacketTimestamps.removeAll()
            scheduledRelays.values.forEach { $0.cancel() }
            scheduledRelays.removeAll()
        }

        solanaQueue.sync {
            pendingWriteBuffers.removeAll()
            recentConnectTimeouts.removeAll()
        }
        recentDisconnectNotifies.removeAll()

        noiseService.clearEphemeralStateForPanic()
        noiseService.clearPersistentIdentity()

        let newNoise = NoiseEncryptionService(keychain: keychain)
        noiseService = newNoise
        configureNoiseServiceCallbacks(for: newNoise)
        refreshPeerIdentity()
        restartGossipManager()

        setNickname(currentNickname)

        messageDeduplicator.reset()
        requestPeerDataPublish()
        startServices()
    }

    // MARK: - Lifecycle
    
    func startServices() {
        // Start Solana and Nostr services
        solanaTransport.startServices()
        nostrTransport.startServices()

        // Send initial announce after services are ready
        messageQueue.asyncAfter(deadline: .now() + TransportConfig.networkAnnounceDelaySeconds) { [weak self] in
            self?.sendAnnounce(forceSend: true)
        }
    }

    func stopServices() {
        // Send leave message synchronously to ensure delivery
        let leavePacket = OliviaPacket(
            type: MessageType.leave.rawValue,
            senderID: myPeerIDData,
            recipientID: nil,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
            payload: Data(),
            signature: nil,
            ttl: messageTTL
        )

        // Send immediately to all connected peers
        if let data = leavePacket.toBinaryData(padding: false) {
            broadcastPacket(leavePacket)
        }

        // Give leave message a moment to send
        Thread.sleep(forTimeInterval: TransportConfig.networkThreadSleepDelaySeconds)

        // Clear pending notifications
        collectionsQueue.sync(flags: .barrier) {
            pendingNotifications.removeAll()
        }

        // Stop timer
        maintenanceTimer?.cancel()
        maintenanceTimer = nil
        connectionDutyTimer?.cancel()
        connectionDutyTimer = nil

        // Stop transports
        solanaTransport.stopServices()
        nostrTransport.stopServices()
    }

    func emergencyDisconnectAll() {
        stopServices()

        // Clear all sessions and peers
        let cancelledTransfers: [(id: String, items: [DispatchWorkItem])] = collectionsQueue.sync(flags: .barrier) {
            let entries = activeTransfers.map { ($0.key, $0.value.workItems) }
            peers.removeAll()
            incomingFragments.removeAll()
            fragmentMetadata.removeAll()
            activeTransfers.removeAll()
            return entries
        }

        for entry in cancelledTransfers {
            entry.items.forEach { $0.cancel() }
            // TODO: Implement transfer progress management
        }

        // Clear processed messages
        messageDeduplicator.reset()

        // Clear connection references
        solanaConnections.removeAll()
        peerToWalletAddress.removeAll()
        activeRelays.removeAll()
        relayToPeerID.removeAll()
    }



    // Ensure this runs on message queue to avoid main thread blocking
    func sendMessage(_ content: String, mentions: [String] = [], to recipientID: PeerID? = nil, messageID: String? = nil, timestamp: Date? = nil) {
        // Call directly if already on messageQueue, otherwise dispatch
        if DispatchQueue.getSpecific(key: messageQueueKey) == nil {
            messageQueue.async { [weak self] in
                self?.sendMessage(content, mentions: mentions, to: recipientID, messageID: messageID, timestamp: timestamp)
            }
            return
        }

        guard content.count <= maxMessageLength else {
            SecureLogger.error("Message too long: \(content.count) chars", category: .session)
            return
        }

        if let recipientID {
            sendPrivateMessage(content, to: recipientID, messageID: messageID ?? UUID().uuidString)
            return
        }

        // Public broadcast
        // Create packet with explicit fields so we can sign it
        let basePacket = OliviaPacket(
            type: MessageType.message.rawValue,
            senderID: Data(hexString: myPeerID.id) ?? Data(),
            recipientID: nil,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
            payload: Data(content.utf8),
            signature: nil,
            ttl: messageTTL
        )
        guard let signedPacket = noiseService.signPacket(basePacket) else {
            SecureLogger.error("❌ Failed to sign public message", category: .security)
            return
        }
        // Pre-mark our own broadcast as processed to avoid handling relayed self copy
        let senderHex = signedPacket.senderID.hexEncodedString()
        let dedupID = "\(senderHex)-\(signedPacket.timestamp)-\(signedPacket.type)"
        messageDeduplicator.markProcessed(dedupID)
        // Call synchronously since we're already on background queue
        broadcastPacket(signedPacket)
        // Track our own broadcast for sync
        gossipSyncManager?.onPublicPacketSeen(signedPacket)
    }
    
    // MARK: - Missing Methods (Stubs for now)
    
    private func broadcastPacket(_ packet: OliviaPacket) {
        SecureLogger.debug("SolanaService: Broadcasting DAO governance packet type \(packet.type)", category: .session)
        
        // Route based on message type for optimal DAO governance
        switch MessageType(rawValue: packet.type) {
        case .message:
            // Public DAO discussions via Nostr for transparency
            broadcastViaNostr(packet)
            
        case .noiseEncrypted:
            // Private DAO communications via both transports for redundancy
            broadcastViaNostr(packet)
            broadcastViaSolana(packet)
            
        case .announce:
            // DAO member announcements via both for discovery
            broadcastViaNostr(packet)
            broadcastViaSolana(packet)
            
        case .fragment:
            // DAO document fragments via Solana for immutability
            broadcastViaSolana(packet)
            
        default:
            // Default: use both transports for DAO governance reliability
            broadcastViaNostr(packet)
            broadcastViaSolana(packet)
        }
    }
    
    private func broadcastViaNostr(_ packet: OliviaPacket) {
        guard let data = packet.toBinaryData(padding: false) else {
            SecureLogger.error("Failed to serialize packet for Nostr broadcast", category: .session)
            return
        }
        
        // Send via Nostr transport for DAO transparency and reach
        // TODO: Implement when NostrTransport.broadcastMessage is available
        SecureLogger.debug("DAO message would broadcast via Nostr: \(data.count) bytes", category: .session)
    }
    
    private func broadcastViaSolana(_ packet: OliviaPacket) {
        guard let data = packet.toBinaryData(padding: false) else {
            SecureLogger.error("Failed to serialize packet for Solana broadcast", category: .session)
            return
        }
        
        // Send via Solana transport for DAO on-chain governance
        // TODO: Implement when SolanaTransport.submitGovernanceMessage is available
        SecureLogger.debug("DAO governance message would submit to Solana: \(data.count) bytes", category: .session)
    }
    
    private func sendPrivateMessage(_ content: String, to peerID: PeerID, messageID: String) {
        SecureLogger.debug("SolanaService: Sending private DAO message to \(peerID)", category: .session)
        
        // Create private message payload with DAO context
        let privateMessage = OliviaMessage(
            id: messageID,
            sender: myNickname,
            content: content,
            timestamp: Date(),
            isRelay: false,
            isPrivate: true,
            senderPeerID: myPeerID
        )
        
        guard let messageData = try? JSONEncoder().encode(privateMessage) else {
            SecureLogger.error("Failed to encode private DAO message", category: .session)
            return
        }
        
        // Create typed payload for Noise encryption
        var payload = Data([NoisePayloadType.privateMessage.rawValue])
        payload.append(messageData)
        
        if noiseService.hasEstablishedSession(with: peerID) {
            sendEncryptedDAOMessage(payload, to: peerID)
        } else {
            // Queue message and initiate handshake for DAO member
            queuePendingDAOMessage(content: content, messageID: messageID, peerID: peerID)
            initiateNoiseHandshake(with: peerID)
        }
    }
    
    private func sendEncryptedDAOMessage(_ payload: Data, to peerID: PeerID) {
        do {
            let encrypted = try noiseService.encrypt(payload, for: peerID)
            let packet = OliviaPacket(
                type: MessageType.noiseEncrypted.rawValue,
                senderID: myPeerIDData,
                recipientID: Data(hexString: peerID.id),
                timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                payload: encrypted,
                signature: nil,
                ttl: messageTTL
            )
            
            // Sign packet for DAO authenticity
            if let signedPacket = noiseService.signPacket(packet) {
                broadcastPacket(signedPacket)
                SecureLogger.debug("Encrypted DAO message sent to \(peerID)", category: .session)
            } else {
                SecureLogger.error("Failed to sign DAO message packet", category: .security)
            }
        } catch {
            SecureLogger.error("Failed to encrypt DAO message: \(error)", category: .security)
        }
    }
    
    private func queuePendingDAOMessage(content: String, messageID: String, peerID: PeerID) {
        messageQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.pendingMessagesAfterHandshake[peerID, default: []].append((content: content, messageID: messageID))
            SecureLogger.debug("Queued DAO message for \(peerID) pending handshake", category: .session)
        }
    }
    
    private func createDAOContext() -> [String: Any] {
        return [
            "dao_id": Self.programID,
            "network": Self.solanaNetwork,
            "governance_version": "1.0",
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    func sendPrivateMessage(_ content: String, to peerID: PeerID, recipientNickname: String, messageID: String) {
        // Transport protocol method - delegate to internal method
        sendPrivateMessage(content, to: peerID, messageID: messageID)
    }
    
    private func initiateNoiseHandshake(with peerID: PeerID) {
        SecureLogger.debug("SolanaService: Initiating DAO member handshake with \(peerID)", category: .session)
        
        do {
            // Create handshake initiation for DAO member
            let handshakeData = try noiseService.initiateHandshake(with: peerID)
            
            // Create handshake packet with DAO governance context
            let packet = OliviaPacket(
                type: MessageType.noiseHandshake.rawValue,
                senderID: myPeerIDData,
                recipientID: Data(hexString: peerID.id),
                timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                payload: handshakeData,
                signature: nil,
                ttl: messageTTL
            )
            
            // Sign handshake for DAO authenticity
            if let signedPacket = noiseService.signPacket(packet) {
                broadcastPacket(signedPacket)
                SecureLogger.debug("DAO handshake initiated with \(peerID)", category: .session)
                
                // Update peer state for DAO governance
                updateDAOPeerState(peerID: peerID, isHandshaking: true)
            } else {
                SecureLogger.error("Failed to sign DAO handshake packet", category: .security)
            }
        } catch {
            SecureLogger.error("Failed to initiate DAO handshake with \(peerID): \(error)", category: .security)
        }
    }
    
    private func updateDAOPeerState(peerID: PeerID, isHandshaking: Bool = false, isConnected: Bool = false) {
        collectionsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var peerInfo = self.peers[peerID] ?? PeerInfo(
                peerID: peerID,
                nickname: "DAO-Member-\(peerID.id.prefix(8))",
                isConnected: false,
                noisePublicKey: nil,
                signingPublicKey: nil,
                isVerifiedNickname: false,
                lastSeen: Date()
            )
            
            peerInfo.isConnected = isConnected
            peerInfo.lastSeen = Date()
            
            self.peers[peerID] = peerInfo
            SecureLogger.debug("Updated DAO peer state for \(peerID): connected=\(isConnected)", category: .session)
        }
    }
    
    private func sendAnnounce(forceSend: Bool = false) {
        let now = Date()
        
        // Check announce throttling for DAO efficiency
        if !forceSend && now.timeIntervalSince(lastAnnounceSent) < announceMinInterval {
            return
        }
        
        SecureLogger.debug("SolanaService: Sending DAO member announcement (force: \(forceSend))", category: .session)
        
        // Create DAO member announcement payload
        let announcePayload = createDAOMemberAnnouncement()
        
        guard let payloadData = try? JSONSerialization.data(withJSONObject: announcePayload) else {
            SecureLogger.error("Failed to serialize DAO announcement payload", category: .session)
            return
        }
        
        let packet = OliviaPacket(
            type: MessageType.announce.rawValue,
            senderID: myPeerIDData,
            recipientID: nil, // Broadcast to all DAO members
            timestamp: UInt64(now.timeIntervalSince1970 * 1000),
            payload: payloadData,
            signature: nil,
            ttl: messageTTL
        )
        
        // Sign announcement for DAO authenticity
        if let signedPacket = noiseService.signPacket(packet) {
            broadcastPacket(signedPacket)
            lastAnnounceSent = now
            SecureLogger.debug("DAO member announcement broadcasted", category: .session)
        } else {
            SecureLogger.error("Failed to sign DAO announcement", category: .security)
        }
    }
    
    private func createDAOMemberAnnouncement() -> [String: Any] {
        return [
            "type": "dao_member_announce",
            "peer_id": myPeerID.id,
            "nickname": myNickname,
            "dao_id": Self.programID,
            "network": Self.solanaNetwork,
            "governance_role": determineGovernanceRole(),
            "voting_power": getVotingPower(),
            "public_key": myPeerIDData.hexEncodedString(),
            "timestamp": Date().timeIntervalSince1970,
            "version": "1.0"
        ]
    }
    
    private func determineGovernanceRole() -> String {
        // TODO: Integrate with Solana governance program to determine role
        // For now, return default member role
        return "member"
    }
    
    private func getVotingPower() -> Int {
        // TODO: Query Solana governance program for actual voting power
        // For now, return default voting power
        return 1
    }
    
    private func publishFullPeerData() {
        SecureLogger.debug("SolanaService: Publishing DAO peer data", category: .session)
        
        let transportPeers: [TransportPeerSnapshot] = collectionsQueue.sync {
            // Compute nickname collision counts for connected DAO members
            let connected = peers.values.filter { $0.isConnected }
            var counts: [String: Int] = [:]
            for p in connected { counts[p.nickname, default: 0] += 1 }
            counts[myNickname, default: 0] += 1
            
            return peers.values.map { info in
                var display = info.nickname
                if info.isConnected, (counts[info.nickname] ?? 0) > 1 {
                    display += "#" + String(info.peerID.id.prefix(4))
                }
                return TransportPeerSnapshot(
                    peerID: info.peerID,
                    nickname: display,
                    isConnected: info.isConnected,
                    noisePublicKey: info.noisePublicKey,
                    lastSeen: info.lastSeen
                )
            }
        }
        
        // Notify non-UI listeners about DAO peer updates
        peerSnapshotSubject.send(transportPeers)
        
        // Notify UI on MainActor via delegate for DAO governance UI
        Task { @MainActor [weak self] in
            self?.peerEventsDelegate?.didUpdatePeerSnapshots(transportPeers)
        }
    }
    
    // MARK: - DAO Governance Message Handling
    
    func sendDAOProposal(_ proposal: DAOProposal) {
        SecureLogger.debug("SolanaService: Sending DAO proposal: \(proposal.title)", category: .session)
        
        guard let proposalData = proposal.encode() else {
            SecureLogger.error("Failed to encode DAO proposal", category: .session)
            return
        }
        
        let packet = OliviaPacket(
            type: MessageType.message.rawValue, // Use message type for DAO proposals
            senderID: myPeerIDData,
            recipientID: nil, // Broadcast to all DAO members
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
            payload: proposalData,
            signature: nil,
            ttl: messageTTL
        )
        
        // Sign proposal for authenticity and submit to Solana
        if let signedPacket = noiseService.signPacket(packet) {
            broadcastViaSolana(signedPacket) // Proposals go on-chain for immutability
            broadcastViaNostr(signedPacket)  // Also broadcast via Nostr for reach
            SecureLogger.debug("DAO proposal submitted: \(proposal.id)", category: .session)
        }
    }
    
    func sendDAOVote(_ vote: DAOVote) {
        SecureLogger.debug("SolanaService: Sending DAO vote for proposal: \(vote.proposalId)", category: .session)
        
        guard let voteData = vote.encode() else {
            SecureLogger.error("Failed to encode DAO vote", category: .session)
            return
        }
        
        let packet = OliviaPacket(
            type: MessageType.message.rawValue, // Use message type for DAO votes
            senderID: myPeerIDData,
            recipientID: nil,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
            payload: voteData,
            signature: nil,
            ttl: messageTTL
        )
        
        // Sign vote and submit to Solana for on-chain governance
        if let signedPacket = noiseService.signPacket(packet) {
            broadcastViaSolana(signedPacket) // Votes must be on-chain
            SecureLogger.debug("DAO vote submitted: \(vote.id)", category: .session)
        }
    }
    
    // MARK: - Transport Protocol Methods
    
    func sendMessage(_ content: String, mentions: [String]) {
        // Transport protocol method - delegate to internal method
        sendMessage(content, mentions: mentions, to: nil, messageID: nil, timestamp: nil)
    }
    
    func sendBroadcastAnnounce() {
        sendAnnounce(forceSend: true)
    }
    
    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: PeerID) {
        // TODO: Implement read receipt sending
        SecureLogger.debug("SolanaService: Sending read receipt to \(peerID)", category: .session)
    }
    
    func sendFavoriteNotification(to peerID: PeerID, isFavorite: Bool) {
        // TODO: Implement favorite notification
        SecureLogger.debug("SolanaService: Sending favorite notification to \(peerID)", category: .session)
    }
    
    func sendDeliveryAck(for messageID: String, to peerID: PeerID) {
        // TODO: Implement delivery acknowledgment
        SecureLogger.debug("SolanaService: Sending delivery ack for \(messageID) to \(peerID)", category: .session)
    }
    
    // MARK: - Connectivity and peers (Transport Protocol)
    
    func isPeerConnected(_ peerID: PeerID) -> Bool {
        let shortID = peerID.toShort()
        return collectionsQueue.sync { peers[shortID]?.isConnected ?? false }
    }

    func isPeerReachable(_ peerID: PeerID) -> Bool {
        let shortID = peerID.toShort()
        return collectionsQueue.sync {
            let meshAttached = peers.values.contains { $0.isConnected }
            guard let info = peers[shortID] else { return false }
            if info.isConnected { return true }
            guard meshAttached else { return false }
            let isVerified = info.isVerifiedNickname
            let retention: TimeInterval = isVerified ? TransportConfig.peerReachabilityRetentionVerifiedSeconds : TransportConfig.peerReachabilityRetentionUnverifiedSeconds
            return Date().timeIntervalSince(info.lastSeen) <= retention
        }
    }

    func peerNickname(peerID: PeerID) -> String? {
        collectionsQueue.sync {
            guard let peer = peers[peerID], peer.isConnected else { return nil }
            return peer.nickname
        }
    }

    func getPeerNicknames() -> [PeerID: String] {
        return collectionsQueue.sync {
            let connected = peers.filter { $0.value.isConnected }
            let tuples = connected.map { ($0.key, $0.value.nickname, true) }
            return PeerDisplayNameResolver.resolve(tuples, selfNickname: myNickname)
        }
    }
    
    // MARK: - Protocol utilities (Transport Protocol)
    
    func getFingerprint(for peerID: PeerID) -> String? {
        return collectionsQueue.sync {
            return peers[peerID]?.noisePublicKey?.sha256Fingerprint()
        }
    }
    
    func getNoiseSessionState(for peerID: PeerID) -> LazyHandshakeState {
        if noiseService.hasEstablishedSession(with: peerID) {
            return .established
        } else if noiseService.hasSession(with: peerID) {
            return .handshaking
        } else {
            return .none
        }
    }
    
    func triggerHandshake(with peerID: PeerID) {
        initiateNoiseHandshake(with: peerID)
    }
    
    func getNoiseService() -> NoiseEncryptionService {
        return noiseService
    }
    
    // MARK: - Missing Helper Methods
    
    private func configureNoiseServiceCallbacks(for service: NoiseEncryptionService) {
        SecureLogger.debug("SolanaService: Configuring DAO Noise service callbacks", category: .session)
        
        // TODO: Configure callbacks when NoiseEncryptionService supports them
        // For now, we'll handle handshake completion and message decryption
        // through direct method calls in the message processing pipeline
    }
    
    private func handleDAOHandshakeCompleted(peerID: PeerID) {
        SecureLogger.debug("DAO handshake completed with \(peerID)", category: .session)
        updateDAOPeerState(peerID: peerID, isConnected: true)
        
        // Send any pending DAO messages after handshake
        sendPendingDAOMessages(for: peerID)
    }
    
    private func handleDAOEncryptedMessage(from peerID: PeerID, payload: Data) {
        SecureLogger.debug("Received encrypted DAO message from \(peerID)", category: .session)
        
        // Process DAO-specific encrypted messages
        guard let payloadType = payload.first else { return }
        let messageData = payload.dropFirst()
        
        switch NoisePayloadType(rawValue: payloadType) {
        case .privateMessage:
            handleDAOPrivateMessage(from: peerID, data: messageData)
        case .readReceipt:
            handleDAOReadReceipt(from: peerID, data: messageData)
        default:
            SecureLogger.warning("Unknown DAO encrypted payload type: \(payloadType)", category: .session)
        }
    }
    
    private func notifyUI(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
    
    private func sendPendingDAOMessages(for peerID: PeerID) {
        let messages = collectionsQueue.sync(flags: .barrier) { () -> [(content: String, messageID: String)] in
            let list = pendingMessagesAfterHandshake[peerID] ?? []
            pendingMessagesAfterHandshake.removeValue(forKey: peerID)
            return list
        }
        
        guard !messages.isEmpty else { return }
        SecureLogger.debug("📤 Sending \(messages.count) pending DAO messages to \(peerID)", category: .session)
        
        for (content, messageID) in messages {
            sendPrivateMessage(content, to: peerID, messageID: messageID)
        }
    }
    
    private func handleDAOPrivateMessage(from peerID: PeerID, data: Data) {
        guard let message = try? JSONDecoder().decode(OliviaMessage.self, from: data) else {
            SecureLogger.error("Failed to decode DAO private message", category: .session)
            return
        }
        
        SecureLogger.debug("Received DAO private message from \(peerID): \(message.content.prefix(50))...", category: .session)
        
        // Notify delegate about DAO private message
        notifyUI { [weak self] in
            self?.delegate?.didReceiveMessage(message)
        }
    }
    
    private func handleDAOReadReceipt(from peerID: PeerID, data: Data) {
        guard let messageID = String(data: data, encoding: .utf8) else { return }
        SecureLogger.debug("Received DAO read receipt from \(peerID) for message \(messageID)", category: .session)
        
        // TODO: Handle read receipt - no specific delegate method available
        // Could use didReceiveNoisePayload or add to OliviaDelegate
    }
    
    private func refreshPeerIdentity() {
        SecureLogger.debug("SolanaService: Refreshing DAO peer identity", category: .session)
        
        // Get identity from noise service for DAO authentication
        let publicKey = noiseService.getStaticPublicKeyData()
        myPeerIDData = publicKey
        if let peerID = PeerID(data: publicKey) {
            myPeerID = peerID
            SecureLogger.debug("DAO peer identity refreshed: \(myPeerID.id.prefix(16))...", category: .session)
        } else {
            SecureLogger.error("Failed to create PeerID from public key", category: .security)
        }
    }
    
    private func setupTransportIntegration() {
        SecureLogger.debug("SolanaService: Setting up DAO transport integration", category: .session)
        
        // Configure Solana transport for DAO governance
        // TODO: Implement when SolanaTransport.configure is available
        SecureLogger.debug("Would configure Solana transport for network: \(Self.solanaNetwork)", category: .session)
        
        // Configure Nostr transport for DAO communications
        // TODO: Implement when NostrTransport.configure is available
        SecureLogger.debug("Would configure Nostr transport with \(getDAORelays().count) relays", category: .session)
    }
    
    private func getDAORelays() -> [String] {
        // Return DAO-specific Nostr relays for governance communications
        return [
            "wss://relay.damus.io",
            "wss://nos.lol",
            "wss://relay.snort.social",
            "wss://relay.current.fyi"
        ]
    }
    
    private func handleSolanaDAOMessage(data: Data, messageType: UInt8) {
        SecureLogger.debug("Received Solana DAO message: type=\(messageType), size=\(data.count)", category: .session)
        // Process Solana-specific DAO governance messages
        processIncomingDAOMessage(data: data, source: .solana)
    }
    
    private func handleNostrDAOMessage(data: Data, messageType: UInt8) {
        SecureLogger.debug("Received Nostr DAO message: type=\(messageType), size=\(data.count)", category: .session)
        // Process Nostr-specific DAO communications
        processIncomingDAOMessage(data: data, source: .nostr)
    }
    
    private func processIncomingDAOMessage(data: Data, source: MessageSource) {
        guard let packet = OliviaPacket.from(data) else {
            SecureLogger.error("Failed to decode DAO packet from \(source)", category: .session)
            return
        }
        
        // Process DAO governance packet based on type
        switch MessageType(rawValue: packet.type) {
        case .message:
            // DAO proposals and votes use message type
            handleDAOMessage(packet, from: source)
        case .announce:
            handleDAOMemberAnnouncement(packet, from: source)
        case .noiseEncrypted:
            handleDAOEncryptedMessage(packet, from: source)
        default:
            SecureLogger.debug("Processing standard DAO message type: \(packet.type)", category: .session)
        }
    }
    
    private func handleDAOMessage(_ packet: OliviaPacket, from source: MessageSource) {
        SecureLogger.debug("Processing DAO message from \(source)", category: .session)
        
        // Try to decode as DAO proposal first
        if let proposal = DAOProposal.decode(packet.payload) {
            handleDAOProposal(proposal, from: source)
            return
        }
        
        // Try to decode as DAO vote
        if let vote = DAOVote.decode(packet.payload) {
            handleDAOVote(vote, from: source)
            return
        }
        
        // Handle as regular DAO message
        SecureLogger.debug("Processing regular DAO message", category: .session)
    }
    
    private func handleDAOProposal(_ proposal: DAOProposal, from source: MessageSource) {
        SecureLogger.debug("Processing DAO proposal '\(proposal.title)' from \(source)", category: .session)
        // TODO: Implement DAO proposal processing
    }
    
    private func handleDAOVote(_ vote: DAOVote, from source: MessageSource) {
        SecureLogger.debug("Processing DAO vote for proposal \(vote.proposalId) from \(source)", category: .session)
        // TODO: Implement DAO vote processing
    }
    
    private func handleDAOEncryptedMessage(_ packet: OliviaPacket, from source: MessageSource) {
        SecureLogger.debug("Processing DAO encrypted message from \(source)", category: .session)
        // TODO: Implement DAO encrypted message processing
    }
    
    private func handleDAOMemberAnnouncement(_ packet: OliviaPacket, from source: MessageSource) {
        SecureLogger.debug("Processing DAO member announcement from \(source)", category: .session)
        // TODO: Implement DAO member announcement processing
    }
    
    private func restartGossipManager() {
        SecureLogger.debug("SolanaService: Restarting DAO gossip manager", category: .session)
        // TODO: Initialize GossipSyncManager when constructor is available
        // gossipSyncManager = GossipSyncManager(myPeerID: myPeerID)
    }
    
    private func performMaintenance() {
        SecureLogger.debug("SolanaService: Performing DAO maintenance", category: .session)
        
        // DAO-specific maintenance tasks
        let now = Date()
        
        // Check DAO member connectivity
        checkDAOMemberConnectivity()
        
        // Clean up old DAO governance data
        cleanupDAOData()
        
        // Send periodic DAO member announcements
        if now.timeIntervalSince(lastAnnounceSent) >= TransportConfig.networkAnnounceIntervalSeconds {
            sendAnnounce(forceSend: false)
        }
    }
    
    private func checkDAOMemberConnectivity() {
        let now = Date()
        var disconnectedMembers: [PeerID] = []
        
        collectionsQueue.sync(flags: .barrier) {
            for (peerID, peer) in peers {
                let age = now.timeIntervalSince(peer.lastSeen)
                if peer.isConnected && age > TransportConfig.peerInactivityTimeoutSeconds {
                    var updated = peer
                    updated.isConnected = false
                    peers[peerID] = updated
                    disconnectedMembers.append(peerID)
                }
            }
        }
        
        // Notify about disconnected DAO members
        for peerID in disconnectedMembers {
            SecureLogger.debug("DAO member disconnected: \(peerID)", category: .session)
            notifyUI { [weak self] in
                self?.delegate?.didDisconnectFromPeer(peerID)
            }
        }
    }
    
    private func cleanupDAOData() {
        let now = Date()
        
        // Clean old DAO message fragments
        collectionsQueue.sync(flags: .barrier) {
            let cutoff = now.addingTimeInterval(-TransportConfig.messageFragmentLifetimeSeconds)
            let oldFragments = fragmentMetadata.filter { $0.value.timestamp < cutoff }.map { $0.key }
            for fragmentID in oldFragments {
                incomingFragments.removeValue(forKey: fragmentID)
                fragmentMetadata.removeValue(forKey: fragmentID)
            }
        }
        
        // Clean old DAO peer data
        messageDeduplicator.cleanup()
    }
    
    private enum MessageSource {
        case solana
        case nostr
    }
}

// MARK: - GossipSyncManager Delegate
extension SolanaService: GossipSyncManager.Delegate {
    func sendPacket(_ packet: OliviaPacket) {
        broadcastPacket(packet)
    }

    func sendPacket(to peerID: PeerID, packet: OliviaPacket) {
        SecureLogger.debug("SolanaService: Sending directed DAO packet to \(peerID)", category: .session)
        
        // Create directed packet with recipient
        let directedPacket = OliviaPacket(
            type: packet.type,
            senderID: packet.senderID,
            recipientID: Data(hexString: peerID.id),
            timestamp: packet.timestamp,
            payload: packet.payload,
            signature: packet.signature,
            ttl: packet.ttl
        )
        
        // Sign packet for DAO authenticity
        if let signedPacket = noiseService.signPacket(directedPacket) {
            broadcastPacket(signedPacket)
        } else {
            SecureLogger.error("Failed to sign directed DAO packet", category: .security)
        }
    }

    func signPacketForBroadcast(_ packet: OliviaPacket) -> OliviaPacket {
        return noiseService.signPacket(packet) ?? packet
    }
}
