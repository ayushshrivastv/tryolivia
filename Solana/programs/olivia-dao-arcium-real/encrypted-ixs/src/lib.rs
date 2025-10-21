use arcis_imports::*;

#[encrypted]
mod circuits {
    use arcis_imports::*;

    // ============================================================================
    // Data Structures for Encrypted Computations
    // ============================================================================

    /// Tracks encrypted DAO statistics
    pub struct DAOStats {
        pub total_votes_cast: u64,
        pub total_proposals: u64,
        pub treasury_balance: u64,
        pub active_members: u64,
    }

    /// Represents encrypted vote statistics for a proposal
    pub struct VoteStats {
        pub votes_for: u64,
        pub votes_against: u64,
        pub total_voting_power: u64,
    }

    /// Represents a single encrypted vote
    pub struct UserVote {
        pub choice: bool,        // true = for, false = against
        pub voting_power: u64,   // Voting power of the voter
    }

    /// Encrypted relay performance metrics
    pub struct RelayMetrics {
        pub uptime_percentage: u64,
        pub average_latency: u64,
        pub messages_processed: u64,
        pub successful_deliveries: u64,
    }

    /// Reward allocation for a relay node
    pub struct RewardAllocation {
        pub relay_index: u32,
        pub reward_amount: u64,
    }

    /// User balance for membership verification
    pub struct UserBalance {
        pub balance: u64,
    }

    // ============================================================================
    // DAO Initialization
    // ============================================================================

    /// Initializes encrypted DAO statistics
    ///
    /// Creates initial encrypted counters for DAO operations including
    /// vote tracking, proposal management, and treasury operations.
    #[instruction]
    pub fn init_dao_stats(
        voting_threshold: u64,
        mxe: Mxe
    ) -> Enc<Mxe, DAOStats> {
        let dao_stats = DAOStats {
            total_votes_cast: 0,
            total_proposals: 0,
            treasury_balance: 0,
            active_members: 0,
        };
        mxe.from_arcis(dao_stats)
    }

    // ============================================================================
    // Anonymous Voting System
    // ============================================================================

    /// Processes an encrypted vote and updates proposal statistics
    ///
    /// Takes an individual encrypted vote and adds it to the running tallies
    /// without revealing the vote choice or voter identity. The vote statistics
    /// remain encrypted throughout the process.
    ///
    /// # Arguments
    /// * `vote_ctxt` - The encrypted vote to be counted
    /// * `vote_stats_ctxt` - Current encrypted vote tallies for the proposal
    ///
    /// # Returns
    /// Updated encrypted vote statistics with the new vote included
    #[instruction]
    pub fn vote_on_proposal(
        vote_ctxt: Enc<Shared, UserVote>,
        vote_stats_ctxt: Enc<Mxe, VoteStats>,
    ) -> Enc<Mxe, VoteStats> {
        let user_vote = vote_ctxt.to_arcis();
        let mut vote_stats = vote_stats_ctxt.to_arcis();

        // Update vote tallies based on encrypted vote choice
        if user_vote.choice {
            vote_stats.votes_for += user_vote.voting_power;
        } else {
            vote_stats.votes_against += user_vote.voting_power;
        }
        
        vote_stats.total_voting_power += user_vote.voting_power;

        vote_stats_ctxt.owner.from_arcis(vote_stats)
    }

    /// Tallies encrypted votes and reveals only the final result
    ///
    /// Processes all encrypted votes for a proposal and determines whether
    /// it passed or failed. Only the final decision is revealed, not the
    /// actual vote counts or individual choices.
    ///
    /// # Arguments
    /// * `vote_stats_ctxt` - Encrypted vote tallies to be evaluated
    /// * `voting_threshold` - Minimum voting power required for quorum
    ///
    /// # Returns
    /// * `true` if the proposal passed (more votes for than against + quorum met)
    /// * `false` if the proposal failed or didn't meet quorum
    #[instruction]
    pub fn tally_votes(
        vote_stats_ctxt: Enc<Mxe, VoteStats>,
        voting_threshold: u64,
    ) -> bool {
        let vote_stats = vote_stats_ctxt.to_arcis();
        
        // Check if quorum is met and proposal passed
        let quorum_met = vote_stats.total_voting_power >= voting_threshold;
        let majority_for = vote_stats.votes_for > vote_stats.votes_against;
        
        (quorum_met && majority_for).reveal()
    }

    // ============================================================================
    // Encrypted Relay Rewards System
    // ============================================================================

