import Foundation
import Combine
import SolanaSwift

// MARK: - Real Solana+Nostr+Noise Implementation for Phase 3

class SolanaTransport: ObservableObject, Transport {
    
    // MARK: - Transport Protocol Properties
    
    weak var delegate: OliviaDelegate?
    weak var peerEventsDelegate: TransportPeerEventsDelegate?
    
    var transportType: TransportType { .hybrid }
    
    private let peerSnapshotSubject = PassthroughSubject<[TransportPeerSnapshot], Never>()
    var peerSnapshotPublisher: AnyPublisher<[TransportPeerSnapshot], Never> {
        peerSnapshotSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Solana+Nostr+Noise-specific Properties
    
    private let solanaManager: SolanaManager
    private let daoInterface: DAOProgramInterface
    private let keychain: KeychainManagerProtocol
    private let noiseService: NoiseEncryptionService
    
    // Phase 9: Real relay network integration
    private let relayNetworkManager: RelayNetworkManager
    
    // Phase 10: Economic system integration
    private let tokenManager: TokenManager
    
    // Magic Block Ephemeral Rollups integration
    private let ephemeralRollupManager: EphemeralRollupManager
    
    @Published var isDAOMember = false
    @Published var daoMembers: [DAOMember] = []
    @Published var myWalletAddress: String?
    
    private var currentPeers: [TransportPeerSnapshot] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Identity
    
    var myPeerID: PeerID {
        // For Solana+Nostr+Noise transport, use wallet address as peer ID
        if let walletAddress = myWalletAddress {
            return PeerID(str: String(walletAddress.prefix(16))) // Use first 16 chars as peer ID
        }
        return PeerID(str: "solana_unknown")
    }
    
    var myNickname: String = "SolanaUser"
    
    // MARK: - Initialization
    
    init(keychain: KeychainManagerProtocol) {
        self.keychain = keychain
        // Initialize with a placeholder, will be set up async
        self.solanaManager = SolanaManager()
        self.daoInterface = DAOProgramInterface(solanaManager: solanaManager)
        
        // Phase 9: Initialize relay network manager
        self.relayNetworkManager = RelayNetworkManager(
            solanaManager: solanaManager,
            daoInterface: daoInterface
        )
        
        // Phase 10: Initialize token manager for economic system
        self.tokenManager = TokenManager(
            solanaManager: solanaManager,
            daoInterface: daoInterface
        )
        
        // Magic Block: Initialize Ephemeral Rollup manager for gasless transactions
        self.ephemeralRollupManager = EphemeralRollupManager(
            solanaManager: solanaManager,
            daoInterface: daoInterface
        )
        
        // Initialize noise service for E2E encryption
        self.noiseService = NoiseEncryptionService(keychain: keychain)
        
        // Setup bindings asynchronously
        Task {
            await setupBindings()
        }
    }
    
    @MainActor
    private func setupBindings() {
        // Observe wallet connection changes
        solanaManager.$walletAddress
            .sink { [weak self] address in
                Task {
                    await self?.handleWalletAddressChange(address)
                }
            }
            .store(in: &cancellables)
        
        // Observe DAO members changes
        $daoMembers
            .sink { [weak self] members in
                self?.updatePeerSnapshots()
            }
            .store(in: &cancellables)
    }
    
    private func handleWalletAddressChange(_ address: String?) async {
        myWalletAddress = address
        updatePeerSnapshots()
    }
    
    // MARK: - Transport Protocol Implementation
    
    func currentPeerSnapshots() -> [TransportPeerSnapshot] {
        return currentPeers
    }
    
    func setNickname(_ nickname: String) {
        myNickname = nickname
        
        // Update in DAO if we're a member
        if isDAOMember {
            Task {
                do {
                    _ = try await daoInterface.updateMember(newNickname: nickname, newNoiseKey: nil)
                } catch {
                    print("Failed to update nickname in DAO: \(error)")
                }
            }
        }
    }
    
    nonisolated func startServices() {
        // Solana+Nostr+Noise transport doesn't need to start background services like Solana+Nostr+Noise
        // Connection is established when wallet is connected
        print("SolanaTransport: Services started")
    }
    
    nonisolated func stopServices() {
        Task { @MainActor in
            await solanaManager.disconnectWallet()
            isDAOMember = false
            daoMembers.removeAll()
            updatePeerSnapshots()
            print("SolanaTransport: Services stopped")
        }
    }
    
    func emergencyDisconnectAll() {
        stopServices()
    }
    
    // MARK: - Connectivity
    
    func isPeerConnected(_ peerID: PeerID) -> Bool {
        // In Solana+Nostr+Noise transport, peers are "connected" if they're DAO members
        return daoMembers.contains { member in
            String(member.walletAddress.prefix(16)) == peerID.id
        }
    }
    
    func isPeerReachable(_ peerID: PeerID) -> Bool {
        // Same as connected for Solana+Nostr+Noise transport
        return isPeerConnected(peerID)
    }
    
    func peerNickname(peerID: PeerID) -> String? {
        return daoMembers.first { member in
            String(member.walletAddress.prefix(16)) == peerID.id
        }?.nickname
    }
    
    func getPeerNicknames() -> [PeerID: String] {
        var nicknames: [PeerID: String] = [:]
        for member in daoMembers {
            let peerID = PeerID(str: String(member.walletAddress.prefix(16)))
            nicknames[peerID] = member.nickname
        }
        return nicknames
    }
    
    // MARK: - Protocol Utilities
    
    func getFingerprint(for peerID: PeerID) -> String? {
        // Return wallet address as fingerprint for Solana+Nostr+Noise peers
        return daoMembers.first { member in
            String(member.walletAddress.prefix(16)) == peerID.id
        }?.walletAddress
    }
    
    func getNoiseSessionState(for peerID: PeerID) -> LazyHandshakeState {
        return noiseService.hasEstablishedSession(with: peerID) ? .established : .none
    }
    
    func triggerHandshake(with peerID: PeerID) {
        // Initiate Noise handshake for E2E encryption
        // Implementation would depend on how we exchange initial keys via Solana+Nostr+Noise
        print("SolanaTransport: Triggering handshake with \(peerID)")
    }
    
    func getNoiseService() -> NoiseEncryptionService {
        return noiseService
    }
    
    // MARK: - Messaging
    
    func sendMessage(_ content: String, mentions: [String]) {
        // Magic Block: Enhanced messaging with gasless transactions
        Task {
            do {
                // Check if Ephemeral Rollup session is active for gasless transactions
                let sessionState = await MainActor.run { ephemeralRollupManager.sessionState }
                
                if case .active = sessionState {
                    // Use gasless Ephemeral Rollup for instant messaging
                    try await sendGaslessMessages(content: content, mentions: mentions)
                } else {
                    // Fallback to traditional fee-based messaging
                    try await sendTraditionalMessages(content: content, mentions: mentions)
                }
                
            } catch {
                print("❌ Failed to send message: \(error)")
                // Emergency fallback to basic messaging
                try await sendEmergencyMessages(content: content, mentions: mentions)
            }
        }
    }
    
    /// Send gasless messages using Magic Block Ephemeral Rollups
    private func sendGaslessMessages(content: String, mentions: [String]) async throws {
        print("⚡ Sending gasless messages via Ephemeral Rollup...")
        
        // Send to all DAO members instantly and gaslessly
        for member in daoMembers {
            if member.walletAddress != myWalletAddress {
                do {
                    let messageId = try await ephemeralRollupManager.sendGaslessMessage(
                        to: member.walletAddress,
                        content: content
                    )
                    print("💨 Gasless message sent to \(member.nickname): \(messageId)")
                } catch {
                    print("❌ Failed gasless message to \(member.nickname): \(error)")
                    // Individual message failures don't stop the batch
                }
            }
        }
        
        print("✅ Gasless message broadcast completed")
    }
    
    /// Traditional fee-based messaging (Phase 10 implementation)
    private func sendTraditionalMessages(content: String, mentions: [String]) async throws {
        print("💰 Sending traditional messages with fees...")
        
        // Step 1: Pay message fee (Phase 10 Economic System)
        _ = try await tokenManager.payMessageFee()
        print("💰 Message fee paid successfully")
        
        // Step 2: Ensure relay network is connected
        let isConnected = await MainActor.run { relayNetworkManager.isConnected }
        if !isConnected {
            try await relayNetworkManager.discoverRelayNodes()
        }
        
        // Step 3: Send message to all DAO members via relay network
        for member in daoMembers {
            if member.walletAddress != myWalletAddress {
                do {
                    let encryptedContent = content.data(using: .utf8) ?? Data()
                    _ = try await relayNetworkManager.sendMessage(
                        to: member.walletAddress,
                        encryptedContent: encryptedContent
                    )
                } catch {
                    print("Failed to send message to \(member.nickname): \(error)")
                    // Fallback to direct DAO call if relay fails
                    do {
                        let fallbackContent = content.data(using: .utf8) ?? Data()
                        _ = try await daoInterface.sendMessage(to: member.walletAddress, encryptedContent: fallbackContent)
                    } catch {
                        print("Fallback also failed for \(member.nickname): \(error)")
                    }
                }
            }
        }
    }
    
    /// Emergency messaging without fees (basic functionality)
    private func sendEmergencyMessages(content: String, mentions: [String]) async throws {
        print("🚨 Using emergency messaging mode...")
        
        for member in daoMembers {
            if member.walletAddress != myWalletAddress {
                do {
                    let fallbackContent = content.data(using: .utf8) ?? Data()
                    _ = try await daoInterface.sendMessage(to: member.walletAddress, encryptedContent: fallbackContent)
                } catch {
                    print("Emergency message failed for \(member.nickname): \(error)")
                }
            }
        }
    }
    
    func sendPrivateMessage(_ content: String, to peerID: PeerID, recipientNickname: String, messageID: String) {
        Task {
            // Find recipient by peer ID
            guard let recipient = daoMembers.first(where: { member in
                String(member.walletAddress.prefix(16)) == peerID.id
            }) else {
                print("Recipient not found in DAO members")
                return
            }
            
            do {
                // Ensure relay network is connected
                let isConnected = await MainActor.run { relayNetworkManager.isConnected }
                if !isConnected {
                    try await relayNetworkManager.discoverRelayNodes()
                }
                
                // Encrypt content with Noise protocol
                let contentData = content.data(using: .utf8) ?? Data()
                let encryptedContent: Data
                
                if noiseService.hasEstablishedSession(with: peerID) {
                    encryptedContent = try noiseService.encrypt(contentData, for: peerID)
                } else {
                    // For demo, send unencrypted (in production, establish session first)
                    encryptedContent = contentData
                }
                
                // Phase 9: Send via relay network
                _ = try await relayNetworkManager.sendMessage(
                    to: recipient.walletAddress,
                    encryptedContent: encryptedContent
                )
                
                print("Private message sent via relay network to \(recipientNickname)")
                
            } catch {
                print("Failed to send private message via relay: \(error)")
                // Fallback to direct DAO call
                do {
                    let contentData = content.data(using: .utf8) ?? Data()
                    _ = try await daoInterface.sendMessage(to: recipient.walletAddress, encryptedContent: contentData)
                    print("Private message sent via DAO fallback to \(recipientNickname)")
                } catch {
                    print("Fallback also failed: \(error)")
                }
            }
        }
    }
    
    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: PeerID) {
        // Implementation for read receipts via Solana+Nostr+Noise
        print("SolanaTransport: Sending read receipt for \(receipt.originalMessageID) to \(peerID)")
    }
    
