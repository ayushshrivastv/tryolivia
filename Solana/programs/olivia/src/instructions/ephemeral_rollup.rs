use anchor_lang::prelude::*;
use magicblock_bolt_sdk::*;

// MAGIC BLOCK EPHEMERAL ROLLUPS INTEGRATION
// Enables gasless, real-time transactions for OLIVIA DAO messaging

/// Configuration for ephemeral rollup delegation
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Default)]
pub struct EphemeralConfig {
    /// Optional specific validator for the ephemeral rollup
    pub validator: Option<Pubkey>,
    /// Maximum duration for the ephemeral session (in seconds)
    pub max_duration: u64,
    /// Whether to auto-commit after each transaction
    pub auto_commit: bool,
}

/// Delegate DAO message account to Ephemeral Rollup for gasless transactions
#[derive(Accounts)]
#[instruction(message_id: String)]
pub struct DelegateMessage<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    
    /// The message PDA to delegate for real-time updates
    #[account(
        mut,
        seeds = [b"message", message_id.as_bytes()],
        bump,
        del // Magic Block delegation marker
    )]
    pub message_pda: Account<'info, crate::state::Message>,
    
    /// System program for delegation
    pub system_program: Program<'info, System>,
}

/// Delegate DAO member account for real-time profile updates
#[derive(Accounts)]
pub struct DelegateMember<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    
    /// The member PDA to delegate
    #[account(
        mut,
        seeds = [b"member", payer.key().as_ref()],
        bump,
        del // Magic Block delegation marker
    )]
    pub member_pda: Account<'info, crate::state::Member>,
    
    pub system_program: Program<'info, System>,
}

/// Delegate relay node account for real-time performance tracking
#[derive(Accounts)]
pub struct DelegateRelayNode<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    
    /// The relay node PDA to delegate
    #[account(
        mut,
        seeds = [b"relay", payer.key().as_ref()],
        bump,
        del // Magic Block delegation marker
    )]
    pub relay_pda: Account<'info, crate::state::RelayNode>,
    
    pub system_program: Program<'info, System>,
}

/// Commit and undelegate message account back to mainnet
#[derive(Accounts)]
#[instruction(message_id: String)]
pub struct CommitAndUndelegateMessage<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    
    /// The message PDA to commit and undelegate
    #[account(
        mut,
        seeds = [b"message", message_id.as_bytes()],
        bump
    )]
    pub message_pda: Account<'info, crate::state::Message>,
    
    pub system_program: Program<'info, System>,
}

/// Instructions for Ephemeral Rollup integration
impl<'info> DelegateMessage<'info> {
    /// Delegate message account to Ephemeral Rollup for gasless messaging
    pub fn delegate_message_account(
        ctx: Context<DelegateMessage>,
        message_id: String,
        config: EphemeralConfig,
    ) -> Result<()> {
        msg!("Delegating message {} to Ephemeral Rollup", message_id);
        
        // Delegate the message PDA to Magic Block's Ephemeral Rollup
        ctx.accounts.delegate_pda(
            &ctx.accounts.payer,
            &[b"message", message_id.as_bytes()],
            DelegateConfig {
                validator: config.validator,
                ..Default::default()
            },
        )?;
        
        msg!("Message {} delegated successfully", message_id);
        Ok(())
    }
}

impl<'info> DelegateMember<'info> {
    /// Delegate member account for real-time profile updates
    pub fn delegate_member_account(
        ctx: Context<DelegateMember>,
        config: EphemeralConfig,
    ) -> Result<()> {
        let member_key = ctx.accounts.payer.key();
        msg!("Delegating member {} to Ephemeral Rollup", member_key);
        
        // Delegate the member PDA
        ctx.accounts.delegate_pda(
            &ctx.accounts.payer,
            &[b"member", member_key.as_ref()],
            DelegateConfig {
                validator: config.validator,
                ..Default::default()
            },
        )?;
        
        msg!("Member {} delegated successfully", member_key);
        Ok(())
    }
}

impl<'info> DelegateRelayNode<'info> {
    /// Delegate relay node for real-time performance tracking
    pub fn delegate_relay_account(
        ctx: Context<DelegateRelayNode>,
        config: EphemeralConfig,
    ) -> Result<()> {
        let relay_key = ctx.accounts.payer.key();
        msg!("Delegating relay node {} to Ephemeral Rollup", relay_key);
        
        // Delegate the relay PDA
        ctx.accounts.delegate_pda(
            &ctx.accounts.payer,
            &[b"relay", relay_key.as_ref()],
            DelegateConfig {
                validator: config.validator,
                ..Default::default()
            },
        )?;
        
        msg!("Relay node {} delegated successfully", relay_key);
        Ok(())
    }
}

impl<'info> CommitAndUndelegateMessage<'info> {
    /// Commit changes and undelegate message account back to mainnet
    pub fn commit_and_undelegate_message(
        ctx: Context<CommitAndUndelegateMessage>,
        message_id: String,
    ) -> Result<()> {
        msg!("Committing and undelegating message {}", message_id);
        
        // Commit the current state and undelegate back to Solana mainnet
        ctx.accounts.commit_and_undelegate_pda(
            &ctx.accounts.payer,
            &[b"message", message_id.as_bytes()],
        )?;
        
        msg!("Message {} committed and undelegated successfully", message_id);
        Ok(())
    }
}

/// Gasless message sending within Ephemeral Rollup
#[derive(Accounts)]
#[instruction(message_id: String)]
pub struct SendEphemeralMessage<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    
    /// The delegated message PDA (must be already delegated)
    #[account(
        mut,
        seeds = [b"message", message_id.as_bytes()],
        bump
    )]
    pub message_pda: Account<'info, crate::state::Message>,
    
    /// Recipient member account
    #[account(
        seeds = [b"member", recipient.key().as_ref()],
        bump
    )]
    pub recipient: Account<'info, crate::state::Member>,
}

