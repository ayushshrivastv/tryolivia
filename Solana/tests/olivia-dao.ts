import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, Keypair } from "@solana/web3.js";
import { OliviaDao } from "../target/types/olivia_dao";
import { OliviaDAOClient } from "../app/olivia-dao-client";
import { expect } from "chai";

describe("olivia-dao", () => {
  // Configure the client to use the local cluster.
  anchor.setProvider(anchor.AnchorProvider.env());

  const program = anchor.workspace.OliviaDao as Program<OliviaDao>;
  const provider = anchor.getProvider() as anchor.AnchorProvider;
  
  let daoClient: OliviaDAOClient;
  let daoStateKeypair: Keypair;
  let governanceTokenMint: PublicKey;

  before(async () => {
    // Initialize test setup
    daoStateKeypair = Keypair.generate();
    governanceTokenMint = Keypair.generate().publicKey; // Mock token mint
    
    daoClient = new OliviaDAOClient(
      provider.connection,
      provider.wallet as anchor.Wallet,
      program.programId
    );
  });

  it("Initializes the DAO", async () => {
    const tx = await daoClient.initializeDAO(
      daoStateKeypair,
      governanceTokenMint,
      1000 // voting threshold
    );

    expect(tx).to.be.a("string");
    console.log("DAO initialization transaction:", tx);

    // Verify DAO state
    const daoState = await daoClient.getDAOState(daoStateKeypair.publicKey);
    expect(daoState.memberCount).to.equal(0);
    expect(daoState.votingThreshold).to.equal(1000);
  });

  it("Allows a user to join the DAO", async () => {
    const nickname = "TestUser";
    const noisePublicKey = new Uint8Array(32).fill(1); // Mock noise key

    const tx = await daoClient.joinDAO(
      daoStateKeypair.publicKey,
      nickname,
      noisePublicKey
    );

    expect(tx).to.be.a("string");
    console.log("Join DAO transaction:", tx);

    // Verify member was created
    const member = await daoClient.getMember();
    expect(member).to.not.be.null;
    expect(member!.nickname).to.equal(nickname);
    expect(member!.isActive).to.be.true;

    // Verify member count increased
    const daoState = await daoClient.getDAOState(daoStateKeypair.publicKey);
    expect(daoState.memberCount).to.equal(1);
  });

  it("Allows updating member information", async () => {
    const newNickname = "UpdatedUser";
    const newNoiseKey = new Uint8Array(32).fill(2);

    const tx = await daoClient.updateMember(newNickname, newNoiseKey);
    expect(tx).to.be.a("string");

    // Verify update
    const member = await daoClient.getMember();
    expect(member!.nickname).to.equal(newNickname);
  });

  it("Allows registering a relay node", async () => {
    const endpoint = "https://relay.olivia.chat";
    const stakeAmount = 1_000_000_000; // 1 SOL in lamports

    const tx = await daoClient.registerRelayNode(endpoint, stakeAmount);
    expect(tx).to.be.a("string");

    // Verify relay node was registered
    const relayNodes = await daoClient.getAllRelayNodes();
    expect(relayNodes.length).to.equal(1);
    expect(relayNodes[0].endpoint).to.equal(endpoint);
    expect(relayNodes[0].stake).to.equal(stakeAmount);
  });

  it("Can fetch all members", async () => {
    const members = await daoClient.getAllMembers();
    expect(members.length).to.equal(1);
    expect(members[0].nickname).to.equal("UpdatedUser");
  });
});
