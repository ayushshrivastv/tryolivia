import SwiftUI

struct UsernameSelectionView: View {
    @StateObject private var usernameService: UsernameService
    @State private var proposedUsername: String = ""
    @State private var isCheckingAvailability = false
    @State private var isRegistering = false
    @State private var availabilityMessage: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    init(usernameService: UsernameService) {
        self._usernameService = StateObject(wrappedValue: usernameService)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Choose Your Username")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Select a unique username for your OLIVIA identity. This will be used for payments and messaging.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Username Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                    
                    HStack {
                        Text("@")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter username", text: $proposedUsername)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            #if os(iOS)
                            .autocapitalization(.none)
                            #endif
                            .disableAutocorrection(true)
                            .onChange(of: proposedUsername) { _ in
                                checkUsernameAvailability()
                            }
                    }
                    
                    // Availability Status
                    if !availabilityMessage.isEmpty {
                        HStack {
                            Image(systemName: availabilityMessage.contains("available") ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(availabilityMessage.contains("available") ? .green : .red)
                            
                            Text(availabilityMessage)
                                .font(.caption)
                                .foregroundColor(availabilityMessage.contains("available") ? .green : .red)
                        }
                    }
                    
                    // Username Rules
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Username Requirements:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("• 3-20 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Letters, numbers, and underscore only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Must be unique across the network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: registerUsername) {
                        HStack {
                            if isRegistering {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            Text(isRegistering ? "Registering..." : "Register Username")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canRegister ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canRegister || isRegistering)
                    
                    Button("Skip for Now") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Username Setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Pre-fill with current nickname if available
            if let currentUsername = usernameService.currentUsername {
                proposedUsername = currentUsername
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var canRegister: Bool {
        !proposedUsername.isEmpty &&
        proposedUsername.count >= 3 &&
        proposedUsername.count <= 20 &&
        availabilityMessage.contains("available") &&
        !isCheckingAvailability &&
        !isRegistering
    }
    
    // MARK: - Actions
    
    private func checkUsernameAvailability() {
        guard !proposedUsername.isEmpty,
              proposedUsername.count >= 3,
              proposedUsername.count <= 20 else {
            availabilityMessage = ""
            return
        }
        
        // Basic format validation
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard proposedUsername.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            availabilityMessage = "Invalid characters (only letters, numbers, and _ allowed)"
            return
        }
        
        isCheckingAvailability = true
        availabilityMessage = "Checking availability..."
        
        Task {
            do {
                let isAvailable = try await usernameService.isUsernameAvailable(proposedUsername)
                
                await MainActor.run {
                    isCheckingAvailability = false
                    if isAvailable {
                        availabilityMessage = "✓ @\(proposedUsername) is available"
                    } else {
                        availabilityMessage = "✗ @\(proposedUsername) is already taken"
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingAvailability = false
                    availabilityMessage = "Error checking availability"
                }
            }
        }
    }
    
    private func registerUsername() {
        guard canRegister else { return }
        
        isRegistering = true
        
        Task {
            do {
                try await usernameService.registerUsername(proposedUsername)
                
                await MainActor.run {
                    isRegistering = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

struct UsernameSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let solanaManager = SolanaManager()
        let ephemeralRollupManager = EphemeralRollupManager(solanaManager: solanaManager)
        let daoProgramInterface = DAOProgramInterface(solanaManager: solanaManager)
        let usernameService = UsernameService(
            solanaManager: solanaManager,
            ephemeralRollupManager: ephemeralRollupManager,
            daoProgramInterface: daoProgramInterface
        )
        
        UsernameSelectionView(usernameService: usernameService)
    }
}
