import SwiftUI

struct WalletConnectionView: View {
    @StateObject private var solanaManager = SolanaManager()
    @Binding var isPresented: Bool
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var onWalletConnected: ((String) -> Void)?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Connect Wallet")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Connect your Solana+Nostr+Noise wallet to join the OLIVIA DAO")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Connection Status
                if solanaManager.isConnected {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Wallet Connected")
                                .fontWeight(.medium)
                        }
                        
                        if let address = solanaManager.walletAddress {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("Balance: \(solanaManager.balance) lamports")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // Connection Status Indicator
                    switch solanaManager.connectionStatus {
                    case .disconnected:
                        EmptyView()
                    case .connecting:
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Connecting...")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    case .connected:
                        EmptyView()
                    case .error(let message):
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(message)
                                .font(.caption)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Wallet Options
                if !solanaManager.isConnected {
                    VStack(spacing: 16) {
                        // Phantom Wallet
                        Button(action: {
                            connectPhantom()
                        }) {
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Phantom Wallet")
                                        .fontWeight(.medium)
                                    Text("Most popular Solana+Nostr+Noise wallet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Solflare Wallet
                        Button(action: {
                            connectSolflare()
                        }) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Solflare Wallet")
                                        .fontWeight(.medium)
                                    Text("Feature-rich Solana+Nostr+Noise wallet")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Demo Mode (for testing)
                        Button(action: {
                            connectDemo()
                        }) {
                            HStack {
                                Image(systemName: "testtube.2")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Demo Mode")
                                        .fontWeight(.medium)
                                    Text("Create test wallet for development")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    // Connected Actions
                    VStack(spacing: 16) {
                        Button("Request Airdrop (Devnet)") {
                            requestAirdrop()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Disconnect Wallet") {
                            Task {
                                await solanaManager.disconnectWallet()
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                // Info Footer
                VStack(spacing: 8) {
                    Text("Secure & Decentralized")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Your wallet keys never leave your device")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Wallet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                if solanaManager.isConnected {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let address = solanaManager.walletAddress {
                                onWalletConnected?(address)
                            }
                            isPresented = false
                        }
                        .fontWeight(.medium)
                    }
                }
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func connectPhantom() {
        Task {
            do {
                let address = try await solanaManager.connectPhantomWallet()
                await MainActor.run {
                    onWalletConnected?(address)
                }
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func connectSolflare() {
        Task {
            do {
                let address = try await solanaManager.connectSolflareWallet()
                await MainActor.run {
                    onWalletConnected?(address)
                }
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func connectDemo() {
        Task {
            do {
                let address = try await solanaManager.connectPhantomWallet() // Same as Phantom for demo
                await MainActor.run {
                    onWalletConnected?(address)
                }
            } catch {
                await MainActor.run {
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func requestAirdrop() {
        Task {
            do {
                try await solanaManager.requestAirdrop()
            } catch {
                await MainActor.run {
                    showError("Airdrop failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

#Preview {
    WalletConnectionView(isPresented: .constant(true))
}
