use anchor_lang::prelude::*;

declare_id!("BQcHvNqgAT7TQonNJR6zoxu7eNCy9c7mB44K9CVaUcA");

#[program]
pub mod olivia_dao {
    use super::*;

    /// Initialize the DAO with basic configuration
    pub fn initialize_dao(
        ctx: Context<InitializeDAO>,
        governance_token_mint: Pubkey,
        voting_threshold: u64,
    ) -> Result<()> {
        let dao_state = &mut ctx.accounts.dao_state;
        dao_state.authority = ctx.accounts.authority.key();
        dao_state.governance_token_mint = governance_token_mint;
        dao_state.voting_threshold = voting_threshold;
        dao_state.member_count = 0;
        dao_state.message_fee = 1000; // 0.001 SOL in lamports
        dao_state.relay_rewards = 500; // 0.0005 SOL in lamports
        dao_state.proposal_count = 0;
        dao_state.treasury_balance = 0;
        
        msg!("OLIVIA DAO initialized with authority: {}", dao_state.authority);
        Ok(())
    }

    /// Create a governance proposal
    pub fn create_proposal(
        ctx: Context<CreateProposal>,
        title: String,
        description: String,
        proposal_type: ProposalType,
    ) -> Result<()> {
        require!(title.len() <= 64, ErrorCode::TitleTooLong);
        require!(description.len() <= 512, ErrorCode::DescriptionTooLong);

        let dao_state = &mut ctx.accounts.dao_state;
        let proposal = &mut ctx.accounts.proposal;
        
        proposal.id = dao_state.proposal_count;
        proposal.proposer = ctx.accounts.proposer.key();
        proposal.title = title;
        proposal.description = description;
        proposal.proposal_type = proposal_type;
        proposal.votes_for = 0;
        proposal.votes_against = 0;
        proposal.created_at = Clock::get()?.unix_timestamp;
        proposal.voting_ends_at = Clock::get()?.unix_timestamp + 7 * 24 * 60 * 60; // 7 days
        proposal.executed = false;
        proposal.cancelled = false;

        dao_state.proposal_count += 1;

        msg!("Proposal created: {} by {}", proposal.title, proposal.proposer);
        Ok(())
    }

    /// Vote on a proposal
    pub fn vote_on_proposal(
        ctx: Context<VoteOnProposal>,
        vote: bool, // true = for, false = against
        voting_power: u64,
    ) -> Result<()> {
        let proposal = &mut ctx.accounts.proposal;
        let vote_record = &mut ctx.accounts.vote_record;
        
        // Check voting period
        let current_time = Clock::get()?.unix_timestamp;
        require!(current_time <= proposal.voting_ends_at, ErrorCode::VotingPeriodEnded);
        require!(!proposal.executed, ErrorCode::ProposalAlreadyExecuted);
        require!(!proposal.cancelled, ErrorCode::ProposalCancelled);

        // Record the vote
        vote_record.voter = ctx.accounts.voter.key();
        vote_record.proposal_id = proposal.id;
        vote_record.vote = vote;
        vote_record.voting_power = voting_power;
        vote_record.voted_at = current_time;

        // Update proposal vote counts
        if vote {
            proposal.votes_for += voting_power;
        } else {
            proposal.votes_against += voting_power;
        }

        msg!("Vote cast on proposal {}: {} with power {}", proposal.id, vote, voting_power);
        Ok(())
    }

