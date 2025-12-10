# How Arcium Enables Encrypted Computation in Olivia: Decentralised Permissionless Predicition Market 

So you're interested in understanding how our Olivia prediction market works, and specifically how we use Arcium to keep predictions private while still computing on them? Great question! Let me walk you through this in a way that makes sense.

## The Core Problem We're Solving

Imagine you want to place a bet in our prediction market - say, whether Bitcoin will hit $100,000 by the end of the year. In a traditional prediction market, everyone can see your bet. But what if you want to keep your prediction private until the market resolves? That's the challenge we're solving with Olivia, and that's exactly where Arcium comes into play.

The trick is that we need the blockchain to process your encrypted prediction and compute rewards based on whether you were right or wrong, but we don't want anyone - not even the network validators - to see what you predicted until after the deadline passes. This is where Arcium's encrypted computation network becomes absolutely essential.

## What Arcium Actually Does

Arcium is essentially a decentralized network that specializes in executing computations on encrypted data without ever decrypting it. Think of it like a magic box where you can put in secret information, ask complex questions about that information, and get answers - all without anyone ever seeing what's inside the box. That's the power of what cryptographers call Multi-Party Computation, or MPC for short.

In our Olivia project, we use Arcium as a trustless computation layer that sits on top of Solana. When you place a bet with an encrypted prediction, instead of sending your actual prediction to the blockchain in plain text, we encrypt it first using advanced cryptographic techniques. Then we send this encrypted data to Arcium's network, which has special nodes called ARX nodes that can perform computations on encrypted data directly.

## How We Integrated Arcium into Olivia

Setting up Arcium in our project was a multi-step process that required careful configuration. First, we deployed the Arcium program itself to our Solana localnet - this is the core program that orchestrates all the encrypted computations. The Arcium program has a special address on Solana at `BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6`, and we cloned it from devnet to ensure we're using the proven, production-tested version. You can verify this program deployment on Solana devnet using [Solscan](https://solscan.io/account/BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6?cluster=devnet), where you'll see it's a verified, deployed program handling encrypted computations for various projects across the network.

Next, we had to create what Arcium calls an MXE - a Multi-Party Execution Environment. Think of the MXE as a specialized workspace where encrypted computations for our prediction market will run. We configured the MXE to know that when computations complete, they should send callbacks back to our Prediction Market program. This is crucial because once Arcium finishes computing on the encrypted data, we need to process those results and update our market state accordingly.

After setting up the MXE, we defined what Arcium calls "computation definitions" - these are essentially blueprints that tell the Arcium network what kind of computations we want to perform and what format the inputs and outputs should be. In our case, we created three computation definitions: one for initializing markets, one for placing bets with encrypted predictions, and one for distributing rewards after markets resolve.

## The Journey of an Encrypted Prediction

Let me walk you through what actually happens when someone places a bet with an encrypted prediction in our system. This is where all the pieces come together in a beautiful dance of cryptography and blockchain technology.

First, the user opens our frontend application and decides to place a bet. Our frontend uses the Arcium client library to generate a special cryptographic keypair using what's called x25519 encryption. This creates a private key that stays with the user and a public key that we can share. The frontend then takes the user's prediction - a simple true or false about whether they think the market outcome will be yes or no - and encrypts it using this keypair along with what's called a nonce, which is just a random number that ensures the encryption is unique every time.

Once we have this encrypted prediction bundle, we call our Solana program's `place_bet` function. But here's where things get interesting - our Solana program doesn't actually process the prediction itself. Instead, it uses what's called `queue_computation`, which is a special function from Arcium that takes the encrypted data and sends it to Arcium's network with instructions on what to do with it.

The Arcium network then takes over. Its distributed network of ARX nodes receives the encrypted computation request and begins processing it using Multi-Party Computation protocols. These nodes work together in a way where no single node ever sees the decrypted data, but together they can perform computations like comparing predictions, calculating pools, and determining rewards. All of this happens while the data remains encrypted throughout the entire process.

