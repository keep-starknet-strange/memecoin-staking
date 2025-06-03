use memecoin_staking::types::{Amount, Cycle};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    /// Fund the contract with rewards.
    /// Doing this sets the points / rewards ratio for the current reward cycle,
    /// and starts a new one.
    /// Can only be called by the funder of the contract.
    /// Will fail if there are no stakes for the current reward cycle.
    fn fund(ref self: TContractState, amount: Amount);

    /// Get the `ContractAddress` of the token used for rewards.
    fn get_token_address(self: @TContractState) -> ContractAddress;

    /// Transfer the equivalent amount of rewards for the given points and reward cycle
    /// to the staking contract.
    /// Can only be called by the staking contract.
    fn claim_rewards(ref self: TContractState, points: u128, reward_cycle: Cycle) -> Amount;

    /// Update the total points for the given reward cycle.
    /// Used when a staker unstakes early.
    /// Can only be called by the Staking Contract.
    fn update_total_points(ref self: TContractState, points_unstaked: u128, reward_cycle: Cycle);
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
