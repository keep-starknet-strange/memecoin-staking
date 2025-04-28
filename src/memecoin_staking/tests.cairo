use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};

struct TestCfg {
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

fn deploy_memecoin_staking_contract(owner: ContractAddress) -> IMemeCoinStakingDispatcher {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    IMemeCoinStakingDispatcher { contract_address: contract_address }
}

fn load_value<T, +Serde<T>, +Store<T>>(
    contract_address: ContractAddress, storage_address: felt252,
) -> T {
    let size = Store::<T>::size().into();
    let mut loaded_value = load(
        target: contract_address, storage_address: storage_address, size: size,
    )
        .span();
    Serde::<T>::deserialize(ref loaded_value).unwrap()
}

#[test]
fn test_constructor() {
    let cfg: TestCfg = Default::default();
    let dispatcher = deploy_memecoin_staking_contract(cfg.owner);
    let contract_address = dispatcher.contract_address;

    let loaded_owner = load_value::<ContractAddress>(contract_address, selector!("owner"));

    assert!(loaded_owner == cfg.owner);
}

#[test]
fn test_set_rewards_contract() {
    let cfg: TestCfg = Default::default();
    let dispatcher = deploy_memecoin_staking_contract(cfg.owner);
    let contract_address = dispatcher.contract_address;

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();

    cheat_caller_address(
        contract_address: contract_address, caller_address: cfg.owner, span: CheatSpan::TargetCalls(1),
    );
    dispatcher.set_rewards_contract(cfg.rewards_contract);

    let loaded_rewards_contract = load_value::<
        ContractAddress,
    >(contract_address, selector!("rewards_contract"));

    assert!(loaded_rewards_contract == rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let cfg: TestCfg = Default::default();
    let dispatcher = deploy_memecoin_staking_contract(cfg.owner);
    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    dispatcher.set_rewards_contract(rewards_contract);
}
