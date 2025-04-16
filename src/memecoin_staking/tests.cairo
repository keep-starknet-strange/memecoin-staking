use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load, cheat_caller_address, CheatSpan};
use starknet::{ContractAddress, Store};
use memecoin_staking::memecoin_staking::interface::{IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait};

fn deploy_memecoin_staking_contract(owner: ContractAddress) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    contract_address
}

#[test]
fn test_constructor() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_memecoin_staking_contract(owner);

    let loaded_owner: ContractAddress = (*load(
        target: contract_address,
        storage_address: selector!("owner"),
        size: Store::<ContractAddress>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();

    assert!(loaded_owner == owner);
}

#[test]
fn test_set_rewards_contract() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_memecoin_staking_contract(owner);

    let dispatcher = IMemeCoinStakingDispatcher {
        contract_address: contract_address,
    };

    let rewards_contract: ContractAddress = 'rewards_contract'.try_into().unwrap();

    cheat_caller_address(
        contract_address: contract_address,
        caller_address: owner,
        span: CheatSpan::TargetCalls(1),
    );
    dispatcher.set_rewards_contract(rewards_contract);

    let loaded_rewards_contract = (*load(
        target: contract_address,
        storage_address: selector!("rewards_contract"),
        size: Store::<ContractAddress>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();

    assert!(loaded_rewards_contract == rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let contract_address = deploy_memecoin_staking_contract(owner);

    let dispatcher = IMemeCoinStakingDispatcher {
        contract_address: contract_address,
    };

    let rewards_contract: ContractAddress = 'rewards_contract'.try_into().unwrap();
    dispatcher.set_rewards_contract(rewards_contract);
}
