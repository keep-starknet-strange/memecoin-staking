use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemeCoinStaking<TContractState> {
    /// Sets the rewards contract address.
    /// Only callable by the contract owner.
    fn set_rewards_contract(ref self: TContractState, rewards_contract: ContractAddress);
}
