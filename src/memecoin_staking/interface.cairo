use memecoin_staking::types::{Amount, Index, Version};
use starknet::ContractAddress;
use starkware_utils::types::time::time::Timestamp;

#[starknet::interface]
pub trait IMemeCoinStaking<TContractState> {
    /// Only callable by the contract owner.
    /// Sets the rewards contract address.
    fn set_rewards_contract(ref self: TContractState, rewards_contract: ContractAddress);

    /// Stakes the specified amount of meme coin for the specified duration.
    fn stake(ref self: TContractState, amount: Amount, duration: StakeDuration) -> Index;

    /// If id is 0, unstakes all stakes.
    /// If id is not 0, unstakes the stake with the specified id.
    /// Either way, this also triggers a claim.
    fn unstake(ref self: TContractState, id: Index);

    /// Returns the caller's stake info.
    fn get_stake_info(self: @TContractState) -> Span<StakeInfo>;

    /// Returns the amount of rewards that the caller is eligible for.
    fn query_rewards(self: @TContractState) -> Amount;

    /// Claims rewards for the caller.
    fn claim(ref self: TContractState);

    /// Only callable by the contract owner.
    /// Returns the total and pending points for a specific version.
    fn query_points(self: @TContractState, version: Version) -> PointsInfo;

    /// Can only be called by the rewards contract.
    /// Bumps current version and returns the total points for the last version.
    fn new_version(ref self: TContractState) -> Amount;
}

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
