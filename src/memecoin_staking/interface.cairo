use memecoin_staking::types::{Amount, Index, Multiplier, Version};
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

#[starknet::interface]
pub trait IMemeCoinStaking<TContractState> {
    /// Stakes the specified amount of meme coin for the specified duration.
    /// Returns the stake id.
    fn stake(ref self: TContractState, amount: Amount, duration: StakeDuration) -> Index;
}

/// Different stake durations.
#[derive(starknet::Store, Drop, Hash, Serde, Copy)]
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

/// Points info for each version.
#[derive(starknet::Store, Drop)]
pub struct PointsInfo {
    /// The total points across all stakes for this version.
    pub total_points: Amount,
    /// The pending points (unvested) across all stakes for this version.
    pub pending_points: Amount,
}

/// Stake info for each stake.
#[derive(starknet::Store, Drop)]
pub struct StakeInfo {
    /// The stake id (unique to the contract, used for unstaking).
    pub id: Index,
    /// The version number.
    pub version: Version,
    /// The amount staked.
    pub amount: Amount,
    /// The stake duration.
    pub stake_duration: StakeDuration,
    /// The vesting time (the time when rewards can be claimed for this stake).
    pub vesting_time: Timestamp,
}
