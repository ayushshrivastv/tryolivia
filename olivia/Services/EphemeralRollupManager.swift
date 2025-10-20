import Foundation
import SolanaSwift
import Combine

// MARK: - Magic Block Ephemeral Rollups Integration for OLIVIA

/// Magic Block Ephemeral Rollup configuration
struct EphemeralRollupConfig {
    /// OLIVIA DAO Program ID (deployed on devnet)
    static let oliviaDaoProgramId = "BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA"
    
    /// Magic Block Delegation Program ID (official)
    static let delegationProgramId = "DELeGGvXpWV2fqJUhqcF5ZSYMS4JTLjteaAMARRSaeSh"
    
    /// Magic Block Validators (devnet)
    static let validators = [
        "MAS1Dt9qreoRMQ14YQuhg8UTZMMzDdKhmkZMECCzk57", // Asia
        "MEUGGrYPxKk17hCr7wpT6s8dtNokZj5U2L57vjYMS8e", // EU
        "MUS3hc9TCw4cGC12vHNoYcCGzJG1txjgQLZWVoeNHNd", // US
        "FnE6VJT5QNZdedZPnCoLsARgBwoE6DeJNjBs2H1gySXA"  // TEE
    ]
    
    /// Local development validator
    static let localValidator = "mAGicPQYBMvcYveUZA5F5UNNwyHvfYh5xkLS2Fr1mev"
    
    /// Ephemeral Rollup RPC endpoints
    static let ephemeralRPCEndpoints = [
        "https://devnet.magicblock.app", // Primary
        "https://api.devnet.solana.com"  // Fallback
    ]
    
    /// Default validator (Asia region for best performance)
    static let defaultValidator = validators[0]
    
    /// Maximum session duration (30 minutes)
    static let maxSessionDuration: TimeInterval = 30 * 60
    
    /// Auto-commit interval (5 minutes) 
    static let autoCommitInterval: TimeInterval = 5 * 60
    
    /// Batch size for message commits
    static let batchCommitSize: Int = 10
    
    /// Development mode flag
    static let isDevelopment: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    /// Get optimal validator based on location/performance
    static func getOptimalValidator() -> String {
        // For now, use Asia validator as default
        // In production, could implement geo-location based selection
        return isDevelopment ? localValidator : defaultValidator
    }
    
    /// Get primary RPC endpoint
    static func getPrimaryRPCEndpoint() -> String {
        return ephemeralRPCEndpoints[0]
    }
}

/// Ephemeral session state
enum EphemeralSessionState {
    case inactive
    case delegating
    case active
    case committing
    case error(String)
}

/// Ephemeral message for gasless transactions
struct EphemeralMessage {
    let id: String
    let sender: String
    let recipient: String
    let content: Data
    let timestamp: Date
    var isCommitted: Bool = false
    var isDelegated: Bool = false
}

class EphemeralRollupManager: ObservableObject {
    @Published var sessionState: EphemeralSessionState = .inactive
    @Published var activeMessages: [EphemeralMessage] = []
    @Published var gaslessTransactionCount: Int = 0
    @Published var lastCommitTime: Date?
    @Published var sessionStartTime: Date?

    private let solanaManager: SolanaManager
    private let daoInterface: DAOProgramInterface
    private var ephemeralAPIClient: JSONRPCAPIClient?
    private var mainnetAPIClient: JSONRPCAPIClient?
    private var autoCommitTimer: Timer?
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Pending messages for batch commit
    private var pendingMessages: [EphemeralMessage] = []

    init(solanaManager: SolanaManager, daoInterface: DAOProgramInterface) {
        self.solanaManager = solanaManager
        self.daoInterface = daoInterface

        setupConnections()
        setupAutoCommit()
    }

    // MARK: - Connection Setup

    private func setupConnections() {
        // Main Solana+Nostr+Noise connection
        let config = ConfigurationManager.getConfiguration()
        mainnetAPIClient = JSONRPCAPIClient(endpoint: APIEndPoint(
            address: config.rpcEndpoint,
            network: .mainnetBeta
        ))
        
        // Magic Block Ephemeral Rollup connection  
        ephemeralAPIClient = JSONRPCAPIClient(endpoint: APIEndPoint(
            address: EphemeralRollupConfig.getPrimaryRPCEndpoint(),
            network: .mainnetBeta
        ))
        
        print("🔗 Magic Block connections configured:")
        print("  Mainnet: \(config.rpcEndpoint)")
        print("  Ephemeral: \(EphemeralRollupConfig.getPrimaryRPCEndpoint())")
        print("  Delegation Program: \(EphemeralRollupConfig.delegationProgramId)")
        print("  Optimal Validator: \(EphemeralRollupConfig.getOptimalValidator())")
    }

