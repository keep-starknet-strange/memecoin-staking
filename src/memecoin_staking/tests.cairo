use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};

fn deploy_memecoin_staking_contract(owner: ContractAddress) -> IMemeCoinStakingDispatcher {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    IMemeCoinStakingDispatcher { contract_address: contract_address }
}

#[test]
fn test_constructor() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let dispatcher = deploy_memecoin_staking_contract(owner);
    let contract_address = dispatcher.contract_address;

    let mut loaded_value = load(
        target: contract_address,
        storage_address: selector!("owner"),
        size: Store::<ContractAddress>::size().into(),
    )
        .span();
    let loaded_owner = Serde::<ContractAddress>::deserialize(ref loaded_value).unwrap();

    assert!(loaded_owner == owner);
}

#[test]
fn test_set_rewards_contract() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let dispatcher = deploy_memecoin_staking_contract(owner);
    let contract_address = dispatcher.contract_address;

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();

    cheat_caller_address(
        contract_address: contract_address, caller_address: owner, span: CheatSpan::TargetCalls(1),
    );
    dispatcher.set_rewards_contract(rewards_contract);

    let mut loaded_value = load(
        target: contract_address,
        storage_address: selector!("rewards_contract"),
        size: Store::<ContractAddress>::size().into(),
    )
        .span();
    let loaded_rewards_contract = Serde::<ContractAddress>::deserialize(ref loaded_value).unwrap();

    assert!(loaded_rewards_contract == rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let dispatcher = deploy_memecoin_staking_contract(owner);
    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    dispatcher.set_rewards_contract(rewards_contract);
}
