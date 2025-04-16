use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::types::{Index, Version};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};
use starknet::{ContractAddress, Store};

fn deploy_memecoin_staking_contract() -> (ContractAddress, IMemeCoinStakingDispatcher) {
    let mut calldata = ArrayTrait::new();

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    (contract_address, IMemeCoinStakingDispatcher { contract_address: contract_address })
}

#[test]
fn test_stake() {
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract();

    let amount = 1000;
    let duration = StakeDuration::OneMonth;

    let stake_id = dispatcher.stake(amount, duration);
    assert!(stake_id == 1);

    let duration = StakeDuration::ThreeMonths;
    let stake_id = dispatcher.stake(amount, duration);
    assert!(stake_id == 2);

    let loaded_stake_id: Index = (*load(
        target: contract_address,
        storage_address: selector!("stake_index"),
        size: Store::<Index>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    assert!(loaded_stake_id == 3);

    let loaded_current_version: Version = (*load(
        target: contract_address,
        storage_address: selector!("current_version"),
        size: Store::<Version>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    assert!(loaded_current_version == 0);
}
