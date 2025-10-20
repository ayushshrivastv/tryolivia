import Foundation

/// Centralized configuration for Solana+Nostr+Noise+Magic Block architecture
/// Legacy Solana+Nostr+Noise configuration removed - now using decentralized transport
enum TransportConfig {
    // Solana+Nostr+Noise Network / Protocol
    static let solanaDefaultFragmentSize: Int = 1232       // Solana+Nostr+Noise transaction size limit
    static let messageTTLDefault: UInt8 = 7                // Default TTL for message routing
    static let maxConcurrentMessages: Int = 128            // Cap concurrent message processing
    static let nostrRelayThreshold: Int = 3                // Minimum relays for redundancy

    // UI / Storage Caps
    static let privateChatCap: Int = 1337
    static let meshTimelineCap: Int = 1337
    static let geoTimelineCap: Int = 1337
    static let contentLRUCap: Int = 2000

    // Timers
    static let networkResetGraceSeconds: TimeInterval = 600 // 10 minutes
    static let basePublicFlushInterval: TimeInterval = 0.08  // ~12.5 fps batching

    // Solana+Nostr+Noise Network Configuration
    static let solanaConnectRateLimitInterval: TimeInterval = 0.5
    static let solanaMaxConcurrentConnections: Int = 6
    static let solanaTransactionTimeout: TimeInterval = 30.0
    static let magicBlockValidatorCount: Int = 4
    static let nostrRelayMinInterval: TimeInterval = 1.0

    // Network Quality Thresholds
    static let solanaRPCTimeoutDefault: TimeInterval = 10.0
    static let nostrRelayConnectionMax: Int = 10
    static let messagePendingBufferCapBytes: Int = 1_000_000
    static let nostrPendingNotificationsCapCount: Int = 20

    // Nostr
    static let nostrReadAckInterval: TimeInterval = 0.35 // ~3 per second

    // UI thresholds
    static let uiLateInsertThreshold: TimeInterval = 15.0
    // Geohash public chats are more sensitive to ordering; use a tighter threshold
    static let uiLateInsertThresholdGeo: TimeInterval = 0.0
    static let uiProcessedNostrEventsCap: Int = 2000
    static let uiChannelInactivityThresholdSeconds: TimeInterval = 9 * 60
    
    // UI rate limiters (token buckets)
    static let uiSenderRateBucketCapacity: Double = 5
    static let uiSenderRateBucketRefillPerSec: Double = 1.0
    static let uiContentRateBucketCapacity: Double = 3
    static let uiContentRateBucketRefillPerSec: Double = 0.5

    // UI sleeps/delays
    static let uiStartupInitialDelaySeconds: TimeInterval = 1.0
    static let uiStartupShortSleepNs: UInt64 = 200_000_000
    static let uiStartupPhaseDurationSeconds: TimeInterval = 2.0
    static let uiAsyncShortSleepNs: UInt64 = 100_000_000
    static let uiAsyncMediumSleepNs: UInt64 = 500_000_000
    static let uiReadReceiptRetryShortSeconds: TimeInterval = 0.1
    static let uiReadReceiptRetryLongSeconds: TimeInterval = 0.5
    static let uiBatchDispatchStaggerSeconds: TimeInterval = 0.15
    static let uiScrollThrottleSeconds: TimeInterval = 0.5
    static let uiAnimationShortSeconds: TimeInterval = 0.15
    static let uiAnimationMediumSeconds: TimeInterval = 0.2
    static let uiAnimationSidebarSeconds: TimeInterval = 0.25
    static let uiRecentCutoffFiveMinutesSeconds: TimeInterval = 5 * 60

    // Network Maintenance & Thresholds
    static let networkMaintenanceInterval: TimeInterval = 5.0
    static let networkMaintenanceLeewaySeconds: Int = 1
    static let solanaConnectionTimeoutSeconds: TimeInterval = 60
    static let nostrRelayTimeoutWindowSeconds: TimeInterval = 60
    static let nostrRelayTimeoutCountThreshold: Int = 3
    static let solanaRPCLatencyThresholdMs: Int = 1000
    static let nostrRelayLatencyThresholdMs: Int = 2000
    static let magicBlockLatencyThresholdMs: Int = 500
    static let networkQualityCheckIntervalSeconds: TimeInterval = 30.0
    // How long without seeing activity before checking connection health
    static let peerInactivityTimeoutSeconds: TimeInterval = 8.0
    // How long to retain a peer as "reachable" since last activity
    static let peerReachabilityRetentionVerifiedSeconds: TimeInterval = 21.0    // 21s for verified/favorites
    static let peerReachabilityRetentionUnverifiedSeconds: TimeInterval = 21.0  // 21s for unknown/unverified
    static let messageFragmentLifetimeSeconds: TimeInterval = 30.0
    static let messageIngressRecordLifetimeSeconds: TimeInterval = 3.0
    static let solanaConnectionBackoffWindowSeconds: TimeInterval = 120.0
    static let recentMessageWindowSeconds: TimeInterval = 30.0
    static let recentMessageWindowMaxCount: Int = 100
    // Keep network monitoring active when we saw traffic recently
    static let recentTrafficForceMonitorSeconds: TimeInterval = 10.0
    static let networkThreadSleepDelaySeconds: TimeInterval = 0.05
    static let expectedTransactionTimeMs: Int = 1000
    static let maxTransactionTimeMs: Int = 30000
    // Message pacing for Solana+Nostr+Noise transactions
    static let solanaTransactionSpacingMs: Int = 100
    static let nostrMessageSpacingMs: Int = 50
    static let networkAnnounceIntervalSeconds: TimeInterval = 4.0
    static let solanaActiveMonitoringDuration: TimeInterval = 3.0
    static let solanaIdleMonitoringDuration: TimeInterval = 15.0
    static let solanaHeartbeatIntervalDense: TimeInterval = 30.0
    static let solanaHeartbeatIntervalSparse: TimeInterval = 15.0
    static let networkJitterDense: TimeInterval = 8.0
    static let networkJitterSparse: TimeInterval = 4.0

