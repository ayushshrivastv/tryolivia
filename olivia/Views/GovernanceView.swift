import SwiftUI

struct GovernanceView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showCreateProposal = false
    @State private var proposals: [DAOProposal] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with DAO stats
                daoStatsHeader
                
                Divider()
                
                // Proposals list
                if isLoading {
                    ProgressView("Loading proposals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if proposals.isEmpty {
                    emptyProposalsView
                } else {
                    proposalsList
                }
            }
            .navigationTitle("DAO Governance")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Proposal") {
                        showCreateProposal = true
                    }
                    .disabled(!viewModel.isDAOMember)
                }
            }
            .sheet(isPresented: $showCreateProposal) {
                CreateProposalView()
                    .environmentObject(viewModel)
            }
            .onAppear {
                loadProposals()
            }
        }
    }
    
    private var daoStatsHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAO Status")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        Label {
                            Text(viewModel.isDAOMember ? "Member" : "Not Member")
                                .font(.caption)
                        } icon: {
                            Image(systemName: viewModel.isDAOMember ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(viewModel.isDAOMember ? .green : .red)
                        }
                        
                        if let address = viewModel.walletAddress {
                            Label {
                                Text(String(address.prefix(8)) + "...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "wallet.pass.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Treasury")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("1,234 SOL")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            
            // Governance stats
            HStack(spacing: 20) {
                StatCard(title: "Active Proposals", value: "\(proposals.filter { !$0.executed && !$0.cancelled }.count)")
                StatCard(title: "Total Members", value: "156")
                StatCard(title: "Voting Power", value: viewModel.isDAOMember ? "1.2K" : "0")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    private var emptyProposalsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Proposals Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Be the first to create a governance proposal for the OLIVIA DAO")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if viewModel.isDAOMember {
                Button("Create First Proposal") {
                    showCreateProposal = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Join DAO to Participate") {
                    Task {
                        try await viewModel.joinDAO()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var proposalsList: some View {
        List(proposals) { proposal in
            ProposalRowView(proposal: proposal)
                .environmentObject(viewModel)
        }
        .listStyle(PlainListStyle())
    }
    
    private func loadProposals() {
        isLoading = true
        
        // Mock proposals for now - in real implementation, fetch from DAO
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.proposals = [
                DAOProposal(
                    id: 1,
                    title: "Reduce Message Fees",
                    description: "Proposal to reduce message fees from 0.001 SOL to 0.0005 SOL to increase adoption",
                    proposer: "Alice",
                    type: .updateMessageFee,
                    votesFor: 1250,
                    votesAgainst: 340,
                    createdAt: Date().addingTimeInterval(-86400 * 2),
                    votingEndsAt: Date().addingTimeInterval(86400 * 5),
                    executed: false,
                    cancelled: false
                ),
                DAOProposal(
                    id: 2,
                    title: "Add New Relay Node",
                    description: "Proposal to add a new relay node in Europe to improve message delivery speed",
                    proposer: "Bob",
                    type: .addRelayNode,
                    votesFor: 890,
                    votesAgainst: 120,
                    createdAt: Date().addingTimeInterval(-86400),
                    votingEndsAt: Date().addingTimeInterval(86400 * 6),
                    executed: false,
                    cancelled: false
                )
            ]
            self.isLoading = false
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProposalRowView: View {
    let proposal: DAOProposal
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showVoteSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("by \(proposal.proposer)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ProposalStatusBadge(proposal: proposal)
            }
            
            // Description
            Text(proposal.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Voting stats
            VStack(spacing: 8) {
                HStack {
                    Text("For: \(proposal.votesFor)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Spacer()
                    
                    Text("Against: \(proposal.votesAgainst)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    let total = proposal.votesFor + proposal.votesAgainst
                    let forPercentage = total > 0 ? Double(proposal.votesFor) / Double(total) : 0
                    
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * forPercentage)
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * (1 - forPercentage))
                    }
                }
                .frame(height: 4)
                .cornerRadius(2)
            }
            
            // Actions
            HStack {
                Text("Ends: \(proposal.votingEndsAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isDAOMember && !proposal.executed && !proposal.cancelled {
                    Button("Vote") {
                        showVoteSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .shadow(radius: 1)
        .sheet(isPresented: $showVoteSheet) {
            VoteSheet(proposal: proposal)
                .environmentObject(viewModel)
        }
    }
}

struct ProposalStatusBadge: View {
    let proposal: DAOProposal
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        if proposal.executed {
            return "Executed"
        } else if proposal.cancelled {
            return "Cancelled"
        } else if Date() > proposal.votingEndsAt {
            return "Ended"
        } else {
            return "Active"
        }
    }
    
    private var statusColor: Color {
        if proposal.executed {
            return .green
        } else if proposal.cancelled {
            return .red
        } else if Date() > proposal.votingEndsAt {
            return .orange
        } else {
            return .blue
        }
    }
}

// Data models
struct DAOProposal: Identifiable {
    let id: UInt64
    let title: String
    let description: String
    let proposer: String
    let type: ProposalType
    let votesFor: UInt64
    let votesAgainst: UInt64
    let createdAt: Date
    let votingEndsAt: Date
    let executed: Bool
    let cancelled: Bool
}

enum ProposalType {
    case updateMessageFee
    case updateRelayRewards
    case addRelayNode
    case removeRelayNode
}

struct CreateProposalView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: ProposalType = .updateMessageFee
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Proposal Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Proposal Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("Update Message Fee").tag(ProposalType.updateMessageFee)
                        Text("Update Relay Rewards").tag(ProposalType.updateRelayRewards)
                        Text("Add Relay Node").tag(ProposalType.addRelayNode)
                        Text("Remove Relay Node").tag(ProposalType.removeRelayNode)
                    }
                }
            }
            .navigationTitle("New Proposal")
                        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        submitProposal()
                    }
                    .disabled(title.isEmpty || description.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func submitProposal() {
        isSubmitting = true
        
        // TODO: Implement actual proposal submission to DAO
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate network call
            
            await MainActor.run {
                isSubmitting = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct VoteSheet: View {
    let proposal: DAOProposal
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var vote: Bool? = nil
    @State private var isVoting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(proposal.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(proposal.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                VStack(spacing: 16) {
                    Button(action: { vote = true }) {
                        HStack {
                            Image(systemName: vote == true ? "checkmark.circle.fill" : "circle")
                            Text("Vote For")
                            Spacer()
                        }
                        .padding()
                        .background(vote == true ? Color.green.opacity(0.2) : Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vote == true ? Color.green : Color.gray, lineWidth: 1)
                        )
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { vote = false }) {
                        HStack {
                            Image(systemName: vote == false ? "checkmark.circle.fill" : "circle")
                            Text("Vote Against")
                            Spacer()
                        }
                        .padding()
                        .background(vote == false ? Color.red.opacity(0.2) : Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(vote == false ? Color.red : Color.gray, lineWidth: 1)
                        )
                    }
                    .foregroundColor(.primary)
                }
                .padding()
                
                Spacer()
                
                Button("Submit Vote") {
                    submitVote()
                }
                .buttonStyle(.borderedProminent)
                .disabled(vote == nil || isVoting)
                .padding()
            }
            .navigationTitle("Vote on Proposal")
                        .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func submitVote() {
        guard let voteChoice = vote else { return }
        
        isVoting = true
        
        // TODO: Implement actual voting through DAO
        print("Submitting vote: \(voteChoice)")
        Task {
            try await Task.sleep(nanoseconds: 1_500_000_000) // Simulate network call
            
            await MainActor.run {
                isVoting = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    GovernanceView()
        .environmentObject(ChatViewModel(keychain: MockKeychainManager(), identityManager: MockIdentityManager()))
}

// Mock classes for preview
class MockKeychainManager: KeychainManagerProtocol {
    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool { true }
    func getIdentityKey(forKey key: String) -> Data? { nil }
    func deleteIdentityKey(forKey key: String) -> Bool { true }
    func deleteAllKeychainData() -> Bool { true }
    
    func secureClear(_ data: inout Data) { data = Data() }
    func secureClear(_ string: inout String) { string = "" }
    
    func verifyIdentityKeyExists() -> Bool { false }
}

class MockIdentityManager: SecureIdentityStateManagerProtocol {
    var staticPublicKey: Data { Data() }
    var staticPrivateKey: Data { Data() }
    
    func regenerateIdentity() throws {}
    func forceSave() {}
    
    // MARK: - Social Identity Management
    func getSocialIdentity(for fingerprint: String) -> SocialIdentity? { nil }
    func updateSocialIdentity(_ identity: SocialIdentity) {}
    
    // MARK: - Cryptographic Identities  
    func upsertCryptographicIdentity(fingerprint: String, noisePublicKey: Data, signingPublicKey: Data?, claimedNickname: String?) {}
    func getCryptoIdentitiesByPeerIDPrefix(_ peerID: PeerID) -> [CryptographicIdentity] { [] }
    
    // MARK: - Favorites Management
    func getFavorites() -> Set<String> { Set() }
    func setFavorite(_ fingerprint: String, isFavorite: Bool) {}
    func isFavorite(fingerprint: String) -> Bool { false }
    
    // MARK: - Blocked Users Management
    func isBlocked(fingerprint: String) -> Bool { false }
    func setBlocked(_ fingerprint: String, isBlocked: Bool) {}
    
    // MARK: - Geohash (Nostr) Blocking
    func isNostrBlocked(pubkeyHexLowercased: String) -> Bool { false }
    func setNostrBlocked(_ pubkeyHexLowercased: String, isBlocked: Bool) {}
    func getBlockedNostrPubkeys() -> Set<String> { Set() }
    
    // MARK: - Ephemeral Session Management
    func registerEphemeralSession(peerID: PeerID, handshakeState: HandshakeState) {}
    func updateHandshakeState(peerID: PeerID, state: HandshakeState) {}
    func removeEphemeralSession(peerID: PeerID) {}
    
    // MARK: - Cleanup
    func clearAllIdentityData() {}
    
    // MARK: - Verification
    func setVerified(fingerprint: String, verified: Bool) {}
    func isVerified(fingerprint: String) -> Bool { false }
    func getVerifiedFingerprints() -> Set<String> { Set() }
}
