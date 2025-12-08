/**
 * Olivia: Decentralised Permissionless Prediction Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

import { Connection, TransactionSignature, Commitment } from "@solana/web3.js";

/**
 * Enhanced transaction confirmation with retries and better error handling
 */
export async function confirmTransactionWithRetry(
  connection: Connection,
  signature: TransactionSignature,
  commitment: Commitment = "confirmed",
  maxRetries: number = 3,
  timeoutMs: number = 60000 // 60 seconds
): Promise<{ confirmed: boolean; error?: string }> {
  const startTime = Date.now();

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`Confirmation attempt ${attempt}/${maxRetries} for signature: ${signature}`);
      
      // Check if we've exceeded total timeout
      const elapsed = Date.now() - startTime;
      if (elapsed >= timeoutMs) {
        return {
          confirmed: false,
          error: `Transaction confirmation timed out after ${timeoutMs}ms. Signature: ${signature}`,
        };
      }

      // Calculate remaining time for this attempt
      const remainingTime = timeoutMs - elapsed;
      const attemptTimeout = Math.min(remainingTime, 30000); // Max 30s per attempt

      // Use confirmTransaction with timeout
      const result = await Promise.race([
        connection.confirmTransaction(
          {
            signature,
            blockhash: (await connection.getLatestBlockhash(commitment)).blockhash,
            lastValidBlockHeight: (await connection.getLatestBlockhash(commitment)).lastValidBlockHeight,
          },
          commitment
        ),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("Attempt timeout")), attemptTimeout)
        ),
      ]);

      if (result.value.err) {
        return {
          confirmed: false,
          error: `Transaction failed: ${JSON.stringify(result.value.err)}`,
        };
      }

      console.log(`Transaction confirmed successfully on attempt ${attempt}`);
      return { confirmed: true };
    } catch (error) {
      console.warn(`Confirmation attempt ${attempt} failed:`, error);

      // If this is the last attempt, return failure
      if (attempt === maxRetries) {
        return {
          confirmed: false,
          error: `Failed to confirm transaction after ${maxRetries} attempts. Last error: ${
            error instanceof Error ? error.message : String(error)
          }`,
        };
      }

      // Wait before retrying (exponential backoff)
      const backoffMs = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
      console.log(`Waiting ${backoffMs}ms before retry...`);
      await new Promise((resolve) => setTimeout(resolve, backoffMs));
    }
  }

  return {
    confirmed: false,
    error: "Unexpected error in confirmation loop",
  };
}

/**
 * Check transaction status by signature
 */
