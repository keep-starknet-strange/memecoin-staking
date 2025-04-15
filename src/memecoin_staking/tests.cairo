use memecoin_staking::types::{Index, Version};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};
use starknet::{ContractAddress, Store};

#[test]
fn test_constructor() {
    let mut calldata = ArrayTrait::new();
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    owner.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    let loaded_owner: ContractAddress = (*load(
        target: contract_address,
        storage_address: selector!("owner"),
        size: Store::<ContractAddress>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    let loaded_version: Version = (*load(
        target: contract_address,
        storage_address: selector!("current_version"),
        size: Store::<Version>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    let loaded_stake_index: Index = (*load(
        target: contract_address,
        storage_address: selector!("stake_index"),
        size: Store::<Index>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();

    assert!(loaded_owner == owner);
    assert!(loaded_version == 0);
    assert!(loaded_stake_index == 1);
}
