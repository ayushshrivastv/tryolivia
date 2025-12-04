/*
 * Olivia: Decentralised Permissionless Predicition Market 
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

use anchor_lang::prelude::*;
use arcium_anchor::prelude::*;

const COMP_DEF_OFFSET_INITIALIZE_MARKET: u32 = comp_def_offset("initialize_market");
const COMP_DEF_OFFSET_PLACE_BET: u32 = comp_def_offset("place_bet");
const COMP_DEF_OFFSET_DISTRIBUTE_REWARDS: u32 = comp_def_offset("distribute_rewards");

declare_id!("EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA");

#[account]
pub struct SignerAccount {
    pub bump: u8,
}

// Helper function for callback validation
pub fn validate_callback_ixs(_instructions_sysvar: &AccountInfo, _program_id: &Pubkey) -> Result<()> {
    Ok(())
}

#[program]
pub mod prediction_market {
    use super::*;

    pub fn init_initialize_market_comp_def(
        ctx: Context<InitInitializeMarketCompDef>,
    ) -> Result<()> {
        init_comp_def(ctx.accounts, true, 0, None, None)?;
        Ok(())
    }

    pub fn init_place_bet_comp_def(ctx: Context<InitPlaceBetCompDef>) -> Result<()> {
        init_comp_def(ctx.accounts, true, 0, None, None)?;
        Ok(())
    }

    pub fn init_distribute_rewards_comp_def(
        ctx: Context<InitDistributeRewardsCompDef>,
    ) -> Result<()> {
        init_comp_def(ctx.accounts, true, 0, None, None)?;
        Ok(())
    }

    pub fn create_market(
        ctx: Context<CreateMarket>,
        computation_offset: u64,
        market_id: u64,
        question: String,
        description: String,
        resolution_deadline: i64,
        min_stake_amount: u64,
        nonce: u128,
    ) -> Result<()> {
        ctx.accounts.sign_pda_account.bump = ctx.bumps.sign_pda_account;

        require!(
            resolution_deadline > Clock::get()?.unix_timestamp,
            ErrorCode::InvalidResolutionDeadline
        );
        require!(
            !question.is_empty() && question.len() <= 200,
            ErrorCode::InvalidQuestion
        );

        let args = vec![Argument::PlaintextU128(nonce)];

        queue_computation(
            ctx.accounts,
            computation_offset,
            args,
            None,
            vec![InitializeMarketCallback::callback_ix(&[])],
        )?;

        let market = &mut ctx.accounts.market;
        market.bump = ctx.bumps.market;
        market.market_id = market_id;
        market.creator = ctx.accounts.creator.key();
        market.question = question.clone();
        market.description = description;
        market.resolution_deadline = resolution_deadline;
        market.min_stake_amount = min_stake_amount;
        market.state = MarketState::Active;
        market.yes_pool = 0;
        market.no_pool = 0;
        market.total_bets = 0;
        market.resolution_result = None;
        market.encrypted_vote_tally = [[0; 32]; 2];
        market.nonce = 0;

        emit!(MarketCreatedEvent {
            market_id,
            creator: ctx.accounts.creator.key(),
            question,
            resolution_deadline,
            min_stake_amount,
        });

        Ok(())
    }

    #[arcium_callback(encrypted_ix = "initialize_market")]
    pub fn initialize_market_callback(
        ctx: Context<InitializeMarketCallback>,
        output: ComputationOutputs<InitializeMarketOutput>,
    ) -> Result<()> {
        let o = match output {
            ComputationOutputs::Success(InitializeMarketOutput { field_0 }) => field_0,
            _ => return Err(ErrorCode::AbortedComputation.into()),
        };

        ctx.accounts.market.encrypted_vote_tally = o.ciphertexts;
        ctx.accounts.market.nonce = o.nonce;

        Ok(())
    }

    pub fn place_bet(
        ctx: Context<PlaceBet>,
        computation_offset: u64,
        market_id: u64,
        amount: u64,
        encrypted_prediction: [u8; 32],
        prediction_pubkey: [u8; 32],
        prediction_nonce: u128,
    ) -> Result<()> {
        ctx.accounts.sign_pda_account.bump = ctx.bumps.sign_pda_account;

        let market = &mut ctx.accounts.market;

        require!(
            market.state == MarketState::Active,
            ErrorCode::MarketNotActive
        );
        require!(
            Clock::get()?.unix_timestamp < market.resolution_deadline,
            ErrorCode::DeadlinePassed
        );
        require!(amount > 0, ErrorCode::InvalidBetAmount);

        // Transfer SOL from bettor to market vault
        let bettor = &ctx.accounts.bettor;
        let market_vault = &ctx.accounts.market_vault;

        **bettor.to_account_info().try_borrow_mut_lamports()? -= amount;
        **market_vault.to_account_info().try_borrow_mut_lamports()? += amount;

        market.total_bets += amount;

        let args = vec![
            Argument::ArcisPubkey(prediction_pubkey),
            Argument::PlaintextU128(prediction_nonce),
            Argument::EncryptedBool(encrypted_prediction),
            Argument::PlaintextU64(amount),
        ];

        queue_computation(
            ctx.accounts,
            computation_offset,
            args,
            None,
            vec![PlaceBetCallback::callback_ix(&[])],
        )?;

        let bet = &mut ctx.accounts.bet;
        bet.bump = ctx.bumps.bet;
        bet.market_id = market_id;
        bet.bettor = ctx.accounts.bettor.key();
        bet.amount = amount;
        bet.encrypted_prediction = encrypted_prediction;
        bet.prediction_pubkey = prediction_pubkey;
        bet.prediction_nonce = prediction_nonce;
        bet.timestamp = Clock::get()?.unix_timestamp;
        bet.resolved = false;
        bet.payout_amount = 0;
        bet.withdrawn = false;

        emit!(BetPlacedEvent {
            market_id,
            bettor: ctx.accounts.bettor.key(),
            amount,
            timestamp: bet.timestamp,
        });

        Ok(())
    }

    #[arcium_callback(encrypted_ix = "place_bet")]
    pub fn place_bet_callback(
        ctx: Context<PlaceBetCallback>,
        output: ComputationOutputs<PlaceBetOutput>,
    ) -> Result<()> {
        let pool_update = match output {
            ComputationOutputs::Success(PlaceBetOutput { field_0 }) => field_0,
            _ => return Err(ErrorCode::AbortedComputation.into()),
        };

        let market = &mut ctx.accounts.market;

        // Update pools with deltas from encrypted computation
        // field_0 = yes_pool_delta, field_1 = no_pool_delta from PoolUpdate struct
        market.yes_pool += pool_update.field_0;
        market.no_pool += pool_update.field_1;

        Ok(())
    }

    pub fn resolve_market(
        ctx: Context<ResolveMarket>,
        _market_id: u64,
        outcome: bool,
    ) -> Result<()> {
        let market = &mut ctx.accounts.market;

        require!(
            market.state == MarketState::Active,
            ErrorCode::MarketNotActive
        );
        require!(
            Clock::get()?.unix_timestamp >= market.resolution_deadline,
            ErrorCode::ResolutionNotReady
        );

        market.resolution_result = Some(outcome);
        market.state = MarketState::Resolved;

        emit!(MarketResolvedEvent {
            market_id: market.market_id,
            outcome,
        });

        Ok(())
    }

    pub fn distribute_rewards(
        ctx: Context<DistributeRewards>,
        computation_offset: u64,
        _market_id: u64,
    ) -> Result<()> {
        ctx.accounts.sign_pda_account.bump = ctx.bumps.sign_pda_account;

        let market = &ctx.accounts.market;

        require!(
            market.state == MarketState::Resolved,
            ErrorCode::MarketNotResolved
        );
        require!(
            market.resolution_result.is_some(),
            ErrorCode::NoResolutionResult
        );

        let bet = &mut ctx.accounts.bet;
        require!(!bet.resolved, ErrorCode::BetAlreadyResolved);

        let args = vec![
            Argument::ArcisPubkey(bet.prediction_pubkey),
            Argument::PlaintextU128(bet.prediction_nonce),
            Argument::EncryptedBool(bet.encrypted_prediction),
            Argument::PlaintextBool(market.resolution_result.unwrap()),
            Argument::PlaintextU64(bet.amount),
            Argument::PlaintextU64(market.yes_pool),
            Argument::PlaintextU64(market.no_pool),
        ];

        queue_computation(
            ctx.accounts,
            computation_offset,
            args,
            None,
            vec![DistributeRewardsCallback::callback_ix(&[])],
        )?;

        Ok(())
    }

    #[arcium_callback(encrypted_ix = "distribute_rewards")]
    pub fn distribute_rewards_callback(
        ctx: Context<DistributeRewardsCallback>,
        output: ComputationOutputs<DistributeRewardsOutput>,
    ) -> Result<()> {
        let result = match output {
            ComputationOutputs::Success(DistributeRewardsOutput { field_0 }) => field_0,
            _ => return Err(ErrorCode::AbortedComputation.into()),
        };

        let bet = &mut ctx.accounts.bet;
        bet.resolved = true;
        bet.payout_amount = result.field_0;

        emit!(RewardsDistributedEvent {
            market_id: bet.market_id,
            bettor: bet.bettor,
            bet_amount: bet.amount,
            payout_amount: result.field_0,
            won: result.field_1,
        });

        Ok(())
    }

    pub fn withdraw_payout(
        ctx: Context<WithdrawPayout>,
        _market_id: u64,
    ) -> Result<()> {
        let bet = &mut ctx.accounts.bet;

        require!(bet.resolved, ErrorCode::BetNotResolved);
        require!(!bet.withdrawn, ErrorCode::AlreadyWithdrawn);
        require!(bet.payout_amount > 0, ErrorCode::NoPayout);

        // Transfer SOL from market vault to bettor
        let market_vault = &mut ctx.accounts.market_vault;
        let bettor = &mut ctx.accounts.bettor;

        let market_id_bytes = ctx.accounts.market.market_id.to_le_bytes();
        let _seeds = &[
            b"vault",
            market_id_bytes.as_ref(),
            &[ctx.bumps.market_vault],
        ];

        **market_vault.to_account_info().try_borrow_mut_lamports()? -= bet.payout_amount;
        **bettor.to_account_info().try_borrow_mut_lamports()? += bet.payout_amount;

        bet.withdrawn = true;

        emit!(PayoutWithdrawnEvent {
            market_id: bet.market_id,
            bettor: bet.bettor,
            payout_amount: bet.payout_amount,
        });

        Ok(())
    }
}

#[queue_computation_accounts("initialize_market", creator)]
#[derive(Accounts)]
#[instruction(computation_offset: u64, market_id: u64)]
pub struct CreateMarket<'info> {
    #[account(mut)]
    pub creator: Signer<'info>,
    #[account(
        init_if_needed,
        space = 9,
        payer = creator,
        seeds = [&SIGN_PDA_SEED],
        bump,
        address = derive_sign_pda!(),
    )]
    pub sign_pda_account: Account<'info, SignerAccount>,
    #[account(
        address = derive_mxe_pda!()
    )]
    pub mxe_account: Account<'info, MXEAccount>,
    #[account(
        mut,
        address = derive_mempool_pda!()
    )]
    /// CHECK: mempool_account, checked by the arcium program.
    pub mempool_account: UncheckedAccount<'info>,
    #[account(
        mut,
        address = derive_execpool_pda!()
    )]
    /// CHECK: executing_pool, checked by the arcium program.
    pub executing_pool: UncheckedAccount<'info>,
    #[account(
        mut,
        address = derive_comp_pda!(computation_offset)
    )]
    /// CHECK: computation_account, checked by the arcium program.
    pub computation_account: UncheckedAccount<'info>,
    #[account(
        address = derive_comp_def_pda!(COMP_DEF_OFFSET_INITIALIZE_MARKET)
    )]
    pub comp_def_account: Account<'info, ComputationDefinitionAccount>,
    #[account(
        mut,
        address = derive_cluster_pda!(mxe_account)
    )]
    pub cluster_account: Account<'info, Cluster>,
    #[account(
        mut,
        address = ARCIUM_FEE_POOL_ACCOUNT_ADDRESS,
    )]
    pub pool_account: Account<'info, FeePool>,
    #[account(
        address = ARCIUM_CLOCK_ACCOUNT_ADDRESS
    )]
    pub clock_account: Account<'info, ClockAccount>,
    pub system_program: Program<'info, System>,
    pub arcium_program: Program<'info, Arcium>,
    #[account(
        init,
        payer = creator,
        space = 8 + PredictionMarket::INIT_SPACE,
        seeds = [b"market", market_id.to_le_bytes().as_ref()],
        bump
    )]
    pub market: Account<'info, PredictionMarket>,
}

#[callback_accounts("initialize_market")]
#[derive(Accounts)]
pub struct InitializeMarketCallback<'info> {
    pub arcium_program: Program<'info, Arcium>,
    #[account(
        address = derive_comp_def_pda!(COMP_DEF_OFFSET_INITIALIZE_MARKET)
    )]
    pub comp_def_account: Account<'info, ComputationDefinitionAccount>,
    #[account(address = ::anchor_lang::solana_program::sysvar::instructions::ID)]
    /// CHECK: instructions_sysvar, checked by the account constraint
    pub instructions_sysvar: AccountInfo<'info>,
    #[account(mut)]
    pub market: Account<'info, PredictionMarket>,
}

#[queue_computation_accounts("place_bet", bettor)]
#[derive(Accounts)]
#[instruction(computation_offset: u64, market_id: u64)]
pub struct PlaceBet<'info> {
    #[account(mut)]
    pub bettor: Signer<'info>,
    #[account(
        init_if_needed,
        space = 9,
        payer = bettor,
        seeds = [&SIGN_PDA_SEED],
        bump,
        address = derive_sign_pda!(),
    )]
    pub sign_pda_account: Account<'info, SignerAccount>,
    #[account(
        address = derive_mxe_pda!()
    )]
    pub mxe_account: Account<'info, MXEAccount>,
    #[account(
        mut,
        address = derive_mempool_pda!()
    )]
    /// CHECK: mempool_account, checked by the arcium program.
    pub mempool_account: UncheckedAccount<'info>,
    #[account(
        mut,
        address = derive_execpool_pda!()
    )]
    /// CHECK: executing_pool, checked by the arcium program.
    pub executing_pool: UncheckedAccount<'info>,
    #[account(
        mut,
        address = derive_comp_pda!(computation_offset)
    )]
    /// CHECK: computation_account, checked by the arcium program.
    pub computation_account: UncheckedAccount<'info>,
    #[account(
        address = derive_comp_def_pda!(COMP_DEF_OFFSET_PLACE_BET)
    )]
    pub comp_def_account: Account<'info, ComputationDefinitionAccount>,
    #[account(
        mut,
        address = derive_cluster_pda!(mxe_account)
    )]
    pub cluster_account: Account<'info, Cluster>,
    #[account(
        mut,
        address = ARCIUM_FEE_POOL_ACCOUNT_ADDRESS,
    )]
    pub pool_account: Account<'info, FeePool>,
    #[account(
        address = ARCIUM_CLOCK_ACCOUNT_ADDRESS
    )]
    pub clock_account: Account<'info, ClockAccount>,
    pub system_program: Program<'info, System>,
    pub arcium_program: Program<'info, Arcium>,
    #[account(
        mut,
        seeds = [b"market", market_id.to_le_bytes().as_ref()],
        bump = market.bump
    )]
    pub market: Account<'info, PredictionMarket>,
    #[account(
        mut,
        seeds = [b"vault", market_id.to_le_bytes().as_ref()],
        bump
    )]
    /// CHECK: Market vault PDA for holding bet funds
    pub market_vault: SystemAccount<'info>,
    #[account(
        init,
        payer = bettor,
        space = 8 + Bet::INIT_SPACE,
        seeds = [b"bet", market_id.to_le_bytes().as_ref(), bettor.key().as_ref()],
        bump
    )]
    pub bet: Account<'info, Bet>,
}

#[callback_accounts("place_bet")]
#[derive(Accounts)]
pub struct PlaceBetCallback<'info> {
    pub arcium_program: Program<'info, Arcium>,
    #[account(
        address = derive_comp_def_pda!(COMP_DEF_OFFSET_PLACE_BET)
    )]
    pub comp_def_account: Account<'info, ComputationDefinitionAccount>,
    #[account(address = ::anchor_lang::solana_program::sysvar::instructions::ID)]
    /// CHECK: instructions_sysvar, checked by the account constraint
    pub instructions_sysvar: AccountInfo<'info>,
    #[account(mut)]
    pub market: Account<'info, PredictionMarket>,
}

#[derive(Accounts)]
#[instruction(market_id: u64)]
pub struct ResolveMarket<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"market", market_id.to_le_bytes().as_ref()],
        bump = market.bump,
        constraint = market.creator == authority.key() @ ErrorCode::UnauthorizedAccess
    )]
    pub market: Account<'info, PredictionMarket>,
}

#[derive(Accounts)]
#[instruction(market_id: u64)]
pub struct WithdrawPayout<'info> {
    #[account(mut)]
    pub bettor: Signer<'info>,
    #[account(
        seeds = [b"market", market_id.to_le_bytes().as_ref()],
        bump = market.bump
    )]
    pub market: Account<'info, PredictionMarket>,
    #[account(
        mut,
        seeds = [b"vault", market_id.to_le_bytes().as_ref()],
        bump
    )]
    /// CHECK: Market vault PDA for holding bet funds
    pub market_vault: SystemAccount<'info>,
    #[account(
        mut,
        seeds = [b"bet", market_id.to_le_bytes().as_ref(), bettor.key().as_ref()],
        bump = bet.bump,
        constraint = bet.bettor == bettor.key() @ ErrorCode::UnauthorizedAccess
    )]
    pub bet: Account<'info, Bet>,
    pub system_program: Program<'info, System>,
}

#[queue_computation_accounts("distribute_rewards", bettor)]
#[derive(Accounts)]
#[instruction(computation_offset: u64, market_id: u64)]
pub struct DistributeRewards<'info> {
    #[account(mut)]
    pub bettor: Signer<'info>,
    #[account(
        init_if_needed,
        space = 9,
        payer = bettor,
        seeds = [&SIGN_PDA_SEED],
        bump,
        address = derive_sign_pda!(),
    )]
    pub sign_pda_account: Account<'info, SignerAccount>,
    #[account(
        address = derive_mxe_pda!()
    )]
    pub mxe_account: Account<'info, MXEAccount>,
    #[account(
        mut,
        address = derive_mempool_pda!()
    )]
    /// CHECK: mempool_account, checked by the arcium program.
    pub mempool_account: UncheckedAccount<'info>,
    #[account(
        mut,
        address = derive_execpool_pda!()
    )]
    /// CHECK: executing_pool, checked by the arcium program.
    pub executing_pool: UncheckedAccount<'info>,
    #[account(
        mut,
        address = derive_comp_pda!(computation_offset)
    )]
    /// CHECK: computation_account, checked by the arcium program.
    pub computation_account: UncheckedAccount<'info>,
    #[account(
        address = derive_comp_def_pda!(COMP_DEF_OFFSET_DISTRIBUTE_REWARDS)
    )]
    pub comp_def_account: Account<'info, ComputationDefinitionAccount>,
    #[account(
        mut,
        address = derive_cluster_pda!(mxe_account)
    )]
    pub cluster_account: Account<'info, Cluster>,
    #[account(
        mut,
        address = ARCIUM_FEE_POOL_ACCOUNT_ADDRESS,
    )]
    pub pool_account: Account<'info, FeePool>,
    #[account(
        address = ARCIUM_CLOCK_ACCOUNT_ADDRESS
    )]
    pub clock_account: Account<'info, ClockAccount>,
    pub system_program: Program<'info, System>,
    pub arcium_program: Program<'info, Arcium>,
    #[account(
        seeds = [b"market", market_id.to_le_bytes().as_ref()],
        bump = market.bump
    )]
    pub market: Account<'info, PredictionMarket>,
    #[account(
        mut,
        seeds = [b"bet", market_id.to_le_bytes().as_ref(), bettor.key().as_ref()],
        bump = bet.bump
    )]
    pub bet: Account<'info, Bet>,
}

#[callback_accounts("distribute_rewards")]
#[derive(Accounts)]
pub struct DistributeRewardsCallback<'info> {
    pub arcium_program: Program<'info, Arcium>,
    #[account(
        address = derive_comp_def_pda!(COMP_DEF_OFFSET_DISTRIBUTE_REWARDS)
    )]
    pub comp_def_account: Account<'info, ComputationDefinitionAccount>,
    #[account(address = ::anchor_lang::solana_program::sysvar::instructions::ID)]
    /// CHECK: instructions_sysvar, checked by the account constraint
    pub instructions_sysvar: AccountInfo<'info>,
    #[account(mut)]
    pub bet: Account<'info, Bet>,
}

#[init_computation_definition_accounts("initialize_market", payer)]
#[derive(Accounts)]
pub struct InitInitializeMarketCompDef<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        mut,
        address = derive_mxe_pda!()
    )]
    pub mxe_account: Box<Account<'info, MXEAccount>>,
    #[account(mut)]
    /// CHECK: comp_def_account, checked by arcium program. Can't check it here as it's not initialized yet.
    pub comp_def_account: UncheckedAccount<'info>,
    pub arcium_program: Program<'info, Arcium>,
    pub system_program: Program<'info, System>,
}

#[init_computation_definition_accounts("place_bet", payer)]
#[derive(Accounts)]
pub struct InitPlaceBetCompDef<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        mut,
        address = derive_mxe_pda!()
    )]
    pub mxe_account: Box<Account<'info, MXEAccount>>,
    #[account(mut)]
    /// CHECK: comp_def_account, checked by arcium program. Can't check it here as it's not initialized yet.
    pub comp_def_account: UncheckedAccount<'info>,
    pub arcium_program: Program<'info, Arcium>,
    pub system_program: Program<'info, System>,
}

#[init_computation_definition_accounts("distribute_rewards", payer)]
#[derive(Accounts)]
pub struct InitDistributeRewardsCompDef<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        mut,
        address = derive_mxe_pda!()
    )]
    pub mxe_account: Box<Account<'info, MXEAccount>>,
    #[account(mut)]
    /// CHECK: comp_def_account, checked by arcium program. Can't check it here as it's not initialized yet.
    pub comp_def_account: UncheckedAccount<'info>,
    pub arcium_program: Program<'info, Arcium>,
    pub system_program: Program<'info, System>,
}

#[account]
#[derive(InitSpace)]
pub struct PredictionMarket {
    pub bump: u8,

    pub market_id: u64,

    pub creator: Pubkey,

    #[max_len(200)]
    pub question: String,

    #[max_len(200)]
    pub description: String,

    pub resolution_deadline: i64,

    pub min_stake_amount: u64,

    pub state: MarketState,

    pub yes_pool: u64,

    pub no_pool: u64,

    pub total_bets: u64,

    pub resolution_result: Option<bool>,

    pub encrypted_vote_tally: [[u8; 32]; 2],

    pub nonce: u128,
}

#[account]
#[derive(InitSpace)]
pub struct Bet {
    pub bump: u8,

    pub market_id: u64,

    pub bettor: Pubkey,

    pub amount: u64,

    pub encrypted_prediction: [u8; 32],

    pub prediction_pubkey: [u8; 32],

    pub prediction_nonce: u128,

    pub timestamp: i64,

    pub resolved: bool,

    pub payout_amount: u64,

    pub withdrawn: bool,
}

#[repr(u8)]
#[derive(InitSpace, AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq, Debug)]
pub enum MarketState {
    Active = 0,

    Resolved = 1,
}

#[event]
pub struct MarketCreatedEvent {
    pub market_id: u64,
    pub creator: Pubkey,
    pub question: String,
    pub resolution_deadline: i64,
    pub min_stake_amount: u64,
}

#[event]
pub struct BetPlacedEvent {
    pub market_id: u64,
    pub bettor: Pubkey,
    pub amount: u64,
    pub timestamp: i64,
}

#[event]
pub struct MarketResolvedEvent {
    pub market_id: u64,
    pub outcome: bool,
}

#[event]
pub struct RewardsDistributedEvent {
    pub market_id: u64,
    pub bettor: Pubkey,
    pub bet_amount: u64,
    pub payout_amount: u64,
    pub won: bool,
}

#[event]
pub struct PayoutWithdrawnEvent {
    pub market_id: u64,
    pub bettor: Pubkey,
    pub payout_amount: u64,
}

#[error_code]
pub enum ErrorCode {
    #[msg("The computation was aborted")]
    AbortedComputation,
    #[msg("Cluster not set")]
    ClusterNotSet,
    #[msg("Market is not active")]
    MarketNotActive,
    #[msg("Deadline has passed")]
    DeadlinePassed,
    #[msg("Invalid bet amount")]
    InvalidBetAmount,
    #[msg("Invalid resolution deadline")]
    InvalidResolutionDeadline,
    #[msg("Invalid question")]
    InvalidQuestion,
    #[msg("Resolution not ready")]
    ResolutionNotReady,
    #[msg("Market is not resolved")]
    MarketNotResolved,
    #[msg("No resolution result")]
    NoResolutionResult,
    #[msg("Bet already resolved")]
    BetAlreadyResolved,
    #[msg("Unauthorized access")]
    UnauthorizedAccess,
    #[msg("Bet is not resolved yet")]
    BetNotResolved,
    #[msg("Payout already withdrawn")]
    AlreadyWithdrawn,
    #[msg("No payout available")]
    NoPayout,
}
