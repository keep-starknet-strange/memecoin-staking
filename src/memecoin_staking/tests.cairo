use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};

fn deploy_memecoin_staking_contract(
    owner: ContractAddress,
) -> (ContractAddress, IMemeCoinStakingDispatcher) {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    (contract_address, IMemeCoinStakingDispatcher { contract_address: contract_address })
}

#[test]
fn test_stake() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
}