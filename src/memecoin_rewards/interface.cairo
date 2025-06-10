use memecoin_staking::types::{Amount, Cycle};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    /// Fund the contract with rewards.
    /// Doing this sets the points / rewards ratio for the current reward cycle,
    /// and starts a new one.
    /// Can only be called by the funder of the contract.
    /// Will fail if there are no stakes for the current reward cycle.
    /// If `use_locked_rewards` is true, the amount will be taken from the locked rewards.
    /// If `use_locked_rewards` is used, `amount` must be 0.
    fn fund(ref self: TContractState, amount: Amount, use_locked_rewards: bool);

    /// Get the `ContractAddress` of the token used for rewards.
    fn get_token_address(self: @TContractState) -> ContractAddress;

    /// Transfer the equivalent amount of rewards for the given points and reward cycle
    /// to the staking contract.
    /// Can only be called by the staking contract.
    fn claim_rewards(ref self: TContractState, points: u128, reward_cycle: Cycle) -> Amount;

    /// Lock the equivalent amount of rewards for a reward cycle
    /// given an amount of points.
    /// Used when a staker unstakes early.
    fn lock_rewards(ref self: TContractState, points: u128, reward_cycle: Cycle);

    /// Get the amount of rewards locked.
    fn get_locked_rewards(self: @TContractState) -> Amount;
}

pub mod Events {
    use memecoin_staking::types::{Amount, Cycle};

    #[derive(Debug, Drop, starknet::Event, PartialEq)]
    pub struct RewardsFunded {
        #[key]
        pub reward_cycle: Cycle,
        pub total_points: u128,
        pub total_rewards: Amount,
    }
}
