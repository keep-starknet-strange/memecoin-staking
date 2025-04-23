use memecoin_staking::types::{Amount, Index, Multiplier, Version};
use starknet::ContractAddress;
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

#[starknet::interface]
pub trait IMemeCoinStaking<TContractState> {
    /// Sets the rewards contract address.
    /// Only callable by the contract owner.
    fn set_rewards_contract(ref self: TContractState, rewards_contract: ContractAddress);

    /// Stakes the specified amount of meme coin for the specified duration.
    /// Returns the stake id.
    fn stake(ref self: TContractState, amount: Amount, duration: StakeDuration) -> Index;

    /// Get info for all stakes for the caller.
    fn get_stake_info(self: @TContractState) -> Span<StakeInfo>;

    /// Bumps version number, returns total points for the previous version.
    fn new_version(ref self: TContractState) -> Amount;
}

/// Different stake durations.
#[derive(starknet::Store, Drop, Hash, Serde, Copy, PartialEq)]
pub enum StakeDuration {
    #[default]
    OneMonth,
    ThreeMonths,
    SixMonths,
    TwelveMonths,
}

#[generate_trait]
pub(crate) impl StakeDurationImpl of StakeDurationTrait {
    /// Converts the stake duration to a time delta.
    fn to_time_delta(self: @StakeDuration) -> TimeDelta {
        match self {
            StakeDuration::OneMonth => Time::days(30),
            StakeDuration::ThreeMonths => Time::days(30 * 3),
            StakeDuration::SixMonths => Time::days(30 * 6),
            StakeDuration::TwelveMonths => Time::days(30 * 12),
        }
    }

    /// Gets the points multiplier for the stake duration.
    fn get_multiplier(self: @StakeDuration) -> Multiplier {
        match self {
            StakeDuration::OneMonth => 10,
            StakeDuration::ThreeMonths => 12,
            StakeDuration::SixMonths => 15,
            StakeDuration::TwelveMonths => 20,
        }
    }
}

/// Iterator over all stake duration options.
#[derive(Drop)]
struct StakeDurationIter {
    stake_duration: Option<StakeDuration>,
}

#[generate_trait]
pub(crate) impl StakeDurationIterImpl of StakeDurationIterTrait {
    fn new() -> StakeDurationIter {
        StakeDurationIter { stake_duration: Some(StakeDuration::OneMonth) }
    }
}

pub(crate) impl StakeDurationIteratorImpl of Iterator<StakeDurationIter> {
    type Item = StakeDuration;

    fn next(ref self: StakeDurationIter) -> Option<StakeDuration> {
        let prev = self.stake_duration;
        if let Some(duration) = self.stake_duration {
            match duration {
                StakeDuration::OneMonth => {
                    self.stake_duration = Some(StakeDuration::ThreeMonths);
                },
                StakeDuration::ThreeMonths => {
                    self.stake_duration = Some(StakeDuration::SixMonths);
                },
                StakeDuration::SixMonths => {
                    self.stake_duration = Some(StakeDuration::TwelveMonths);
                },
                StakeDuration::TwelveMonths => { self.stake_duration = None; },
            }
        }
        prev
    }
}

/// Points info for each version.
#[derive(starknet::Store, Drop)]
pub struct PointsInfo {
    /// The total points across all stakes for this version.
    pub total_points: Amount,
    /// The pending points (unvested) across all stakes for this version.
    pub pending_points: Amount,
}

/// Stake info for each stake.
#[derive(starknet::Store, Drop, Serde)]
pub struct StakeInfo {
    /// The stake id (unique to the contract, used for unstaking).
    pub id: Index,
    /// The version number.
    pub version: Version,
    /// The amount staked.
    pub amount: Amount,
    /// The vesting time (the time when rewards can be claimed for this stake).
    pub vesting_time: Timestamp,
}
