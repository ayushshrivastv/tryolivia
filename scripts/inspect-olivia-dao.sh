#!/bin/bash

# OLIVIA DAO Account Inspector using Arcium SAD tool
# This script uses the Solana Account Deserializer to inspect OLIVIA DAO accounts

OLIVIA_PROGRAM_ID="BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA"
SAD_PATH="./solana-gadgets/rust/sad/target/release/sad"
YAML_DECL="./solana-gadgets/samples/yamldecls/${OLIVIA_PROGRAM_ID}.yml"

echo "🔍 OLIVIA DAO Account Inspector"
echo "==============================="
echo "Program ID: $OLIVIA_PROGRAM_ID"
echo "Using Arcium SAD tool for account deserialization"
echo ""

# Check if SAD tool is built
if [ ! -f "$SAD_PATH" ]; then
    echo "⚠️  SAD tool not found. Building..."
    cd solana-gadgets/rust/sad
    cargo build --release
    cd ../../..
fi

# Function to inspect all program accounts
inspect_all_accounts() {
    echo "📊 Inspecting all OLIVIA DAO program accounts..."
    echo "================================================"
    
    $SAD_PATH program \
        -p $OLIVIA_PROGRAM_ID \
        -d $YAML_DECL \
        -u https://api.devnet.solana.com \
        -o json \
        -f olivia_dao_accounts.json
    
    echo "✅ Results saved to olivia_dao_accounts.json"
}

# Function to inspect specific account
inspect_account() {
    local account_key=$1
    echo "🔍 Inspecting account: $account_key"
    echo "=================================="
    
    $SAD_PATH account \
        -p $account_key \
        -d $YAML_DECL \
        -u https://api.devnet.solana.com
}

# Function to get DAO state account
get_dao_state() {
    echo "🏛️ Getting OLIVIA DAO State Account..."
    echo "====================================="
    
    # DAO state is typically at a PDA derived from ["dao_state"]
    # We'll need to calculate this or find it through program accounts
    inspect_all_accounts | jq '.[] | select(.data.authority != null)'
}

# Function to show account statistics
show_stats() {
    echo "📈 OLIVIA DAO Statistics"
    echo "======================="
    
    # Get all accounts and analyze
    $SAD_PATH program \
        -p $OLIVIA_PROGRAM_ID \
        -d $YAML_DECL \
        -u https://api.devnet.solana.com \
        -o json | jq '
        {
            "total_accounts": length,
            "dao_states": [.[] | select(.data.authority != null)] | length,
            "proposals": [.[] | select(.data.proposal_type != null)] | length,
            "members": [.[] | select(.data.wallet != null and .data.joined_at != null)] | length,
            "relays": [.[] | select(.data.node_id != null)] | length,
            "votes": [.[] | select(.data.vote_choice != null)] | length
        }'
}

# Function to monitor real-time changes
monitor_dao() {
    echo "👀 Monitoring OLIVIA DAO (Press Ctrl+C to stop)"
    echo "==============================================="
    
    while true; do
        clear
        echo "🕐 $(date)"
        show_stats
        echo ""
        echo "Refreshing in 30 seconds..."
        sleep 30
    done
}

# Main menu
case "${1:-menu}" in
    "all")
        inspect_all_accounts
        ;;
    "account")
        if [ -z "$2" ]; then
            echo "Usage: $0 account <account_key>"
            exit 1
        fi
        inspect_account $2
        ;;
    "state")
        get_dao_state
        ;;
    "stats")
        show_stats
        ;;
    "monitor")
        monitor_dao
        ;;
    "menu"|*)
        echo "OLIVIA DAO Inspector Commands:"
        echo "=============================="
        echo "$0 all          - Inspect all program accounts"
        echo "$0 account <key> - Inspect specific account"
        echo "$0 state        - Get DAO state account"
        echo "$0 stats        - Show DAO statistics"
        echo "$0 monitor      - Monitor DAO in real-time"
        echo ""
        echo "Examples:"
        echo "$0 all"
        echo "$0 stats"
        echo "$0 account 5gMsBeLmPkwEKQ1H2AwceAPasXLyZ4tvWGCYR59qf47U"
        ;;
esac
