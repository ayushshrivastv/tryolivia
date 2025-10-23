import Foundation
import SolanaSwift

/// Service for managing usernames and username-based payments in OLIVIA DAO
@MainActor
class UsernameService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentUsername: String?
    @Published var isUsernameRegistered: Bool = false
    @Published var availableUsernames: [String] = []
    @Published var paymentHistory: [PaymentRecord] = []
    
    // MARK: - Dependencies
    
    private let solanaManager: SolanaManager
    private let ephemeralRollupManager: EphemeralRollupManager
    private let daoProgramInterface: DAOProgramInterface
    
    // MARK: - Constants
    
    private let usernameStorageKey = "olivia_username"
    private let minUsernameLength = 3
    private let maxUsernameLength = 20
    
    // MARK: - Initialization
    
    init(
        solanaManager: SolanaManager,
        ephemeralRollupManager: EphemeralRollupManager,
        daoProgramInterface: DAOProgramInterface
    ) {
        self.solanaManager = solanaManager
        self.ephemeralRollupManager = ephemeralRollupManager
        self.daoProgramInterface = daoProgramInterface
        
        loadStoredUsername()
    }
    
    // MARK: - Username Registration
    
    /// Check if a username is available for registration
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        guard isValidUsername(username) else {
            throw UsernameError.invalidFormat
        }
        
        // Check on-chain if username is already taken
        do {
            let _ = try await resolveUsernameToWallet(username)
            return false // Username exists, not available
        } catch UsernameError.usernameNotFound {
            return true // Username not found, available
        } catch {
            throw error // Other error occurred
        }
    }
    
    /// Register a username for the current wallet
    func registerUsername(_ username: String) async throws {
        guard let walletAddress = solanaManager.walletAddress else {
            throw UsernameError.walletNotConnected
        }
        
        guard isValidUsername(username) else {
            throw UsernameError.invalidFormat
        }
        
        guard try await isUsernameAvailable(username) else {
            throw UsernameError.usernameAlreadyTaken
        }
        
        // Register username on-chain
        try await daoProgramInterface.registerUsername(username)
        
        // Store locally
        currentUsername = username
        isUsernameRegistered = true
        UserDefaults.standard.set(username, forKey: usernameStorageKey)
        
        print("✅ Username '\(username)' registered successfully")
    }
    
    /// Update current username
    func updateUsername(_ newUsername: String) async throws {
        guard isUsernameRegistered else {
            throw UsernameError.noUsernameRegistered
        }
        
        guard isValidUsername(newUsername) else {
            throw UsernameError.invalidFormat
        }
        
        guard try await isUsernameAvailable(newUsername) else {
            throw UsernameError.usernameAlreadyTaken
        }
        
        // Update username on-chain
        try await daoProgramInterface.updateUsername(newUsername)
        
        // Update locally
        currentUsername = newUsername
        UserDefaults.standard.set(newUsername, forKey: usernameStorageKey)
        
        print("✅ Username updated to '\(newUsername)'")
    }
    
    // MARK: - Username Resolution
    
    /// Resolve a username to wallet address
    func resolveUsernameToWallet(_ username: String) async throws -> String {
        guard isValidUsername(username) else {
            throw UsernameError.invalidFormat
        }
        
        // Query on-chain username registry
        do {
            let walletAddress = try await daoProgramInterface.resolveUsername(username)
            return walletAddress
        } catch {
            throw UsernameError.usernameNotFound
        }
    }
    
    /// Search for usernames matching a query
    func searchUsernames(_ query: String) async throws -> [UsernameSearchResult] {
        guard query.count >= 2 else { return [] }
        
        // This would query the on-chain registry for matching usernames
        // For now, return empty array - would need to implement pagination
        // and filtering on the Solana program side
        return []
    }
    
    // MARK: - Payment Functions
    
    /// Send SOL with message to a username (gasless via Magic Block)
    func sendPaymentToUsername(
        username: String,
        amount: UInt64, // Amount in lamports
        message: String
    ) async throws -> String {
        guard let senderWallet = solanaManager.walletAddress else {
            throw UsernameError.walletNotConnected
        }
        
        guard isValidUsername(username) else {
            throw UsernameError.invalidFormat
        }
        
        guard amount > 0 else {
            throw UsernameError.invalidAmount
        }
        
        guard message.count <= 280 else {
            throw UsernameError.messageTooLong
        }
        
        // Resolve username to wallet address
        let recipientWallet = try await resolveUsernameToWallet(username)
        
        // Send gasless payment via Magic Block
        let transactionId = try await ephemeralRollupManager.sendGaslessPaymentToUsername(
            username: username,
            amount: amount,
            message: message
        )
        
        // Add to local payment history
        let paymentRecord = PaymentRecord(
            id: transactionId,
            sender: senderWallet,
            recipient: recipientWallet,
            recipientUsername: username,
            amount: amount,
            message: message,
            timestamp: Date(),
            isGasless: true
        )
        
        paymentHistory.append(paymentRecord)
        
        print("💸 Sent \(Double(amount) / 1_000_000_000) SOL to @\(username): '\(message)'")
        return transactionId
    }
    
    /// Parse payment command from chat message
    func parsePaymentCommand(_ message: String) -> PaymentCommand? {
        // Parse messages like:
        // "Send 0.1 SOL to @alice"
        // "Send 0.5 SOL to @bob with message: Coffee payment"
        // "@alice 0.1 SOL for coffee"
        
        let patterns = [
            // "Send X SOL to @username"
            #"(?i)send\s+([0-9]*\.?[0-9]+)\s+sol\s+to\s+@(\w+)(?:\s+(?:with\s+message:?\s*)?(.+))?"#,
            // "@username X SOL for message"
            #"@(\w+)\s+([0-9]*\.?[0-9]+)\s+sol(?:\s+for\s+(.+))?"#,
            // "Pay @username X SOL"
            #"(?i)pay\s+@(\w+)\s+([0-9]*\.?[0-9]+)\s+sol(?:\s+(.+))?"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: message, options: [], range: NSRange(location: 0, length: message.count)) {
                
                var username: String = ""
                var amountString: String = ""
                var paymentMessage: String = ""
                
                // Extract based on pattern type
                if pattern.contains("send") {
                    // "Send X SOL to @username"
                    if match.numberOfRanges >= 3 {
                        amountString = String(message[Range(match.range(at: 1), in: message)!])
                        username = String(message[Range(match.range(at: 2), in: message)!])
                        if match.numberOfRanges >= 4 && match.range(at: 3).location != NSNotFound {
                            paymentMessage = String(message[Range(match.range(at: 3), in: message)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                } else {
                    // "@username X SOL" patterns
                    if match.numberOfRanges >= 3 {
                        username = String(message[Range(match.range(at: 1), in: message)!])
                        amountString = String(message[Range(match.range(at: 2), in: message)!])
                        if match.numberOfRanges >= 4 && match.range(at: 3).location != NSNotFound {
                            paymentMessage = String(message[Range(match.range(at: 3), in: message)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                }
                
                // Convert amount to lamports
                if let amount = Double(amountString) {
                    let lamports = UInt64(amount * 1_000_000_000) // Convert SOL to lamports
                    
                    return PaymentCommand(
                        username: username,
                        amount: lamports,
                        message: paymentMessage.isEmpty ? "Payment via OLIVIA" : paymentMessage
                    )
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func loadStoredUsername() {
        if let storedUsername = UserDefaults.standard.string(forKey: usernameStorageKey) {
            currentUsername = storedUsername
            isUsernameRegistered = true
        }
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        guard username.count >= minUsernameLength && username.count <= maxUsernameLength else {
            return false
        }
        
        // Only alphanumeric and underscore allowed
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return username.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
}

// MARK: - Data Models

struct PaymentRecord: Identifiable, Codable {
    let id: String
    let sender: String
    let recipient: String
    let recipientUsername: String
    let amount: UInt64
    let message: String
    let timestamp: Date
    let isGasless: Bool
}

struct PaymentCommand {
    let username: String
    let amount: UInt64 // in lamports
    let message: String
}

struct UsernameSearchResult: Identifiable {
    let id = UUID()
    let username: String
    let walletAddress: String
    let registeredAt: Date
}

// MARK: - Errors

enum UsernameError: Error, LocalizedError {
    case walletNotConnected
    case invalidFormat
    case usernameAlreadyTaken
    case usernameNotFound
    case noUsernameRegistered
    case invalidAmount
    case messageTooLong
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .walletNotConnected:
            return "Wallet not connected"
        case .invalidFormat:
            return "Username must be 3-20 characters, alphanumeric and underscore only"
        case .usernameAlreadyTaken:
            return "Username is already taken"
        case .usernameNotFound:
            return "Username not found"
        case .noUsernameRegistered:
            return "No username registered for this wallet"
        case .invalidAmount:
            return "Invalid payment amount"
        case .messageTooLong:
            return "Message too long (max 280 characters)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
