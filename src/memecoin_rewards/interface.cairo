use memecoin_staking::types::Amount;

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    /// Fund the contract with rewards.
    /// Doing this sets the points / rewards ratio for the current reward cycle,
    /// and starts a new one.
    /// Can only be called by the funder of the contract.
    /// Will fail if there are no stakes for the current reward cycle.
    fn fund(ref self: TContractState, amount: Amount);
}
