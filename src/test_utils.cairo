use starknet::{ContractAddress, Store};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};

pub struct TestCfg {
    pub owner: ContractAddress,
    pub rewards_contract: ContractAddress,
}

impl TestInitConfigDefault of Default<TestCfg> {
    fn default() -> TestCfg {
        TestCfg {
            owner: 'OWNER'.try_into().unwrap(),
            rewards_contract: 'REWARDS_CONTRACT'.try_into().unwrap(),
        }
    }
}

pub fn deploy_memecoin_staking_contract(owner: ContractAddress) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref output: calldata);

    let memecoin_staking_contract = declare(contract: "MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract
        .deploy(constructor_calldata: @calldata)
        .unwrap();

    contract_address
}

pub fn load_value<T, +Serde<T>, +Store<T>>(contract_address: ContractAddress, storage_address: felt252) -> T {
    let size = Store::<T>::size().into();
    let mut loaded_value = load(target: contract_address, :storage_address, :size).span();
    Serde::deserialize(ref serialized: loaded_value).unwrap()
}
