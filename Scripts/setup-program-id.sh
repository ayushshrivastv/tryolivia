#!/bin/bash
# Setup script to ensure program ID matches declared ID

DECLARED_ID="Eb8zo9c1YwtGw64C4TRcWxuPCBAVHVPUBUC7jcGNVWYJ"

echo "Setting up program keypair for ID: $DECLARED_ID"

# Create deploy directory if it doesn't exist
mkdir -p target/deploy

# Generate keypair using solana-keygen with the specific pubkey
# First, generate a random keypair, then we'll need to extract the secret key
# that corresponds to our desired pubkey

# For now, Anchor expects the keypair file in a specific format
# The keypair file should contain the secret key bytes as a JSON array

# Check if keypair already exists and matches
if [ -f "target/deploy/prediction_market-keypair.json" ]; then
    CURRENT_ID=$(solana-keygen pubkey target/deploy/prediction_market-keypair.json 2>/dev/null)
    if [ "$CURRENT_ID" == "$DECLARED_ID" ]; then
        echo "✓ Keypair already matches declared ID"
        exit 0
    fi
fi

echo "Note: To use the exact declared ID, you may need to:"
echo "1. Generate a keypair with that specific pubkey (requires private key derivation)"
echo "2. Or update declare_id! in lib.rs to match a newly generated keypair"
echo ""
echo "For now, generating a new keypair..."
solana-keygen new --no-bip39-passphrase -o target/deploy/prediction_market-keypair.json

GENERATED_ID=$(solana-keygen pubkey target/deploy/prediction_market-keypair.json)
echo ""
echo "Generated keypair with ID: $GENERATED_ID"
echo ""
echo "Next steps:"
echo "1. Update declare_id!(\"$GENERATED_ID\") in Programs/PredictionMarket/src/lib.rs"
echo "2. Update Anchor.toml programs.localnet.PredictionMarket = \"$GENERATED_ID\""
echo "3. Run anchor build again"

