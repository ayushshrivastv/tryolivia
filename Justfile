# OLIVIA macOS Build Justfile
# Decentralized Communication Network - Build System

# Default recipe - shows available commands
default:
    @echo "OLIVIA DAO Communication Network Build Commands:"
    @echo "  just run     - Build and run the macOS app"
    @echo "  just build   - Build the macOS app only"
    @echo "  just clean   - Clean build artifacts and restore original files"
    @echo "  just check   - Check prerequisites"
    @echo "  just deploy-solana - Deploy Solana contracts (see Solana/deploy-mainnet.sh)"
    @echo ""
    @echo "Decentralized DAO messaging with blockchain governance"

# Check prerequisites
check:
    @echo "Checking prerequisites..."
    @command -v xcodebuild >/dev/null 2>&1 || (echo "❌ xcodebuild not found. Install Xcode from App Store" && exit 1)
    @xcode-select -p | grep -q "Xcode.app" || (echo "❌ Full Xcode required, not just command line tools. Install from App Store and run:\n   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" && exit 1)
    @test -d "/Applications/Xcode.app" || (echo "❌ Xcode.app not found in Applications folder. Install from App Store" && exit 1)
    @xcodebuild -version >/dev/null 2>&1 || (echo "❌ Xcode not properly configured. Try:\n   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" && exit 1)
    @security find-identity -v -p codesigning | grep -q "Apple Development\|Developer ID" || (echo "⚠️  No Developer ID found - code signing may fail" && exit 0)
    @echo "All prerequisites met"

# Backup original files
backup:
    @echo "Backing up original project configuration..."
    @if [ -f olivia.xcodeproj/project.pbxproj ]; then cp olivia.xcodeproj/project.pbxproj olivia.xcodeproj/project.pbxproj.backup; fi
    @if [ -f olivia/Info.plist ]; then cp olivia/Info.plist olivia/Info.plist.backup; fi

# Restore original files
restore:
    @echo "Restoring original project configuration..."
    @if [ -f project.yml.backup ]; then mv project.yml.backup project.yml; fi
    @# Restore iOS-specific files
    @if [ -f olivia/LaunchScreen.storyboard.ios ]; then mv olivia/LaunchScreen.storyboard.ios olivia/LaunchScreen.storyboard; fi
    @# Use git to restore all modified files except Justfile
    @git checkout -- project.yml olivia.xcodeproj/project.pbxproj olivia/Info.plist 2>/dev/null || echo "⚠️  Could not restore some files with git"
    @# Remove any backup files
    @rm -f olivia.xcodeproj/project.pbxproj.backup olivia/Info.plist.backup 2>/dev/null || true

# Apply macOS-specific modifications
patch-for-macos: backup
    @echo "Temporarily hiding iOS-specific files for macOS build..."
    @# Move iOS-specific files out of the way temporarily
    @if [ -f olivia/LaunchScreen.storyboard ]; then mv olivia/LaunchScreen.storyboard olivia/LaunchScreen.storyboard.ios; fi

# Build the macOS app
build: #check generate
    @echo "Building OLIVIA for macOS..."
    @xcodebuild -project olivia.xcodeproj -scheme "olivia (macOS)" -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" build

# Run the macOS app
run: build
    @echo "Launching OLIVIA..."
    @find ~/Library/Developer/Xcode/DerivedData -name "olivia.app" -path "*/Debug/*" -not -path "*/Index.noindex/*" | head -1 | xargs -I {} open "{}"

# Clean build artifacts and restore original files
clean: restore
    @echo "Cleaning build artifacts..."
    @rm -rf ~/Library/Developer/Xcode/DerivedData/olivia-* 2>/dev/null || true
    @# Only remove the generated project if we have a backup, otherwise use git
    @if [ -f olivia.xcodeproj/project.pbxproj.backup ]; then \
        rm -rf olivia.xcodeproj; \
    else \
        git checkout -- olivia.xcodeproj/project.pbxproj 2>/dev/null || echo "⚠️  Could not restore project.pbxproj"; \
    fi
    @rm -f project-macos.yml 2>/dev/null || true
    @echo "Cleaned and restored original files"

# Quick run without cleaning (for development)
dev-run: check
    @echo "Quick development build..."
    @xcodebuild -project olivia.xcodeproj -scheme "olivia (macOS)" -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGN_ENTITLEMENTS="" build
    @find ~/Library/Developer/Xcode/DerivedData -name "olivia.app" -path "*/Debug/*" -not -path "*/Index.noindex/*" | head -1 | xargs -I {} open "{}"

# Show app info
info:
    @echo "OLIVIA - Decentralized DAO Communication Network"
    @echo "======================================"
    @echo "• Native macOS SwiftUI app"
    @echo "• Solana blockchain governance"
    @echo "• Magic Block gasless transactions"
    @echo "• Noise Protocol encryption"
    @echo "• Nostr protocol compatibility"
    @echo "• Decentralized relay network"
    @echo ""
    @echo "Requirements:"
    @echo "• macOS 12.0+ (Monterey)"
    @echo "• Solana wallet (Phantom/Solflare)"
    @echo "• Internet connection for blockchain"
    @echo ""
    @echo "Usage:"
    @echo "• Connect wallet and join DAO"
    @echo "• Send gasless messages via Magic Block"
    @echo "• Participate in governance voting"
    @echo "• Earn rewards by running relay nodes"

# Force clean everything (nuclear option)
nuke:
    @echo "Nuclear clean - removing all build artifacts and backups..."
    @rm -rf ~/Library/Developer/Xcode/DerivedData/olivia-* 2>/dev/null || true
    @rm -rf olivia.xcodeproj 2>/dev/null || true
    @rm -f olivia.xcodeproj/project.pbxproj.backup 2>/dev/null || true
    @rm -f olivia/Info.plist.backup 2>/dev/null || true
    @# Restore iOS-specific files if they were moved
    @if [ -f olivia/LaunchScreen.storyboard.ios ]; then mv olivia/LaunchScreen.storyboard.ios olivia/LaunchScreen.storyboard; fi
    @git checkout olivia.xcodeproj/project.pbxproj olivia/Info.plist 2>/dev/null || echo "⚠️  Not a git repo or no changes to restore"
    @echo "Nuclear clean complete"

# Deploy Solana contracts (delegates to separate script)
deploy-solana:
    @echo "🚀 Deploying OLIVIA DAO to Solana..."
    @echo "This will run the dedicated Solana deployment script"
    @cd Solana && ./deploy-mainnet.sh
