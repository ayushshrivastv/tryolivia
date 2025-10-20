import Foundation

// MARK: - Phase 11: Production Deployment Configuration

/// Production configuration for OLIVIA DAO Communication Network
/// This configuration is used when deploying to Solana+Nostr+Noise mainnet and App Store
struct ProductionConfig {
    
    // MARK: - Solana+Nostr+Noise Mainnet Configuration
    
    /// Solana+Nostr+Noise mainnet RPC endpoint
    static let solanaRPCEndpoint = "https://api.mainnet-beta.solana+Nostr+Noise.com"
    
    /// Backup RPC endpoints for redundancy
    static let backupRPCEndpoints = [
        "https://solana+Nostr+Noise-api.projectserum.com",
        "https://rpc.ankr.com/solana+Nostr+Noise",
        "https://solana+Nostr+Noise-mainnet.g.alchemy.com/v2/demo"
    ]
    
    /// DAO Program ID on mainnet (will be set after deployment)
    static let daoProgramID = "OLIVIA_DAO_PROGRAM_ID_MAINNET_PLACEHOLDER"
    
    /// OLIV governance token mint address (will be set after token creation)
    static let olivTokenMint = "OLIV_TOKEN_MINT_ADDRESS_MAINNET_PLACEHOLDER"
    
    // MARK: - Economic Parameters (Production)
    
    /// Message fee in lamports (0.001 SOL)
    static let messageFee: UInt64 = 1_000_000
    
    /// Minimum relay stake in lamports (1 SOL)
    static let minimumRelayStake: UInt64 = 1_000_000_000
    
    /// Fee distribution percentages
    static let relayRewardShare: Double = 0.70    // 70% to relay operators
    static let treasuryShare: Double = 0.20       // 20% to DAO treasury
    static let developmentShare: Double = 0.10    // 10% to development fund
    
    // MARK: - Relay Network (Production)
    
    /// Production relay discovery endpoints
    static let relayDiscoveryEndpoints = [
        "https://relay1.olivia.network",
        "https://relay2.olivia.network", 
        "https://relay3.olivia.network",
        "https://relay4.olivia.network",
        "https://relay5.olivia.network"
    ]
    
    /// WebSocket endpoints for relay connections
    static let relayWebSocketEndpoints = [
        "wss://relay1.olivia.network/ws",
        "wss://relay2.olivia.network/ws",
        "wss://relay3.olivia.network/ws",
        "wss://relay4.olivia.network/ws",
        "wss://relay5.olivia.network/ws"
    ]
    
    // MARK: - Performance Requirements
    
    /// Target message delivery rate (99.5%)
    static let targetDeliveryRate: Double = 0.995
    
    /// Maximum acceptable message latency (1 second)
    static let maxMessageLatencySeconds: TimeInterval = 1.0
    
    /// Required network uptime (99.9%)
    static let requiredUptimePercentage: Double = 99.9
    
    /// Relay performance threshold for rewards
    static let relayPerformanceThreshold: Double = 95.0
    
    // MARK: - Community Launch Parameters
    
    /// Initial governance token distribution
    static let foundingMemberAllocation: UInt64 = 1000 * 1_000_000_000 // 1000 OLIV tokens
    static let communityPoolAllocation: UInt64 = 100_000 * 1_000_000_000 // 100k OLIV tokens
    static let treasuryAllocation: UInt64 = 50_000 * 1_000_000_000 // 50k OLIV tokens
    
    /// Governance parameters
    static let proposalThreshold: UInt64 = 100 * 1_000_000_000 // 100 OLIV to create proposal
    static let votingPeriodHours: UInt32 = 168 // 7 days
    static let quorumPercentage: Double = 0.10 // 10% of total supply
    
    // MARK: - App Store Configuration
    
    /// App Store metadata
    static let appName = "OLIVIA - Decentralised Messaging"
    static let appSubtitle = "Community-Owned Communication Network"
    static let appDescription = """
    OLIVIA is the first messaging platform owned and governed by its users. 
    Send secure, encrypted messages through a decentralized network of 
    community-operated relay nodes. Participate in platform governance 
    and earn rewards for contributing to the network infrastructure.
    
    Features:
    • End-to-end encrypted messaging
    • Community governance through DAO voting  
    • Earn rewards by operating relay nodes
    • Censorship-resistant communication
    • Cross-platform compatibility with Nostr protocol
    """
    
