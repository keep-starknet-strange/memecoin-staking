use memecoin_staking::types::Amount;

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    /// Alerts the contract that the new version has been funded,
    /// and adds a new entry to the `version_info` array.
    fn fund(ref self: TContractState, amount: Amount);
}

#[derive(starknet::Store, Drop)]
pub struct VersionInfo {
    pub total_points: Amount,
    pub total_rewards: Amount,
}
