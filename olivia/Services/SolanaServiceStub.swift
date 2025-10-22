import Foundation
import Combine
import OliviaLogger

/// Stub implementation of SolanaService for Solana+Nostr+Noise+Magic Block architecture
/// Replaces the legacy Solana network relay networking with no-op implementations
final class SolanaServiceStub: Transport {
    
    // MARK: - Transport Protocol Implementation
    
    var delegate: OliviaDelegate?
    var peerEventsDelegate: TransportPeerEventsDelegate?
    
    var peerSnapshotPublisher: AnyPublisher<[TransportPeerSnapshot], Never> {
        Just([]).eraseToAnyPublisher()
    }
    
    func currentPeerSnapshots() -> [TransportPeerSnapshot] {
        return []
    }
    
    var myPeerID: PeerID = PeerID(str: "stub")
    var myNickname: String = "Solana+Nostr+Noise Disabled"
    
    func setNickname(_ nickname: String) {
        // No-op
    }
    
    func startServices() {
        SecureLogger.info("SolanaServiceStub: Legacy BLE network disabled - using Solana+Nostr+Noise+Magic Block", category: .session)
    }
    
    func stopServices() {
        SecureLogger.info("SolanaServiceStub: No legacy BLE network services to stop", category: .session)
    }
    
    func emergencyDisconnectAll() {
        // No-op
    }
    
    func isPeerConnected(_ peerID: PeerID) -> Bool {
        return false
    }
    
    func isPeerReachable(_ peerID: PeerID) -> Bool {
        return false
    }
    
    func peerNickname(peerID: PeerID) -> String? {
        return nil
    }
    
    func getPeerNicknames() -> [PeerID: String] {
        return [:]
    }
    
    func getFingerprint(for peerID: PeerID) -> String? {
        return nil
    }
    
    func getNoiseSessionState(for peerID: PeerID) -> LazyHandshakeState {
        return .none
    }
    
    func triggerHandshake(with peerID: PeerID) {
        // No-op
    }
    
    func sendPrivateMessage(_ content: String, to peerID: PeerID, recipientNickname: String, messageID: String) {
        SecureLogger.debug("SolanaServiceStub: Private message routing disabled - use Nostr transport", category: .session)
    }
    
    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: PeerID) {
        SecureLogger.debug("SolanaServiceStub: Read receipt routing disabled - use Nostr transport", category: .session)
    }
    
    func getNoiseService() -> NoiseEncryptionService {
        fatalError("SolanaServiceStub: Noise service not available - use SolanaService for real encryption")
    }
    
    func sendMessage(_ content: String, mentions: [String]) {
        SecureLogger.debug("SolanaServiceStub: Message broadcasting disabled", category: .session)
    }
    
    func sendFavoriteNotification(to peerID: PeerID, isFavorite: Bool) {
        SecureLogger.debug("SolanaServiceStub: Favorite notifications disabled", category: .session)
    }
    
    func sendBroadcastAnnounce() {
        SecureLogger.debug("SolanaServiceStub: Broadcast announce disabled", category: .session)
    }
    
    func sendDeliveryAck(for messageID: String, to peerID: PeerID) {
        SecureLogger.debug("SolanaServiceStub: Delivery ack disabled", category: .session)
    }
    
    // MARK: - Legacy Methods (No-op)
    
    func sendPublicMessage(_ content: String, nickname: String, messageID: String) {
        SecureLogger.debug("SolanaServiceStub: Public message broadcasting disabled", category: .session)
    }
    
    func requestSync(from peerID: PeerID) {
        SecureLogger.debug("SolanaServiceStub: Sync requests disabled", category: .session)
    }
    
    func updateNetworkState() {
        // No-op
    }
    
    func getCurrentPeers() -> [OliviaPeer] {
        return []
    }
}