    /// Calculates encrypted relay rewards based on performance metrics
    ///
    /// Processes encrypted performance data for all relay nodes and calculates
    /// fair reward distribution without revealing individual performance metrics.
    /// Only the final reward allocations are revealed.
    ///
    /// # Arguments
    /// * `relay_metrics` - Vector of encrypted performance metrics for each relay
    /// * `total_reward_pool` - Total rewards available for distribution
    ///
    /// # Returns
    /// Vector of reward allocations for each relay node
    #[instruction]
    pub fn calculate_rewards(
        relay_metrics: Vec<Enc<Shared, RelayMetrics>>,
        total_reward_pool: u64,
    ) -> Vec<RewardAllocation> {
        let mut total_performance_score = 0u64;
        let mut relay_scores = Vec::new();

        // Calculate performance scores for each relay (encrypted computation)
        for (index, encrypted_metrics) in relay_metrics.iter().enumerate() {
            let metrics = encrypted_metrics.to_arcis();
            
            // Weighted performance calculation
            let uptime_score = (metrics.uptime_percentage * 40) / 100;
            let latency_score = if metrics.average_latency < 100 { 
                30 
            } else { 
                3000 / metrics.average_latency 
            };
            let throughput_score = (metrics.messages_processed * 30) / 1000;
            
            let performance_score = uptime_score + latency_score.min(30) + throughput_score.min(30);
            
            total_performance_score += performance_score;
            relay_scores.push((index as u32, performance_score));
        }

        // Distribute rewards proportionally based on performance
        let mut allocations = Vec::new();
        for (relay_index, score) in relay_scores {
            if total_performance_score > 0 {
                let reward_amount = (total_reward_pool * score) / total_performance_score;
                allocations.push(RewardAllocation {
                    relay_index,
                    reward_amount,
                });
            }
        }

        allocations.reveal()
    }

    // ============================================================================
    // Zero-Knowledge Membership Verification
    // ============================================================================

    /// Verifies membership eligibility without revealing user balance
    ///
    /// Checks if a user meets the minimum balance requirement for DAO membership
    /// without revealing their actual balance. Only the eligibility result is disclosed.
    ///
    /// # Arguments
    /// * `user_balance_ctxt` - Encrypted user balance
    /// * `minimum_balance` - Minimum balance required for membership
    ///
    /// # Returns
    /// * `true` if user is eligible (balance >= minimum)
    /// * `false` if user is not eligible
    #[instruction]
    pub fn verify_membership(
        user_balance_ctxt: Enc<Shared, UserBalance>,
        minimum_balance: u64,
    ) -> bool {
        let user_balance = user_balance_ctxt.to_arcis();
        (user_balance.balance >= minimum_balance).reveal()
    }

    // ============================================================================
    // Advanced Privacy Features
    // ============================================================================

    /// Calculates encrypted treasury operations
    ///
    /// Processes treasury transactions while keeping individual amounts private.
    /// Useful for private fund allocation and budget management.
    #[instruction]
    pub fn process_treasury_operation(
        current_balance_ctxt: Enc<Mxe, u64>,
        operation_amount: Enc<Shared, u64>,
        is_withdrawal: bool,
    ) -> Enc<Mxe, u64> {
        let current_balance = current_balance_ctxt.to_arcis();
        let amount = operation_amount.to_arcis();
        
        let new_balance = if is_withdrawal {
            if current_balance >= amount {
                current_balance - amount
            } else {
                current_balance // Insufficient funds, no change
            }
        } else {
            current_balance + amount // Deposit
        };
        
        current_balance_ctxt.owner.from_arcis(new_balance)
    }

    /// Verifies proposal eligibility based on encrypted criteria
    ///
    /// Checks if a proposal meets various encrypted requirements without
    /// revealing the specific criteria or proposer information.
    #[instruction]
    pub fn verify_proposal_eligibility(
        proposer_reputation_ctxt: Enc<Shared, u64>,
        proposer_stake_ctxt: Enc<Shared, u64>,
        minimum_reputation: u64,
        minimum_stake: u64,
    ) -> bool {
        let reputation = proposer_reputation_ctxt.to_arcis();
        let stake = proposer_stake_ctxt.to_arcis();
        
        let reputation_ok = reputation >= minimum_reputation;
        let stake_ok = stake >= minimum_stake;
        
        (reputation_ok && stake_ok).reveal()
    }

    /// Calculates encrypted governance token distribution
    ///
    /// Distributes governance tokens based on encrypted participation metrics
    /// while keeping individual contributions private.
    #[instruction]
    pub fn distribute_governance_tokens(
        participation_metrics: Vec<Enc<Shared, u64>>,
        total_token_pool: u64,
    ) -> Vec<u64> {
        let mut total_participation = 0u64;
        let mut individual_participation = Vec::new();

        // Calculate total participation (encrypted)
        for metrics in &participation_metrics {
            let participation = metrics.to_arcis();
            total_participation += participation;
            individual_participation.push(participation);
        }

        // Distribute tokens proportionally
        let mut distributions = Vec::new();
        for participation in individual_participation {
            if total_participation > 0 {
                let token_amount = (total_token_pool * participation) / total_participation;
                distributions.push(token_amount);
            } else {
                distributions.push(0);
            }
        }

        distributions.reveal()
    }
}