    // Location
    static let locationDistanceFilterMeters: Double = 1000
    // Live (channel sheet open) distance threshold for meaningful updates
    static let locationDistanceFilterLiveMeters: Double = 10.0
    static let locationLiveRefreshInterval: TimeInterval = 5.0

    // Notifications (geohash)
    static let uiGeoNotifyCooldownSeconds: TimeInterval = 60.0
    static let uiGeoNotifySnippetMaxLen: Int = 80

    // Nostr geohash
    static let nostrGeohashInitialLookbackSeconds: TimeInterval = 3600
    static let nostrGeohashInitialLimit: Int = 200
    static let nostrGeoRelayCount: Int = 5
    static let nostrGeohashSampleLookbackSeconds: TimeInterval = 300
    static let nostrGeohashSampleLimit: Int = 100
    static let nostrDMSubscribeLookbackSeconds: TimeInterval = 86400

    // Nostr helpers
    static let nostrShortKeyDisplayLength: Int = 8
    static let nostrConvKeyPrefixLength: Int = 16

    // Compression
    static let compressionThresholdBytes: Int = 100

    // Message deduplication
    static let messageDedupMaxAgeSeconds: TimeInterval = 300
    static let messageDedupMaxCount: Int = 1000

    // Verification QR
    static let verificationQRMaxAgeSeconds: TimeInterval = 5 * 60

    // Nostr relay backoff
    static let nostrRelayInitialBackoffSeconds: TimeInterval = 1.0
    static let nostrRelayMaxBackoffSeconds: TimeInterval = 300.0
    static let nostrRelayBackoffMultiplier: Double = 2.0
    static let nostrRelayMaxReconnectAttempts: Int = 10
    static let nostrRelayDefaultFetchLimit: Int = 100

    // Geo relay directory
    static let geoRelayFetchIntervalSeconds: TimeInterval = 60 * 60 * 24

    // Network Operational Delays
    static let solanaInitialConnectDelaySeconds: TimeInterval = 0.6
    static let nostrRelayReconnectDelaySeconds: TimeInterval = 0.1
    static let magicBlockSubscribeDelaySeconds: TimeInterval = 0.05
    static let networkAnnounceDelaySeconds: TimeInterval = 0.4
    static let networkForceAnnounceMinIntervalSeconds: TimeInterval = 0.15

    // Store-and-forward for directed messages via relays
    static let messageSpoolWindowSeconds: TimeInterval = 15.0

    // Log/UI debounce windows
    // Shorter debounce so UI reacts faster while still suppressing duplicate callbacks
    static let networkDisconnectNotifyDebounceSeconds: TimeInterval = 0.9
    static let networkReconnectLogDebounceSeconds: TimeInterval = 2.0

    // Poor connection cooldown after timeouts
    static let networkWeakConnectionCooldownSeconds: TimeInterval = 30.0
    static let networkLatencyThresholdMs: Int = 2000

    // Content hashing / formatting
    static let contentKeyPrefixLength: Int = 256
    static let uiLongMessageLengthThreshold: Int = 2000
    static let uiVeryLongTokenThreshold: Int = 512
    static let uiLongMessageLineLimit: Int = 30
    static let uiFingerprintSampleCount: Int = 3
    
    // UI swipe/gesture thresholds
    static let uiBackSwipeTranslationLarge: CGFloat = 50
    static let uiBackSwipeTranslationSmall: CGFloat = 30
    static let uiBackSwipeVelocityThreshold: CGFloat = 300
    
    // UI color tuning
    static let uiColorHueAvoidanceDelta: Double = 0.05
    static let uiColorHueOffset: Double = 0.12
    // Peer list palette
    static let uiPeerPaletteSlots: Int = 36
    static let uiPeerPaletteRingBrightnessDeltaLight: Double = 0.07
    static let uiPeerPaletteRingBrightnessDeltaDark: Double = -0.07

    // UI windowing (infinite scroll)
    static let uiWindowInitialCountPublic: Int = 300
    static let uiWindowInitialCountPrivate: Int = 300
    static let uiWindowStepCount: Int = 200

    // Share extension
    static let uiShareExtensionDismissDelaySeconds: TimeInterval = 2.0
    static let uiShareAcceptWindowSeconds: TimeInterval = 30.0
    static let uiMigrationCutoffSeconds: TimeInterval = 24 * 60 * 60
}
