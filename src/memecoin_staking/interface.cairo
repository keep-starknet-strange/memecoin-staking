use memecoin_staking::types::{Amount, Index, Multiplier, Version};
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

#[starknet::interface]
pub trait IMemeCoinStaking<TContractState> {
    /// Stakes the specified amount of meme coin for the specified duration.
    /// Returns the stake id.
    fn stake(ref self: TContractState, amount: Amount, duration: StakeDuration) -> Index;
}

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
    fn to_time_delta(self: @StakeDuration) -> TimeDelta {
        match self {
            StakeDuration::OneMonth => Time::days(30),
            StakeDuration::ThreeMonths => Time::days(30 * 3),
            StakeDuration::SixMonths => Time::days(30 * 6),
            StakeDuration::TwelveMonths => Time::days(30 * 12),
        }
    }

    fn get_multiplier(self: @StakeDuration) -> Multiplier {
        match self {
            StakeDuration::OneMonth => 10,
            StakeDuration::ThreeMonths => 12,
            StakeDuration::SixMonths => 15,
            StakeDuration::TwelveMonths => 20,
        }
    }
}

#[derive(starknet::Store)]
pub struct PointsInfo {
    pub total_points: Amount,
    pub pending_points: Amount,
}

#[derive(starknet::Store, Drop)]
pub struct StakeInfo {
    pub id: Index,
    pub version: Version,
    pub amount: Amount,
    pub stake_duration: StakeDuration,
    pub vesting_time: Timestamp,
}