    /// Execute a passed proposal
    pub fn execute_proposal(ctx: Context<ExecuteProposal>) -> Result<()> {
        let dao_state = &ctx.accounts.dao_state;
        let proposal = &mut ctx.accounts.proposal;
        
        // Check if proposal passed
        let total_votes = proposal.votes_for + proposal.votes_against;
        require!(total_votes >= dao_state.voting_threshold, ErrorCode::InsufficientVotes);
        require!(proposal.votes_for > proposal.votes_against, ErrorCode::ProposalRejected);
        
        // Check voting period ended
        let current_time = Clock::get()?.unix_timestamp;
        require!(current_time > proposal.voting_ends_at, ErrorCode::VotingPeriodActive);
        require!(!proposal.executed, ErrorCode::ProposalAlreadyExecuted);

        proposal.executed = true;

        // Execute based on proposal type
        match proposal.proposal_type {
            ProposalType::UpdateMessageFee => {
                // Implementation for updating message fees
                msg!("Executing message fee update proposal");
            },
            ProposalType::UpdateRelayRewards => {
                // Implementation for updating relay rewards
                msg!("Executing relay rewards update proposal");
            },
            ProposalType::AddRelayNode => {
                // Implementation for adding relay nodes
                msg!("Executing add relay node proposal");
            },
            ProposalType::RemoveRelayNode => {
                // Implementation for removing relay nodes
                msg!("Executing remove relay node proposal");
            },
        }

        msg!("Proposal {} executed successfully", proposal.id);
        Ok(())
    }

    /// Join the DAO as a new member
    pub fn join_dao(
        ctx: Context<JoinDAO>,
        nickname: String,
        noise_public_key: [u8; 32],
    ) -> Result<()> {
        require!(nickname.len() <= 32, ErrorCode::NicknameTooLong);
        
        let member = &mut ctx.accounts.member;
        member.wallet = ctx.accounts.user.key();
        member.nickname = nickname;
        member.noise_public_key = noise_public_key;
        member.reputation = 0;
        member.joined_at = Clock::get()?.unix_timestamp;
        member.is_active = true;

        // Increment member count in DAO state
        let dao_state = &mut ctx.accounts.dao_state;
        dao_state.member_count = dao_state.member_count.checked_add(1).unwrap();

        msg!("New member joined: {} ({})", member.nickname, member.wallet);
        Ok(())
    }

    /// Update member information
    pub fn update_member(
        ctx: Context<UpdateMember>,
        new_nickname: Option<String>,
        new_noise_key: Option<[u8; 32]>,
    ) -> Result<()> {
        let member = &mut ctx.accounts.member;
        
        if let Some(nickname) = new_nickname {
            require!(nickname.len() <= 32, ErrorCode::NicknameTooLong);
            member.nickname = nickname;
        }
        
        if let Some(noise_key) = new_noise_key {
            member.noise_public_key = noise_key;
        }

        msg!("Member updated: {}", member.wallet);
        Ok(())
    }

    /// Register a relay node
    pub fn register_relay_node(
        ctx: Context<RegisterRelayNode>,
        endpoint: String,
        stake_amount: u64,
    ) -> Result<()> {
        require!(endpoint.len() <= 128, ErrorCode::EndpointTooLong);
        require!(stake_amount >= 1_000_000_000, ErrorCode::InsufficientStake); // Min 1 SOL

        let relay_node = &mut ctx.accounts.relay_node;
        relay_node.operator = ctx.accounts.operator.key();
        relay_node.endpoint = endpoint;
        relay_node.stake = stake_amount;
        relay_node.performance = 100; // Start with 100% performance
        relay_node.is_active = true;

        msg!("Relay node registered: {} by {}", relay_node.endpoint, relay_node.operator);
        Ok(())
    }

