use memecoin_staking::types::{Amount, Cycle};

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    /// Fund the contract with rewards.
    /// Doing this sets the points / rewards ratio for the current version,
    /// and starts a new one.
    /// Can only be called by the owner of the contract.
    /// Will fail if there are no stakes for the current version.
    fn fund(ref self: TContractState, amount: Amount);

    /// Transfer the equivalent amount of rewards for the given points and reward cycle
    /// to the Staking Contract.
    /// Can only be called by the Staking Contract.
    fn claim_rewards(ref self: TContractState, points: u128, reward_cycle: Cycle) -> Amount;
}
