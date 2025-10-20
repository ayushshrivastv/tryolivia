import Foundation
import CryptoKit

// MARK: - Noise Protocol Security Types

enum NoiseSecurityError: Error, LocalizedError {
    case invalidPeerID
    case rateLimitExceeded
    case messageTooLarge
    case sessionNotFound
    case handshakeFailed
    case encryptionFailed
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPeerID:
            return "Invalid peer ID"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .messageTooLarge:
            return "Message too large"
        case .sessionNotFound:
            return "Session not found"
        case .handshakeFailed:
            return "Handshake failed"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        }
    }
}

// MARK: - Noise Session Manager

class NoiseSessionManager {
    private let localStaticKey: Data
    private let keychain: KeychainManagerProtocol
    private var sessions: [String: NoiseSession] = [:]
    
    // Callback properties that NoiseEncryptionService expects
    var onSessionEstablished: ((PeerID, Curve25519.KeyAgreement.PublicKey) -> Void)?
    
    init(localStaticKey: Data, keychain: KeychainManagerProtocol) {
        self.localStaticKey = localStaticKey
        self.keychain = keychain
    }
    
    func getSession(for peerID: PeerID) -> NoiseSession? {
        return sessions[peerID.id]
    }
    
    func createSession(for peerID: PeerID) -> NoiseSession {
        let session = NoiseSession(peerID: peerID, localStaticKey: localStaticKey)
        sessions[peerID.id] = session
        return session
    }
    
    func removeSession(for peerID: PeerID) {
        sessions.removeValue(forKey: peerID.id)
    }
    
    func hasSession(for peerID: PeerID) -> Bool {
        return sessions[peerID.id] != nil
    }
    
    func encrypt(_ data: Data, for peerID: PeerID) throws -> Data {
        guard let session = sessions[peerID.id] else {
            throw NoiseSecurityError.sessionNotFound
        }
        return try session.encrypt(data)
    }
    
    func decrypt(_ data: Data, from peerID: PeerID) throws -> Data {
        guard let session = sessions[peerID.id] else {
            throw NoiseSecurityError.sessionNotFound
        }
        return try session.decrypt(data)
    }
    
    func removeAllSessions() {
        sessions.removeAll()
    }
    
    func getSessionsNeedingRekey() -> [(PeerID, Bool)] {
        // Mock implementation - in real implementation would check session age/usage
        return sessions.map { (PeerID(str: $0.key), false) }
    }
    
    func initiateRekey(for peerID: PeerID) throws {
        // Mock implementation - in real implementation would start rekey process
        guard let session = sessions[peerID.id] else {
            throw NoiseSecurityError.sessionNotFound
        }
        session.setState(.handshakeQueued)
    }
    
    // Methods that NoiseEncryptionService expects
    func getRemoteStaticKey(for peerID: PeerID) -> Curve25519.KeyAgreement.PublicKey? {
        // Mock implementation - return the peer's static key if session exists
        guard let session = sessions[peerID.id] else { return nil }
        // In real implementation, this would return the actual remote static key
        // For now, generate a mock public key
        do {
            let mockPrivateKey = Curve25519.KeyAgreement.PrivateKey()
            return mockPrivateKey.publicKey
        } catch {
            return nil
        }
    }
    
    func initiateHandshake(with peerID: PeerID) throws -> Data {
        // Create or get session
        let session = sessions[peerID.id] ?? createSession(for: peerID)
        
        // Process handshake and return handshake data
        return try session.processHandshakeMessage(Data()) ?? Data("handshake_init".utf8)
    }
    
    func handleIncomingHandshake(from peerID: PeerID, message: Data) throws -> Data? {
        // Create or get session
        let session = sessions[peerID.id] ?? createSession(for: peerID)
        
        // Process the incoming handshake message
        let response = try session.processHandshakeMessage(message)
        
        // If handshake is complete, trigger callback
        if case .established = session.getState() {
            let mockPrivateKey = Curve25519.KeyAgreement.PrivateKey()
            let remoteKey = mockPrivateKey.publicKey // Mock remote key
            onSessionEstablished?(peerID, remoteKey)
        }
        
        return response
    }
}