    /// Send a message through the DAO (with fee)
    pub fn send_message(
        ctx: Context<SendMessage>,
        recipient: Pubkey,
        encrypted_content: Vec<u8>,
    ) -> Result<()> {
        let dao_state = &mut ctx.accounts.dao_state;
        let sender = &ctx.accounts.sender;
        
        // Charge message fee
        let fee = dao_state.message_fee;
        
        // Transfer fee from sender to DAO treasury
        let ix = anchor_lang::solana_program::system_instruction::transfer(
            &sender.key(),
            &dao_state.key(),
            fee,
        );
        
        anchor_lang::solana_program::program::invoke(
            &ix,
            &[
                sender.to_account_info(),
                dao_state.to_account_info(),
            ],
        )?;

        // Update treasury balance
        dao_state.treasury_balance += fee;

        // Create message record
        let message_record = &mut ctx.accounts.message_record;
        message_record.sender = sender.key();
        message_record.recipient = recipient;
        message_record.content_hash = anchor_lang::solana_program::hash::hash(&encrypted_content).to_bytes();
        message_record.timestamp = Clock::get()?.unix_timestamp;
        message_record.fee_paid = fee;

        msg!("Message sent from {} to {} with fee {}", sender.key(), recipient, fee);
        Ok(())
    }

    /// Update relay node performance and status
    pub fn update_relay_performance(
        ctx: Context<UpdateRelayPerformance>,
        messages_relayed: u64,
        uptime_percentage: u64,
        latency_ms: u64,
    ) -> Result<()> {
        let relay_node = &mut ctx.accounts.relay_node;
        
        // Update performance metrics
        relay_node.messages_relayed += messages_relayed;
        relay_node.total_uptime_checks += 1;
        relay_node.successful_uptime_checks += if uptime_percentage > 95 { 1 } else { 0 };
        relay_node.average_latency = ((relay_node.average_latency * (relay_node.total_uptime_checks - 1)) + latency_ms) / relay_node.total_uptime_checks;
        
        // Calculate new performance score (0-100)
        let uptime_score = (relay_node.successful_uptime_checks * 100) / relay_node.total_uptime_checks;
        let latency_score = if relay_node.average_latency < 100 { 100 } else { 10000 / relay_node.average_latency };
        let message_score = if relay_node.messages_relayed > 1000 { 100 } else { (relay_node.messages_relayed * 100) / 1000 };
        
        relay_node.performance = (uptime_score + latency_score.min(100) + message_score) / 3;
        relay_node.last_heartbeat = Clock::get()?.unix_timestamp;

        msg!("Relay performance updated: {} (performance: {})", relay_node.operator, relay_node.performance);
        Ok(())
    }

    /// Route message through relay network
    pub fn route_message(
        ctx: Context<RouteMessage>,
        recipient: Pubkey,
        encrypted_content: Vec<u8>,
        relay_path: Vec<Pubkey>,
    ) -> Result<()> {
        let dao_state = &mut ctx.accounts.dao_state;
        let sender = &ctx.accounts.sender;
        let message_record = &mut ctx.accounts.message_record;
        
        // Charge message fee
        let fee = dao_state.message_fee;
        
        // Transfer fee from sender to DAO treasury
        let ix = anchor_lang::solana_program::system_instruction::transfer(
            &sender.key(),
            &dao_state.key(),
            fee,
        );
        
        anchor_lang::solana_program::program::invoke(
            &ix,
            &[
                sender.to_account_info(),
                dao_state.to_account_info(),
            ],
        )?;

        dao_state.treasury_balance += fee;

        // Create message routing record
        message_record.sender = sender.key();
        message_record.recipient = recipient;
        message_record.content_hash = anchor_lang::solana_program::hash::hash(&encrypted_content).to_bytes();
        message_record.relay_path = relay_path;
        message_record.timestamp = Clock::get()?.unix_timestamp;
        message_record.fee_paid = fee;
        message_record.delivery_status = DeliveryStatus::Pending;
        message_record.retry_count = 0;

        msg!("Message routed from {} to {} via {} relays", sender.key(), recipient, message_record.relay_path.len());
        Ok(())
    }

