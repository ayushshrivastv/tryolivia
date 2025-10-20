import SwiftUI

// MARK: - Phase 10: Economic Dashboard

struct EconomicDashboardView: View {
    @StateObject private var tokenManager: TokenManager
    @State private var showingStakeSheet = false
    @State private var showingUnstakeSheet = false
    @State private var stakeAmount: String = ""
    @State private var unstakeAmount: String = ""
    
    init(tokenManager: TokenManager) {
        self._tokenManager = StateObject(wrappedValue: tokenManager)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Token Balance Section
                    tokenBalanceSection
                    
                    // Staking Section
                    stakingSection
                    
                    // Rewards Section
                    rewardsSection
                    
                    // Economic Activity Section
                    economicActivitySection
                    
                    // Actions Section
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Economic Dashboard")
            .refreshable {
                await tokenManager.refreshTokenBalance()
            }
        }
        .sheet(isPresented: $showingStakeSheet) {
            stakeTokensSheet
        }
        .sheet(isPresented: $showingUnstakeSheet) {
            unstakeTokensSheet
        }
        .task {
            await tokenManager.refreshTokenBalance()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                
                Text("OLIVIA Economic System")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if tokenManager.isLoadingBalance {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text("Decentralized DAO Communication Network")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Token Balance Section
    
    private var tokenBalanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Balance")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // OLIV Balance
                VStack(alignment: .leading, spacing: 4) {
                    Text("OLIV Tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatTokenAmount(tokenManager.olivBalance)) OLIV")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // SOL Balance (from SolanaManager)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("SOL Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("-- SOL")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Staking Section
    
    private var stakingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Relay Node Staking")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Staked Amount")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatTokenAmount(tokenManager.stakedAmount)) OLIV")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Performance Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(tokenManager.relayPerformanceScore, specifier: "%.1f")%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(performanceColor)
                }
            }
            
            if tokenManager.stakedAmount > 0 {
                Text("✅ Relay node active - earning rewards")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Stake OLIV tokens to operate a relay node and earn rewards")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Rewards Section
    
    private var rewardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rewards & Earnings")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pending Rewards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatSOLAmount(tokenManager.pendingRewards)) SOL")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatSOLAmount(tokenManager.totalEarned)) SOL")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            if let lastClaim = tokenManager.lastRewardClaim {
                Text("Last claim: \(lastClaim, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Economic Activity Section
    
    private var economicActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Messages Sent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(tokenManager.messagesSent)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Fees Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatSOLAmount(tokenManager.totalFeesSpent)) SOL")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Claim Rewards Button
            Button(action: {
                Task {
                    do {
                        _ = try await tokenManager.claimRelayRewards()
                    } catch {
                        print("Failed to claim rewards: \(error)")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "gift.fill")
                    Text("Claim Rewards (\(formatSOLAmount(tokenManager.pendingRewards)) SOL)")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(tokenManager.pendingRewards > 0 ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(tokenManager.pendingRewards == 0)
            
            HStack(spacing: 12) {
                // Stake Tokens Button
                Button("Stake Tokens") {
                    showingStakeSheet = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                // Unstake Tokens Button
                Button("Unstake Tokens") {
                    showingUnstakeSheet = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(tokenManager.stakedAmount > 0 ? Color.red : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(tokenManager.stakedAmount == 0)
            }
        }
    }
    
    // MARK: - Stake Tokens Sheet
    
    private var stakeTokensSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Stake OLIV Tokens")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Stake OLIV tokens to operate a relay node and earn rewards from message routing.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount to Stake")
                        .font(.headline)
                    
                    TextField("Enter amount", text: $stakeAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    
                    Text("Minimum stake: \(formatSOLAmount(EconomicParameters.minimumRelayStake)) SOL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Stake Tokens") {
                    Task {
                        if let amount = UInt64(stakeAmount) {
                            do {
                                _ = try await tokenManager.stakeTokensForRelay(amount: amount)
                                showingStakeSheet = false
                                stakeAmount = ""
                            } catch {
                                print("Failed to stake tokens: \(error)")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(stakeAmount.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Stake Tokens")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        showingStakeSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Unstake Tokens Sheet
    
    private var unstakeTokensSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Unstake OLIV Tokens")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Unstaking has a cooldown period. Your tokens will be returned after the cooldown.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount to Unstake")
                        .font(.headline)
                    
                    TextField("Enter amount", text: $unstakeAmount)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    
                    Text("Currently staked: \(formatTokenAmount(tokenManager.stakedAmount)) OLIV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Unstake Tokens") {
                    Task {
                        if let amount = UInt64(unstakeAmount) {
                            do {
                                _ = try await tokenManager.unstakeTokens(amount: amount)
                                showingUnstakeSheet = false
                                unstakeAmount = ""
                            } catch {
                                print("Failed to unstake tokens: \(error)")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(unstakeAmount.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Unstake Tokens")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        showingUnstakeSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var performanceColor: Color {
        if tokenManager.relayPerformanceScore >= 95 {
            return .green
        } else if tokenManager.relayPerformanceScore >= 80 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatTokenAmount(_ amount: UInt64) -> String {
        let decimal = Double(amount) / pow(10, Double(OLIVToken.decimals))
        return String(format: "%.2f", decimal)
    }
    
    private func formatSOLAmount(_ lamports: UInt64) -> String {
        let sol = Double(lamports) / 1_000_000_000.0
        return String(format: "%.4f", sol)
    }
}

// MARK: - Preview

struct EconomicDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSolanaManager = SolanaManager()
        let mockDAOInterface = DAOProgramInterface(solanaManager: mockSolanaManager)
        let mockTokenManager = TokenManager(solanaManager: mockSolanaManager, daoInterface: mockDAOInterface)
        
        EconomicDashboardView(tokenManager: mockTokenManager)
    }
}