// MARK: - Noise Session

class NoiseSession {
    let peerID: PeerID
    private let localStaticKey: Data
    private var state: LazyHandshakeState = .none
    private var sendKey: Data?
    private var receiveKey: Data?
    
    init(peerID: PeerID, localStaticKey: Data) {
        self.peerID = peerID
        self.localStaticKey = localStaticKey
    }
    
    func getState() -> LazyHandshakeState {
        return state
    }
    
    func setState(_ newState: LazyHandshakeState) {
        self.state = newState
    }
    
    func processHandshakeMessage(_ message: Data) throws -> Data? {
        // Mock handshake processing
        // In a real implementation, this would use the Noise protocol
        switch state {
        case .none:
            state = .handshaking
            return Data("handshake_response".utf8)
        case .handshaking:
            state = .established
            // Generate mock keys
            sendKey = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            receiveKey = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
            return nil
        case .established:
            throw NoiseSecurityError.handshakeFailed
        case .handshakeQueued:
            state = .handshaking
            return Data("handshake_queued_response".utf8)
        case .failed(_):
            throw NoiseSecurityError.handshakeFailed
        }
    }
    
    func encrypt(_ data: Data) throws -> Data {
        guard case .established = state, let key = sendKey else {
            throw NoiseSecurityError.encryptionFailed
        }
        // Mock encryption - in real implementation would use ChaCha20Poly1305
        var encrypted = data
        for i in 0..<min(data.count, key.count) {
            encrypted[i] = data[i] ^ key[i % key.count]
        }
        return encrypted
    }
    
    func decrypt(_ data: Data) throws -> Data {
        guard case .established = state, let key = receiveKey else {
            throw NoiseSecurityError.decryptionFailed
        }
        // Mock decryption - in real implementation would use ChaCha20Poly1305
        var decrypted = data
        for i in 0..<min(data.count, key.count) {
            decrypted[i] = data[i] ^ key[i % key.count]
        }
        return decrypted
    }
    
    // Method that NoiseEncryptionService expects
    func isEstablished() -> Bool {
        if case .established = state {
            return true
        }
        return false
    }
}

// MARK: - Noise Security Validator

struct NoiseSecurityValidator {
    static let maxHandshakeMessageSize = 1024 * 4  // 4KB
    static let maxMessageSize = 1024 * 64          // 64KB
    
    static func validateHandshakeMessageSize(_ message: Data) -> Bool {
        return message.count <= maxHandshakeMessageSize
    }
    
    static func validateMessageSize(_ message: Data) -> Bool {
        return message.count <= maxMessageSize
    }
}

// MARK: - Noise Rate Limiter

class NoiseRateLimiter {
    private var handshakeAttempts: [String: [Date]] = [:]
    private var messageAttempts: [String: [Date]] = [:]
    
    private let maxHandshakesPerMinute = 10
    private let maxMessagesPerSecond = 100
    
    func allowHandshake(from peerID: PeerID) -> Bool {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // Clean old attempts
        handshakeAttempts[peerID.id] = handshakeAttempts[peerID.id]?.filter { $0 > oneMinuteAgo } ?? []
        
        // Check if under limit
        let recentAttempts = handshakeAttempts[peerID.id]?.count ?? 0
        if recentAttempts >= maxHandshakesPerMinute {
            return false
        }
        
        // Record this attempt
        handshakeAttempts[peerID.id, default: []].append(now)
        return true
    }
    
    func allowMessage(from peerID: PeerID) -> Bool {
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1)
        
        // Clean old attempts
        messageAttempts[peerID.id] = messageAttempts[peerID.id]?.filter { $0 > oneSecondAgo } ?? []
        
        // Check if under limit
        let recentAttempts = messageAttempts[peerID.id]?.count ?? 0
        if recentAttempts >= maxMessagesPerSecond {
            return false
        }
        
        // Record this attempt
        messageAttempts[peerID.id, default: []].append(now)
        return true
    }
    
    func resetAll() {
        handshakeAttempts.removeAll()
        messageAttempts.removeAll()
    }
}

// Note: LazyHandshakeState is already defined in OliviaProtocol.swift
