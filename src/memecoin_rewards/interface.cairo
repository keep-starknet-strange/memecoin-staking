use memecoin_staking::types::{Amount, Cycle};

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    /// Fund the contract with rewards.
    /// Doing this sets the points / rewards ratio for the current version,
    /// and starts a new one.
    /// Can only be called by the owner of the contract.
    /// Will fail if there are no stakes for the current version.
    fn fund(ref self: TContractState, amount: Amount);

    /// Query this contract for the expected rewards given a list of points per version.
    /// Can only be called by the staking contract.
    fn query_rewards(self: @TContractState, points_per_version: Span<(Cycle, u128)>) -> Amount;
}