    private func setupAutoCommit() {
        // Auto-commit timer to periodically commit pending messages
        autoCommitTimer = Timer.scheduledTimer(withTimeInterval: EphemeralRollupConfig.autoCommitInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.autoCommitPendingMessages()
            }
        }
    }

    // MARK: - Session Management

    /// Start an Ephemeral Rollup session for gasless messaging
    func startEphemeralSession() async throws {
        guard case .inactive = sessionState else {
            throw EphemeralRollupError.sessionAlreadyActive
        }

        sessionState = .delegating
        sessionStartTime = Date()

        do {
            // Delegate user's member account to Ephemeral Rollup
            try await delegateMemberAccount()

            sessionState = .active

            // Set session timeout
            sessionTimer = Timer.scheduledTimer(withTimeInterval: EphemeralRollupConfig.maxSessionDuration, repeats: false) { [weak self] _ in
                Task {
                    await self?.endEphemeralSession()
                }
            }

            print("Ephemeral Rollup session started successfully")

        } catch {
            sessionState = .error(error.localizedDescription)
            throw error
        }
    }

    /// End the Ephemeral Rollup session and commit all changes
    func endEphemeralSession() async {
        switch sessionState {
        case .active, .committing:
            break
        default:
            return
        }
        
        if case .active = sessionState {
            sessionState = .committing
        }

        sessionState = .committing

        do {
            // Commit all pending messages
            await commitAllPendingMessages()

            // Undelegate member account back to mainnet
            try await undelegateMemberAccount()

            sessionState = .inactive
            sessionStartTime = nil

            // Cancel timers
            autoCommitTimer?.invalidate()
            sessionTimer?.invalidate()

            print("Ephemeral Rollup session ended successfully")

        } catch {
            sessionState = .error(error.localizedDescription)
            print("Failed to end Ephemeral session: \(error)")
        }
    }

    // MARK: - Account Delegation

    private func delegateMemberAccount() async throws {
        guard let account = await solanaManager.getCurrentAccount() else {
            throw EphemeralRollupError.walletNotConnected
        }

        // Create delegation instruction using Magic Block's official delegation program
        let instruction = try createDelegateMemberInstruction(
            member: account.publicKey,
            validator: EphemeralRollupConfig.getOptimalValidator()
        )

        // Send delegation transaction on mainnet
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)

        print("🔗 Member account delegated: \(signature)")
    }

    private func undelegateMemberAccount() async throws {
        guard let account = await solanaManager.getCurrentAccount() else {
            throw EphemeralRollupError.walletNotConnected
        }

        // Create undelegation instruction
        let instruction = try createUndelegateMemberInstruction(
            member: account.publicKey
        )

        // Send undelegation transaction on mainnet
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)

        print("🔓 Member account undelegated: \(signature)")
    }

    // MARK: - Gasless Messaging

    /// Send a gasless message through Ephemeral Rollup
    func sendGaslessMessage(
        to recipient: String,
        content: String,
        messageId: String? = nil
    ) async throws -> String {
        guard case .active = sessionState else {
            throw EphemeralRollupError.sessionNotActive
        }

        guard let account = await solanaManager.getCurrentAccount() else {
            throw EphemeralRollupError.walletNotConnected
        }

        let finalMessageId = messageId ?? UUID().uuidString
        let contentData = content.data(using: .utf8) ?? Data()

        // Create ephemeral message
        let ephemeralMessage = EphemeralMessage(
            id: finalMessageId,
            sender: account.publicKey.base58EncodedString,
            recipient: recipient,
            content: contentData,
            timestamp: Date(),
            isDelegated: true
        )

        do {
            // First, delegate the message PDA to Ephemeral Rollup
            try await delegateMessageAccount(messageId: finalMessageId)

            // Send gasless message within Ephemeral Rollup
            try await sendEphemeralMessage(
                messageId: finalMessageId,
                content: contentData,
                recipient: recipient
            )

            // Add to active messages
            activeMessages.append(ephemeralMessage)
            pendingMessages.append(ephemeralMessage)
            gaslessTransactionCount += 1

            print("Gasless message sent: \(finalMessageId)")
            return finalMessageId

        } catch {
            print("Failed to send gasless message: \(error)")
            throw error
        }
    }

    private func delegateMessageAccount(messageId: String) async throws {
        guard let account = await solanaManager.getCurrentAccount() else {
            throw EphemeralRollupError.walletNotConnected
        }

        let instruction = try createDelegateMessageInstruction(
            messageId: messageId,
            payer: account.publicKey
        )

        // Send on mainnet to delegate the message PDA
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        _ = try await solanaManager.sendTransaction(preparedTransaction)
    }

    private func sendEphemeralMessage(
        messageId: String,
        content: Data,
        recipient: String
    ) async throws {
        guard let ephemeralAPIClient = ephemeralAPIClient else {
            throw EphemeralRollupError.ephemeralConnectionFailed
        }

        guard let account = await solanaManager.getCurrentAccount() else {
            throw EphemeralRollupError.walletNotConnected
        }

        // Create gasless message instruction (executed on Ephemeral Rollup)
        let instruction = try createSendEphemeralMessageInstruction(
            messageId: messageId,
            content: content,
            sender: account.publicKey,
            recipient: try PublicKey(string: recipient)
        )

        // Create transaction for Ephemeral Rollup
        var transaction = Transaction(instructions: [instruction])
        transaction.feePayer = account.publicKey
        
        // Get recent blockhash from Ephemeral Rollup
        let recentBlockhash = try await ephemeralAPIClient.getRecentBlockhash(commitment: nil)
        transaction.recentBlockhash = recentBlockhash
        
        // Sign and send to Ephemeral Rollup (gasless)
        try transaction.sign(signers: [account])
        let signature = try await ephemeralAPIClient.sendTransaction(transaction: transaction.serialize().base64EncodedString())

        print("⚡ Ephemeral message sent: \(signature)")
    }

    // MARK: - Message Committing

    private func autoCommitPendingMessages() async {
        guard case .active = sessionState, !pendingMessages.isEmpty else { return }

        print("Auto-committing \(pendingMessages.count) pending messages...")

        // Commit in batches
        let batches = pendingMessages.chunked(into: EphemeralRollupConfig.batchCommitSize)

        for batch in batches {
            do {
                try await commitMessageBatch(batch)
            } catch {
                print("Failed to commit batch: \(error)")
            }
        }
    }

    private func commitAllPendingMessages() async {
        guard !pendingMessages.isEmpty else { return }

        print("🔄 Committing all \(pendingMessages.count) pending messages...")

        let batches = pendingMessages.chunked(into: EphemeralRollupConfig.batchCommitSize)

        for batch in batches {
            do {
                try await commitMessageBatch(batch)
            } catch {
                print("Failed to commit batch during session end: \(error)")
            }
        }
    }

    private func commitMessageBatch(_ messages: [EphemeralMessage]) async throws {
        let messageIds = messages.map { $0.id }

        // Create batch commit instruction
        let instruction = try await createBatchCommitInstruction(messageIds: messageIds)

        // Send commit transaction on mainnet
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)

        // Update message states
        for messageId in messageIds {
            if let index = pendingMessages.firstIndex(where: { $0.id == messageId }) {
                pendingMessages[index].isCommitted = true
                pendingMessages.remove(at: index)
            }

            if let index = activeMessages.firstIndex(where: { $0.id == messageId }) {
                activeMessages[index].isCommitted = true
            }
        }

        lastCommitTime = Date()
        print("Committed batch of \(messageIds.count) messages: \(signature)")
    }

    // MARK: - Instruction Creation

    private func createDelegateMemberInstruction(
        member: PublicKey,
        validator: String
    ) throws -> TransactionInstruction {
        // Use Magic Block's official delegation program
        let delegationProgramId = try PublicKey(string: EphemeralRollupConfig.delegationProgramId)
        let validatorPubkey = try PublicKey(string: validator)
        let programId = try PublicKey(string: DAOProgramInterface.programID)

        let memberPDA = try PublicKey.findProgramAddress(
            seeds: [
                "member".data(using: .utf8)!,
                member.data
            ],
            programId: programId
        )

        return TransactionInstruction(
            keys: [
                .writable(publicKey: member, isSigner: true),
                .writable(publicKey: memberPDA.0, isSigner: false),
                .readonly(publicKey: validatorPubkey, isSigner: false),
                .readonly(publicKey: delegationProgramId, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: delegationProgramId, // Use Magic Block delegation program
            data: Array(encodeMagicBlockDelegationData(
                pda: memberPDA.0,
                validator: validatorPubkey
            ))
        )
    }

    private func createDelegateMessageInstruction(
        messageId: String,
        payer: PublicKey
    ) throws -> TransactionInstruction {
        let programId = try PublicKey(string: DAOProgramInterface.programID)

        let messagePDA = try PublicKey.findProgramAddress(
            seeds: [
                "message".data(using: .utf8)!,
                messageId.data(using: .utf8)!
            ],
            programId: programId
        )

        return TransactionInstruction(
            keys: [
                .writable(publicKey: payer, isSigner: true),
                .writable(publicKey: messagePDA.0, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: programId,
            data: Array(encodeDelegateMessageData(messageId: messageId))
        )
    }

    private func createSendEphemeralMessageInstruction(
        messageId: String,
        content: Data,
        sender: PublicKey,
        recipient: PublicKey
    ) throws -> TransactionInstruction {
        let programId = try PublicKey(string: DAOProgramInterface.programID)

        let messagePDA = try PublicKey.findProgramAddress(
            seeds: [
                "message".data(using: .utf8)!,
                messageId.data(using: .utf8)!
            ],
            programId: programId
        )

        let recipientPDA = try PublicKey.findProgramAddress(
            seeds: [
                "member".data(using: .utf8)!,
                recipient.data
            ],
            programId: programId
        )

        return TransactionInstruction(
            keys: [
                .writable(publicKey: sender, isSigner: true),
                .writable(publicKey: messagePDA.0, isSigner: false),
                .readonly(publicKey: recipientPDA.0, isSigner: false)
            ],
            programId: programId,
            data: Array(encodeSendEphemeralMessageData(
                messageId: messageId,
                content: content,
                recipient: recipient
            ))
        )
    }

    private func createBatchCommitInstruction(messageIds: [String]) async throws -> TransactionInstruction {
        let programId = try PublicKey(string: DAOProgramInterface.programID)
        
        guard let account = await solanaManager.getCurrentAccount() else {
            throw EphemeralRollupError.walletNotConnected
        }

        return TransactionInstruction(
            keys: [
                .writable(publicKey: account.publicKey, isSigner: true),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: programId,
            data: Array(encodeBatchCommitData(messageIds: messageIds))
        )
    }

    private func createUndelegateMemberInstruction(member: PublicKey) throws -> TransactionInstruction {
        let programId = try PublicKey(string: DAOProgramInterface.programID)

        let memberPDA = try PublicKey.findProgramAddress(
            seeds: [
                "member".data(using: .utf8)!,
                member.data
            ],
            programId: programId
        )

        return TransactionInstruction(
            keys: [
                .writable(publicKey: member, isSigner: true),
                .writable(publicKey: memberPDA.0, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: programId,
            data: Array(encodeUndelegateMemberData())
        )
    }

    // MARK: - Data Encoding
    
    /// Encode data for Magic Block delegation program
    private func encodeMagicBlockDelegationData(pda: PublicKey, validator: PublicKey) -> Data {
        var data = Data()
        
        // Magic Block delegation instruction discriminator
        // This would need to match Magic Block's actual instruction format
        data.append(0) // Delegate instruction
        
        // Add PDA to delegate
        data.append(pda.data)
        
        // Add validator public key
        data.append(validator.data)
        
        return data
    }
    
    private func encodeDelegateMessageData(messageId: String) -> Data {
        var data = Data()
        data.append(11) // Instruction discriminator for delegate_message
        
        let messageIdData = messageId.data(using: .utf8) ?? Data()
        data.append(UInt32(messageIdData.count).littleEndianData)
        data.append(messageIdData)
        
        return data
    }

    private func encodeSendEphemeralMessageData(
        messageId: String,
        content: Data,
        recipient: PublicKey
    ) -> Data {
        var data = Data()
        data.append(12) // Instruction discriminator for send_ephemeral_message

        let messageIdData = messageId.data(using: .utf8) ?? Data()
        data.append(UInt32(messageIdData.count).littleEndianData)
        data.append(messageIdData)

        data.append(UInt32(content.count).littleEndianData)
        data.append(content)

        data.append(recipient.data)

        return data
    }

    private func encodeBatchCommitData(messageIds: [String]) -> Data {
        var data = Data()
        data.append(13) // Instruction discriminator for batch_commit

        data.append(UInt32(messageIds.count).littleEndianData)

        for messageId in messageIds {
            let messageIdData = messageId.data(using: .utf8) ?? Data()
            data.append(UInt32(messageIdData.count).littleEndianData)
            data.append(messageIdData)
        }

        return data
    }

    private func encodeUndelegateMemberData() -> Data {
        var data = Data()
        data.append(14) // Instruction discriminator for undelegate_member
        return data
    }

    // MARK: - Cleanup

    deinit {
        autoCommitTimer?.invalidate()
        sessionTimer?.invalidate()
    }
}

// MARK: - Supporting Types and Extensions

enum EphemeralRollupError: Error, LocalizedError {
    case sessionAlreadyActive
    case sessionNotActive
    case walletNotConnected
    case ephemeralConnectionFailed
    case delegationFailed
    case commitFailed

    var errorDescription: String? {
        switch self {
        case .sessionAlreadyActive:
            return "Ephemeral Rollup session is already active"
        case .sessionNotActive:
            return "No active Ephemeral Rollup session"
        case .walletNotConnected:
            return "Wallet not connected"
        case .ephemeralConnectionFailed:
            return "Failed to connect to Ephemeral Rollup"
        case .delegationFailed:
            return "Failed to delegate account"
        case .commitFailed:
            return "Failed to commit changes"
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Note: UInt32.littleEndianData extension already exists in the project
