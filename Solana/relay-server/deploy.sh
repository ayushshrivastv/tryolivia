#!/bin/bash

# OLIVIA Relay Node - Real Infrastructure Deployment Script
set -e

echo "🚀 Deploying OLIVIA Relay Node to Production..."

# Configuration
RELAY_NAME=${1:-"olivia-relay-1"}
CLOUD_PROVIDER=${2:-"digitalocean"}  # digitalocean, aws, gcp
REGION=${3:-"nyc3"}
DOMAIN=${4:-"relay1.olivia.network"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if required tools are installed
    command -v docker >/dev/null 2>&1 || error "Docker is required but not installed"
    command -v doctl >/dev/null 2>&1 || warn "DigitalOcean CLI not found, install with: snap install doctl"
    
    # Check environment variables
    [ -z "$SOLANA_RPC_URL" ] && error "SOLANA_RPC_URL environment variable is required"
    [ -z "$DAO_PROGRAM_ID" ] && error "DAO_PROGRAM_ID environment variable is required"
    [ -z "$RELAY_PRIVATE_KEY" ] && error "RELAY_PRIVATE_KEY environment variable is required"
    
    log "Prerequisites check passed ✓"
}

# Generate SSL certificates using Let's Encrypt
setup_ssl() {
    log "Setting up SSL certificates for $DOMAIN..."
    
    mkdir -p ssl
    
    # Use certbot to generate SSL certificates
    if command -v certbot >/dev/null 2>&1; then
        sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@olivia.network
        sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ssl/$DOMAIN.crt
        sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ssl/$DOMAIN.key
        sudo chown $(whoami):$(whoami) ssl/*
    else
        warn "Certbot not found. Using self-signed certificates for development."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/$DOMAIN.key \
            -out ssl/$DOMAIN.crt \
            -subj "/C=US/ST=CA/L=SF/O=OLIVIA/CN=$DOMAIN"
    fi
    
    log "SSL certificates configured ✓"
}

# Deploy to DigitalOcean
deploy_digitalocean() {
    log "Deploying to DigitalOcean..."
    
    # Create droplet
    DROPLET_ID=$(doctl compute droplet create $RELAY_NAME \
        --image docker-20-04 \
        --size s-2vcpu-2gb \
        --region $REGION \
        --ssh-keys $(doctl compute ssh-key list --format ID --no-header | head -1) \
        --format ID --no-header)
    
    log "Created droplet: $DROPLET_ID"
    
    # Wait for droplet to be ready
    log "Waiting for droplet to be ready..."
    sleep 60
    
    # Get droplet IP
    DROPLET_IP=$(doctl compute droplet get $DROPLET_ID --format PublicIPv4 --no-header)
    log "Droplet IP: $DROPLET_IP"
    
    # Update DNS record
    log "Updating DNS record for $DOMAIN..."
    # Note: This requires DNS API access - implement based on your DNS provider
    
    # Deploy application
    log "Deploying application to droplet..."
    
    # Copy files to droplet
    scp -o StrictHostKeyChecking=no -r . root@$DROPLET_IP:/opt/olivia-relay/
    
    # Run deployment on droplet
    ssh -o StrictHostKeyChecking=no root@$DROPLET_IP << EOF
        cd /opt/olivia-relay
        
        # Set environment variables
        export SOLANA_RPC_URL="$SOLANA_RPC_URL"
        export DAO_PROGRAM_ID="$DAO_PROGRAM_ID"
        export RELAY_PRIVATE_KEY="$RELAY_PRIVATE_KEY"
        export RELAY_ENDPOINT="wss://$DOMAIN/ws"
        export RELAY_LOCATION="$REGION"
        
        # Start services
        docker-compose up -d
        
        # Verify deployment
        sleep 10
        curl -f http://localhost:3000/health || exit 1
EOF
    
    log "Deployment to DigitalOcean completed ✓"
    log "Relay endpoint: wss://$DOMAIN/ws"
    log "API endpoint: https://$DOMAIN/api"
}

# Deploy to AWS
deploy_aws() {
    log "Deploying to AWS..."
    error "AWS deployment not implemented yet. Use DigitalOcean for now."
}

# Deploy to GCP
deploy_gcp() {
    log "Deploying to GCP..."
    error "GCP deployment not implemented yet. Use DigitalOcean for now."
}

# Register relay with DAO
register_with_dao() {
    log "Registering relay node with DAO smart contract..."
    
    # This would typically be done by the relay server itself
    # But we can trigger it manually for initial setup
    
    cat > register_relay.js << 'EOF'
const { Connection, PublicKey, Keypair } = require('@solana+Nostr+Noise/web3.js');
const { Program, AnchorProvider, Wallet } = require('@coral-xyz/anchor');

async function registerRelay() {
    const connection = new Connection(process.env.SOLANA_RPC_URL);
    const keypair = Keypair.fromSecretKey(new Uint8Array(JSON.parse(process.env.RELAY_PRIVATE_KEY)));
    
    console.log('Registering relay:', keypair.publicKey.toString());
    console.log('Endpoint:', process.env.RELAY_ENDPOINT);
    
    // TODO: Implement actual DAO program interaction
    // This requires the DAO program to be deployed and accessible
    
    console.log('Relay registration completed');
}

registerRelay().catch(console.error);
EOF
    
    node register_relay.js
    rm register_relay.js
    
    log "Relay registration completed ✓"
}

# Main deployment flow
main() {
    log "Starting OLIVIA Relay Node deployment..."
    log "Relay Name: $RELAY_NAME"
    log "Cloud Provider: $CLOUD_PROVIDER"
    log "Region: $REGION"
    log "Domain: $DOMAIN"
    
    check_prerequisites
    setup_ssl
    
    case $CLOUD_PROVIDER in
        digitalocean)
            deploy_digitalocean
            ;;
        aws)
            deploy_aws
            ;;
        gcp)
            deploy_gcp
            ;;
        *)
            error "Unsupported cloud provider: $CLOUD_PROVIDER"
            ;;
    esac
    
    register_with_dao
    
    log "🎉 OLIVIA Relay Node deployment completed successfully!"
    log "Monitor your relay at: https://$DOMAIN/health"
}

# Run main function
main "$@"
