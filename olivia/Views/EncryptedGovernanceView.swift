import SwiftUI
import AppKit

struct EncryptedGovernanceView: View {
    @StateObject private var arciumService: ArciumIntegrationService
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    @State private var showCreateProposal = false
    @State private var showVoteSheet = false
    @State private var selectedProposal: EncryptedProposal?
    @State private var proposals: [EncryptedProposal] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(solanaManager: SolanaManager) {
        _arciumService = StateObject(wrappedValue: ArciumIntegrationService(solanaManager: solanaManager))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Arcium Status Header
                arciumStatusHeader
                
                // Proposals List
                if isLoading {
                    ProgressView("Loading encrypted proposals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if proposals.isEmpty {
                    emptyStateView
                } else {
                    proposalsList
                }
            }
            .navigationTitle("🔐 Encrypted Governance")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateProposal = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                    .disabled(!arciumService.isArciumEnabled)
                }
            }
            .sheet(isPresented: $showCreateProposal) {
                // TODO: Implement CreateEncryptedProposalView
                Text("Create Encrypted Proposal - Coming Soon")
                    .padding()
            }
            .sheet(isPresented: $showVoteSheet) {
                if selectedProposal != nil {
                    // TODO: Implement EncryptedVoteView
                    Text("Encrypted Vote - Coming Soon")
                        .padding()
                }
            }
            .onAppear {
                loadEncryptedProposals()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var arciumStatusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(arciumService.isArciumEnabled ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arcium Encrypted Compute")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(arciumStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusIndicator
            }
            .padding(.horizontal)
            
            if !arciumService.isArciumEnabled {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("Encrypted governance provides anonymous voting and hidden proposer identities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
    }
    
    private var arciumStatusText: String {
        switch arciumService.encryptedComputeStatus {
        case .disconnected:
            return "Disconnected from Arcium network"
        case .connecting:
            return "Connecting to encrypted compute..."
        case .connected:
            return "Connected - Privacy-preserving governance active"
        case .computing:
            return "Processing encrypted computation..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 4)
                    .scaleEffect(arciumService.encryptedComputeStatus == .computing ? 1.5 : 1.0)
                    .opacity(arciumService.encryptedComputeStatus == .computing ? 0 : 1)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: false), 
                              value: arciumService.encryptedComputeStatus == .computing)
            )
    }
    
    private var statusColor: Color {
        switch arciumService.encryptedComputeStatus {
        case .connected:
            return .green
        case .connecting, .computing:
            return .blue
        case .error:
            return .red
        case .disconnected:
            return .gray
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.doc.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Encrypted Proposals")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create the first privacy-preserving proposal where your identity remains hidden")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Encrypted Proposal") {
                showCreateProposal = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!arciumService.isArciumEnabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var proposalsList: some View {
        List(proposals) { proposal in
            EncryptedProposalRow(proposal: proposal) {
                selectedProposal = proposal
                showVoteSheet = true
            }
        }
        .listStyle(.plain)
    }
    
    private func loadEncryptedProposals() {
        isLoading = true
        
        Task {
            // In a real implementation, this would fetch encrypted proposals
            // For now, we'll use mock data
            let mockProposals = createMockEncryptedProposals()
            
            await MainActor.run {
                self.proposals = mockProposals
                self.isLoading = false
            }
        }
    }
    
    private func createMockEncryptedProposals() -> [EncryptedProposal] {
        return [
            EncryptedProposal(
                id: 1,
                encryptedTitle: "🔒 Hidden Proposal #1",
                encryptedDescription: "Proposal details encrypted - vote to reveal results",
                proposalType: .updateMessageFee,
                status: .active,
                votingEndsAt: Date().addingTimeInterval(86400 * 5), // 5 days
                encryptedVoteCount: 42
            ),
            EncryptedProposal(
                id: 2,
                encryptedTitle: "🔒 Hidden Proposal #2", 
                encryptedDescription: "Anonymous governance proposal - proposer identity protected",
                proposalType: .addRelayNode,
                status: .active,
                votingEndsAt: Date().addingTimeInterval(86400 * 3), // 3 days
                encryptedVoteCount: 28
            )
        ]
    }
}

struct EncryptedProposalRow: View {
    let proposal: EncryptedProposal
    let onVote: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.encryptedTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(proposal.encryptedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    proposalStatusBadge
                    
                    Text("\(proposal.encryptedVoteCount) encrypted votes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label(proposal.proposalType.displayName, systemImage: proposal.proposalType.icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("Ends \(proposal.votingEndsAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Vote Privately") {
                    onVote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var proposalStatusBadge: some View {
        Text(proposal.status.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(proposal.status.color.opacity(0.2))
            .foregroundColor(proposal.status.color)
            .cornerRadius(8)
    }
}

// MARK: - Data Models

struct EncryptedProposal: Identifiable {
    let id: UInt64
    let encryptedTitle: String
    let encryptedDescription: String
    let proposalType: ProposalType
    let status: ProposalStatus
    let votingEndsAt: Date
    let encryptedVoteCount: Int
}

enum ProposalStatus {
    case active
    case passed
    case rejected
    case executed
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .passed: return "Passed"
        case .rejected: return "Rejected"
        case .executed: return "Executed"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .blue
        case .passed: return .green
        case .rejected: return .red
        case .executed: return .purple
        }
    }
}

extension ProposalType {
    var displayName: String {
        switch self {
        case .updateMessageFee: return "Update Message Fee"
        case .updateRelayRewards: return "Update Relay Rewards"
        case .addRelayNode: return "Add Relay Node"
        case .removeRelayNode: return "Remove Relay Node"
        case .treasuryAllocation: return "Treasury Allocation"
        }
    }
    
    var icon: String {
        switch self {
        case .updateMessageFee: return "dollarsign.circle"
        case .updateRelayRewards: return "gift.circle"
        case .addRelayNode: return "plus.circle"
        case .removeRelayNode: return "minus.circle"
        case .treasuryAllocation: return "banknote"
        }
    }
}

#Preview {
    EncryptedGovernanceView(solanaManager: SolanaManager())
        .environmentObject(ChatViewModel(keychain: KeychainManager(), identityManager: SecureIdentityStateManager(KeychainManager())))
}