    /// Confirm message delivery
    pub fn confirm_delivery(
        ctx: Context<ConfirmDelivery>,
        message_hash: [u8; 32],
    ) -> Result<()> {
        let message_record = &mut ctx.accounts.message_record;
        let relay_node = &mut ctx.accounts.relay_node;
        
        require!(message_record.content_hash == message_hash, ErrorCode::InvalidMessageHash);
        require!(message_record.delivery_status == DeliveryStatus::Pending, ErrorCode::MessageAlreadyDelivered);

        message_record.delivery_status = DeliveryStatus::Delivered;
        message_record.delivered_at = Some(Clock::get()?.unix_timestamp);

        // Reward the relay node for successful delivery
        relay_node.successful_deliveries += 1;

        msg!("Message delivery confirmed by relay {}", relay_node.operator);
        Ok(())
    }

    /// Claim relay rewards based on performance
    pub fn claim_relay_rewards(ctx: Context<ClaimRelayRewards>) -> Result<()> {
        let dao_state = &mut ctx.accounts.dao_state;
        let relay_node = &mut ctx.accounts.relay_node;
        let operator = &ctx.accounts.operator;

        // Check if enough time has passed since last claim (24 hours)
        let current_time = Clock::get()?.unix_timestamp;
        let time_since_last_claim = current_time - relay_node.last_reward_claim;
        require!(time_since_last_claim >= 86400, ErrorCode::RewardClaimTooEarly); // 24 hours

        // Calculate rewards based on performance, stake, and deliveries
        let base_reward = dao_state.relay_rewards;
        let performance_multiplier = relay_node.performance;
        let stake_multiplier = (relay_node.stake / 1_000_000_000).min(10); // Max 10x for 10 SOL stake
        let delivery_bonus = (relay_node.successful_deliveries * 100).min(1000); // Bonus for deliveries
        
        let reward_amount = (base_reward * performance_multiplier * stake_multiplier / 10000) + delivery_bonus;

        // Ensure treasury has enough funds
        require!(dao_state.treasury_balance >= reward_amount, ErrorCode::InsufficientTreasuryFunds);

        // Transfer rewards from treasury to operator
        **dao_state.to_account_info().try_borrow_mut_lamports()? -= reward_amount;
        **operator.to_account_info().try_borrow_mut_lamports()? += reward_amount;

        dao_state.treasury_balance -= reward_amount;
        relay_node.last_reward_claim = current_time;
        relay_node.total_rewards_earned += reward_amount;

        msg!("Relay rewards claimed: {} lamports to {} (performance: {})", reward_amount, operator.key(), relay_node.performance);
        Ok(())
    }

    /// Slash relay node for poor performance
    pub fn slash_relay_node(
        ctx: Context<SlashRelayNode>,
        reason: SlashReason,
    ) -> Result<()> {
        let dao_state = &mut ctx.accounts.dao_state;
        let relay_node = &mut ctx.accounts.relay_node;
        
        // Calculate slash amount based on reason
        let slash_amount = match reason {
            SlashReason::Downtime => relay_node.stake / 20, // 5% slash
            SlashReason::MaliciousBehavior => relay_node.stake / 2, // 50% slash
            SlashReason::PoorPerformance => relay_node.stake / 10, // 10% slash
        };

        // Transfer slashed amount to treasury
        relay_node.stake -= slash_amount;
        dao_state.treasury_balance += slash_amount;

        // Deactivate if stake falls below minimum
        if relay_node.stake < 1_000_000_000 { // 1 SOL minimum
            relay_node.is_active = false;
        }

        msg!("Relay node {} slashed {} lamports for {:?}", relay_node.operator, slash_amount, reason);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializeDAO<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + DAOState::INIT_SPACE
    )]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(mut)]
    pub authority: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct JoinDAO<'info> {
    #[account(
        init,
        payer = user,
        space = 8 + Member::INIT_SPACE,
        seeds = [b"member", user.key().as_ref()],
        bump
    )]
    pub member: Account<'info, Member>,
    
    #[account(mut)]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(mut)]
    pub user: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateMember<'info> {
    #[account(
        mut,
        seeds = [b"member", user.key().as_ref()],
        bump,
        constraint = member.wallet == user.key() @ ErrorCode::UnauthorizedMember
    )]
    pub member: Account<'info, Member>,
    
    #[account(mut)]
    pub user: Signer<'info>,
}

