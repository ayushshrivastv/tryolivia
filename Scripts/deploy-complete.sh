#!/bin/bash

###############################################################################
# Olivia Prediction Market - Complete Deployment Script
# This script handles the entire deployment process for localnet, devnet, or mainnet
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Olivia Prediction Market - Deployment Script         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Functions
###############################################################################

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✓${NC}  $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}✗${NC}  $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        exit 1
    fi
    log_success "$1 is installed"
}

###############################################################################
# Step 1: Pre-flight Checks
###############################################################################

log_info "Running pre-flight checks..."
echo ""

# Check required commands
check_command "anchor"
check_command "solana"
check_command "node"
check_command "docker"

# Check Anchor version
ANCHOR_VERSION=$(anchor --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
log_info "Anchor version: $ANCHOR_VERSION"

# Check Solana version
SOLANA_VERSION=$(solana --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
log_info "Solana version: $SOLANA_VERSION"

echo ""

###############################################################################
# Step 2: Select Network
###############################################################################

log_info "Select deployment target:"
echo "  1) Localnet (for development)"
echo "  2) Devnet (for testing)"
echo "  3) Mainnet-beta (for production)"
echo ""
read -p "Enter choice (1-3): " NETWORK_CHOICE

case $NETWORK_CHOICE in
    1)
        NETWORK="localnet"
        RPC_URL="http://localhost:8899"
        ;;
    2)
        NETWORK="devnet"
        RPC_URL="https://api.devnet.solana.com"
        ;;
    3)
        NETWORK="mainnet-beta"
        RPC_URL="https://api.mainnet-beta.solana.com"
        log_warning "Deploying to MAINNET. This will use real SOL!"
        read -p "Are you sure you want to continue? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            log_error "Deployment cancelled"
            exit 1
        fi
        ;;
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

log_success "Selected network: $NETWORK"
log_info "RPC URL: $RPC_URL"
echo ""

###############################################################################
# Step 3: Configure Solana CLI
###############################################################################

log_info "Configuring Solana CLI for $NETWORK..."
solana config set --url $RPC_URL
solana config set --commitment confirmed

# Check wallet
WALLET_PATH=$(solana config get keypair | grep "Keypair Path" | awk '{print $3}')
log_info "Using wallet: $WALLET_PATH"

WALLET_PUBKEY=$(solana-keygen pubkey $WALLET_PATH)
log_info "Wallet address: $WALLET_PUBKEY"

# Check balance
BALANCE=$(solana balance $WALLET_PUBKEY 2>&1 | grep -oE '[0-9]+\.[0-9]+' || echo "0")
log_info "Wallet balance: $BALANCE SOL"

# Check minimum balance
MIN_BALANCE="5.0"
if (( $(echo "$BALANCE < $MIN_BALANCE" | bc -l) )); then
    log_warning "Insufficient balance. Need at least $MIN_BALANCE SOL"

    if [ "$NETWORK" == "devnet" ]; then
        log_info "Requesting airdrop..."
        solana airdrop 2 $WALLET_PUBKEY || true
        sleep 5
        BALANCE=$(solana balance $WALLET_PUBKEY | grep -oE '[0-9]+\.[0-9]+')
        log_info "New balance: $BALANCE SOL"
    else
        log_error "Please fund your wallet with at least $MIN_BALANCE SOL"
        exit 1
    fi
fi

echo ""

###############################################################################
# Step 4: Build Program
###############################################################################

log_info "Building Solana program..."
cd "$PROJECT_ROOT"

# Build with Anchor
anchor build --skip-lint

if [ $? -eq 0 ]; then
    log_success "Program built successfully"
else
    log_error "Build failed"
    exit 1
fi

# Get program ID from keypair
PROGRAM_ID=$(solana-keygen pubkey target/deploy/prediction_market-keypair.json)
log_info "Program ID: $PROGRAM_ID"

# Verify program ID matches declare_id in code
DECLARED_ID=$(grep -oP 'declare_id!\("\K[^"]+' Programs/PredictionMarket/src/lib.rs)
if [ "$PROGRAM_ID" != "$DECLARED_ID" ]; then
    log_error "Program ID mismatch!"
    log_error "  Keypair: $PROGRAM_ID"
    log_error "  Declared: $DECLARED_ID"
    exit 1
fi

log_success "Program ID matches declared ID"
echo ""

###############################################################################
# Step 5: Start ARX Nodes (Localnet only)
###############################################################################

if [ "$NETWORK" == "localnet" ]; then
    log_info "Starting ARX nodes for local development..."

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi

    # Start ARX nodes
    cd "$PROJECT_ROOT/Arcium/artifacts"
    docker-compose -f docker-compose-arx-env.yml up -d

    if [ $? -eq 0 ]; then
        log_success "ARX nodes started"

        # Wait for nodes to be ready
        log_info "Waiting for ARX nodes to initialize (30 seconds)..."
        sleep 30

        # Check node status
        docker-compose -f docker-compose-arx-env.yml ps
    else
        log_error "Failed to start ARX nodes"
        exit 1
    fi

    cd "$PROJECT_ROOT"
    echo ""
fi

###############################################################################
# Step 6: Start Solana Test Validator (Localnet only)
###############################################################################

