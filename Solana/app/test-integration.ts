import { Connection, PublicKey, Keypair } from '@solana/web3.js';

async function testSolanaConnection() {
    console.log('🚀 Testing Solana Connection...');
    
    try {
        // Connect to devnet
        const connection = new Connection('https://api.devnet.solana.com', 'confirmed');
        
        // Create a test wallet
        const wallet = Keypair.generate();
        console.log('📝 Generated test wallet:', wallet.publicKey.toString());
        
        // Request airdrop
        console.log('💰 Requesting airdrop...');
        const airdropSignature = await connection.requestAirdrop(wallet.publicKey, 1000000000); // 1 SOL
        await connection.confirmTransaction(airdropSignature);
        
        const balance = await connection.getBalance(wallet.publicKey);
        console.log('💳 Wallet balance:', balance / 1000000000, 'SOL');
        
        // Test program ID
        const programId = new PublicKey('BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA');
        console.log('🎯 Program ID:', programId.toString());
        
        // Check if program exists
        const programInfo = await connection.getAccountInfo(programId);
        if (programInfo) {
            console.log('✅ DAO program found on devnet!');
            console.log('📊 Program data length:', programInfo.data.length);
            console.log('👤 Program owner:', programInfo.owner.toString());
        } else {
            console.log('⚠️  DAO program not found (may need deployment)');
        }
        
        console.log('🎉 Solana connection test completed!');
        
    } catch (error) {
        console.error('❌ Connection test failed:', error instanceof Error ? error.message : error);
    }
}

// Run the test
testSolanaConnection();