#[derive(Accounts)]
pub struct RegisterRelayNode<'info> {
    #[account(
        init,
        payer = operator,
        space = 8 + RelayNode::INIT_SPACE,
        seeds = [b"relay", operator.key().as_ref()],
        bump
    )]
    pub relay_node: Account<'info, RelayNode>,
    
    #[account(mut)]
    pub operator: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct CreateProposal<'info> {
    #[account(
        init,
        payer = proposer,
        space = 8 + Proposal::INIT_SPACE,
        seeds = [b"proposal", dao_state.proposal_count.to_le_bytes().as_ref()],
        bump
    )]
    pub proposal: Account<'info, Proposal>,
    
    #[account(mut)]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(mut)]
    pub proposer: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct VoteOnProposal<'info> {
    #[account(mut)]
    pub proposal: Account<'info, Proposal>,
    
    #[account(
        init,
        payer = voter,
        space = 8 + VoteRecord::INIT_SPACE,
        seeds = [b"vote", proposal.key().as_ref(), voter.key().as_ref()],
        bump
    )]
    pub vote_record: Account<'info, VoteRecord>,
    
    #[account(mut)]
    pub voter: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ExecuteProposal<'info> {
    #[account(mut)]
    pub proposal: Account<'info, Proposal>,
    
    pub dao_state: Account<'info, DAOState>,
    
    pub executor: Signer<'info>,
}

#[derive(Accounts)]
pub struct SendMessage<'info> {
    #[account(mut)]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(
        init,
        payer = sender,
        space = 8 + MessageRecord::INIT_SPACE,
    )]
    pub message_record: Account<'info, MessageRecord>,
    
    #[account(mut)]
    pub sender: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateRelayPerformance<'info> {
    #[account(
        mut,
        seeds = [b"relay", operator.key().as_ref()],
        bump,
        has_one = operator
    )]
    pub relay_node: Account<'info, RelayNode>,
    
    pub operator: Signer<'info>,
}

#[derive(Accounts)]
pub struct RouteMessage<'info> {
    #[account(mut)]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(
        init,
        payer = sender,
        space = 8 + MessageRecord::INIT_SPACE,
    )]
    pub message_record: Account<'info, MessageRecord>,
    
    #[account(mut)]
    pub sender: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ConfirmDelivery<'info> {
    #[account(mut)]
    pub message_record: Account<'info, MessageRecord>,
    
    #[account(
        mut,
        seeds = [b"relay", relay_operator.key().as_ref()],
        bump
    )]
    pub relay_node: Account<'info, RelayNode>,
    
    pub relay_operator: Signer<'info>,
}

#[derive(Accounts)]
pub struct SlashRelayNode<'info> {
    #[account(mut)]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(
        mut,
        seeds = [b"relay", relay_operator.key().as_ref()],
        bump
    )]
    pub relay_node: Account<'info, RelayNode>,
    
    /// The relay operator being slashed
    pub relay_operator: AccountInfo<'info>,
    
    /// Authority that can perform slashing (DAO governance)
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct ClaimRelayRewards<'info> {
    #[account(mut)]
    pub dao_state: Account<'info, DAOState>,
    
    #[account(
        mut,
        seeds = [b"relay", operator.key().as_ref()],
        bump,
        has_one = operator
    )]
    pub relay_node: Account<'info, RelayNode>,
    
    #[account(mut)]
    pub operator: Signer<'info>,
}

#[account]
#[derive(InitSpace)]
pub struct DAOState {
    pub authority: Pubkey,
    pub governance_token_mint: Pubkey,
    pub voting_threshold: u64,
    pub member_count: u64,
    pub message_fee: u64,
    pub relay_rewards: u64,
    pub proposal_count: u64,
    pub treasury_balance: u64,
}

