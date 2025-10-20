import SwiftUI

struct RelayNetworkView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var relayNodes: [RelayNodeInfo] = []
    @State private var isLoading = false
    @State private var showAddRelay = false
    @State private var networkStats = NetworkStats()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Network overview
                networkOverviewHeader
                
                Divider()
                
                // Relay nodes list
                if isLoading {
                    ProgressView("Loading relay network...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if relayNodes.isEmpty {
                    emptyRelayNetworkView
                } else {
                    relayNodesList
                }
            }
            .navigationTitle("Relay Network")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Add Relay Node") {
                            showAddRelay = true
                        }
                        
                        Button("Network Statistics") {
                            // Show detailed stats
                        }
                        
                        Button("Refresh Network") {
                            loadRelayNodes()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddRelay) {
                AddRelayNodeView()
                    .environmentObject(viewModel)
            }
            .onAppear {
                loadRelayNodes()
                loadNetworkStats()
            }
        }
    }
    
    private var networkOverviewHeader: some View {
        VStack(spacing: 16) {
            // Network health indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network Status")
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(networkHealthColor)
                            .frame(width: 8, height: 8)
                        
                        Text(networkHealthText)
                            .font(.subheadline)
                            .foregroundColor(networkHealthColor)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Active Relays")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(networkStats.activeRelays)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            // Network statistics
            HStack(spacing: 20) {
                NetworkStatCard(
                    title: "Messages/Hour", 
                    value: "\(networkStats.messagesPerHour)",
                    icon: "envelope.arrow.triangle.branch"
                )
                
                NetworkStatCard(
                    title: "Avg Latency", 
                    value: "\(networkStats.averageLatency)ms",
                    icon: "speedometer"
                )
                
                NetworkStatCard(
                    title: "Uptime", 
                    value: String(format: "%.1f%%", networkStats.networkUptime),
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
.background(Color.gray.opacity(0.1))
    }
    
    private var networkHealthColor: Color {
        if networkStats.activeRelays >= 5 && networkStats.networkUptime > 95 {
            return .green
        } else if networkStats.activeRelays >= 2 && networkStats.networkUptime > 80 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var networkHealthText: String {
        if networkStats.activeRelays >= 5 && networkStats.networkUptime > 95 {
            return "Excellent"
        } else if networkStats.activeRelays >= 2 && networkStats.networkUptime > 80 {
            return "Good"
        } else {
            return "Poor"
        }
    }
    
    private var emptyRelayNetworkView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Relay Nodes")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("The relay network is empty. Be the first to add a relay node and earn rewards!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if viewModel.isDAOMember {
                Button("Add First Relay Node") {
                    showAddRelay = true
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
    
    private var relayNodesList: some View {
        List(relayNodes) { relay in
            RelayNodeRowView(relay: relay)
                .environmentObject(viewModel)
        }
        .listStyle(PlainListStyle())
    }
    
    private func loadRelayNodes() {
        isLoading = true
        
        // Mock relay nodes - in real implementation, fetch from DAO
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.relayNodes = [
                RelayNodeInfo(
                    id: "relay1",
                    operator: "Alice",
                    endpoint: "wss://relay1.olivia.chat",
                    stake: 5.0,
                    performance: 98,
                    messagesRelayed: 15420,
                    uptime: 99.2,
                    averageLatency: 45,
                    isActive: true,
                    lastSeen: Date().addingTimeInterval(-300),
                    rewardsEarned: 2.5
                ),
                RelayNodeInfo(
                    id: "relay2",
                    operator: "Bob",
                    endpoint: "wss://relay2.olivia.chat",
                    stake: 10.0,
                    performance: 95,
                    messagesRelayed: 23100,
                    uptime: 97.8,
                    averageLatency: 52,
                    isActive: true,
                    lastSeen: Date().addingTimeInterval(-120),
                    rewardsEarned: 4.8
                ),
                RelayNodeInfo(
                    id: "relay3",
                    operator: "Charlie",
                    endpoint: "wss://relay3.olivia.chat",
                    stake: 2.0,
                    performance: 87,
                    messagesRelayed: 8900,
                    uptime: 89.5,
                    averageLatency: 78,
                    isActive: false,
                    lastSeen: Date().addingTimeInterval(-3600),
                    rewardsEarned: 1.2
                )
            ]
            self.isLoading = false
        }
    }
    
    private func loadNetworkStats() {
        // Mock network statistics
        networkStats = NetworkStats(
            activeRelays: 2,
            totalRelays: 3,
            messagesPerHour: 1250,
            averageLatency: 48,
            networkUptime: 98.5,
            totalStaked: 17.0
        )
    }
}

struct NetworkStatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct RelayNodeRowView: View {
    let relay: RelayNodeInfo
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showRelayDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(relay.operator)
                            .font(.headline)
                        
                        if relay.isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    
                    Text(relay.endpoint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(relay.stake, specifier: "%.1f") SOL")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Staked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Performance metrics
            HStack(spacing: 16) {
                MetricBadge(title: "Performance", value: "\(relay.performance)%", color: performanceColor(relay.performance))
                MetricBadge(title: "Uptime", value: String(format: "%.1f%%", relay.uptime), color: uptimeColor(relay.uptime))
                MetricBadge(title: "Latency", value: "\(relay.averageLatency)ms", color: latencyColor(relay.averageLatency))
            }
            
            // Statistics
            HStack {
                Text("Messages: \(relay.messagesRelayed)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Earned: \(relay.rewardsEarned, specifier: "%.2f") SOL")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("Last seen: \(relay.lastSeen, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Actions
            HStack {
                Button("Details") {
                    showRelayDetails = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                if viewModel.walletAddress == relay.id { // If user owns this relay
                    Button("Claim Rewards") {
                        claimRewards()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .shadow(radius: 1)
        .sheet(isPresented: $showRelayDetails) {
            RelayNodeDetailView(relay: relay)
                .environmentObject(viewModel)
        }
    }
    
    private func performanceColor(_ performance: Int) -> Color {
        if performance >= 95 { return .green }
        else if performance >= 80 { return .orange }
        else { return .red }
    }
    
    private func uptimeColor(_ uptime: Double) -> Color {
        if uptime >= 95 { return .green }
        else if uptime >= 80 { return .orange }
        else { return .red }
    }
    
    private func latencyColor(_ latency: Int) -> Color {
        if latency <= 50 { return .green }
        else if latency <= 100 { return .orange }
        else { return .red }
    }
    
    private func claimRewards() {
        // TODO: Implement actual reward claiming
        print("Claiming rewards for relay: \(relay.id)")
    }
}

struct MetricBadge: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct AddRelayNodeView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var endpoint = ""
    @State private var stakeAmount = "1.0"
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Relay Configuration") {
                    TextField("Endpoint URL", text: $endpoint)
                        .autocorrectionDisabled()
                    
                    TextField("Stake Amount (SOL)", text: $stakeAmount)
                }
                
                Section("Requirements") {
                    Label("Minimum 1 SOL stake required", systemImage: "info.circle")
                        .foregroundColor(.blue)
                    
                    Label("Relay must be publicly accessible", systemImage: "network")
                        .foregroundColor(.blue)
                    
                    Label("Uptime >95% recommended for rewards", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Add Relay Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register") {
                        registerRelay()
                    }
                    .disabled(endpoint.isEmpty || stakeAmount.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func registerRelay() {
        isSubmitting = true
        
        // TODO: Implement actual relay registration
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // Simulate network call
            
            await MainActor.run {
                isSubmitting = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct RelayNodeDetailView: View {
    let relay: RelayNodeInfo
    @EnvironmentObject var viewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(relay.operator)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(relay.endpoint)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Performance charts would go here
                    Text("Performance charts and detailed metrics would be displayed here in a full implementation")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Relay Details")
        }
    }
}

// Data models
struct RelayNodeInfo: Identifiable {
    let id: String
    let `operator`: String
    let endpoint: String
    let stake: Double
    let performance: Int
    let messagesRelayed: Int
    let uptime: Double
    let averageLatency: Int
    let isActive: Bool
    let lastSeen: Date
    let rewardsEarned: Double
}

struct NetworkStats {
    var activeRelays: Int = 0
    var totalRelays: Int = 0
    var messagesPerHour: Int = 0
    var averageLatency: Int = 0
    var networkUptime: Double = 0.0
    var totalStaked: Double = 0.0
}

#Preview {
    RelayNetworkView()
        .environmentObject(ChatViewModel(keychain: MockKeychainManager(), identityManager: MockIdentityManager()))
}
