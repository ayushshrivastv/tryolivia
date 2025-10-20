import Foundation
import Combine
import SolanaSwift

// MARK: - Phase 8 Real Solana+Nostr+Noise Manager Implementation

class SolanaManager: ObservableObject {
    @Published var isConnected = false
    @Published var walletAddress: String?
    @Published var balance: UInt64 = 0
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // Real Solana+Nostr+Noise properties
    private var apiClient: JSONRPCAPIClient?
    private var blockchainClient: BlockchainClient?
    private var account: KeyPair?
    private let endpoint: APIEndPoint
    private let accountStorage: SolanaAccountStorage
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    enum SolanaError: Error, LocalizedError {
        case walletNotConnected
        case invalidWalletAddress
        case transactionFailed(String)
        case networkError(String)
        
        var errorDescription: String? {
            switch self {
            case .walletNotConnected:
                return "Wallet not connected"
            case .invalidWalletAddress:
                return "Invalid wallet address"
            case .transactionFailed(let message):
                return "Transaction failed: \(message)"
            case .networkError(let message):
                return "Network error: \(message)"
            }
        }
    }
    
    init() {
        // Initialize endpoint for devnet (change to mainnet for production)
        self.endpoint = APIEndPoint(address: "https://api.devnet.solana.com", network: .devnet)
        
        // Use in-memory storage for now (should be keychain in production)
        self.accountStorage = InMemoryAccountStorage()
        
        setupSolanaClients()
    }
    
    private func setupSolanaClients() {
        // Initialize real Solana+Nostr+Noise clients
        self.apiClient = JSONRPCAPIClient(endpoint: endpoint)
        if let apiClient = self.apiClient {
            self.blockchainClient = BlockchainClient(apiClient: apiClient)
        }
        
        // Try to restore existing account
        Task {
            await restoreExistingAccount()
        }
    }
    
    /// Create or restore embedded wallet (iOS-appropriate approach)
    func createOrRestoreWallet() async throws -> String {
        connectionStatus = .connecting
        
        do {
            // Try to restore existing account first
            if let existingAccount = accountStorage.account {
                self.account = existingAccount
                print("Restored existing wallet")
            } else {
                // Create new account if none exists
                let newAccount = try await KeyPair(network: .devnet)
                try accountStorage.save(newAccount)
                self.account = newAccount
                print("Created new embedded wallet")
            }
            
            guard let account = self.account else {
                throw SolanaError.walletNotConnected
            }
            
            let address = account.publicKey.base58EncodedString
            self.walletAddress = address
            self.isConnected = true
            self.connectionStatus = .connected
            
            // Get real balance from network
            await updateBalance()
            
            return address
        } catch {
            connectionStatus = .error(error.localizedDescription)
            throw SolanaError.networkError(error.localizedDescription)
        }
    }
    
    /// Restore wallet from seed phrase
    func restoreWalletFromSeed(_ seedPhrase: String) async throws -> String {
        connectionStatus = .connecting
        
        do {
            // Create account from seed phrase
            let account = try await KeyPair(phrase: seedPhrase.components(separatedBy: " "), network: .devnet)
            try accountStorage.save(account)
            self.account = account
            
            let address = account.publicKey.base58EncodedString
            self.walletAddress = address
            self.isConnected = true
            self.connectionStatus = .connected
            
            await updateBalance()
            return address
        } catch {
            connectionStatus = .error(error.localizedDescription)
            throw SolanaError.networkError(error.localizedDescription)
        }
    }
    
    /// Disconnect wallet
    func disconnectWallet() async {
        // Clear account from storage if needed
        // Note: For embedded wallets, you might want to keep the account
        // and just mark as disconnected for UX purposes
        account = nil
        walletAddress = nil
        isConnected = false
        balance = 0
        connectionStatus = .disconnected
    }
    
    /// Update wallet balance from network
    private func updateBalance() async {
        guard let account = account,
              let apiClient = apiClient else { return }
        
        do {
            let balanceInfo = try await apiClient.getBalance(
                account: account.publicKey.base58EncodedString,
                commitment: "confirmed"
            )
            
            await MainActor.run {
                self.balance = balanceInfo
            }
        } catch {
            print("Failed to get balance: \(error)")
        }
    }
    
    /// Restore existing account on app launch
    private func restoreExistingAccount() async {
        do {
            if let existingAccount = accountStorage.account {
                self.account = existingAccount
                let address = existingAccount.publicKey.base58EncodedString
                
                await MainActor.run {
                    self.walletAddress = address
                    self.isConnected = true
                    self.connectionStatus = .connected
                }
                
                await updateBalance()
            }
        } catch {
            print("Failed to restore account: \(error)")
        }
    }
    
    /// Prepare and sign a transaction with instructions
    func prepareTransaction(instructions: [TransactionInstruction]) async throws -> PreparedTransaction {
        guard let account = account,
              let blockchainClient = blockchainClient else {
            throw SolanaError.walletNotConnected
        }
        
        do {
            let preparedTransaction = try await blockchainClient.prepareTransaction(
                instructions: instructions,
                signers: [account],
                feePayer: account.publicKey
            )
            return preparedTransaction
        } catch {
            throw SolanaError.transactionFailed(error.localizedDescription)
        }
    }
    
    /// Send a real transaction to the network
    func sendTransaction(_ transaction: PreparedTransaction) async throws -> String {
        guard let blockchainClient = blockchainClient else {
            throw SolanaError.networkError("Blockchain client not initialized")
        }
        
        do {
            let signature = try await blockchainClient.sendTransaction(
                preparedTransaction: transaction
            )
            return signature
        } catch {
            throw SolanaError.transactionFailed(error.localizedDescription)
        }
    }
    
    /// Request airdrop for testing (devnet only)
    func requestAirdrop(amount: UInt64 = 1_000_000_000) async throws {
        guard let account = account,
              let apiClient = apiClient else {
            throw SolanaError.walletNotConnected
        }
        
        do {
            let signature = try await apiClient.requestAirdrop(
                account: account.publicKey.base58EncodedString,
                lamports: amount
            )
            print("Airdrop requested: \(signature)")
            
            // Wait a moment then update balance
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await updateBalance()
        } catch {
            throw SolanaError.networkError(error.localizedDescription)
        }
    }
    
    /// Get current account
    func getCurrentAccount() -> KeyPair? {
        return account
    }
    
    /// Get API client instance
    func getAPIClient() -> JSONRPCAPIClient? {
        return apiClient
    }
    
    /// Get blockchain client instance
    func getBlockchainClient() -> BlockchainClient? {
        return blockchainClient
    }
    
    /// Export seed phrase for backup
    func exportSeedPhrase() throws -> [String] {
        guard let account = account else {
            throw SolanaError.walletNotConnected
        }
        
        // Note: This should be implemented securely with user authentication
        // The KeyPair type should have access to the seed phrase, but we need to be careful about security
        // For now, returning empty array as seed phrase export needs careful security consideration
        return []
    }
    
    /// Connect Phantom wallet (alias for createOrRestoreWallet for compatibility)
    func connectPhantomWallet() async throws -> String {
        return try await createOrRestoreWallet()
    }
    
    /// Connect Solflare wallet (alias for createOrRestoreWallet for compatibility)
    func connectSolflareWallet() async throws -> String {
        return try await createOrRestoreWallet()
    }
}
