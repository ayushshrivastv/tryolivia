import Foundation
import SolanaSwift
import Combine

// MARK: - Phase 10: Economic System Activation

/// OLIVIA Token (OLIV) - Governance and utility token for the DAO
struct OLIVToken {
    static let mintAddress = "OLIV_TOKEN_MINT_ADDRESS_PLACEHOLDER" // Will be replaced with real mint
    static let decimals: UInt8 = 9
    static let symbol = "OLIV"
    static let name = "OLIVIA DAO Token"
}

/// Economic parameters for the network
struct EconomicParameters {
    static let messageFeeSOL: UInt64 = 1_000_000 // 0.001 SOL in lamports
    static let relayRewardShare: Double = 0.70    // 70% to relay operators
    static let treasuryShare: Double = 0.20       // 20% to DAO treasury
    static let developmentShare: Double = 0.10    // 10% to development fund
    
    static let minimumRelayStake: UInt64 = 1_000_000_000 // 1 SOL minimum stake
    static let rewardDistributionInterval: TimeInterval = 3600 // 1 hour
}

class TokenManager: ObservableObject {
    @Published var olivBalance: UInt64 = 0
    @Published var stakedAmount: UInt64 = 0
    @Published var pendingRewards: UInt64 = 0
    @Published var totalEarned: UInt64 = 0
    @Published var isLoadingBalance = false
    @Published var lastRewardClaim: Date?
    
    private let solanaManager: SolanaManager
    private let daoInterface: DAOProgramInterface
    private var cancellables = Set<AnyCancellable>()
    
    // Economic tracking
    @Published var messagesSent: Int = 0
    @Published var totalFeesSpent: UInt64 = 0
    @Published var relayPerformanceScore: Double = 0.0
    
    init(solanaManager: SolanaManager, daoInterface: DAOProgramInterface) {
        self.solanaManager = solanaManager
        self.daoInterface = daoInterface
        
        // Auto-refresh balance every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.refreshTokenBalance()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Token Balance Management
    
    func refreshTokenBalance() async {
        isLoadingBalance = true
        defer { isLoadingBalance = false }
        
        do {
            // Get OLIV token balance
            let balance = try await getOLIVTokenBalance()
            await MainActor.run {
                self.olivBalance = balance
            }
            
            // Get staking information
            let stakingInfo = try await getStakingInfo()
            await MainActor.run {
                self.stakedAmount = stakingInfo.stakedAmount
                self.pendingRewards = stakingInfo.pendingRewards
                self.totalEarned = stakingInfo.totalEarned
            }
            
        } catch {
            print("Failed to refresh token balance: \(error)")
        }
    }
    
    private func getOLIVTokenBalance() async throws -> UInt64 {
        guard let walletAddress = solanaManager.walletAddress else {
            throw TokenError.walletNotConnected
        }
        
        // For Phase 10, return mock balance
        // In production, this would query the actual SPL token account
        return 1000 * UInt64(pow(10, Double(OLIVToken.decimals))) // 1000 OLIV tokens
    }
    
    private func getStakingInfo() async throws -> StakingInfo {
        // For Phase 10, return mock staking info
        // In production, this would query the DAO program accounts
        return StakingInfo(
            stakedAmount: 500 * UInt64(pow(10, Double(OLIVToken.decimals))), // 500 OLIV staked
            pendingRewards: 50 * 1_000_000, // 0.05 SOL pending
            totalEarned: 200 * 1_000_000     // 0.2 SOL total earned
        )
    }
    
    // MARK: - Economic Transactions
    
    /// Pay message fee when sending a message
    func payMessageFee() async throws -> String {
        guard let account = await solanaManager.getCurrentAccount() else {
            throw TokenError.walletNotConnected
        }
        
        // Create fee payment instruction
        let instruction = try createMessageFeeInstruction(
            sender: account.publicKey,
            feeAmount: EconomicParameters.messageFeeSOL
        )
        
        // Send transaction
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)
        
        // Update local tracking
        await MainActor.run {
            self.messagesSent += 1
            self.totalFeesSpent += EconomicParameters.messageFeeSOL
        }
        
        print("💰 Message fee paid: \(EconomicParameters.messageFeeSOL) lamports")
        return signature
    }
    
    /// Stake OLIV tokens to operate a relay node
    func stakeTokensForRelay(amount: UInt64) async throws -> String {
        guard amount >= EconomicParameters.minimumRelayStake else {
            throw TokenError.insufficientStakeAmount
        }
        
        guard let account = await solanaManager.getCurrentAccount() else {
            throw TokenError.walletNotConnected
        }
        
        // Create staking instruction
        let instruction = try createStakeInstruction(
            staker: account.publicKey,
            amount: amount
        )
        
        // Send transaction
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)
        
        // Update local state
        await MainActor.run {
            self.stakedAmount += amount
            self.olivBalance -= amount
        }
        
