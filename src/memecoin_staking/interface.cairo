use memecoin_staking::types::{Amount, Index, Version};
use starkware_utils::types::time::time::Timestamp;

#[derive(Drop, Serde, Copy, PartialEq, starknet::Store, Hash)]
pub enum StakeDuration {
    #[default]
    OneMonth,
    ThreeMonths,
    SixMonths,
    TwelveMonths,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct PointsInfo {
    pub total_points: Amount,
    pub pending_points: Amount,
}

#[derive(Drop, PartialEq, Copy, Serde, starknet::Store)]
pub struct StakeInfo {
    pub id: Index,
    pub version: Version,
    pub amount: Amount,
    pub stake_duration: StakeDuration,
    pub vesting_time: Timestamp,
}
