use memecoin_staking::types::Amount;

#[starknet::interface]
pub trait IMemeCoinRewards<TContractState> {
    fn fund(ref self: TContractState, amount: Amount);
}