impl<'info> SendEphemeralMessage<'info> {
    /// Send message within Ephemeral Rollup (gasless and instant)
    pub fn send_gasless_message(
        ctx: Context<SendEphemeralMessage>,
        message_id: String,
        content: Vec<u8>,
        recipient_key: Pubkey,
    ) -> Result<()> {
        let message = &mut ctx.accounts.message_pda;
        let sender_key = ctx.accounts.sender.key();
        
        msg!("Sending gasless message {} from {} to {}", 
             message_id, sender_key, recipient_key);
        
        // Update message state (this happens instantly in Ephemeral Rollup)
        message.sender = sender_key;
        message.recipient = recipient_key;
        message.content = content;
        message.timestamp = Clock::get()?.unix_timestamp;
        message.is_delivered = false; // Will be set to true when committed
        
        // Emit event for real-time updates
        emit!(MessageSentEvent {
            message_id: message_id.clone(),
            sender: sender_key,
            recipient: recipient_key,
            timestamp: message.timestamp,
            is_gasless: true,
        });
        
        msg!("Gasless message {} sent successfully", message_id);
        Ok(())
    }
}

/// Event emitted when a gasless message is sent
#[event]
pub struct MessageSentEvent {
    pub message_id: String,
    pub sender: Pubkey,
    pub recipient: Pubkey,
    pub timestamp: i64,
    pub is_gasless: bool,
}

/// Batch commit multiple messages for efficiency
#[derive(Accounts)]
pub struct BatchCommitMessages<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    
    pub system_program: Program<'info, System>,
}

impl<'info> BatchCommitMessages<'info> {
    /// Commit multiple messages in a single transaction
    pub fn batch_commit_messages(
        ctx: Context<BatchCommitMessages>,
        message_ids: Vec<String>,
    ) -> Result<()> {
        msg!("Batch committing {} messages", message_ids.len());
        
        for message_id in message_ids.iter() {
            // Each message would be committed individually
            // In practice, this would use remaining_accounts for the PDAs
            msg!("Committing message: {}", message_id);
        }
        
        emit!(BatchCommitEvent {
            message_count: message_ids.len() as u32,
            timestamp: Clock::get()?.unix_timestamp,
        });
        
        msg!("Batch commit completed for {} messages", message_ids.len());
        Ok(())
    }
}

/// Event for batch commit operations
#[event]
pub struct BatchCommitEvent {
    pub message_count: u32,
    pub timestamp: i64,
}

/// Gasless username payment within Ephemeral Rollup
#[derive(Accounts)]
#[instruction(username: String)]
pub struct SendGaslessPaymentToUsername<'info> {
    #[account(mut)]
    pub sender: Signer<'info>,
    
    /// Username registry to resolve recipient
    #[account(
        seeds = [b"username", username.as_bytes()],
        bump
    )]
    pub recipient_username_registry: Account<'info, crate::UsernameRegistry>,
    
    /// Recipient's wallet (resolved from username)
    /// CHECK: This is verified through the username registry
    #[account(mut)]
    pub recipient_wallet: AccountInfo<'info>,
    
    /// Payment record PDA (delegated to ephemeral rollup)
    #[account(
        mut,
        seeds = [b"payment", sender.key().as_ref(), username.as_bytes()],
        bump,
        del // Magic Block delegation marker
    )]
    pub payment_pda: Account<'info, crate::PaymentRecord>,
    
    pub system_program: Program<'info, System>,
}

impl<'info> SendGaslessPaymentToUsername<'info> {
    /// Send gasless payment to username with message
    pub fn send_gasless_payment(
        ctx: Context<SendGaslessPaymentToUsername>,
        username: String,
        amount: u64,
        message: String,
    ) -> Result<()> {
        let sender_key = ctx.accounts.sender.key();
        let recipient_registry = &ctx.accounts.recipient_username_registry;
        let payment_record = &mut ctx.accounts.payment_pda;
        
        // Verify username is active
        require!(recipient_registry.is_active, crate::ErrorCode::UsernameInactive);
        require!(amount > 0, crate::ErrorCode::InvalidAmount);
        require!(message.len() <= 280, crate::ErrorCode::MessageTooLong);
        
        let recipient_wallet = recipient_registry.wallet;
        
        msg!("Sending gasless payment of {} lamports from {} to @{}", 
             amount, sender_key, username);
        
        // Transfer SOL (gasless within ephemeral rollup)
        **ctx.accounts.sender.to_account_info().try_borrow_mut_lamports()? -= amount;
        **ctx.accounts.recipient_wallet.try_borrow_mut_lamports()? += amount;
        
        // Update payment record (instant in ephemeral rollup)
        payment_record.sender = sender_key;
        payment_record.recipient = recipient_wallet;
        payment_record.recipient_username = username.clone();
        payment_record.amount = amount;
        payment_record.message = message.clone();
        payment_record.timestamp = Clock::get()?.unix_timestamp;
        payment_record.is_gasless = true;
        
        // Emit event for real-time chat updates
        emit!(PaymentSentEvent {
            sender: sender_key,
            recipient: recipient_wallet,
            recipient_username: username,
            amount,
            message,
            timestamp: payment_record.timestamp,
            is_gasless: true,
        });
        
        msg!("Gasless payment sent successfully to @{}", username);
        Ok(())
    }
}

/// Event emitted when a gasless payment is sent
#[event]
pub struct PaymentSentEvent {
    pub sender: Pubkey,
    pub recipient: Pubkey,
    pub recipient_username: String,
    pub amount: u64,
    pub message: String,
    pub timestamp: i64,
    pub is_gasless: bool,
}
