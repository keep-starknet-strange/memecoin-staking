use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
};
use starkware_utils::test_utils::cheat_caller_address_once;
use memecoin_staking::test_utils::*;

#[test]
fn test_constructor() {
    let cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_staking_contract(owner: cfg.owner);

    let loaded_owner = load_value(:contract_address, storage_address: selector!("owner"));

    assert!(loaded_owner == cfg.owner);
}

#[test]
fn test_set_rewards_contract() {
    let cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_staking_contract(owner: cfg.owner);
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address };

    cheat_caller_address_once(:contract_address, caller_address: cfg.owner);
    dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    let loaded_rewards_contract = load_value(
        :contract_address, storage_address: selector!("rewards_contract"),
    );

    assert!(loaded_rewards_contract == cfg.rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_staking_contract(owner: cfg.owner);
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address };

    dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);
}
