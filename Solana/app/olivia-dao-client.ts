import * as anchor from "@coral-xyz/anchor";
import { Program, AnchorProvider, Wallet } from "@coral-xyz/anchor";
import { Connection, PublicKey, Keypair, SystemProgram } from "@solana/web3.js";
import { OliviaDao } from "../target/types/olivia_dao";

export interface DAOMember {
  wallet: string;
  nickname: string;
  noisePublicKey: Uint8Array;
  reputation: number;
  joinedAt: number;
  isActive: boolean;
}

export interface RelayNode {
  operator: string;
  endpoint: string;
  stake: number;
  performance: number;
  isActive: boolean;
}

export class OliviaDAOClient {
  private program: Program<OliviaDao>;
  private provider: AnchorProvider;

  constructor(
    connection: Connection,
    wallet: Wallet,
    programId: PublicKey
  ) {
    this.provider = new AnchorProvider(connection, wallet, {});
    anchor.setProvider(this.provider);
    this.program = new Program(
      require("../target/idl/olivia_dao.json"),
      programId,
      this.provider
    );
  }

  /**
   * Initialize the DAO (only called once by authority)
   */
  async initializeDAO(
    daoStateKeypair: Keypair,
    governanceTokenMint: PublicKey,
    votingThreshold: number
  ): Promise<string> {
    const tx = await this.program.methods
      .initializeDao(governanceTokenMint, new anchor.BN(votingThreshold))
      .accounts({
        daoState: daoStateKeypair.publicKey,
        authority: this.provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .signers([daoStateKeypair])
      .rpc();

    console.log("DAO initialized with transaction:", tx);
    return tx;
  }

  /**
   * Join the DAO as a new member
   */
  async joinDAO(
    daoState: PublicKey,
    nickname: string,
    noisePublicKey: Uint8Array
  ): Promise<string> {
    const [memberPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("member"), this.provider.wallet.publicKey.toBuffer()],
      this.program.programId
    );

    const tx = await this.program.methods
      .joinDao(nickname, Array.from(noisePublicKey))
      .accounts({
        member: memberPDA,
        daoState: daoState,
        user: this.provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    console.log("Joined DAO with transaction:", tx);
    return tx;
  }

  /**
   * Update member information
   */
  async updateMember(
    newNickname?: string,
    newNoiseKey?: Uint8Array
  ): Promise<string> {
    const [memberPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("member"), this.provider.wallet.publicKey.toBuffer()],
      this.program.programId
    );

    const tx = await this.program.methods
      .updateMember(
        newNickname || null,
        newNoiseKey ? Array.from(newNoiseKey) : null
      )
      .accounts({
        member: memberPDA,
        user: this.provider.wallet.publicKey,
      })
      .rpc();

    console.log("Updated member with transaction:", tx);
    return tx;
  }

  /**
   * Register a relay node
   */
  async registerRelayNode(
    endpoint: string,
    stakeAmount: number
  ): Promise<string> {
    const [relayPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("relay"), this.provider.wallet.publicKey.toBuffer()],
      this.program.programId
    );

    const tx = await this.program.methods
      .registerRelayNode(endpoint, new anchor.BN(stakeAmount))
      .accounts({
        relayNode: relayPDA,
        operator: this.provider.wallet.publicKey,
        systemProgram: SystemProgram.programId,
      })
      .rpc();

    console.log("Registered relay node with transaction:", tx);
    return tx;
  }

  /**
   * Get member information
   */
  async getMember(walletAddress?: PublicKey): Promise<DAOMember | null> {
    const wallet = walletAddress || this.provider.wallet.publicKey;
    const [memberPDA] = PublicKey.findProgramAddressSync(
      [Buffer.from("member"), wallet.toBuffer()],
      this.program.programId
    );

    try {
      const memberAccount = await this.program.account.member.fetch(memberPDA);
      return {
        wallet: memberAccount.wallet.toString(),
        nickname: memberAccount.nickname,
        noisePublicKey: new Uint8Array(memberAccount.noisePublicKey),
        reputation: memberAccount.reputation.toNumber(),
        joinedAt: memberAccount.joinedAt.toNumber(),
        isActive: memberAccount.isActive,
      };
    } catch (error) {
      console.log("Member not found:", error);
      return null;
    }
  }

  /**
   * Get DAO state information
   */
  async getDAOState(daoStateAddress: PublicKey) {
    try {
      const daoState = await this.program.account.daoState.fetch(daoStateAddress);
      return {
        authority: daoState.authority.toString(),
        governanceTokenMint: daoState.governanceTokenMint.toString(),
        votingThreshold: daoState.votingThreshold.toNumber(),
        memberCount: daoState.memberCount.toNumber(),
        messageFee: daoState.messageFee.toNumber(),
        relayRewards: daoState.relayRewards.toNumber(),
      };
    } catch (error) {
      console.error("Failed to fetch DAO state:", error);
      throw error;
    }
  }

  /**
   * Get all members (this would need pagination in production)
   */
  async getAllMembers(): Promise<DAOMember[]> {
    const memberAccounts = await this.program.account.member.all();
    return memberAccounts.map((account) => ({
      wallet: account.account.wallet.toString(),
      nickname: account.account.nickname,
      noisePublicKey: new Uint8Array(account.account.noisePublicKey),
      reputation: account.account.reputation.toNumber(),
      joinedAt: account.account.joinedAt.toNumber(),
      isActive: account.account.isActive,
    }));
  }

  /**
   * Get all relay nodes
   */
  async getAllRelayNodes(): Promise<RelayNode[]> {
    const relayAccounts = await this.program.account.relayNode.all();
    return relayAccounts.map((account) => ({
      operator: account.account.operator.toString(),
      endpoint: account.account.endpoint,
      stake: account.account.stake.toNumber(),
      performance: account.account.performance.toNumber(),
      isActive: account.account.isActive,
    }));
  }
}