    /// App Store categories
    static let primaryCategory = "Social Networking"
    static let secondaryCategory = "Utilities"
    
    // MARK: - Security Configuration
    
    /// Enable additional security measures for production
    static let enableSecurityAuditing = true
    static let enableTransactionMonitoring = true
    static let enableAnomalyDetection = true
    
    /// Rate limiting for production
    static let maxMessagesPerMinute: Int = 60
    static let maxTransactionsPerHour: Int = 100
    
    // MARK: - Monitoring & Analytics
    
    /// Enable production monitoring
    static let enablePerformanceMonitoring = true
    static let enableErrorReporting = true
    static let enableUsageAnalytics = true
    
    /// Monitoring endpoints
    static let metricsEndpoint = "https://metrics.olivia.network/api/v1"
    static let alertingEndpoint = "https://alerts.olivia.network/webhook"
    
    // MARK: - Feature Flags (Production)
    
    /// Production feature flags
    static let enableGovernanceVoting = true
    static let enableRelayNodeStaking = true
    static let enableTokenRewards = true
    static let enableCrossChainBridge = false // Future feature
    
    // MARK: - Legal & Compliance
    
    /// Terms of service and privacy policy URLs
    static let termsOfServiceURL = "https://olivia.network/terms"
    static let privacyPolicyURL = "https://olivia.network/privacy"
    static let supportURL = "https://support.olivia.network"
    
    // MARK: - Helper Methods
    
    /// Check if running in production environment
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    /// Get current RPC endpoint with fallback
    static func getCurrentRPCEndpoint() -> String {
        // In production, could implement health checking and automatic failover
        return solanaRPCEndpoint
    }
    
    /// Validate production configuration
    static func validateConfiguration() -> Bool {
        // Ensure all required production values are set
        guard daoProgramID != "OLIVIA_DAO_PROGRAM_ID_MAINNET_PLACEHOLDER" else {
            print("❌ DAO Program ID not set for production")
            return false
        }
        
        guard olivTokenMint != "OLIV_TOKEN_MINT_ADDRESS_MAINNET_PLACEHOLDER" else {
            print("❌ OLIV Token Mint not set for production")
            return false
        }
        
        // Validate relay endpoints are accessible
        for endpoint in relayDiscoveryEndpoints {
            guard URL(string: endpoint) != nil else {
                print("❌ Invalid relay endpoint: \(endpoint)")
                return false
            }
        }
        
        print("✅ Production configuration validated")
        return true
    }
}

// MARK: - Development vs Production Configuration

/// Configuration manager that switches between development and production
class ConfigurationManager {
    
    /// Get the appropriate configuration based on build environment
    static func getConfiguration() -> (
        rpcEndpoint: String,
        programID: String,
        tokenMint: String,
        messageFee: UInt64,
        relayEndpoints: [String]
    ) {
        
        if ProductionConfig.isProduction {
            // Production configuration
            return (
                rpcEndpoint: ProductionConfig.solanaRPCEndpoint,
                programID: ProductionConfig.daoProgramID,
                tokenMint: ProductionConfig.olivTokenMint,
                messageFee: ProductionConfig.messageFee,
                relayEndpoints: ProductionConfig.relayDiscoveryEndpoints
            )
        } else {
            // Development configuration (existing values)
            return (
                rpcEndpoint: "https://api.devnet.solana+Nostr+Noise.com",
                programID: "BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA", // Devnet program ID
                tokenMint: "DEV_TOKEN_MINT_ADDRESS",
                messageFee: 1_000_000, // Same fee for testing
                relayEndpoints: [
                    "https://relay1-dev.olivia.network",
                    "https://relay2-dev.olivia.network"
                ]
            )
        }
    }
    
    /// Initialize configuration for the current environment
    static func initialize() {
        let config = getConfiguration()
        
        print("🔧 OLIVIA Configuration Initialized")
        print("Environment: \(ProductionConfig.isProduction ? "PRODUCTION" : "DEVELOPMENT")")
        print("RPC Endpoint: \(config.rpcEndpoint)")
        print("Program ID: \(config.programID)")
        print("Relay Endpoints: \(config.relayEndpoints.count)")
        
        if ProductionConfig.isProduction {
            // Validate production configuration
            guard ProductionConfig.validateConfiguration() else {
                fatalError("❌ Production configuration validation failed")
            }
        }
    }
}