if [ "$NETWORK" == "localnet" ]; then
    log_info "Checking if Solana test validator is running..."

    if ! curl -s http://localhost:8899 &> /dev/null; then
        log_info "Starting Solana test validator..."

        # Clone Arcium program to localnet
        ARCIUM_PROGRAM_ID="BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6"

        solana-test-validator \
            --clone $ARCIUM_PROGRAM_ID \
            --url devnet \
            --reset &> .local-validator.log &

        VALIDATOR_PID=$!
        log_info "Validator PID: $VALIDATOR_PID"

        # Wait for validator to start
        log_info "Waiting for validator to start (15 seconds)..."
        sleep 15

        # Verify it's running
        if curl -s http://localhost:8899 &> /dev/null; then
            log_success "Solana test validator is running"
        else
            log_error "Failed to start test validator"
            exit 1
        fi
    else
        log_success "Solana test validator already running"
    fi

    echo ""
fi

###############################################################################
# Step 7: Deploy Program
###############################################################################

log_info "Deploying program to $NETWORK..."

anchor deploy --provider.cluster $NETWORK

if [ $? -eq 0 ]; then
    log_success "Program deployed successfully"
else
    log_error "Deployment failed"
    exit 1
fi

# Verify deployment
DEPLOYED_PROGRAM=$(solana program show $PROGRAM_ID 2>&1)
if echo "$DEPLOYED_PROGRAM" | grep -q "ProgramData Address"; then
    log_success "Program verified on-chain"
else
    log_warning "Could not verify program deployment"
fi

echo ""

###############################################################################
# Step 8: Initialize Arcium
###############################################################################

log_info "Initializing Arcium MXE and computation definitions..."

if [ "$NETWORK" == "devnet" ]; then
    # Initialize MXE on devnet
    log_info "Initializing MXE account..."
    node "$PROJECT_ROOT/Arcium/scripts/init-mxe-devnet.js"

    if [ $? -eq 0 ]; then
        log_success "MXE initialized"
    else
        log_error "MXE initialization failed"
        exit 1
    fi

    # Initialize computation definitions
    log_info "Initializing computation definitions..."
    node "$PROJECT_ROOT/Arcium/scripts/init-comp-defs-devnet.js"

    if [ $? -eq 0 ]; then
        log_success "Computation definitions initialized"
    else
        log_error "Computation definition initialization failed"
        exit 1
    fi
elif [ "$NETWORK" == "localnet" ]; then
    # Initialize for localnet
    log_info "Initializing Arcium for localnet..."
    node "$PROJECT_ROOT/Arcium/scripts/init-arcium-localnet.js"

    if [ $? -eq 0 ]; then
        log_success "Arcium initialized for localnet"
    else
        log_error "Arcium initialization failed"
        exit 1
    fi
fi

echo ""

###############################################################################
# Step 9: Update Frontend Configuration
###############################################################################

log_info "Updating frontend configuration..."

# Update .env.local
ENV_FILE="$PROJECT_ROOT/Frontend/.env.local"

cat > "$ENV_FILE" << EOF
NEXT_PUBLIC_SOLANA_NETWORK=$NETWORK
NEXT_PUBLIC_SOLANA_RPC_URL=$RPC_URL
NEXT_PUBLIC_PREDICTION_MARKET_PROGRAM_ID=$PROGRAM_ID
NEXT_PUBLIC_ARCIUM_CLUSTER_OFFSET=1078779259
NEXT_PUBLIC_DEMO_NO_ARCIUM=false
EOF

log_success "Frontend environment configured"
log_info "Configuration:"
cat "$ENV_FILE"

echo ""

###############################################################################
# Step 10: Build Frontend
###############################################################################

log_info "Building frontend..."
cd "$PROJECT_ROOT/Frontend"

npm install
npm run build

if [ $? -eq 0 ]; then
    log_success "Frontend built successfully"
else
    log_error "Frontend build failed"
    exit 1
fi

echo ""

###############################################################################
# Summary
###############################################################################

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║               Deployment Successful!                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_success "Network: $NETWORK"
log_success "Program ID: $PROGRAM_ID"
log_success "Wallet: $WALLET_PUBKEY"
echo ""
log_info "Next steps:"
echo "  1. Start the frontend: cd Frontend && npm run dev"
echo "  2. Open browser: http://localhost:3000"
echo "  3. Connect your wallet"
echo "  4. Start betting!"
echo ""

if [ "$NETWORK" == "devnet" ] || [ "$NETWORK" == "mainnet-beta" ]; then
    echo "  View on Solscan:"
    echo "  https://solscan.io/account/$PROGRAM_ID?cluster=$NETWORK"
    echo ""
fi

if [ "$NETWORK" == "localnet" ]; then
    log_info "ARX nodes status:"
    cd "$PROJECT_ROOT/Arcium/artifacts"
    docker-compose -f docker-compose-arx-env.yml ps
    echo ""
    log_info "To stop localnet:"
    echo "  pkill solana-test-validator"
    echo "  docker-compose -f Arcium/artifacts/docker-compose-arx-env.yml down"
fi

echo -e "${GREEN}Deployment complete!${NC}"