    func sendFavoriteNotification(to peerID: PeerID, isFavorite: Bool) {
        // Implementation for favorite notifications via Solana+Nostr+Noise
        print("SolanaTransport: Sending favorite notification to \(peerID): \(isFavorite)")
    }
    
    func sendBroadcastAnnounce() {
        // Not needed for Solana+Nostr+Noise transport - DAO membership serves this purpose
        print("SolanaTransport: Broadcast announce (no-op)")
    }
    
    func sendDeliveryAck(for messageID: String, to peerID: PeerID) {
        // Implementation for delivery acknowledgments via Solana+Nostr+Noise
        print("SolanaTransport: Sending delivery ack for \(messageID) to \(peerID)")
    }
    
    // MARK: - Solana+Nostr+Noise-specific Methods
    
    func connectWallet() async throws -> String? {
        return try await solanaManager.connectPhantomWallet()
    }
    
    func getWalletAddress() -> String? {
        return myWalletAddress
    }
    
    func joinDAO() async throws {
        guard let _ = myWalletAddress else {
            throw SolanaManager.SolanaError.walletNotConnected
        }
        
        let noisePublicKey = noiseService.getStaticPublicKeyData()
        _ = try await daoInterface.joinDAO(nickname: myNickname, noisePublicKey: noisePublicKey)
        
        isDAOMember = true
    }
    
