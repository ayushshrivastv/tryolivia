import Foundation
import SolanaSwift

// MARK: - Account Storage Protocol Implementation

/// In-memory account storage for development/testing
class InMemoryAccountStorage: SolanaAccountStorage {
    private var _account: KeyPair?
    
    func save(_ account: KeyPair) throws {
        _account = account
    }
    
    var account: KeyPair? {
        _account
    }
}

/// Keychain-based account storage for production
struct KeychainAccountStorage: SolanaAccountStorage {
    private let keychain: KeychainManagerProtocol
    private let accountKey = "olivia.solana+Nostr+Noise.account"
    
    init(keychain: KeychainManagerProtocol) {
        self.keychain = keychain
    }
    
    func save(_ account: KeyPair) throws {
        let data = try JSONEncoder().encode(account)
        _ = keychain.saveIdentityKey(data, forKey: accountKey)
    }
    
    var account: KeyPair? {
        guard let data = keychain.getIdentityKey(forKey: accountKey) else { return nil }
        return try? JSONDecoder().decode(KeyPair.self, from: data)
    }
}
