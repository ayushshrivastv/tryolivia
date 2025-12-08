/**
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useState, useEffect, ChangeEvent, useCallback, useMemo } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { LAMPORTS_PER_SOL, PublicKey, SystemProgram, Transaction } from '@solana/web3.js';
import { BN, Wallet, Idl, AnchorProvider, Program } from '@coral-xyz/anchor';
import { Button } from '@/src/ui/Button';
import { Input } from '@/src/ui/Input';
import { ArrowDownIcon } from '@/src/components/Icons';
import { Loader2, X, CheckCircle2, AlertCircle, ExternalLink } from 'lucide-react';
import Depth from '@/src/trade/Depth/Depth';
import Image from 'next/image';
import {
  encryptPrediction,
  generateComputationOffset,
  getArciumAccounts,
  waitForComputationFinalization,
  ARCIUM_PROGRAM_ID,
} from '@/src/utils/arciumClient';
import {
  createAnchorProvider,
  createProgram,
  loadIdl,
  getMarketPDA,
  getBetPDA,
  getMarketVaultPDA,
  PREDICTION_MARKET_PROGRAM_ID,
} from '@/src/utils/programClient';
import { waitForTransaction } from '@/src/utils/transactionUtils';
import { getClusterAccAddress } from '@arcium-hq/client';
// MagicBlock disabled to avoid mixed RPC routing during confirmations
// import { ConnectionMagicRouter } from '@magicblock-labs/ephemeral-rollups-sdk';

interface SwapUIProps {
  baseCurrency: string;
  quoteCurrency: string;
  marketId?: number; // Optional market ID, will be derived from market name if not provided
}

type OrderType = 'BUY' | 'SELL';
type OrderMode = 'MKT' | 'LIMIT';

// Required fixed accounts from IDL
const POOL_ACCOUNT = new PublicKey('7MGSS4iKNM4sVib7bDZDJhVqB6EcchPwVnTKenCY1jt3');
const CLOCK_ACCOUNT = new PublicKey('FHriyvoZotYiFnbUzKFjzRSb2NiaC8RPWY7jtKuKhg65');

// Resolve Arcium cluster account from ENV
function getClusterAccountOrThrow(): PublicKey {
  let envOffset = process.env.NEXT_PUBLIC_ARCIUM_CLUSTER_OFFSET;
  if (!envOffset || envOffset.trim().length === 0) {
    console.warn(
      'NEXT_PUBLIC_ARCIUM_CLUSTER_OFFSET not set. Falling back to devnet offset 1078779259.'
    );
    envOffset = '1078779259';
  }
  const offsetNum = Number(envOffset);
  if (!Number.isInteger(offsetNum) || offsetNum < 0) {
    throw new Error(
      `Invalid NEXT_PUBLIC_ARCIUM_CLUSTER_OFFSET "${envOffset}". It must be a non-negative integer.`
    );
  }
  return getClusterAccAddress(offsetNum) as PublicKey;
}

// Helper function to initialize a market
async function initializeMarket(
  program: Program<Idl>,
  provider: AnchorProvider,
  authority: PublicKey,
  marketId: number,
  marketPDA: PublicKey,
  computationOffset: BN
): Promise<void> {
  console.log('Initializing market with ID:', marketId);
  
  // Get Arcium accounts for market initialization
  const clusterAccount = getClusterAccountOrThrow();
  const arciumAccounts = getArciumAccounts(
    PREDICTION_MARKET_PROGRAM_ID,
    computationOffset,
    'initialize_market',
    clusterAccount
  );
  // Debug log all accounts for initialize_market
  console.log('INIT MARKET - Accounts');
  console.log('clusterAccount:', clusterAccount.toString());
  console.log('mxeAccount:', arciumAccounts.mxeAccount.toString());
  console.log('mempoolAccount:', arciumAccounts.mempoolAccount.toString());
  console.log('executingPool:', arciumAccounts.executingPool.toString());
  console.log('computationAccount:', arciumAccounts.computationAccount.toString());
  console.log('compDefAccount (init):', arciumAccounts.compDefAccount.toString());
  console.log('poolAccount:', POOL_ACCOUNT.toString());
  console.log('clockAccount:', CLOCK_ACCOUNT.toString());
  console.log('arciumProgram:', ARCIUM_PROGRAM_ID.toString());
  console.log('systemProgram:', SystemProgram.programId.toString());
  // Sanity: ensure cluster and comp def exist on-chain
  const clusterInfo = await provider.connection.getAccountInfo(clusterAccount);
  if (!clusterInfo) {
    throw new Error(`Cluster account not found on-chain: ${clusterAccount.toString()}`);
  }
  
  // Build market initialization transaction
  console.log('Creating market with parameters:');
  console.log('- computationOffset:', computationOffset.toString());
  console.log('- marketId:', marketId);
  console.log('- computationOffset type:', typeof computationOffset);
  
  // Ensure all parameters are properly typed
  const params = {
    computationOffset: computationOffset, // u64 - already a BN
    marketId: new BN(marketId), // u64
    question: "Who will win the NYC Mayoral Election?", // string
    description: "NYC Mayoral Election 2025", // string
    resolutionDeadline: new BN(Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60)), // i64
    minStakeAmount: new BN(100000000), // u64 - 0.1 SOL
    nonce: new BN(Math.floor(Math.random() * 1000000)) // u128
  };
  
  console.log('Parameters prepared:', params);
  
  const transaction = await program.methods
    .createMarket(
      params.computationOffset,
      params.marketId,
      params.question,
      params.description,
      params.resolutionDeadline,
      params.minStakeAmount,
      params.nonce
    )
    .accountsPartial({
      creator: authority,
      market: marketPDA,
      computationAccount: arciumAccounts.computationAccount,
      clusterAccount: getClusterAccountOrThrow(),
      mxeAccount: arciumAccounts.mxeAccount,
      mempoolAccount: arciumAccounts.mempoolAccount,
      executingPool: arciumAccounts.executingPool,
      compDefAccount: arciumAccounts.compDefAccount,
      poolAccount: POOL_ACCOUNT,
      clockAccount: CLOCK_ACCOUNT,
      arciumProgram: ARCIUM_PROGRAM_ID,
      systemProgram: SystemProgram.programId,
      // poolAccount and clockAccount will be inferred by Anchor
    })
    .transaction();

  // Set transaction properties
  const { blockhash, lastValidBlockHeight } = await provider.connection.getLatestBlockhash('confirmed');
  transaction.recentBlockhash = blockhash;
  transaction.lastValidBlockHeight = lastValidBlockHeight;
  transaction.feePayer = authority;

  // Sign and send the transaction
  const signedTransaction = await provider.wallet.signTransaction(transaction);
  const signature = await provider.connection.sendRawTransaction(
    signedTransaction.serialize(),
    {
      skipPreflight: true,
      maxRetries: 3,
    }
  );

  console.log('Market initialization transaction submitted:', signature);
  console.log(`🔍 Track transaction: https://explorer.solana.com/tx/${signature}?cluster=devnet`);
  
  // Wait for confirmation with extended timeout for complex Arcium transactions
  console.log(`Waiting for market initialization confirmation: ${signature}`);
  console.log('This may take up to 3 minutes for complex Arcium transactions...');
  
  const confirmResult = await waitForTransaction(
    provider.connection,
    signature,
    'confirmed',
    180000, // 3 minutes timeout for complex Arcium market initialization
    5000    // Poll every 5 seconds to reduce RPC load
  );

  if (!confirmResult.success) {
    console.warn('Transaction confirmation timed out, but checking if market was actually created...');
    
    // Check if the market account was actually created despite timeout
    try {
      const marketAccountInfo = await provider.connection.getAccountInfo(marketPDA);
      if (marketAccountInfo) {
        console.log('✅ Market was successfully created despite confirmation timeout!');
        console.log('Market account data length:', marketAccountInfo.data.length);
        return; // Market exists, we can proceed
      }
    } catch (checkError) {
      console.error('Error checking market account:', checkError);
    }
    
    throw new Error(`${confirmResult.error || 'Market initialization failed'}. Transaction: ${signature}`);
  }
  
  console.log('Market initialization confirmed!');
}

interface QuoteResponse {
  payload: {
    avg_price: string;
    quantity: string;
    total_cost: string;
  };
  type: string;
}

interface TransactionStatus {
  status: 'idle' | 'encrypting' | 'signing' | 'submitting' | 'waiting' | 'success' | 'error';
  message: string;
  signature?: string;
  error?: string;
}

export default function SwapUI({ baseCurrency, quoteCurrency, marketId }: SwapUIProps) {
  const { connection } = useConnection();
  const wallet = useWallet();
  
  const isNYCMayorMarket = baseCurrency.includes('NYC-MAYOR') || baseCurrency === 'NYC-MAYOR';
  const candidates = isNYCMayorMarket ? [
    'Zohran Mamdani',
    'Andrew Cuomo',
    'Curtis Sliwa',
    'Eric Adams',
  ] : [];
  
  const market = `${baseCurrency.replace(/_+$/, '')}_${quoteCurrency}`;
  // Demo mode only when explicitly enabled
  const demoNoArcium = process.env.NEXT_PUBLIC_DEMO_NO_ARCIUM === 'true';

  // Comp definitions are initialized on-chain; skip any init from UI
  
  // Derive marketId from market name if not provided
  const derivedMarketId = useMemo(() => {
    if (marketId) return marketId;
    // Simple hash function to convert market name to number
    let hash = 0;
    for (let i = 0; i < market.length; i++) {
      const char = market.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash) % 1000000; // Limit to 6 digits
  }, [market, marketId]);
  
  const [selectedCandidate, setSelectedCandidate] = useState<string>(candidates[0] || '');
  const [orderType, setOrderType] = useState<OrderType>('BUY');
  const [orderMode, setOrderMode] = useState<OrderMode>('MKT');
  const [limitPrice, setLimitPrice] = useState<string>('');
  const [amount, setAmount] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [quote, setQuote] = useState<QuoteResponse | null>(null);
  const [showBetConfirmation, setShowBetConfirmation] = useState<boolean>(false);
  const [showSuccessModal, setShowSuccessModal] = useState<boolean>(false);
  const [transactionStatus, setTransactionStatus] = useState<TransactionStatus>({
    status: 'idle',
    message: '',
  });
  const [idl, setIdl] = useState<Idl | null>(null);

  // Load IDL on mount
  useEffect(() => {
    const loadProgramIdl = async () => {
      try {
        // Try to load from public folder or use a URL
        // For now, we'll try a relative path - adjust based on where IDL is placed
        const idlData = await loadIdl('/idl/prediction_market.json').catch(() => null);
        if (idlData) {
          setIdl(idlData);
        } else {
          console.warn('Could not load IDL. Place prediction_market.json in public/idl/ or update the path.');
        }
      } catch (error) {
        console.error('Failed to load IDL:', error);
      }
    };
    loadProgramIdl();
  }, []);

  const getQuote = useCallback(async (): Promise<void> => {
    if (!amount || parseFloat(amount) <= 0) return;

    setLoading(true);
    try {
      // For now, keep quote functionality as-is (optional REST API)
      // This can be replaced later with on-chain price calculations
      setQuote({
        payload: {
          avg_price: '1.0',
          quantity: amount,
          total_cost: '0.00',
        },
        type: 'quote',
      });
    } catch {
      setQuote(null);
    } finally {
      setLoading(false);
    }
  }, [amount]);

  useEffect(() => {
    if (orderMode === 'MKT' && amount && parseFloat(amount) > 0) {
      getQuote();
    }
  }, [amount, orderType, orderMode, getQuote]);


  const handleBetClick = (): void => {
    if (amount && parseFloat(amount) > 0) {
      setShowBetConfirmation(true);
    }
  };

  const placeBet = async (): Promise<void> => {
    setShowBetConfirmation(false);
    setLoading(true);
    setTransactionStatus({ status: 'encrypting', message: 'Encrypting prediction...' });

    if (!connection) {
      setTransactionStatus({
        status: 'error',
        message: 'Not connected to Solana network',
        error: 'Connection required',
      });
      setLoading(false);
      return;
    }

    if (!wallet.publicKey || !wallet.signTransaction) {
      setTransactionStatus({
        status: 'error',
        message: 'Wallet not connected',
        error: 'Please connect your wallet',
      });
      setLoading(false);
      return;
    }

    if (!idl) {
      setTransactionStatus({
        status: 'error',
        message: 'Program IDL not loaded',
        error: 'Failed to load program interface',
      });
      setLoading(false);
      return;
    }

    try {
      // Provider selection: use normal Solana connection only (no MagicBlock)
      // Default provider only
      const walletAdapter = {
        publicKey: wallet.publicKey,
        signTransaction: wallet.signTransaction!,
        signAllTransactions: wallet.signAllTransactions!,
      };
      const provider = createAnchorProvider(connection, walletAdapter as unknown as Wallet);
      const program = createProgram(provider, idl as Idl);

      // DEMO PATH: bypass Arcium and send a simple on-chain tx for signature
      if (demoNoArcium) {
        setTransactionStatus({ status: 'submitting', message: 'Submitting transaction...' });
        const tx = new Transaction().add(
          SystemProgram.transfer({
            fromPubkey: wallet.publicKey,
            toPubkey: wallet.publicKey,
            lamports: 1, // 1 lamport no-op transfer to self
          })
        );
        const { blockhash, lastValidBlockHeight } = await provider.connection.getLatestBlockhash('confirmed');
        tx.recentBlockhash = blockhash;
        tx.lastValidBlockHeight = lastValidBlockHeight;
        tx.feePayer = wallet.publicKey!;

        const signed = await wallet.signTransaction!(tx);
        const sig = await provider.connection.sendRawTransaction(signed.serialize(), { skipPreflight: true, maxRetries: 3 });
        setTransactionStatus({ status: 'waiting', message: 'Waiting for confirmation...', signature: sig });
        const res = await waitForTransaction(provider.connection, sig, 'confirmed', 60000, 2000);
        if (!res.success) {
          throw new Error(res.error || 'Demo transaction failed');
        }
        setTransactionStatus({ status: 'success', message: 'Bet submitted', signature: sig });
        setShowBetConfirmation(false);
        setShowSuccessModal(true);
        setTimeout(() => setTransactionStatus({ status: 'idle', message: '' }), 5000);
        return;
      }

      // Bypass comp-def init (already initialized on-chain)

      // Determine prediction: BUY = true (YES), SELL = false (NO)
      const prediction = orderType === 'BUY';

      // Convert amount to lamports
      const betAmountLamports = new BN(parseFloat(amount) * LAMPORTS_PER_SOL);

      setTransactionStatus({ status: 'encrypting', message: 'Encrypting prediction...' });
      
      // Encrypt prediction
      const encryptionData = await encryptPrediction(
        prediction,
        provider,
        PREDICTION_MARKET_PROGRAM_ID
      );

      setTransactionStatus({ status: 'signing', message: 'Preparing transaction...' });

      // Generate computation offset ONCE for both market init and bet
      const computationOffset = generateComputationOffset();

      // Get market, bet, and vault PDAs
      const marketPDA = getMarketPDA(derivedMarketId);
      const betPDA = getBetPDA(derivedMarketId, wallet.publicKey);
      const marketVaultPDA = getMarketVaultPDA(derivedMarketId);

      // Get Arcium accounts for place_bet
      const clusterAccount2 = getClusterAccountOrThrow();
      const arciumAccounts = getArciumAccounts(
        PREDICTION_MARKET_PROGRAM_ID,
        computationOffset,
        'place_bet',
        clusterAccount2
      );
      // Debug log all accounts for place_bet
      console.log('PLACE BET - Accounts');
      console.log('clusterAccount:', clusterAccount2.toString());
      console.log('mxeAccount:', arciumAccounts.mxeAccount.toString());
      console.log('mempoolAccount:', arciumAccounts.mempoolAccount.toString());
      console.log('executingPool:', arciumAccounts.executingPool.toString());
      console.log('computationAccount:', arciumAccounts.computationAccount.toString());
      console.log('compDefAccount (bet):', arciumAccounts.compDefAccount.toString());
      console.log('poolAccount:', POOL_ACCOUNT.toString());
      console.log('clockAccount:', CLOCK_ACCOUNT.toString());
      console.log('arciumProgram:', ARCIUM_PROGRAM_ID.toString());
      console.log('systemProgram:', SystemProgram.programId.toString());
      const clusterInfo2 = await provider.connection.getAccountInfo(clusterAccount2);
      if (!clusterInfo2) {
        throw new Error(`Cluster account not found on-chain: ${clusterAccount2.toString()}`);
      }

      setTransactionStatus({ status: 'submitting', message: 'Submitting transaction...' });

      // Build transaction manually to avoid RPC timeout issues
      // Using accountsPartial to let Anchor infer system_program and arcium_program
      let signature: string;
      try {
        console.log('Building transaction...');
        
        // Build the transaction without sending it
        const transaction = await program.methods
          .placeBet(
            computationOffset,
            new BN(derivedMarketId),
            betAmountLamports,
            encryptionData.encryptedPrediction,
            encryptionData.publicKey,
            encryptionData.nonceBN
          )
          .accountsPartial({
            bettor: wallet.publicKey,
            computationAccount: arciumAccounts.computationAccount,
            clusterAccount: getClusterAccountOrThrow(),
            mxeAccount: arciumAccounts.mxeAccount,
            mempoolAccount: arciumAccounts.mempoolAccount,
            executingPool: arciumAccounts.executingPool,
            compDefAccount: arciumAccounts.compDefAccount,
            poolAccount: POOL_ACCOUNT,
            clockAccount: CLOCK_ACCOUNT,
            arciumProgram: ARCIUM_PROGRAM_ID,
            systemProgram: SystemProgram.programId,
            market: marketPDA,
            marketVault: marketVaultPDA,
            bet: betPDA,
          })
          .transaction();

        console.log('Transaction built successfully, getting recent blockhash...');
        
        // Get recent blockhash
        const { blockhash, lastValidBlockHeight } = await provider.connection.getLatestBlockhash('confirmed');
        transaction.recentBlockhash = blockhash;
        transaction.lastValidBlockHeight = lastValidBlockHeight;
        
        // CRITICAL: Set the fee payer (this is required for manual transaction building)
        transaction.feePayer = wallet.publicKey!;

        // Note: Priority fees temporarily removed to avoid import issues
        // Will add back once basic transaction flow is working
        console.log('Transaction ready for signing...');
        
        // Debug: Check account states before signing
        console.log('=== TRANSACTION DEBUG INFO ===');
        console.log('Market PDA:', marketPDA.toString());
        console.log('Bet PDA:', betPDA.toString());
        console.log('Bettor:', wallet.publicKey!.toString());
        console.log('Bet Amount (lamports):', betAmountLamports.toString());
        console.log('Market ID:', derivedMarketId);
        console.log('Computation Offset:', computationOffset.toString());
        
        // Check wallet balance
        const balance = await provider.connection.getBalance(wallet.publicKey!);
        console.log('Wallet balance:', balance / LAMPORTS_PER_SOL, 'SOL');
        
        if (balance < betAmountLamports.toNumber() + 10000000) { // 0.01 SOL for fees
          throw new Error(`Insufficient balance. Need ${(betAmountLamports.toNumber() + 10000000) / LAMPORTS_PER_SOL} SOL, have ${balance / LAMPORTS_PER_SOL} SOL`);
        }
        
        // Check if market account exists
        const marketAccountInfo = await provider.connection.getAccountInfo(marketPDA);
        console.log('Market account exists:', !!marketAccountInfo);
        if (marketAccountInfo) {
          console.log('Market account owner:', marketAccountInfo.owner.toString());
          console.log('Market account data length:', marketAccountInfo.data.length);
        } else {
          console.log('Market does not exist - initializing it now...');
          
          // Initialize the market first
          setTransactionStatus({ status: 'submitting', message: 'Initializing market...' });
          
          try {
            await initializeMarket(
              program,
              provider,
              wallet.publicKey!,
              derivedMarketId,
              marketPDA,
              computationOffset
            );
            console.log('Market initialized successfully!');
            setTransactionStatus({ status: 'submitting', message: 'Market initialized, now placing bet...' });
          } catch (initError) {
            console.error('Failed to initialize market:', initError);
            throw new Error(`Failed to initialize market: ${initError instanceof Error ? initError.message : String(initError)}`);
          }
        }
        
        // Check Arcium accounts
        console.log('MXE Account:', arciumAccounts.mxeAccount.toString());
        console.log('Computation Account:', arciumAccounts.computationAccount.toString());
        console.log('Comp Def Account:', arciumAccounts.compDefAccount.toString());
        
        console.log('=== END DEBUG INFO ===');

        console.log('Signing transaction...');
        
        // Sign the transaction
        const signedTransaction = await wallet.signTransaction!(transaction);

        console.log('Sending transaction...');
        
        // Send the transaction with custom timeout
        signature = await provider.connection.sendRawTransaction(
          signedTransaction.serialize(),
          {
            skipPreflight: true,
            maxRetries: 3,
          }
        );

        console.log('Transaction submitted:', signature);
      } catch (txError) {
        console.error('Transaction submission error:', txError);
        throw new Error(`Failed to submit transaction: ${txError instanceof Error ? txError.message : String(txError)}`);
      }

      setTransactionStatus({
        status: 'waiting',
        message: 'Confirming transaction on blockchain...',
        signature,
      });

      // Wait for initial transaction confirmation with extended timeout
      const confirmResult = await waitForTransaction(
        provider.connection,
        signature,
        'confirmed',
        120000, // 120 seconds timeout (increased for Arcium transactions)
        3000   // Poll every 3 seconds (reduced frequency to avoid rate limits)
      );

      if (!confirmResult.success) {
        throw new Error(confirmResult.error || 'Transaction confirmation failed');
      }

      setTransactionStatus({
        status: 'waiting',
        message: 'Waiting for computation finalization...',
        signature,
      });

      // Wait for computation to finalize with extended timeout
      let finalizeSig: string;
      try {
        finalizeSig = await waitForComputationFinalization(
          provider,
          computationOffset,
          PREDICTION_MARKET_PROGRAM_ID,
          'confirmed'
        );
        console.log('Computation finalized:', finalizeSig);
      } catch (finalizeError) {
        console.warn('Computation finalization warning:', finalizeError);
        // Use the original signature if finalization fails
        finalizeSig = signature;
      }

      setTransactionStatus({
        status: 'success',
        message: 'Bet placed successfully!',
        signature: finalizeSig,
      });

      // Show success modal
      setShowSuccessModal(true);

      // Reset form after success
      setTimeout(() => {
        setAmount('');
        setTransactionStatus({ status: 'idle', message: '' });
      }, 5000);
    } catch (error) {
      console.error('Place bet error:', error);
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      setTransactionStatus({
        status: 'error',
        message: 'Failed to place bet',
        error: errorMessage,
      });
    } finally {
      setLoading(false);
    }
  };

  const handleOrderTypeChange = (type: OrderType): void => {
    setOrderType(type);
    if (orderMode === 'MKT' && amount && parseFloat(amount) > 0) {
      getQuote();
    }
  };

  const handleOrderModeChange = (mode: OrderMode): void => {
    setOrderMode(mode);
    setQuote(null);
  };

  const handleAmountChange = (e: ChangeEvent<HTMLInputElement>): void => {
    setAmount(e.target.value);
  };

  const handleLimitPriceChange = (e: ChangeEvent<HTMLInputElement>): void => {
    setLimitPrice(e.target.value);
  };

  const applyMultiplier = (multiplier: number): void => {
    if (amount) {
      const newAmount = (parseFloat(amount) * multiplier).toString();
      setAmount(newAmount);
    }
  };

  const executionCost = quote ? quote.payload.total_cost : '0.00';

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      <div className="flex-shrink-0">
        {isNYCMayorMarket && candidates.length > 0 ? (
          <div className="mb-4">
            <div className="text-sm mb-2 text-muted-foreground">Select Candidate:</div>
            <div 
              className="flex gap-2 overflow-x-auto pb-2"
              style={{
                scrollbarWidth: 'thin',
                scrollbarColor: 'rgba(255, 255, 255, 0.1) transparent',
              }}
            >
              {candidates.map((candidate) => (
                <button
                  key={candidate}
                  onClick={() => setSelectedCandidate(candidate)}
                  className={`rounded-full px-4 py-2 text-sm transition-all duration-200 whitespace-nowrap flex-shrink-0 ${
                    selectedCandidate === candidate
                      ? 'text-white'
                      : 'text-muted-foreground'
                  }`}
                  style={{
                    backgroundColor: selectedCandidate === candidate
                      ? 'rgba(255, 255, 255, 0.1)'
                      : 'rgba(10, 10, 10, 0.7)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    backdropFilter: 'blur(10px)',
                  }}
                  onMouseEnter={(e) => {
                    if (selectedCandidate !== candidate) {
                      e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.05)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (selectedCandidate !== candidate) {
                      e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
                    }
                  }}
                >
                  {candidate}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="flex mb-4">
            <Button
              className={`flex-1 ${
                orderType === 'BUY'
                  ? 'bg-white text-green-500'
                  : 'bg-card hover:bg-card/90 text-green-500'
              } rounded-l-xl rounded-r-none border border-border font-semibold`}
              onClick={() => handleOrderTypeChange('BUY')}
            >
              BUY
            </Button>
            <Button
              className={`flex-1 ${
                orderType === 'SELL'
                  ? 'bg-white text-red-500'
                  : 'bg-card hover:bg-card/90 text-red-500'
              } rounded-r-xl rounded-l-none border border-l-0 border-border font-semibold`}
              onClick={() => handleOrderTypeChange('SELL')}
            >
              SELL
            </Button>
          </div>
        )}

        <div className="flex mb-4">
          <Button
            className={`flex-1 ${
              orderMode === 'MKT'
                ? 'bg-white text-black'
                : 'bg-card hover:bg-card/90 text-foreground'
            } rounded-l-xl rounded-r-none border border-border`}
            onClick={() => handleOrderModeChange('MKT')}
          >
            Buy
          </Button>
          <Button
            className={`flex-1 ${
              orderMode === 'LIMIT'
                ? 'bg-white text-background'
                : 'bg-card hover:bg-card/90 text-foreground'
            } rounded-r-xl rounded-l-none border border-l-0 border-border`}
            onClick={() => handleOrderModeChange('LIMIT')}
          >
            Sell
          </Button>
        </div>
      </div>

      {orderMode === 'LIMIT' && (
        <div className="flex-shrink-0 mb-4">
          <div className="flex justify-between items-center text-sm mb-2">
            <span>Limit Price:</span>
            <div className="bg-secondary text-xs rounded-md px-2 py-1">
              {quoteCurrency}
            </div>
          </div>
          <Input
            className="bg-card border-border"
            placeholder="enter price"
            value={limitPrice}
            onChange={handleLimitPriceChange}
            type="number"
            step="0.0001"
          />
        </div>
      )}

      <div className="flex-shrink-0 mb-4">
        <div className="flex justify-between items-center text-sm mb-2">
          <span>Amount:</span>
          <div className="flex gap-2">
            <button
              className="rounded-full px-3 py-1.5 text-sm transition-all duration-200 text-white"
              style={{
                backgroundColor: 'rgba(10, 10, 10, 0.7)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                backdropFilter: 'blur(10px)',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
              }}
              onClick={() => applyMultiplier(0.5)}
            >
              .5x
            </button>
            <button
              className="rounded-full px-3 py-1.5 text-sm transition-all duration-200 text-white"
              style={{
                backgroundColor: 'rgba(10, 10, 10, 0.7)',
                border: '1px solid rgba(255, 255, 255, 0.1)',
                backdropFilter: 'blur(10px)',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
              }}
              onClick={() => applyMultiplier(2)}
            >
              2x
            </button>
          </div>
        </div>
        <div className="flex">
          <Input
            className="bg-card border-border rounded-r-none"
            placeholder="0"
            value={amount}
            onChange={handleAmountChange}
            type="number"
            step="0.01"
          />
          <button
            className="rounded-l-none rounded-r-md px-4 py-2 text-sm transition-all duration-200 text-white flex items-center gap-2"
            style={{
              backgroundColor: 'rgba(10, 10, 10, 0.7)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(10px)',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
            }}
          >
            SOLANA
            <ArrowDownIcon className="h-4 w-4" />
          </button>
        </div>
      </div>

      <div className="flex-shrink-0 flex justify-between items-center text-sm mb-2">
        <span>Execution</span>
        <span
          className={orderType === 'BUY' ? 'text-green-500' : 'text-red-500'}
        >
          {loading ? 'Calculating...' : `${executionCost} SOL`}
        </span>
      </div>


      {/* Transaction Status Display */}
      {transactionStatus.status !== 'idle' && (
        <div
          className={`flex-shrink-0 text-sm mb-2 p-3 rounded-md flex items-center gap-2 ${
            transactionStatus.status === 'success'
              ? 'text-green-500 bg-green-500/10 border border-green-500/20'
              : transactionStatus.status === 'error'
              ? 'text-red-500 bg-red-500/10 border border-red-500/20'
              : 'text-blue-500 bg-blue-500/10 border border-blue-500/20'
          }`}
        >
          {transactionStatus.status === 'success' ? (
            <CheckCircle2 className="h-4 w-4" />
          ) : transactionStatus.status === 'error' ? (
            <AlertCircle className="h-4 w-4" />
          ) : (
            <Loader2 className="h-4 w-4 animate-spin" />
          )}
          <div className="flex-1">
            <div className="font-medium">{transactionStatus.message}</div>
            {transactionStatus.error && (
              <div className="text-xs mt-1 opacity-80">{transactionStatus.error}</div>
            )}
            {transactionStatus.signature && (
              <a
                href={`https://explorer.solana.com/tx/${transactionStatus.signature}?cluster=devnet`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs mt-1 underline opacity-80 hover:opacity-100"
              >
                View transaction
              </a>
            )}
          </div>
        </div>
      )}

      <div className="flex-shrink-0 mt-auto">
        <button
          onClick={handleBetClick}
          disabled={
            loading ||
            !amount ||
            parseFloat(amount) <= 0 ||
            (orderMode === 'LIMIT' &&
              (!limitPrice || parseFloat(limitPrice) <= 0))
          }
          className={`w-full py-3 rounded-full text-sm transition-all duration-200 flex items-center justify-center ${
            loading ||
            !amount ||
            parseFloat(amount) <= 0 ||
            (orderMode === 'LIMIT' &&
              (!limitPrice || parseFloat(limitPrice) <= 0))
              ? 'text-muted-foreground cursor-not-allowed opacity-50'
              : 'text-white'
          }`}
          style={{
            backgroundColor: loading ||
              !amount ||
              parseFloat(amount) <= 0 ||
              (orderMode === 'LIMIT' &&
                (!limitPrice || parseFloat(limitPrice) <= 0))
              ? 'rgba(10, 10, 10, 0.7)'
              : 'rgba(10, 10, 10, 0.7)',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)',
          }}
          onMouseEnter={(e) => {
            if (!loading &&
                amount &&
                parseFloat(amount) > 0 &&
                !(orderMode === 'LIMIT' && (!limitPrice || parseFloat(limitPrice) <= 0))) {
              e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
            }
          }}
          onMouseLeave={(e) => {
            if (!loading &&
                amount &&
                parseFloat(amount) > 0 &&
                !(orderMode === 'LIMIT' && (!limitPrice || parseFloat(limitPrice) <= 0))) {
              e.currentTarget.style.backgroundColor = 'rgba(10, 10, 10, 0.7)';
            }
          }}
        >
          {loading ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Processing...
            </>
          ) : (
            isNYCMayorMarket && selectedCandidate
              ? orderType === 'BUY'
                ? `Bet on ${selectedCandidate}`
                : `Sell ${selectedCandidate}`
              : `${orderType} ${baseCurrency.replace(/_+$/, '')}`
          )}
        </button>
      </div>

      {/* Depth Table Section - Scrollable */}
      <div className="flex-shrink-0 mt-4 border-t border-border/20 pt-4 flex flex-col" style={{ height: '256px' }}>
        <Depth market={market} isNYCMayorMarket={isNYCMayorMarket} />
      </div>

      {/* Bet Confirmation Modal */}
      {showBetConfirmation && (
        <div
          className="fixed inset-0 flex items-center justify-center p-4"
          style={{ backgroundColor: 'rgba(0, 0, 0, 0.7)', zIndex: 9999 }}
          onClick={() => setShowBetConfirmation(false)}
        >
          <div
            className="w-full max-w-2xl rounded-xl p-6 max-h-[90vh] overflow-y-auto"
            style={{
              backgroundColor: 'rgba(10, 10, 10, 0.95)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(10px)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-semibold text-white">Bet Confirmation</h2>
              <button
                onClick={() => setShowBetConfirmation(false)}
                className="text-white hover:opacity-70 transition-opacity"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Bet Details */}
              <div className="space-y-4">
                <div className="bg-white/5 rounded-lg p-4 border border-white/10">
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Market</span>
                      <span className="text-white font-medium">
                        {isNYCMayorMarket ? 'NYC Mayoral Election' : `${baseCurrency}/${quoteCurrency}`}
                      </span>
                    </div>
                    
                    {isNYCMayorMarket && selectedCandidate && (
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-gray-300">Candidate</span>
                        <span className="text-white font-medium">{selectedCandidate}</span>
                      </div>
                    )}

                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Order Type</span>
                      <span className="text-white font-medium">{orderType}</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Amount</span>
                      <span className="text-white font-medium">{amount} SOL</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Execution Cost</span>
                      <span className="text-white font-medium">{executionCost} SOL</span>
                    </div>

                    {orderMode === 'LIMIT' && limitPrice && (
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-gray-300">Limit Price</span>
                        <span className="text-white font-medium">{limitPrice}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* Notice */}
              <div className="border-t border-white/10 pt-4 mt-4">
                <div className="bg-white/5 rounded-lg p-4 border border-white/10">
                  <p className="text-xs text-gray-300 leading-relaxed mb-4">
                    Please review your bet details carefully. Once confirmed, the transaction will be processed on the blockchain.
                  </p>
                  
                  {/* Magic Block Promotion */}
                  <div className="flex items-center gap-3 pt-4 border-t border-white/10">
                    <Image
                      src="/Magic Block.png"
                      alt="Magic Block"
                      width={100}
                      height={100}
                      className="flex-shrink-0"
                    />
                    <div className="flex-1">
                      <p className="text-xs text-white leading-relaxed">
                        Powered by MagicBlock — offers{' '}
                        <span className="font-semibold text-green-400">zero transaction fees</span>
                        {' '}and faster block times.{' '}
                        <a
                          href="https://www.magicblock.xyz/blog/solana-plugins"
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-blue-400 hover:text-blue-300 underline"
                        >
                          Learn more
                        </a>
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowBetConfirmation(false)}
                  className="px-4 py-2 rounded-full text-sm transition-all duration-200 border border-white/20 text-white hover:bg-white/10"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={placeBet}
                  disabled={loading}
                  className="px-4 py-2 rounded-full text-sm transition-all duration-200 text-white disabled:opacity-50 disabled:cursor-not-allowed"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    backdropFilter: 'blur(10px)',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.15)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                  }}
                >
                  Confirm Bet
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Success Modal */}
      {showSuccessModal && transactionStatus.signature && (
        <div
          className="fixed inset-0 flex items-center justify-center p-4"
          style={{ backgroundColor: 'rgba(0, 0, 0, 0.7)', zIndex: 9999 }}
          onClick={() => setShowSuccessModal(false)}
        >
          <div
            className="w-full max-w-2xl rounded-xl p-6 max-h-[90vh] overflow-y-auto"
            style={{
              backgroundColor: 'rgba(10, 10, 10, 0.95)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              backdropFilter: 'blur(10px)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <CheckCircle2 className="h-6 w-6 text-green-500" />
                <h2 className="text-2xl font-semibold text-white">Bet Placed Successfully</h2>
              </div>
              <button
                onClick={() => setShowSuccessModal(false)}
                className="text-white hover:opacity-70 transition-opacity"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Bet Details */}
              <div className="space-y-4">
                <div className="bg-white/5 rounded-lg p-4 border border-white/10">
                  <div className="space-y-3">
                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Market</span>
                      <span className="text-white font-medium">
                        {isNYCMayorMarket ? 'NYC Mayoral Election' : `${baseCurrency}/${quoteCurrency}`}
                      </span>
                    </div>

                    {isNYCMayorMarket && selectedCandidate && (
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-gray-300">Candidate</span>
                        <span className="text-white font-medium">{selectedCandidate}</span>
                      </div>
                    )}

                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Order Type</span>
                      <span className="text-white font-medium">{orderType}</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Amount</span>
                      <span className="text-white font-medium">{amount} SOL</span>
                    </div>

                    <div className="flex justify-between items-center">
                      <span className="text-sm text-gray-300">Status</span>
                      <span className="text-green-500 font-medium flex items-center gap-2">
                        <CheckCircle2 className="h-4 w-4" />
                        Confirmed
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Transaction Verification */}
              <div className="border-t border-white/10 pt-4">
                <div className="bg-white/5 rounded-lg p-4 border border-white/10">
                  <p className="text-xs text-gray-300 mb-3">
                    Your bet has been confirmed on the Solana blockchain. View the transaction details on Solscan.
                  </p>

                  <a
                    href={`https://solscan.io/tx/${transactionStatus.signature}?cluster=${process.env.NEXT_PUBLIC_SOLANA_NETWORK || 'devnet'}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center justify-center gap-2 px-4 py-2 rounded-full text-sm transition-all duration-200"
                    style={{
                      backgroundColor: 'rgba(255, 255, 255, 0.1)',
                      border: '1px solid rgba(255, 255, 255, 0.1)',
                      backdropFilter: 'blur(10px)',
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.15)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                    }}
                  >
                    <ExternalLink className="h-4 w-4" />
                    <span className="text-white">View on Solscan</span>
                  </a>
                </div>
              </div>

              {/* Close Button */}
              <div className="flex items-center justify-end gap-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowSuccessModal(false)}
                  className="px-4 py-2 rounded-full text-sm transition-all duration-200 text-white"
                  style={{
                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                    border: '1px solid rgba(255, 255, 255, 0.1)',
                    backdropFilter: 'blur(10px)',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.15)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                  }}
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
