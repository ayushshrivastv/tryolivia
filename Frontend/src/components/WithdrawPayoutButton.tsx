/**
 * Olivia: Decentralised Permissionless Prediction Market
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

'use client';

import { useState } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import { PublicKey, SystemProgram } from '@solana/web3.js';
import { BN, Wallet, Idl, AnchorProvider, Program } from '@coral-xyz/anchor';
import { Button } from '@/src/ui/Button';
import { Loader2, CheckCircle2, AlertCircle } from 'lucide-react';
import {
  createAnchorProvider,
  createProgram,
  getBetPDA,
  getMarketPDA,
  getMarketVaultPDA,
  PREDICTION_MARKET_PROGRAM_ID,
} from '@/src/utils/programClient';
import { waitForTransaction } from '@/src/utils/transactionUtils';

interface WithdrawPayoutButtonProps {
  marketId: number;
  betAmount: number;
  payoutAmount: number;
  resolved: boolean;
  withdrawn: boolean;
  idl: Idl | null;
  onSuccess?: () => void;
}

interface TransactionStatus {
  status: 'idle' | 'submitting' | 'waiting' | 'success' | 'error';
  message: string;
  signature?: string;
  error?: string;
}

export default function WithdrawPayoutButton({
  marketId,
  betAmount,
  payoutAmount,
  resolved,
  withdrawn,
  idl,
  onSuccess,
}: WithdrawPayoutButtonProps) {
  const { connection } = useConnection();
  const wallet = useWallet();
  const [loading, setLoading] = useState<boolean>(false);
  const [transactionStatus, setTransactionStatus] = useState<TransactionStatus>({
    status: 'idle',
    message: '',
  });

  // Check if withdrawal is available
  const canWithdraw = resolved && !withdrawn && payoutAmount > 0;

  const handleWithdraw = async (): Promise<void> => {
    if (!canWithdraw || !wallet.publicKey || !wallet.signTransaction || !idl) {
      return;
    }

    setLoading(true);
    setTransactionStatus({ status: 'submitting', message: 'Preparing withdrawal...' });

    try {
      // Create provider and program
      const walletAdapter = {
        publicKey: wallet.publicKey,
        signTransaction: wallet.signTransaction!,
        signAllTransactions: wallet.signAllTransactions!,
      };
      const provider = createAnchorProvider(connection, walletAdapter as unknown as Wallet);
      const program = createProgram(provider, idl as Idl);

      // Get PDAs
      const marketPDA = getMarketPDA(marketId);
      const betPDA = getBetPDA(marketId, wallet.publicKey);
      const marketVaultPDA = getMarketVaultPDA(marketId);

      console.log('Withdrawal PDAs:');
      console.log('- Market:', marketPDA.toString());
      console.log('- Bet:', betPDA.toString());
      console.log('- Vault:', marketVaultPDA.toString());
      console.log('- Payout Amount:', payoutAmount);

      setTransactionStatus({ status: 'submitting', message: 'Building transaction...' });

      // Build withdrawal transaction
      const transaction = await program.methods
        .withdrawPayout(new BN(marketId))
        .accountsPartial({
          bettor: wallet.publicKey,
          market: marketPDA,
          marketVault: marketVaultPDA,
          bet: betPDA,
          systemProgram: SystemProgram.programId,
        })
        .transaction();

      // Get recent blockhash
      const { blockhash, lastValidBlockHeight } = await provider.connection.getLatestBlockhash('confirmed');
      transaction.recentBlockhash = blockhash;
      transaction.lastValidBlockHeight = lastValidBlockHeight;
      transaction.feePayer = wallet.publicKey;

      setTransactionStatus({ status: 'submitting', message: 'Signing transaction...' });

      // Sign and send
      const signedTransaction = await wallet.signTransaction!(transaction);
      const signature = await provider.connection.sendRawTransaction(
        signedTransaction.serialize(),
        {
          skipPreflight: true,
          maxRetries: 3,
        }
      );

      console.log('Withdrawal transaction submitted:', signature);

      setTransactionStatus({
        status: 'waiting',
        message: 'Confirming transaction...',
        signature,
      });

      // Wait for confirmation
      const confirmResult = await waitForTransaction(
        provider.connection,
        signature,
        'confirmed',
        60000, // 60 seconds
        2000   // Poll every 2 seconds
      );

      if (!confirmResult.success) {
        throw new Error(confirmResult.error || 'Transaction confirmation failed');
      }

      setTransactionStatus({
        status: 'success',
        message: 'Withdrawal successful!',
        signature,
      });

      // Call success callback after a short delay
      setTimeout(() => {
        setTransactionStatus({ status: 'idle', message: '' });
        onSuccess?.();
      }, 3000);

    } catch (error) {
      console.error('Withdrawal error:', error);
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      setTransactionStatus({
        status: 'error',
        message: 'Withdrawal failed',
        error: errorMessage,
      });

      // Reset after 5 seconds
      setTimeout(() => {
        setTransactionStatus({ status: 'idle', message: '' });
      }, 5000);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-2">
      {/* Transaction Status */}
      {transactionStatus.status !== 'idle' && (
        <div
          className={`text-sm p-3 rounded-md flex items-center gap-2 ${
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

      {/* Withdrawal Button */}
      <Button
        onClick={handleWithdraw}
        disabled={!canWithdraw || loading || !wallet.publicKey || !idl}
        className={`w-full ${
          !canWithdraw || loading || !wallet.publicKey || !idl
            ? 'opacity-50 cursor-not-allowed bg-gray-600'
            : 'bg-green-600 hover:bg-green-700'
        }`}
      >
        {loading ? (
          <>
            <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            Processing...
          </>
        ) : withdrawn ? (
          'Already Withdrawn'
        ) : !resolved ? (
          'Bet Not Resolved'
        ) : payoutAmount === 0 ? (
          'No Payout'
        ) : !wallet.publicKey ? (
          'Connect Wallet'
        ) : !idl ? (
          'Loading...'
        ) : (
          `Withdraw ${(payoutAmount / 1e9).toFixed(4)} SOL`
        )}
      </Button>

      {/* Bet Info */}
      {canWithdraw && (
        <div className="text-xs text-gray-400 space-y-1">
          <div className="flex justify-between">
            <span>Bet Amount:</span>
            <span>{(betAmount / 1e9).toFixed(4)} SOL</span>
          </div>
          <div className="flex justify-between">
            <span>Payout:</span>
            <span className="text-green-400 font-medium">{(payoutAmount / 1e9).toFixed(4)} SOL</span>
          </div>
          <div className="flex justify-between">
            <span>Profit:</span>
            <span className={payoutAmount > betAmount ? 'text-green-400' : 'text-red-400'}>
              {((payoutAmount - betAmount) / 1e9).toFixed(4)} SOL
            </span>
          </div>
        </div>
      )}
    </div>
  );
}