After the computation completes, Arcium needs a way to get the results back to us. This is where callbacks come in. We configured our MXE so that when Arcium finishes a computation, it triggers a callback instruction to our Prediction Market program. Our program has special callback handlers - `place_bet_callback`, `initialize_market_callback`, and `distribute_rewards_callback` - that receive the computation results (which come back still encrypted in a specific format) and update the market state accordingly.

## The Technical Architecture

From a technical perspective, we've built a sophisticated multi-layer architecture. At the blockchain layer, we have our Solana program deployed at program ID `EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA`. You can verify our Prediction Market program is deployed and operational by checking it on [Solscan](https://solscan.io/account/EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA?cluster=devnet) for devnet deployment, or on the local explorer at `http://localhost:8899/` for localnet testing. This program has all the logic for managing markets, bets, and resolutions. But instead of handling the actual prediction logic directly, it delegates to Arcium for any computation involving encrypted data.

The Arcium layer consists of the Arcium program itself (which runs on Solana and coordinates everything) plus a network of Docker containers running ARX nodes. These nodes are what actually perform the MPC computations. We have two ARX nodes running locally for development and testing, configured to work together as a cluster.

Then we have our infrastructure components - a WebSocket server for real-time communication, a database processor for storing and querying market data, and our Next.js frontend that provides the user interface. All of these pieces work together, but the encryption and computation magic happens entirely within the Arcium layer.

## What Makes This Special

What's really revolutionary about this setup is that we achieve true privacy for predictions without sacrificing decentralization or trustlessness. Traditional prediction markets require you to reveal your prediction upfront, which can influence market dynamics and enable front-running. With Arcium's encrypted computation, your prediction stays private until the market resolves, but the system can still compute accurate rewards and pool distributions.

Moreover, because everything happens on-chain through Solana with the computation layer provided by Arcium's decentralized network, there's no single point of failure or trusted intermediary. The cryptographic proofs ensure that computations are performed correctly, and the blockchain ensures that all transactions and state changes are immutable and verifiable.

## The Migration Journey

We actually went through a significant technical challenge to get everything working properly. Initially, we were using Arcium version 0.2.0, but we discovered that the deployed Arcium program on devnet was version 0.3.0, which had breaking API changes. This caused compatibility issues where our program couldn't communicate properly with the Arcium network - we'd get errors saying instructions couldn't be deserialized.

We migrated our entire codebase to Arcium 0.3.0, which required updating all our dependencies, refactoring how we make computation calls, adding new account structures for signing PDAs (Program Derived Addresses), and updating our callback handling. The migration was complex but necessary, and now everything works seamlessly together.

One particular challenge we solved was around authority configuration. When we first initialized our MXE account, we didn't set an authority, which meant the Arcium network didn't know who was allowed to create computation definitions. After understanding the system better, we reinitialized the MXE with the proper authority set to our wallet, which allowed us to successfully create all our computation definitions.

### Build Optimization for Arcium v0.3.0

During deployment, we encountered a macro expansion error with Arcium SDK v0.3.0 when using multiple `init`/`init_if_needed` accounts within a single `queue_computation_accounts` struct. The error manifested as:
```
error[E0425]: cannot find crate `try_from_unchecked` in the list of imported crates
```

**Root Cause:** The `PlaceBet` struct had three accounts using initialization constraints (`sign_pda_account`, `market_vault`, and `bet`), which exceeded the macro expansion limits when combined with `#[queue_computation_accounts]` and `#[derive(Accounts)]`.

**Solution:** We changed the `market_vault` account from `init_if_needed` to `mut` constraint, reducing the number of init accounts from 3 to 2. This resolved the compilation error while maintaining the same functionality, as the vault can be initialized separately or in the market creation flow.

