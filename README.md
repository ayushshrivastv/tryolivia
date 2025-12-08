# Olivia

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Solana](https://img.shields.io/badge/Solana-Blockchain-purple.svg)
![Arcium](https://img.shields.io/badge/Arcium-Encrypted%20Computation-green.svg)
![Magic Block](https://img.shields.io/badge/Magic%20Block-Ephemeral%20Rollups-orange.svg)
![Decentralized](https://img.shields.io/badge/Decentralized-Yes-brightgreen.svg)
![Permissionless](https://img.shields.io/badge/Permissionless-Yes-success.svg)

Olivia — A truly decentralized, permissionless prediction market that runs without middlemen, gatekeepers, or hidden agendas. Anyone, anywhere, can spin up a market on any question that sparks their curiosity: election results, tech breakthroughs, sports outcomes, or even that friendly office bet. No approvals, no oversight, just pure, open participation.

Arcium’s encrypted computation keeps every prediction private until the market resolves. Using Multi-Party Computation (MPC), your bet stays sealed in a cryptographic black box while the network crunches the numbers—fair rewards, zero peeking, no front-running.

Magic Block’s Ephemeral Rollups on Solana eliminate fees and latency. Place bets, resolve markets, claim rewards—instantly and for free, with the same snappiness you expect from top web apps.

Solana’s high-performance backbone ties it all together, ensuring speed, security, and decentralization without compromise.

The result? A platform where privacy, speed, and openness aren’t trade-offs—they’re the default. Communities form organically around the questions people actually care about, and collective insight emerges naturally, unhindered by cost or strategic gamesmanship.

Olivia isn’t just tech—it’s a vision: prediction markets should feel effortless yet remain fully decentralized. Whether you’re a developer diving into MPC and rollups, or a first-time user placing your inaugural bet, I’ve built this to be approachable, transparent, and fun.

Dive in, create a market, predict boldly—and let’s see what emerges when barriers vanish.

When Others Watch Chaos.
Predict Them. Profit From Them.

Ayush Srivastava

---

## How Arcium Private Encryption Works

### 1. Encrypt Prediction

Generate keypair and encrypt prediction using x25519 with MXE public key:

```typescript
import { x25519 } from "@noble/curves/ed25519";
import { RescueCipher, getMXEPublicKey } from "@arcium-hq/client";
import { randomBytes } from "crypto";

// Generate encryption keypair
const privateKey = x25519.utils.randomSecretKey();
const publicKey = x25519.getPublicKey(privateKey);

// Get MXE public key for encryption
const mxePublicKey = await getMXEPublicKey(provider, programId);

// Derive shared secret and create cipher
const sharedSecret = x25519.getSharedSecret(privateKey, mxePublicKey);
const cipher = new RescueCipher(sharedSecret);

// Encrypt prediction (true = YES, false = NO)
const prediction = true;
const nonce = randomBytes(16);
const encryptedPrediction = cipher.encrypt(
  [BigInt(prediction ? 1 : 0)],
  nonce
);
```

### 2. MPC Circuit for Encrypted Computation

Arcium circuit defines the encrypted computation logic that runs on encrypted data:

```rust
// Arcium/circuits/EncryptedIxs/src/lib.rs
#[instruction]
pub fn place_bet(
    prediction_ctxt: Enc<Shared, bool>, 
    amount: u64
) -> PoolUpdate {
    // Decrypt in MPC (no single node sees the value)
    let prediction = prediction_ctxt.to_arcis();
    
    // Update pools without revealing individual predictions
    PoolUpdate {
        yes_pool_delta: if prediction { amount } else { 0 },
        no_pool_delta: if !prediction { amount } else { 0 },
    }
    .reveal()
}
```

### 3. Queue Encrypted Computation

Submit encrypted prediction to Arcium's computation queue (Arcium accounts required):

```typescript
import {
  getMXEAccAddress,
  getComputationAccAddress,
  getCompDefAccAddress,
  getCompDefAccOffset,
  getMempoolAccAddress,
  getExecutingPoolAccAddress,
  getClusterAccAddress,
  awaitComputationFinalization,
  deserializeLE,
} from "@arcium-hq/client";
import { randomBytes } from "crypto";

const computationOffset = new anchor.BN(randomBytes(8), "hex");

// Queue computation with Arcium accounts
await program.methods
  .placeBet(
    computationOffset,
    marketId,
    betAmount,
    Array.from(encryptedPrediction[0]),
    Array.from(publicKey),
    new anchor.BN(deserializeLE(nonce).toString())
  )
  .accountsPartial({
    bettor: user.publicKey,
    // Arcium accounts for encrypted computation
    mxeAccount: getMXEAccAddress(programId),
    computationAccount: getComputationAccAddress(programId, computationOffset),
    compDefAccount: getCompDefAccAddress(
      programId,
      Buffer.from(getCompDefAccOffset("place_bet")).readUInt32LE()
    ),
    mempoolAccount: getMempoolAccAddress(programId),
    executingPool: getExecutingPoolAccAddress(programId),
    clusterAccount: getClusterAccAddress(clusterOffset),
    market: marketPDA,
    bet: betPDA,
  })
  .rpc();

// Wait for computation to finalize
await awaitComputationFinalization(provider, computationOffset, programId, "confirmed");
```

### 4. Callback Receives Result

Arcium callback receives computation result and updates market state:

```rust
// Callback from Arcium after market resolution computation
pub fn resolve_market_callback(
    ctx: Context<ResolveMarketCallback>,
    _market_id: u64,
    outcome: bool,
    yes_votes: u8,
    no_votes: u8,
) -> Result<()> {
    let market = &mut ctx.accounts.market;
    market.resolution_result = Some(outcome);
    market.state = MarketState::Resolved;
    Ok(())
}
```

**Note:** The current `place_bet` implementation is legacy and stores encrypted data directly. The Arcium circuit (`place_bet`) and integration pattern above represent the intended encrypted computation flow for processing predictions privately via MPC.

---

For detailed Arcium integration documentation, see [Arcium/README.md](Arcium/README.md).
