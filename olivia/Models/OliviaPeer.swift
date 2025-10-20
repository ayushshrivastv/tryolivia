import Foundation

/// Represents a peer in the OLIVIA network with all associated metadata
struct OliviaPeer: Equatable {
    let peerID: PeerID // Hex-encoded peer ID
    let noisePublicKey: Data
    let nickname: String
    let lastSeen: Date
    let isConnected: Bool
    let isReachable: Bool
    
    // Favorite-related properties
    var favoriteStatus: FavoritesPersistenceService.FavoriteRelationship?
    
    // Nostr identity (if known)
    var nostrPublicKey: String?
    
    // Connection state
    enum ConnectionState {
        case solanaConnected    // Connected via Solana+Nostr+Noise network
        case nostrAvailable     // Reachable via Nostr relays
        case offline            // Not connected via any transport
    }
    
    var connectionState: ConnectionState {
        if isConnected {
            return .solanaConnected
        } else if favoriteStatus?.isMutual == true || nostrPublicKey != nil {
            // Available via Nostr relays
            return .nostrAvailable
        } else {
            return .offline
        }
    }
    
    var isFavorite: Bool {
        favoriteStatus?.isFavorite ?? false
    }
    
    var isMutualFavorite: Bool {
        favoriteStatus?.isMutual ?? false
    }
    
    var theyFavoritedUs: Bool {
        favoriteStatus?.theyFavoritedUs ?? false
    }
    
    // Display helpers
    var displayName: String {
        nickname.isEmpty ? String(peerID.id.prefix(8)) : nickname
    }
    
    var statusIcon: String {
        switch connectionState {
        case .solanaConnected:
            return "🔗" // Link icon for Solana+Nostr+Noise connection
        case .nostrAvailable:
            return "📡" // Antenna for Nostr relays
        case .offline:
            if theyFavoritedUs && !isFavorite {
                return "🌙" // Crescent moon - they favorited us but we didn't reciprocate
            } else {
                return ""
            }
        }
    }
    
    // Initialize from network service data
    init(
        peerID: PeerID,
        noisePublicKey: Data,
        nickname: String,
        lastSeen: Date = Date(),
        isConnected: Bool = false,
        isReachable: Bool = false
    ) {
        self.peerID = peerID
        self.noisePublicKey = noisePublicKey
        self.nickname = nickname
        self.lastSeen = lastSeen
        self.isConnected = isConnected
        self.isReachable = isReachable
        
        // Load favorite status - will be set later by the manager
        self.favoriteStatus = nil
        self.nostrPublicKey = nil
    }
    
    static func == (lhs: OliviaPeer, rhs: OliviaPeer) -> Bool {
        lhs.peerID == rhs.peerID
    }
}
