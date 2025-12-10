# Olivia

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Solana](https://img.shields.io/badge/Solana-Blockchain-purple.svg)
![Arcium](https://img.shields.io/badge/Arcium-Encrypted%20Computation-green.svg)
![Magic Block](https://img.shields.io/badge/Magic%20Block-Ephemeral%20Rollups-orange.svg)
![Decentralized](https://img.shields.io/badge/Decentralized-Yes-brightgreen.svg)
![Permissionless](https://img.shields.io/badge/Permissionless-Yes-success.svg)

Olivia — A truly decentralized, permissionless prediction market that runs without middlemen, gatekeepers, or hidden agendas. Anyone, anywhere, can spin up a market on any question that sparks their curiosity: election results, tech breakthroughs, sports outcomes, or even that friendly office bet. No approvals, no oversight, just pure, open participation.

Arcium's encrypted computation keeps every prediction private until the market resolves. Using Multi-Party Computation (MPC), your bet stays sealed in a cryptographic black box while the network crunches the numbers—fair rewards, zero peeking, no front-running.

Magic Block's Ephemeral Rollups on Solana eliminate fees and latency. Place bets, resolve markets, claim rewards—instantly and for free, with the same snappiness you expect from top web apps.

Solana's high-performance backbone ties it all together, ensuring speed, security, and decentralization without compromise.

The result? A platform where privacy, speed, and openness aren't trade-offs—they're the default. Communities form organically around the questions people actually care about, and collective insight emerges naturally, unhindered by cost or strategic gamesmanship.

Olivia isn't just tech—it's a vision: prediction markets should feel effortless yet remain fully decentralized. Whether you're a developer diving into MPC and rollups, or a first-time user placing your inaugural bet, I've built this to be approachable, transparent, and fun.

Dive in, create a market, predict boldly—and let's see what emerges when barriers vanish.

When Others Watch Chaos.
Predict Them. Profit From Them.

---

## Magic Block's Ephemeral Rollups

Olivia leverages **Magic Block's Ephemeral Rollups** on Solana to deliver instant, zero-cost transactions without sacrificing decentralization or security. While traditional Layer 2 rollups bundle transactions for cost efficiency, they introduce delays and still incur fees. Magic Block's approach is fundamentally different—ephemeral rollups create temporary, high-speed execution environments that handle rapid state changes off-chain, then commit only the final state back to Solana's mainnet.

### What Are Ephemeral Rollups?

Ephemeral rollups are temporary execution layers that exist only for the duration of active user interactions. Unlike persistent rollups that maintain continuous state, ephemeral rollups spin up on-demand when users initiate actions, process transactions instantly with zero fees during the active session, commit the final state to Solana Layer 1 once the interaction completes, and dissolve automatically after finalization—leaving no permanent overhead.

Think of them as pop-up speed lanes that materialize exactly when needed, handle all the heavy lifting at lightning speed, then merge back onto the main blockchain highway with just the essential data.

**Magic Block Ephemeral Rollups:** [Arcium/docs/MagicBlock.md](Arcium/docs/MagicBlock.md) - Discover how ephemeral rollups deliver instant, zero-fee transactions while maintaining decentralization

### The Game-Theoretic Problem: Strategic Dishonesty

Here's the fatal flaw in majority-based voting systems: if quorum members can see how others have voted before submitting their own vote, they're incentivized to vote dishonestly. Imagine you're part of a 10-person quorum resolving "Did Candidate X win the election?" You know the answer is YES, but you see that 6 people have already voted NO. If incorrect votes are penalized (through stake slashing), you might vote NO anyway to avoid losing your stake—even though you know it's wrong.

This creates a **dishonest equilibrium** where participants prioritize self-preservation over truth. The market's integrity collapses because rational actors game the system.

Arcium's **confidential voting** eliminates this problem entirely. Using encrypted computation, quorum votes remain hidden until the voting period closes. No one knows how others voted, so there's no strategic advantage to lying. Your best move is always to vote honestly—because you can't predict what everyone else will do. This restores the **honest equilibrium** that prediction markets require to function.

**Learn more:** [The Future of Prediction Markets Using Arcium](https://www.arcium.com/articles/the-future-of-prediction-markets-using-arcium)

### Why This Changes Prediction Markets

Before Arcium, decentralized prediction markets faced an impossible choice: sacrifice decentralization by using trusted resolvers, or sacrifice fairness by exposing votes publicly. Polymarket chose the first path (DAO-controlled resolution). Augur chose the second (transparent voting with game-theoretic flaws).

Olivia, powered by Arcium, escapes this trade-off entirely. Encrypted voting preserves privacy during the critical window when strategic manipulation could occur, then reveals results only when honesty is the only rational strategy. Combined with permissionless market creation and automated resolution, Arcium makes prediction markets truly open, fair, and trustless.

This is why Arcium isn't just a feature—it's the foundation that makes Olivia's vision possible.

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

## Documentation

For detailed technical documentation on how these technologies integrate with Olivia:

- **Arcium Encrypted Computation:** [Arcium/docs/Arcium.md](Arcium/docs/Arcium.md) - Learn how Multi-Party Computation enables private predictions and trustless market resolution
- **Magic Block Ephemeral Rollups:** [Arcium/docs/MagicBlock.md](Arcium/docs/MagicBlock.md) - Discover how ephemeral rollups deliver instant, zero-fee transactions while maintaining decentralization