export async function checkTransactionStatus(
  connection: Connection,
  signature: TransactionSignature,
  commitment: Commitment = "confirmed"
): Promise<{
  status: "success" | "failed" | "not_found";
  error?: string;
}> {
  try {
    const status = await connection.getSignatureStatus(signature, {
      searchTransactionHistory: true,
    });

    if (!status || !status.value) {
      return { status: "not_found" };
    }

    if (status.value.err) {
      return {
        status: "failed",
        error: JSON.stringify(status.value.err),
      };
    }

    // Check if transaction has reached desired commitment level
    const confirmationStatus = status.value.confirmationStatus;
    if (
      confirmationStatus === commitment ||
      (commitment === "confirmed" && confirmationStatus === "finalized")
    ) {
      return { status: "success" };
    }

    return { status: "not_found" };
  } catch (error) {
    console.error("Error checking transaction status:", error);
    return {
      status: "failed",
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

/**
 * Wait for transaction with polling fallback
 */
export async function waitForTransaction(
  connection: Connection,
  signature: TransactionSignature,
  commitment: Commitment = "confirmed",
  timeoutMs: number = 90000, // 90 seconds
  pollIntervalMs: number = 2000
): Promise<{ success: boolean; error?: string }> {
  const startTime = Date.now();

  console.log(`Waiting for transaction: ${signature}`);
  console.log(`Timeout: ${timeoutMs}ms, Poll interval: ${pollIntervalMs}ms`);

  while (Date.now() - startTime < timeoutMs) {
    try {
      const status = await checkTransactionStatusWithFallback(connection, signature, commitment);

      if (status.status === "success") {
        console.log(`Transaction confirmed: ${signature}`);
        return { success: true };
      }

      if (status.status === "failed") {
        console.error(`Transaction failed: ${signature}`, status.error);
        return {
          success: false,
          error: status.error || "Transaction failed",
        };
      }

      // Transaction not found yet, continue polling
      console.log(`Transaction pending, polling again in ${pollIntervalMs}ms...`);
      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    } catch (error) {
      console.warn("Error during transaction polling:", error);
      // Continue polling even if there's an error
      await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
    }
  }

  // Timeout reached
  console.warn(`Transaction timeout reached for: ${signature}`);
  return {
    success: false,
    error: `Transaction not confirmed within ${timeoutMs}ms. Check signature ${signature} on Solana Explorer.`,
  };
}

/**
 * Get recommended RPC URLs for better reliability
 */
export function getRecommendedRPCUrls(): {
  primary: string;
  fallbacks: string[];
} {
  const network = (process.env.NEXT_PUBLIC_SOLANA_NETWORK || 'devnet') as
    | 'devnet'
    | 'testnet'
    | 'mainnet-beta';

  if (network === 'testnet') {
    return {
      primary: "https://api.testnet.solana.com",
      fallbacks: [
        "https://rpc.ankr.com/solana_testnet",
        "https://testnet.helius-rpc.com",
        "https://solana-testnet.g.alchemy.com/v2/demo",
      ],
    };
  }

  if (network === 'mainnet-beta') {
    return {
      primary: "https://api.mainnet-beta.solana.com",
      fallbacks: [
        "https://rpc.ankr.com/solana",
        "https://mainnet.helius-rpc.com",
        "https://solana-mainnet.g.alchemy.com/v2/demo",
      ],
    };
  }

  return {
    primary: "https://api.devnet.solana.com",
    fallbacks: [
      "https://rpc.ankr.com/solana_devnet",
      "https://devnet.helius-rpc.com",
      "https://solana-devnet.g.alchemy.com/v2/demo",
    ],
  };
}

/**
 * Enhanced transaction status check with RPC fallback
 */
export async function checkTransactionStatusWithFallback(
  connection: Connection,
  signature: TransactionSignature,
  commitment: Commitment = "confirmed"
): Promise<{
  status: "success" | "failed" | "not_found";
  error?: string;
}> {
  try {
    return await checkTransactionStatus(connection, signature, commitment);
  } catch {
    console.warn('Primary RPC failed, this is expected sometimes on public RPCs');
    console.log('Transaction signature:', signature);
    const cluster = process.env.NEXT_PUBLIC_SOLANA_NETWORK || 'testnet';
    console.log('Check manually at:', `https://explorer.solana.com/tx/${signature}?cluster=${cluster}`);

    // Return not_found to continue polling rather than failing immediately
    return { status: "not_found" };
  }
}

/**
 * Simulate transaction before sending to catch errors early
 * This is especially important for Arcium transactions which can be expensive
 *
 * NOTE: For newer Solana web3.js versions, we need to handle the transaction format carefully
 */
export async function simulateTransaction(
  connection: Connection,
  transaction: any,
  signers?: any[],
  commitment: Commitment = "confirmed"
): Promise<{
  success: boolean;
  error?: string;
  logs?: string[];
}> {
  try {
    console.log('🔍 Simulating transaction before sending...');

    // For simulation, we need to ensure the transaction has the right structure
    // Try different simulation approaches based on transaction type

    let simulation;

    try {
      // Approach 1: Try with replaceRecentBlockhash (works with modern Transaction objects)
      if (transaction.recentBlockhash && transaction.feePayer) {
        simulation = await connection.simulateTransaction(
          transaction,
          signers,
          {
            commitment,
            replaceRecentBlockhash: true, // Use fresh blockhash for simulation
          }
        );
      } else {
        // Approach 2: Standard simulation
        simulation = await connection.simulateTransaction(transaction, {
          commitment,
        });
      }
    } catch (simError: any) {
      // If simulation fails due to format issues, just skip it and let the actual transaction run
      console.warn('⚠️ Transaction simulation skipped due to format issue:', simError.message);
      console.log('Transaction will be sent without pre-validation');
      return {
        success: true, // Return success to allow transaction to proceed
        logs: [],
      };
    }

    if (simulation.value.err) {
      const errorStr = JSON.stringify(simulation.value.err);
      console.error('❌ Transaction simulation failed:', errorStr);
      console.error('Simulation logs:', simulation.value.logs);

      return {
        success: false,
        error: errorStr,
        logs: simulation.value.logs || [],
      };
    }

    console.log('✅ Transaction simulation successful');
    if (simulation.value.logs && simulation.value.logs.length > 0) {
      console.log('Simulation logs:', simulation.value.logs.slice(-5)); // Last 5 logs
    }

    return {
      success: true,
      logs: simulation.value.logs || [],
    };
  } catch (error) {
    console.error('Simulation error:', error);
    // Don't block the transaction if simulation fails for technical reasons
    console.log('⚠️ Skipping simulation, will attempt actual transaction');
    return {
      success: true, // Allow transaction to proceed
      logs: [],
    };
  }
}
