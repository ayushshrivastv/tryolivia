import SwiftUI

// MARK: - Magic Block Ephemeral Rollups Dashboard

struct MagicBlockDashboard: View {
    @StateObject private var ephemeralManager: EphemeralRollupManager
    @State private var showingSessionDetails = false
    @State private var showingMessageHistory = false
    
    init(ephemeralManager: EphemeralRollupManager) {
        self._ephemeralManager = StateObject(wrappedValue: ephemeralManager)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Session Status Section
                    sessionStatusSection
                    
                    // Performance Metrics Section
                    performanceMetricsSection
                    
                    // Active Messages Section
                    activeMessagesSection
                    
                    // Controls Section
                    controlsSection
                }
                .padding()
            }
            .navigationTitle("Magic Block")
            .refreshable {
                // Refresh data
            }
        }
        .sheet(isPresented: $showingSessionDetails) {
            sessionDetailsSheet
        }
        .sheet(isPresented: $showingMessageHistory) {
            messageHistorySheet
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .font(.title)
                    .foregroundColor(.yellow)
                
                Text("Ephemeral Rollups")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                sessionStatusBadge
            }
            
            Text("Gasless, Real-time Transactions on Solana+Nostr+Noise")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var sessionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(sessionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(sessionStatusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(sessionStatusColor.opacity(0.2))
        .cornerRadius(8)
    }
    
    // MARK: - Session Status Section
    
    private var sessionStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current State")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(sessionStatusDescription)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(sessionStatusColor)
                }
                
                Spacer()
                
                if let startTime = ephemeralManager.sessionStartTime {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Session Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(from: startTime))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
            }
            
            if case .active = ephemeralManager.sessionState {
                sessionProgressBar
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var sessionProgressBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(sessionProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: sessionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
    }
    
    // MARK: - Performance Metrics Section
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                metricCard(
                    title: "Gasless Transactions",
                    value: "\(ephemeralManager.gaslessTransactionCount)",
                    icon: "bolt.fill",
                    color: .yellow
                )
                
                metricCard(
                    title: "Active Messages",
                    value: "\(ephemeralManager.activeMessages.count)",
                    icon: "message.fill",
                    color: .blue
                )
                
                metricCard(
                    title: "Pending Commits",
                    value: "\(pendingCommitCount)",
                    icon: "clock.fill",
                    color: .orange
                )
                
                metricCard(
                    title: "Last Commit",
                    value: lastCommitText,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Active Messages Section
    
    private var activeMessagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Messages")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingMessageHistory = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if ephemeralManager.activeMessages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "message.badge")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No active messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(ephemeralManager.activeMessages.prefix(3).enumerated()), id: \.offset) { index, message in
                        messageRow(message: message)
                    }
                    
                    if ephemeralManager.activeMessages.count > 3 {
                        Text("+ \(ephemeralManager.activeMessages.count - 3) more messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func messageRow(message: EphemeralMessage) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(message.isCommitted ? .green : .orange)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Message \(message.id.prefix(8))...")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("To: \(message.recipient.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(message.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            if case .inactive = ephemeralManager.sessionState {
                startSessionButton
            } else if case .active = ephemeralManager.sessionState {
                HStack(spacing: 12) {
                    sessionDetailsButton
                    endSessionButton
                }
            } else {
                sessionStatusButton
            }
        }
    }
    
    private var startSessionButton: some View {
        Button(action: {
            Task {
                do {
                    try await ephemeralManager.startEphemeralSession()
                } catch {
                    print("Failed to start session: \(error)")
                }
            }
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Gasless Session")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var sessionDetailsButton: some View {
        Button("Session Details") {
            showingSessionDetails = true
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.2))
        .foregroundColor(.primary)
        .cornerRadius(10)
    }
    
    private var endSessionButton: some View {
        Button(action: {
            Task {
                await ephemeralManager.endEphemeralSession()
            }
        }) {
            HStack {
                Image(systemName: "stop.fill")
                Text("End Session")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    private var sessionStatusButton: some View {
        Button(sessionStatusDescription) {
            // Show status details
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(sessionStatusColor.opacity(0.2))
        .foregroundColor(sessionStatusColor)
        .cornerRadius(10)
        .disabled(true)
    }
    
    // MARK: - Session Details Sheet
    
    private var sessionDetailsSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Ephemeral Rollup Session")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let startTime = ephemeralManager.sessionStartTime {
                    VStack(spacing: 12) {
                        detailRow(title: "Started", value: formatTime(startTime))
                        detailRow(title: "Duration", value: formatDuration(from: startTime))
                        detailRow(title: "Max Duration", value: "30 minutes")
                        detailRow(title: "Auto-commit", value: "Every 5 minutes")
                    }
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    detailRow(title: "Gasless Transactions", value: "\(ephemeralManager.gaslessTransactionCount)")
                    detailRow(title: "Active Messages", value: "\(ephemeralManager.activeMessages.count)")
                    detailRow(title: "Pending Commits", value: "\(pendingCommitCount)")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Session Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        showingSessionDetails = false
                    }
                }
            }
        }
    }
    
    // MARK: - Message History Sheet
    
    private var messageHistorySheet: some View {
        NavigationView {
            List {
                ForEach(Array(ephemeralManager.activeMessages.enumerated()), id: \.offset) { index, message in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Message \(message.id)")
                                .font(.headline)
                            
                            Spacer()
                            
                            statusBadge(for: message)
                        }
                        
                        Text("To: \(message.recipient)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Sent: \(message.timestamp, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Message History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        showingMessageHistory = false
                    }
                }
            }
        }
    }
    
    private func statusBadge(for message: EphemeralMessage) -> some View {
        Text(message.isCommitted ? "Committed" : "Pending")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(message.isCommitted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            .foregroundColor(message.isCommitted ? .green : .orange)
            .cornerRadius(4)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Helper Properties
    
    private var sessionStatusColor: Color {
        switch ephemeralManager.sessionState {
        case .inactive:
            return .gray
        case .delegating:
            return .orange
        case .active:
            return .green
        case .committing:
            return .blue
        case .error:
            return .red
        }
    }
    
    private var sessionStatusText: String {
        switch ephemeralManager.sessionState {
        case .inactive:
            return "Inactive"
        case .delegating:
            return "Starting"
        case .active:
            return "Active"
        case .committing:
            return "Committing"
        case .error:
            return "Error"
        }
    }
    
    private var sessionStatusDescription: String {
        switch ephemeralManager.sessionState {
        case .inactive:
            return "No active session"
        case .delegating:
            return "Starting session..."
        case .active:
            return "Gasless transactions enabled"
        case .committing:
            return "Committing changes..."
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var pendingCommitCount: Int {
        ephemeralManager.activeMessages.filter { !$0.isCommitted }.count
    }
    
    private var lastCommitText: String {
        if let lastCommit = ephemeralManager.lastCommitTime {
            return formatTime(lastCommit)
        } else {
            return "Never"
        }
    }
    
    private var sessionProgress: Double {
        guard let startTime = ephemeralManager.sessionStartTime else { return 0.0 }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let maxDuration = EphemeralRollupConfig.maxSessionDuration
        
        return min(elapsed / maxDuration, 1.0)
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(from startTime: Date) -> String {
        let duration = Date().timeIntervalSince(startTime)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct MagicBlockDashboard_Previews: PreviewProvider {
    static var previews: some View {
        let mockSolanaManager = SolanaManager()
        let mockDAOInterface = DAOProgramInterface(solanaManager: mockSolanaManager)
        let mockEphemeralManager = EphemeralRollupManager(
            solanaManager: mockSolanaManager,
            daoInterface: mockDAOInterface
        )
        
        MagicBlockDashboard(ephemeralManager: mockEphemeralManager)
    }
}