        print("🔒 Staked \(amount) OLIV tokens for relay operation")
        return signature
    }
    
    /// Claim pending rewards from relay operation
    func claimRelayRewards() async throws -> String {
        guard pendingRewards > 0 else {
            throw TokenError.noRewardsToClaim
        }
        
        guard let account = await solanaManager.getCurrentAccount() else {
            throw TokenError.walletNotConnected
        }
        
        // Create claim rewards instruction
        let instruction = try createClaimRewardsInstruction(
            claimer: account.publicKey
        )
        
        // Send transaction
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)
        
        // Update local state
        let claimedAmount = pendingRewards
        await MainActor.run {
            self.totalEarned += claimedAmount
            self.pendingRewards = 0
            self.lastRewardClaim = Date()
        }
        
        print("💎 Claimed \(claimedAmount) lamports in relay rewards")
        return signature
    }
    
    /// Unstake OLIV tokens (with cooldown period)
    func unstakeTokens(amount: UInt64) async throws -> String {
        guard amount <= stakedAmount else {
            throw TokenError.insufficientStakedAmount
        }
        
        guard let account = await solanaManager.getCurrentAccount() else {
            throw TokenError.walletNotConnected
        }
        
        // Create unstaking instruction
        let instruction = try createUnstakeInstruction(
            unstaker: account.publicKey,
            amount: amount
        )
        
        // Send transaction
        let preparedTransaction = try await solanaManager.prepareTransaction(instructions: [instruction])
        let signature = try await solanaManager.sendTransaction(preparedTransaction)
        
        // Update local state
        await MainActor.run {
            self.stakedAmount -= amount
            // Note: Tokens will be returned after cooldown period
        }
        
        print("🔓 Initiated unstaking of \(amount) OLIV tokens")
        return signature
    }
    
    // MARK: - Instruction Creation
    
    private func createMessageFeeInstruction(sender: PublicKey, feeAmount: UInt64) throws -> TransactionInstruction {
        // Create instruction to pay message fee to DAO treasury
        // This would interact with the DAO program's route_message instruction
        
        let daoTreasuryPDA = try PublicKey.findProgramAddress(
            seeds: [
                "treasury".data(using: .utf8)!
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID)
        )
        
        return TransactionInstruction(
            keys: [
                .writable(publicKey: sender, isSigner: true),
                .writable(publicKey: daoTreasuryPDA.0, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID),
            data: Array(encodeMessageFeeData(feeAmount: feeAmount))
        )
    }
    
    private func createStakeInstruction(staker: PublicKey, amount: UInt64) throws -> TransactionInstruction {
        // Create instruction to stake OLIV tokens for relay operation
        
        let stakingPDA = try PublicKey.findProgramAddress(
            seeds: [
                "staking".data(using: .utf8)!,
                staker.data
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID)
        )
        
        return TransactionInstruction(
            keys: [
                .writable(publicKey: staker, isSigner: true),
                .writable(publicKey: stakingPDA.0, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID),
            data: Array(encodeStakeData(amount: amount))
        )
    }
    
    private func createClaimRewardsInstruction(claimer: PublicKey) throws -> TransactionInstruction {
        // Create instruction to claim pending relay rewards
        
        let rewardsPDA = try PublicKey.findProgramAddress(
            seeds: [
                "rewards".data(using: .utf8)!,
                claimer.data
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID)
        )
        
        return TransactionInstruction(
            keys: [
                .writable(publicKey: claimer, isSigner: true),
                .writable(publicKey: rewardsPDA.0, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID),
            data: Array(encodeClaimRewardsData())
        )
    }
    
    private func createUnstakeInstruction(unstaker: PublicKey, amount: UInt64) throws -> TransactionInstruction {
        // Create instruction to unstake OLIV tokens
        
        let stakingPDA = try PublicKey.findProgramAddress(
            seeds: [
                "staking".data(using: .utf8)!,
                unstaker.data
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID)
        )
        
        return TransactionInstruction(
            keys: [
                .writable(publicKey: unstaker, isSigner: true),
                .writable(publicKey: stakingPDA.0, isSigner: false),
                .readonly(publicKey: SystemProgram.id, isSigner: false)
            ],
            programId: try PublicKey(string: DAOProgramInterface.programID),
            data: Array(encodeUnstakeData(amount: amount))
        )
    }
    
    // MARK: - Data Encoding
    
    private func encodeMessageFeeData(feeAmount: UInt64) -> Data {
        var data = Data()
        data.append(3) // Instruction discriminator for pay_message_fee
        data.append(feeAmount.littleEndianData)
        return data
    }
    
    private func encodeStakeData(amount: UInt64) -> Data {
        var data = Data()
        data.append(4) // Instruction discriminator for stake_tokens
        data.append(amount.littleEndianData)
        return data
    }
    
    private func encodeClaimRewardsData() -> Data {
        var data = Data()
        data.append(5) // Instruction discriminator for claim_rewards
        return data
    }
    
    private func encodeUnstakeData(amount: UInt64) -> Data {
        var data = Data()
        data.append(6) // Instruction discriminator for unstake_tokens
        data.append(amount.littleEndianData)
        return data
    }
}

// MARK: - Supporting Types

struct StakingInfo {
    let stakedAmount: UInt64
    let pendingRewards: UInt64
    let totalEarned: UInt64
}

enum TokenError: Error, LocalizedError {
    case walletNotConnected
    case insufficientBalance
    case insufficientStakeAmount
    case insufficientStakedAmount
    case noRewardsToClaim
    case tokenAccountNotFound
    case invalidTokenMint
    
    var errorDescription: String? {
        switch self {
        case .walletNotConnected:
            return "Wallet not connected"
        case .insufficientBalance:
            return "Insufficient token balance"
        case .insufficientStakeAmount:
            return "Minimum stake amount is \(EconomicParameters.minimumRelayStake) lamports"
        case .insufficientStakedAmount:
            return "Insufficient staked amount"
        case .noRewardsToClaim:
            return "No rewards available to claim"
        case .tokenAccountNotFound:
            return "Token account not found"
        case .invalidTokenMint:
            return "Invalid token mint address"
        }
    }
}

// MARK: - Extensions

// Note: littleEndianData extension already exists in the project