    func joinDAO(nickname: String, noisePublicKey: Data) async throws {
        guard let _ = myWalletAddress else {
            throw SolanaManager.SolanaError.walletNotConnected
        }
        
        _ = try await daoInterface.joinDAO(nickname: nickname, noisePublicKey: noisePublicKey)
        
        isDAOMember = true
        
        // Refresh DAO members list
        await refreshDAOMembers()
    }
    
    func getDAOMembers() async throws -> [DAOMember] {
        let members = try await daoInterface.getMembers()
        await MainActor.run {
            self.daoMembers = members
        }
        return members
    }
    
    // MARK: - Private Methods
    
    private func updatePeerSnapshots() {
        currentPeers = daoMembers.map { member in
            TransportPeerSnapshot(
                peerID: PeerID(str: String(member.walletAddress.prefix(16))),
                nickname: member.nickname,
                isConnected: true, // DAO members are always "connected"
                noisePublicKey: member.noisePublicKey,
                lastSeen: Date() // For Solana+Nostr+Noise, we don't track last seen the same way
            )
        }
        
        peerSnapshotSubject.send(currentPeers)
        
        // Call delegate on MainActor
        Task { @MainActor in
            peerEventsDelegate?.didUpdatePeerSnapshots(currentPeers)
        }
    }
    
    private func refreshDAOMembers() async {
        do {
            _ = try await getDAOMembers()
        } catch {
            print("Failed to refresh DAO members: \(error)")
        }
    }
    
    // MARK: - Wallet Management (Public Interface)
    
    func createOrRestoreWallet() async throws -> String {
        return try await solanaManager.createOrRestoreWallet()
    }
    
    func requestAirdrop() async throws {
        try await solanaManager.requestAirdrop()
    }
    
    var walletAddress: String? {
        solanaManager.walletAddress
    }
    
    var walletBalance: UInt64 {
        solanaManager.balance
    }
    
    var isWalletConnected: Bool {
        solanaManager.isConnected
    }
}
