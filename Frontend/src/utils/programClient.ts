/**
 * Olivia: Decentralised Permissionless Prediction Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

import { PublicKey, Connection, Commitment } from "@solana/web3.js";
import { AnchorProvider, Program, Wallet, Idl, BN } from "@coral-xyz/anchor";
import { useConnection, useWallet } from "@solana/wallet-adapter-react";

// Program ID is read from env for flexibility across clusters.
// Fallback uses the current program deployment.
const PROGRAM_ID_STR =
  process.env.NEXT_PUBLIC_PREDICTION_MARKET_PROGRAM_ID ||
  "EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA";

export const PREDICTION_MARKET_PROGRAM_ID = new PublicKey(PROGRAM_ID_STR);

/**
 * Initialize Anchor provider from wallet and connection
 * with optimized settings for devnet reliability
 */
export function createAnchorProvider(
  connection: Connection,
  wallet: Wallet,
  commitment: Commitment = "confirmed"
): AnchorProvider {
  return new AnchorProvider(connection, wallet, {
    commitment,
    skipPreflight: true, // Skip preflight for better reliability on congested networks
    preflightCommitment: commitment,
    maxRetries: 3, // Retry failed transactions
  });
}

/**
 * Initialize program from provider and IDL
 */
export function createProgram(
  provider: AnchorProvider,
  idl: Idl
): Program<Idl> {
  return new Program(idl, provider);
}

/**
 * React hook to get program instance
 * Requires IDL to be loaded separately
 */
export function useProgram(idl: Idl | null): {
  program: Program<Idl> | null;
  provider: AnchorProvider | null;
  connection: Connection | null;
} {
  const { connection } = useConnection();
  const wallet = useWallet();

  if (!idl || !connection || !wallet.publicKey) {
    return { program: null, provider: null, connection: null };
  }

  const walletAdapter = {
    publicKey: wallet.publicKey,
    signTransaction: wallet.signTransaction!,
    signAllTransactions: wallet.signAllTransactions!,
  };

  const provider = createAnchorProvider(connection, walletAdapter as unknown as Wallet);
  const program = createProgram(provider, idl);

  return { program, provider, connection };
}

/**
 * Load IDL from a URL (public folder or CDN)
 */
export async function loadIdl(idlUrl: string): Promise<Idl> {
  const response = await fetch(idlUrl);
  if (!response.ok) {
    throw new Error(`Failed to load IDL from ${idlUrl}: ${response.statusText}`);
  }
  return response.json();
}

function bigintToEightBytesLE(val: bigint): Uint8Array {
  const arr = new Uint8Array(8);
  const view = new DataView(arr.buffer);
  view.setBigUint64(0, val, true); // true = little-endian
  return arr;
}

/**
 * Get market PDA
 */
export function getMarketPDA(marketId: BN | number | string): PublicKey {
  const marketIdBN = typeof marketId === "number" || typeof marketId === "string"
    ? new BN(marketId)
    : marketId;
  
  const marketIdBuffer = bigintToEightBytesLE(BigInt(marketIdBN.toString()));

  const [pda] = PublicKey.findProgramAddressSync(
    [Buffer.from("market"), marketIdBuffer],
    PREDICTION_MARKET_PROGRAM_ID
  );

  return pda;
}

/**
 * Get bet PDA
 */
export function getBetPDA(
  marketId: BN | number | string,
  bettor: PublicKey
): PublicKey {
  const marketIdBN = typeof marketId === "number" || typeof marketId === "string"
    ? new BN(marketId)
    : marketId;

  const marketIdBuffer = bigintToEightBytesLE(BigInt(marketIdBN.toString()));

  const [pda] = PublicKey.findProgramAddressSync(
    [
      Buffer.from("bet"),
      marketIdBuffer,
      bettor.toBuffer(),
    ],
    PREDICTION_MARKET_PROGRAM_ID
  );

  return pda;
}

/**
 * Get market vault PDA for holding bet funds
 */
export function getMarketVaultPDA(marketId: BN | number | string): PublicKey {
  const marketIdBN = typeof marketId === "number" || typeof marketId === "string"
    ? new BN(marketId)
    : marketId;

  const marketIdBuffer = bigintToEightBytesLE(BigInt(marketIdBN.toString()));

  const [pda] = PublicKey.findProgramAddressSync(
    [
      Buffer.from("vault"),
      marketIdBuffer,
    ],
    PREDICTION_MARKET_PROGRAM_ID
  );

  return pda;
}

