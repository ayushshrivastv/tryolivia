import Foundation
import Network
import Combine

// MARK: - Phase 9: Real Relay Network Integration

struct RelayNode: Codable, Identifiable {
    let id: String
    let endpoint: String
    let publicKey: String
    let stake: UInt64
    let performance: Double
    let isOnline: Bool
    let location: String?
    
    var websocketURL: URL? {
        guard let url = URL(string: endpoint) else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "ws"
        return components?.url
    }
}

struct RelayMessage: Codable {
    let type: String
    let recipient: String
    let encryptedContent: Data
    let messageHash: String
    let timestamp: Date
    let sender: String
}

class RelayNetworkManager: ObservableObject {
    @Published var connectedRelays: [RelayNode] = []
    @Published var isConnected = false
    @Published var connectionStatus: String = "Disconnected"
    
    private let solanaManager: SolanaManager
    private let daoInterface: DAOProgramInterface
    private var webSocketTasks: [String: URLSessionWebSocketTask] = [:]
    private var urlSession: URLSession
    
    init(solanaManager: SolanaManager, daoInterface: DAOProgramInterface) {
        self.solanaManager = solanaManager
        self.daoInterface = daoInterface
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Relay Discovery
    
    func discoverRelayNodes() async throws {
        connectionStatus = "Discovering relays..."
        
        do {
            // Get active relay nodes from DAO smart contract
            let allRelays = try await daoInterface.getActiveRelayNodes()
            
            // Filter by performance and stake requirements
            let qualifiedRelays = allRelays.filter { relay in
                relay.performance > 95.0 && relay.stake >= 1_000_000_000 // 1 SOL minimum
            }.sorted { $0.performance > $1.performance }
            
            // Take top 5 relays for redundancy
            let selectedRelays = Array(qualifiedRelays.prefix(5))
            
            await MainActor.run {
                self.connectedRelays = selectedRelays
                self.connectionStatus = "Found \(selectedRelays.count) qualified relays"
            }
            
            // Connect to selected relays
            await connectToRelays(selectedRelays)
            
        } catch {
            connectionStatus = "Discovery failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - WebSocket Connection Management
    
    private func connectToRelays(_ relays: [RelayNode]) async {
        connectionStatus = "Connecting to relays..."
        
        for relay in relays {
            await connectToRelay(relay)
        }
        
        let connectedCount = webSocketTasks.count
        isConnected = connectedCount > 0
        connectionStatus = connectedCount > 0 ? "Connected to \(connectedCount) relays" : "No relay connections"
    }
    
    private func connectToRelay(_ relay: RelayNode) async {
        guard let wsURL = relay.websocketURL else {
            print("Invalid WebSocket URL for relay: \(relay.id)")
            return
        }
        
        let webSocketTask = urlSession.webSocketTask(with: wsURL)
        webSocketTasks[relay.id] = webSocketTask
        
        // Start listening for messages
        Task {
            await listenForMessages(from: webSocketTask, relayId: relay.id)
        }
        
        webSocketTask.resume()
        print("Connected to relay: \(relay.id) at \(wsURL)")
    }
    
    private func listenForMessages(from webSocketTask: URLSessionWebSocketTask, relayId: String) async {
        do {
            while webSocketTask.state == .running {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .string(let text):
                    await handleRelayMessage(text, from: relayId)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleRelayMessage(text, from: relayId)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            print("WebSocket error for relay \(relayId): \(error)")
            webSocketTasks.removeValue(forKey: relayId)
        }
    }
    
    private func handleRelayMessage(_ messageText: String, from relayId: String) async {
        do {
            guard let messageData = messageText.data(using: .utf8) else { return }
            let relayMessage = try JSONDecoder().decode(RelayMessage.self, from: messageData)
            
            // Process incoming message (decrypt, validate, deliver to UI)
            await processIncomingMessage(relayMessage, from: relayId)
            
        } catch {
            print("Failed to parse relay message from \(relayId): \(error)")
        }
    }
    
    private func processIncomingMessage(_ message: RelayMessage, from relayId: String) async {
        // TODO: Decrypt message content using Noise protocol
        // TODO: Validate message authenticity
        // TODO: Deliver to appropriate UI component
        
        print("Received message from relay \(relayId): \(message.messageHash)")
    }
    
    // MARK: - Message Sending
    
    func sendMessage(to recipient: String, encryptedContent: Data) async throws -> String {
        guard !webSocketTasks.isEmpty else {
            throw RelayNetworkError.noRelaysConnected
        }
        
        // Select optimal relay for sending
        guard let optimalRelay = selectOptimalRelay() else {
            throw RelayNetworkError.noOptimalRelay
        }
        
        guard let webSocketTask = webSocketTasks[optimalRelay.id] else {
            throw RelayNetworkError.relayNotConnected
        }
        
        // Create relay message
        let messageHash = generateMessageHash()
        let relayMessage = RelayMessage(
            type: "relay_message",
            recipient: recipient,
            encryptedContent: encryptedContent,
            messageHash: messageHash,
            timestamp: Date(),
            sender: solanaManager.walletAddress ?? "unknown"
        )
        
        // Send via WebSocket
        let messageData = try JSONEncoder().encode(relayMessage)
        let messageText = String(data: messageData, encoding: .utf8) ?? ""
        
        try await webSocketTask.send(.string(messageText))
        
        print("Message sent via relay \(optimalRelay.id): \(messageHash)")
        return messageHash
    }
    
    private func selectOptimalRelay() -> RelayNode? {
        // Select relay based on:
        // 1. Connection status
        // 2. Performance metrics
        // 3. Load balancing
        
        return connectedRelays.first { relay in
            webSocketTasks[relay.id]?.state == .running
        }
    }
    
    private func generateMessageHash() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
    }
    
    // MARK: - Cleanup
    
    func disconnect() {
        for (relayId, webSocketTask) in webSocketTasks {
            webSocketTask.cancel()
            print("Disconnected from relay: \(relayId)")
        }
        
        webSocketTasks.removeAll()
        isConnected = false
        connectionStatus = "Disconnected"
    }
}

// MARK: - Errors

enum RelayNetworkError: Error, LocalizedError {
    case noRelaysConnected
    case noOptimalRelay
    case relayNotConnected
    case messageEncodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noRelaysConnected:
            return "No relay nodes connected"
        case .noOptimalRelay:
            return "No optimal relay found"
        case .relayNotConnected:
            return "Selected relay not connected"
        case .messageEncodingFailed:
            return "Failed to encode message"
        }
    }
}