**Technical Details:**
- **SDK Versions:** arcium-client 0.3.0, arcium-macros 0.3.0, arcium-anchor 0.3.1
- **Rust Version Required:** 1.88.0+ (currently using 1.90.0)
- **proc-macro2 Patch:** Required workspace-level patch from `https://github.com/arcium-hq/proc-macro2.git`
- **Build Warning:** Minor stack offset warning (16 bytes over limit) is non-critical and monitored

## Looking Forward

Now that we have the full Arcium integration working, we have a production-ready encrypted computation infrastructure. Users can place bets with private predictions, the system can compute rewards without revealing any information, and everything happens in a trustless, decentralized manner. The combination of Solana's fast, low-cost blockchain with Arcium's powerful encrypted computation capabilities creates something truly unique in the prediction market space.

The beauty of this architecture is that as Arcium's network grows and adds more nodes, our system automatically benefits from increased security and potentially better performance, all without us having to change a single line of code. The decentralized nature means the network becomes more resilient over time, and users can place increasingly larger bets with confidence that their predictions remain private and the computation remains accurate.

## Verifiable On-Chain Deployments

To verify that everything is actually deployed and operational on-chain, you can check the following addresses on Solana:

**Arcium Program (Devnet)**: [`BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6`](https://solscan.io/account/BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6?cluster=devnet) - This is the core Arcium encrypted computation program that we clone to our localnet. It's a verified, production-tested program deployed on Solana devnet that handles all encrypted computation orchestration across the network.

**Olivia Prediction Market Program (Devnet)**: [`EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA`](https://solscan.io/account/EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA?cluster=devnet) - Our deployed Prediction Market program on Solana devnet. You can verify it's on-chain and see all the market creation, betting, and resolution transactions. The program handles market lifecycle management and coordinates with Arcium for encrypted computation processing.

**Deployment Details:**
- **Program ID:** `EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA`
- **Program Data Address:** `FPew8hiui7GkcwomfM28ZTFu8P5KFFpE8skKicLAsQjd`
- **Binary Size:** 503,240 bytes (491 KB)
- **Deployment Slot:** 418521756
- **Network:** Solana Devnet
- **Transaction:** [`2sAt2vi2ngz6vkgHWDC1FGmAbMsMVLDdh9nyp7Bug5664JfEF1H3FLskMxs1JUqb3omh9tRHAQ4i9AC2EvRuFaUT`](https://solscan.io/tx/2sAt2vi2ngz6vkgHWDC1FGmAbMsMVLDdh9nyp7Bug5664JfEF1H3FLskMxs1JUqb3omh9tRHAQ4i9AC2EvRuFaUT?cluster=devnet)

**MXE Account (Devnet)**: [`BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1`](https://solscan.io/account/BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1?cluster=devnet) - The Multi-Party Execution Environment that coordinates encrypted computations for the prediction market. This account was successfully initialized on devnet and contains the MXE public key used for x25519 encryption.

**MXE Initialization Details:**
- **Address:** `BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1`
- **Cluster Offset:** 1078779259 (Devnet)
- **Mempool Size:** Tiny
- **Authority:** `HeaVXD9nctTFNd43Y9ic9jJwdGjvdFML4kbaATKs3Mg8`
- **Transaction:** [`5qc4SwuxKLWQKn77CQ6oCPPjYY5EXkcSE2CN9AVTs4WYZTy2YjgXsEo3Dfgesi6tWSUXexyK4Awfe23VjzBus6SM`](https://solscan.io/tx/5qc4SwuxKLWQKn77CQ6oCPPjYY5EXkcSE2CN9AVTs4WYZTy2YjgXsEo3Dfgesi6tWSUXexyK4Awfe23VjzBus6SM?cluster=devnet)

**Computation Definitions (Devnet):**

All computation definitions are deployed on-chain as Program Derived Addresses (PDAs) and ready to process encrypted transactions:

1. **`initialize_market`**: [`EaLE6pVXWddMMoo5ZdBMcq8LNTVFSDpf2va8Yg1SyM8W`](https://solscan.io/account/EaLE6pVXWddMMoo5ZdBMcq8LNTVFSDpf2va8Yg1SyM8W?cluster=devnet)
   - Transaction: [`bdJVfG3DJufz4cTRvmBRVyDz2dTf43SkHTcfcZgM6wHxKg2SJjgyjk4QR4j6sZDyeR1Un6BUz1oPErnBf1hJ5kC`](https://solscan.io/tx/bdJVfG3DJufz4cTRvmBRVyDz2dTf43SkHTcfcZgM6wHxKg2SJjgyjk4QR4j6sZDyeR1Un6BUz1oPErnBf1hJ5kC?cluster=devnet)

2. **`place_bet`**: [`4jXcnCaJU4BmEWL5ZtngH3hL3sruLFn2mvaD6QZi6FVF`](https://solscan.io/account/4jXcnCaJU4BmEWL5ZtngH3hL3sruLFn2mvaD6QZi6FVF?cluster=devnet)
   - Transaction: [`2su7HtCYwzMEbHGnvhFLy5dW5dxjiBTSvkBQQkNrDmWzEVKD5SSW6Cp35s2QGwARQNxmWZW1o4iVoBcKqCNCiiUf`](https://solscan.io/tx/2su7HtCYwzMEbHGnvhFLy5dW5dxjiBTSvkBQQkNrDmWzEVKD5SSW6Cp35s2QGwARQNxmWZW1o4iVoBcKqCNCiiUf?cluster=devnet)

3. **`distribute_rewards`**: [`EWW5AMMoW8qgQCGrjRaJuQhufv7p3JXPZoPtU6jXjSSB`](https://solscan.io/account/EWW5AMMoW8qgQCGrjRaJuQhufv7p3JXPZoPtU6jXjSSB?cluster=devnet)
   - Transaction: [`2r1SbM3WoK7kqgffPgqL2NbqfBDGHGBSkV4uHoXFhewgcCzstx3rbwhRLRfgoQoPQZbAgWcLXLwQDC3km8Kx3ptR`](https://solscan.io/tx/2r1SbM3WoK7kqgffPgqL2NbqfBDGHGBSkV4uHoXFhewgcCzstx3rbwhRLRfgoQoPQZbAgWcLXLwQDC3km8Kx3ptR?cluster=devnet)

These verifiable on-chain deployments demonstrate that Olivia isn't just a concept - it's a fully functional, deployed system where anyone can verify the code, the transactions, and the encrypted computation infrastructure is all working together on a public blockchain.

---

## Building and Deploying

### 🎉 Current Deployment Status

**The Olivia Prediction Market is fully deployed and operational on Solana Devnet with complete Arcium MXE integration!**

- ✅ Prediction Market Program deployed
- ✅ MXE Account initialized
- ✅ All 3 Computation Definitions initialized
- ✅ Encrypted predictions enabled (`NEXT_PUBLIC_DEMO_NO_ARCIUM=false`)
- ✅ Ready for production testing on devnet

The instructions below are for reference and fresh deployments.

---

### Prerequisites

1. **Rust Toolchain:** Version 1.88.0 or higher
   ```bash
   rustc --version  # Should show 1.88.0+
   ```

2. **Anchor CLI:** Version 0.31.1
   ```bash
   anchor --version
   avm use 0.31.1  # If needed
   ```

3. **Solana CLI:** Latest version
   ```bash
   solana --version
   ```

4. **Workspace Configuration:** Ensure the root `Cargo.toml` includes the proc-macro2 patch:
   ```toml
   [patch.crates-io]
   proc-macro2 = { git = 'https://github.com/arcium-hq/proc-macro2.git' }
   ```

### Build Instructions

1. **Clean Build Environment:**
   ```bash
   cd /path/to/Olivia
   rm -rf target
   cargo clean
   ```

2. **Build the Program:**
   ```bash
   cargo build-sbf --manifest-path Programs/PredictionMarket/Cargo.toml
   ```

   **Expected Output:**
   - Compiled binary: `target/deploy/prediction_market.so` (~491 KB)
   - Keypair: `target/deploy/prediction_market-keypair.json`
   - Minor stack offset warning (16 bytes) - non-critical

3. **Verify Program ID Match:**
   ```bash
   solana-keygen pubkey target/deploy/prediction_market-keypair.json
   # Should match: EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA
   ```

### Deployment to Devnet

1. **Configure Solana CLI:**
   ```bash
   solana config set --url https://api.devnet.solana.com
   solana config set --commitment confirmed
   ```

2. **Check Wallet Balance:**
   ```bash
   solana balance
   # Need ~4 SOL for deployment
   ```

3. **Request Airdrop (if needed):**
   ```bash
   solana airdrop 2
   ```

4. **Deploy Program:**
   ```bash
   solana program deploy target/deploy/prediction_market.so
   ```

5. **Verify Deployment:**
   ```bash
   solana program show EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA
   ```

### Initialize Arcium Accounts

After deployment, initialize the Arcium infrastructure. You can use either the Arcium CLI (recommended) or the Node.js scripts.

#### Method 1: Using Arcium CLI (Recommended)

1. **Initialize MXE Account:**
   ```bash
   arcium init-mxe \
     --callback-program EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA \
     --cluster-offset 1078779259 \
     --keypair-path ~/.config/solana/id.json \
     --rpc-url https://api.devnet.solana.com \
     --mempool-size Tiny \
     --authority <YOUR_WALLET_ADDRESS>
   ```

2. **Initialize Computation Definitions:**
   ```bash
   node Arcium/scripts/init-comp-defs-devnet.js
   ```

3. **Verify Initialization:**
   ```bash
   # Check MXE account information
   arcium mxe-info \
     --mxe-program EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA \
     --rpc-url https://api.devnet.solana.com
   ```

#### Method 2: Using Node.js Scripts

1. **Initialize MXE Account:**
   ```bash
   node Arcium/scripts/init-mxe-devnet.js
   ```

2. **Initialize Computation Definitions:**
   ```bash
   node Arcium/scripts/init-comp-defs-devnet.js
   ```

3. **Verify Initialization:**
   ```bash
   # Check MXE account exists
   solana account BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1

   # Check computation definitions are initialized
   # (Addresses are derived PDAs from program ID)
   ```

**Note:** The MXE and all computation definitions are already initialized on devnet. These steps are only needed for fresh deployments or localnet setup.

### Localnet Setup (Development)

For local development with ARX nodes:

1. **Start ARX Containers:**
   ```bash
   cd Arcium/artifacts
   docker compose -f docker-compose-arx-env.yml up -d
   ```

2. **Start Solana Test Validator:**
   ```bash
   # Clone Arcium program from devnet
   solana-test-validator \
     --clone BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6 \
     --url devnet \
     --reset &
   ```

3. **Deploy to Localnet:**
   ```bash
   solana config set --url http://localhost:8899
   anchor deploy
   ```

4. **Initialize Arcium for Localnet:**
   ```bash
   node Arcium/scripts/init-arcium-localnet.js
   ```

### Frontend Configuration

Update `Frontend/.env.local`:
```env
NEXT_PUBLIC_SOLANA_NETWORK=devnet
NEXT_PUBLIC_SOLANA_RPC_URL=https://devnet.helius-rpc.com/?api-key=YOUR_API_KEY
NEXT_PUBLIC_PREDICTION_MARKET_PROGRAM_ID=EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA
NEXT_PUBLIC_ARCIUM_CLUSTER_OFFSET=1078779259
NEXT_PUBLIC_DEMO_NO_ARCIUM=false
```

**Important Configuration Notes:**
- **RPC URL**: We use Helius RPC for better reliability and rate limits. Get your free API key at [helius.dev](https://www.helius.dev/)
- **DEMO_NO_ARCIUM**: Set to `false` to enable encrypted predictions via Arcium MXE (production mode)
- **DEMO_NO_ARCIUM**: Set to `true` only for testing basic program functionality without MPC encryption

The current production deployment on devnet has Arcium MXE fully initialized and operational.

### Troubleshooting

**Issue: `try_from_unchecked` compilation error**
- **Cause:** Too many `init`/`init_if_needed` accounts in `queue_computation_accounts` struct
- **Solution:** Reduce init accounts or use `mut` constraint instead (as done with `market_vault`)

**Issue: Stack offset warning**
- **Cause:** Large account struct exceeds Solana's 4096-byte stack limit by 16 bytes
- **Impact:** Non-critical; program functions normally
- **Monitoring:** Will optimize in future iterations if needed

**Issue: Arcium program not found on localnet**
- **Cause:** Test validator started without cloning Arcium program
- **Solution:** Restart validator with `--clone BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6` flag

**Issue: Insufficient funds for deployment**
- **Cause:** Deployment requires ~3.5 SOL for rent-exempt program account
- **Solution:** Request airdrops on devnet: `solana airdrop 2` (may need multiple requests)

**Issue: MXE initialization fails with "ConstraintSeeds" error**
- **Cause:** Using Node.js script `init-mxe-devnet.js` may have incorrect seed derivation for MXE keygen computation account
- **Solution:** Use the Arcium CLI instead: `arcium init-mxe` with proper parameters
- **Alternative:** The MXE is already initialized on devnet, no action needed for existing deployment

---

## Testing the Deployment

1. **Verify Program is Callable:**
   ```bash
   # View program on Solscan
   open https://solscan.io/account/EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA?cluster=devnet
   ```

2. **Test Market Creation:**
   - Use frontend to create a test market
   - Verify market PDA is created on-chain
   - Check Arcium computation is queued

3. **Test Encrypted Betting:**
   - Place a bet with encrypted prediction
   - Verify bet account is created
   - Check Arcium callback updates market state

4. **Monitor ARX Nodes (Localnet):**
   ```bash
   docker compose -f Arcium/artifacts/docker-compose-arx-env.yml logs -f
   ```

---

## Quick Reference

### Devnet Addresses

```
Prediction Market Program: EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA
Arcium Program:            BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6
MXE Account:               BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1
```

### Computation Definitions

```
initialize_market:    EaLE6pVXWddMMoo5ZdBMcq8LNTVFSDpf2va8Yg1SyM8W
place_bet:            4jXcnCaJU4BmEWL5ZtngH3hL3sruLFn2mvaD6QZi6FVF
distribute_rewards:   EWW5AMMoW8qgQCGrjRaJuQhufv7p3JXPZoPtU6jXjSSB
```

### Useful Commands

**Check MXE Status:**
```bash
arcium mxe-info --mxe-program EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA --rpc-url https://api.devnet.solana.com
```

**Verify Accounts:**
```bash
solana account BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1 --url devnet
```

**View on Solscan:**
- [Prediction Market Program](https://solscan.io/account/EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA?cluster=devnet)
- [MXE Account](https://solscan.io/account/BJ5kW53KtdsXLvieZPbvLXq3PBHnDFhD42oLZ952JBR1?cluster=devnet)
- [Arcium Program](https://solscan.io/account/BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6?cluster=devnet)

---

## Additional Documentation

For more detailed technical documentation on Olivia's integrated tech stack:

- **Magic Block Ephemeral Rollups:** [docs/MagicBlock.md](docs/MagicBlock.md) - Learn how ephemeral rollups deliver instant, zero-fee transactions while maintaining decentralization
- **Arcium Encrypted Computation:** [docs/Arcium.md](docs/Arcium.md) - Deep dive into Multi-Party Computation for private predictions and trustless market resolution

---

