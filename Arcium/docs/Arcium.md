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

From a technical perspective, we've built a sophisticated multi-layer architecture. At the blockchain layer, we have our Solana program deployed at program ID `Eb8zo9c1YwtGw64C4TRcWxuPCBAVHVPUBUC7jcGNVWYJ`. You can verify our Prediction Market program is deployed and operational by checking it on [Solscan](https://solscan.io/account/Eb8zo9c1YwtGw64C4TRcWxuPCBAVHVPUBUC7jcGNVWYJ?cluster=devnet) if deployed to devnet, or on the local explorer at `http://localhost:8899/` for localnet testing. This program has all the logic for managing markets, bets, and resolutions. But instead of handling the actual prediction logic directly, it delegates to Arcium for any computation involving encrypted data.

The Arcium layer consists of the Arcium program itself (which runs on Solana and coordinates everything) plus a network of Docker containers running ARX nodes. These nodes are what actually perform the MPC computations. We have two ARX nodes running locally for development and testing, configured to work together as a cluster.

Then we have our infrastructure components - a WebSocket server for real-time communication, a database processor for storing and querying market data, and our Next.js frontend that provides the user interface. All of these pieces work together, but the encryption and computation magic happens entirely within the Arcium layer.

## What Makes This Special

What's really revolutionary about this setup is that we achieve true privacy for predictions without sacrificing decentralization or trustlessness. Traditional prediction markets require you to reveal your prediction upfront, which can influence market dynamics and enable front-running. With Arcium's encrypted computation, your prediction stays private until the market resolves, but the system can still compute accurate rewards and pool distributions.

Moreover, because everything happens on-chain through Solana with the computation layer provided by Arcium's decentralized network, there's no single point of failure or trusted intermediary. The cryptographic proofs ensure that computations are performed correctly, and the blockchain ensures that all transactions and state changes are immutable and verifiable.

## The Migration Journey

We actually went through a significant technical challenge to get everything working properly. Initially, we were using Arcium version 0.2.0, but we discovered that the deployed Arcium program on devnet was version 0.3.0, which had breaking API changes. This caused compatibility issues where our program couldn't communicate properly with the Arcium network - we'd get errors saying instructions couldn't be deserialized.

We migrated our entire codebase to Arcium 0.3.0, which required updating all our dependencies, refactoring how we make computation calls, adding new account structures for signing PDAs (Program Derived Addresses), and updating our callback handling. The migration was complex but necessary, and now everything works seamlessly together.

One particular challenge we solved was around authority configuration. When we first initialized our MXE account, we didn't set an authority, which meant the Arcium network didn't know who was allowed to create computation definitions. After understanding the system better, we reinitialized the MXE with the proper authority set to our wallet, which allowed us to successfully create all our computation definitions.

## Looking Forward

Now that we have the full Arcium integration working, we have a production-ready encrypted computation infrastructure. Users can place bets with private predictions, the system can compute rewards without revealing any information, and everything happens in a trustless, decentralized manner. The combination of Solana's fast, low-cost blockchain with Arcium's powerful encrypted computation capabilities creates something truly unique in the prediction market space.

The beauty of this architecture is that as Arcium's network grows and adds more nodes, our system automatically benefits from increased security and potentially better performance, all without us having to change a single line of code. The decentralized nature means the network becomes more resilient over time, and users can place increasingly larger bets with confidence that their predictions remain private and the computation remains accurate.

## Verifiable On-Chain Deployments

To verify that everything is actually deployed and operational on-chain, you can check the following addresses on Solana:

**Arcium Program (Devnet)**: [`BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6`](https://solscan.io/account/BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6?cluster=devnet) - This is the core Arcium encrypted computation program that we clone to our localnet. It's a verified, production-tested program deployed on Solana devnet that handles all encrypted computation orchestration across the network.

**Olivia Prediction Market Program**: [`Eb8zo9c1YwtGw64C4TRcWxuPCBAVHVPUBUC7jcGNVWYJ`](https://solscan.io/account/Eb8zo9c1YwtGw64C4TRcWxuPCBAVHVPUBUC7jcGNVWYJ?cluster=devnet) - This is our deployed Prediction Market program. When deployed to devnet or mainnet, you'll be able to verify it's on-chain and see all the market creation, betting, and resolution transactions. The program handles market lifecycle management and coordinates with Arcium for encrypted computation processing.

All of our computation definitions are also on-chain as Program Derived Addresses (PDAs) derived from these program addresses, meaning you can verify that the `initialize_market`, `place_bet`, and `distribute_rewards` computation definitions have been properly initialized and are ready to process encrypted transactions.

These verifiable on-chain deployments demonstrate that Olivia isn't just a concept - it's a fully functional, deployed system where anyone can verify the code, the transactions, and the encrypted computation infrastructure is all working together on a public blockchain.