#[account]
#[derive(InitSpace)]
pub struct Proposal {
    pub id: u64,
    pub proposer: Pubkey,
    #[max_len(64)]
    pub title: String,
    #[max_len(512)]
    pub description: String,
    pub proposal_type: ProposalType,
    pub votes_for: u64,
    pub votes_against: u64,
    pub created_at: i64,
    pub voting_ends_at: i64,
    pub executed: bool,
    pub cancelled: bool,
}

#[account]
#[derive(InitSpace)]
pub struct VoteRecord {
    pub voter: Pubkey,
    pub proposal_id: u64,
    pub vote: bool, // true = for, false = against
    pub voting_power: u64,
    pub voted_at: i64,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace)]
pub enum ProposalType {
    UpdateMessageFee,
    UpdateRelayRewards,
    AddRelayNode,
    RemoveRelayNode,
}

#[account]
#[derive(InitSpace)]
pub struct Member {
    pub wallet: Pubkey,
    #[max_len(32)]
    pub nickname: String,
    pub noise_public_key: [u8; 32],
    pub reputation: u64,
    pub joined_at: i64,
    pub is_active: bool,
}

#[account]
#[derive(InitSpace)]
pub struct RelayNode {
    pub operator: Pubkey,
    #[max_len(128)]
    pub endpoint: String,
    pub stake: u64,
    pub performance: u64,
    pub is_active: bool,
    // Phase 5: Enhanced relay metrics
    pub messages_relayed: u64,
    pub successful_deliveries: u64,
    pub total_uptime_checks: u64,
    pub successful_uptime_checks: u64,
    pub average_latency: u64,
    pub last_heartbeat: i64,
    pub last_reward_claim: i64,
    pub total_rewards_earned: u64,
}

#[account]
#[derive(InitSpace)]
pub struct MessageRecord {
    pub sender: Pubkey,
    pub recipient: Pubkey,
    pub content_hash: [u8; 32], // Hash of encrypted content
    pub timestamp: i64,
    pub fee_paid: u64,
    // Phase 5: Enhanced message routing
    #[max_len(5)]
    pub relay_path: Vec<Pubkey>, // Path through relay nodes
    pub delivery_status: DeliveryStatus,
    pub delivered_at: Option<i64>,
    pub retry_count: u8,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace, PartialEq)]
pub enum DeliveryStatus {
    Pending,
    Delivered,
    Failed,
    Retrying,
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, InitSpace, Debug)]
pub enum SlashReason {
    Downtime,
    MaliciousBehavior,
    PoorPerformance,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Nickname is too long (max 32 characters)")]
    NicknameTooLong,
    #[msg("Endpoint URL is too long (max 128 characters)")]
    EndpointTooLong,
    #[msg("Insufficient stake amount (minimum 1 SOL)")]
    InsufficientStake,
    #[msg("Unauthorized member access")]
    UnauthorizedMember,
    #[msg("Proposal title is too long (max 64 characters)")]
    TitleTooLong,
    #[msg("Proposal description is too long (max 512 characters)")]
    DescriptionTooLong,
    #[msg("Voting period has ended")]
    VotingPeriodEnded,
    #[msg("Proposal has already been executed")]
    ProposalAlreadyExecuted,
    #[msg("Proposal has been cancelled")]
    ProposalCancelled,
    #[msg("Insufficient votes to execute proposal")]
    InsufficientVotes,
    #[msg("Proposal was rejected by voters")]
    ProposalRejected,
    #[msg("Voting period is still active")]
    VotingPeriodActive,
    #[msg("Invalid message hash")]
    InvalidMessageHash,
    #[msg("Message already delivered")]
    MessageAlreadyDelivered,
    #[msg("Reward claim too early (24 hour cooldown)")]
    RewardClaimTooEarly,
    #[msg("Insufficient treasury funds")]
    InsufficientTreasuryFunds,
}
