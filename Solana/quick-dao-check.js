#!/usr/bin/env node

/**
 * Quick OLIVIA DAO Account Inspector
 * Uses Solana Web3.js to inspect deployed OLIVIA DAO accounts
 */

const { Connection, PublicKey } = require('@solana/web3.js');

const OLIVIA_PROGRAM_ID = 'BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA';
const RPC_URL = 'https://api.devnet.solana.com';

async function inspectOliviaDAO() {
    console.log('🔍 OLIVIA DAO Quick Inspector');
    console.log('=============================');
    console.log(`Program ID: ${OLIVIA_PROGRAM_ID}`);
    console.log(`RPC URL: ${RPC_URL}`);
    console.log('');

    const connection = new Connection(RPC_URL, 'confirmed');
    const programId = new PublicKey(OLIVIA_PROGRAM_ID);

    try {
        // Get program info
        console.log('📋 Program Information:');
        const programInfo = await connection.getAccountInfo(programId);
        if (programInfo) {
            console.log(`✅ Program is deployed`);
            console.log(`   Owner: ${programInfo.owner.toString()}`);
            console.log(`   Executable: ${programInfo.executable}`);
            console.log(`   Data Length: ${programInfo.data.length} bytes`);
        } else {
            console.log('❌ Program not found');
            return;
        }

        console.log('');

        // Get all program accounts
        console.log('🏛️ Program Owned Accounts:');
        const accounts = await connection.getProgramAccounts(programId);
        
        console.log(`Found ${accounts.length} accounts owned by OLIVIA DAO program`);
        console.log('');

        if (accounts.length === 0) {
            console.log('ℹ️  No accounts found. DAO may not be initialized yet.');
            return;
        }

        // Analyze accounts
        let daoStateAccounts = 0;
        let proposalAccounts = 0;
        let memberAccounts = 0;
        let relayAccounts = 0;
        let otherAccounts = 0;

        accounts.forEach((account, index) => {
            const dataLength = account.account.data.length;
            console.log(`Account ${index + 1}:`);
            console.log(`  Address: ${account.pubkey.toString()}`);
            console.log(`  Data Length: ${dataLength} bytes`);
            console.log(`  Lamports: ${account.account.lamports}`);
            
            // Try to categorize based on data length (rough estimation)
            if (dataLength > 200) {
                console.log(`  Likely Type: DAO State or Large Proposal`);
                daoStateAccounts++;
            } else if (dataLength > 100) {
                console.log(`  Likely Type: Proposal or Member`);
                proposalAccounts++;
            } else if (dataLength > 50) {
                console.log(`  Likely Type: Member or Vote Record`);
                memberAccounts++;
            } else {
                console.log(`  Likely Type: Small data account`);
                otherAccounts++;
            }
            
            // Show first few bytes as hex for debugging
            const firstBytes = account.account.data.slice(0, 8);
            console.log(`  First 8 bytes: ${firstBytes.toString('hex')}`);
            console.log('');
        });

        // Summary
        console.log('📊 Account Summary:');
        console.log(`   Large accounts (likely DAO state): ${daoStateAccounts}`);
        console.log(`   Medium accounts (likely proposals): ${proposalAccounts}`);
        console.log(`   Small accounts (likely members/votes): ${memberAccounts}`);
        console.log(`   Other accounts: ${otherAccounts}`);
        console.log(`   Total accounts: ${accounts.length}`);

        // Check if we can find the DAO state PDA
        console.log('');
        console.log('🔍 Looking for DAO State PDA:');
        try {
            const [daoStatePDA] = PublicKey.findProgramAddressSync(
                [Buffer.from('dao_state')],
                programId
            );
            console.log(`Expected DAO State PDA: ${daoStatePDA.toString()}`);
            
            const daoStateInfo = await connection.getAccountInfo(daoStatePDA);
            if (daoStateInfo) {
                console.log('✅ DAO State account found!');
                console.log(`   Data Length: ${daoStateInfo.data.length} bytes`);
                console.log(`   Lamports: ${daoStateInfo.lamports}`);
                
                // Try to read some basic fields (assuming borsh serialization)
                if (daoStateInfo.data.length >= 64) {
                    console.log('   Raw data preview:');
                    console.log(`   First 32 bytes: ${daoStateInfo.data.slice(0, 32).toString('hex')}`);
                    console.log(`   Next 32 bytes: ${daoStateInfo.data.slice(32, 64).toString('hex')}`);
                }
            } else {
                console.log('❌ DAO State account not found at expected PDA');
            }
        } catch (error) {
            console.log(`❌ Error finding DAO State PDA: ${error.message}`);
        }

        console.log('');
        console.log('💡 Tips:');
        console.log('   - Use the Arcium SAD tool for detailed deserialization');
        console.log('   - Run ./scripts/inspect-olivia-dao.sh for advanced inspection');
        console.log('   - Check Solana Explorer: https://explorer.solana.com/address/' + OLIVIA_PROGRAM_ID + '?cluster=devnet');

    } catch (error) {
        console.error('❌ Error inspecting OLIVIA DAO:', error.message);
    }
}

// Run the inspector
inspectOliviaDAO().catch(console.error);
