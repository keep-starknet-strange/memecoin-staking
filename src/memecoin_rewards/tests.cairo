use memecoin_staking::errors::Error;
use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::{IMemeCoinStakingDispatcher, StakeDuration};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_stake, deploy_memecoin_rewards_contract, deploy_memecoin_staking_contract,
    load_value, memecoin_staking_test_setup,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starkware_utils::errors::Describable;
use starkware_utils_testing::test_utils::{assert_panic_with_error, cheat_caller_address_once};

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    cfg.staking_contract = deploy_memecoin_staking_contract(ref :cfg);
    cfg.rewards_contract = deploy_memecoin_rewards_contract(ref :cfg);

    let loaded_funder = load_value(
        contract_address: cfg.rewards_contract, storage_address: selector!("funder"),
    );
    assert!(loaded_funder == cfg.funder);

    let loaded_staking_dispatcher: IMemeCoinStakingDispatcher = load_value(
        contract_address: cfg.rewards_contract, storage_address: selector!("staking_dispatcher"),
    );
    assert!(loaded_staking_dispatcher.contract_address == cfg.staking_contract);

    let loaded_token_dispatcher: IERC20Dispatcher = load_value(
        contract_address: cfg.rewards_contract, storage_address: selector!("token_dispatcher"),
    );
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}

#[test]
fn test_constructor_token_mismatch() {
    let mut cfg: TestCfg = Default::default();
    cfg.staking_contract = deploy_memecoin_staking_contract(ref :cfg);
    cfg.token_address = 'ANOTHER_TOKEN'.try_into().unwrap();

    let mut calldata = ArrayTrait::new();
    cfg.funder.serialize(ref output: calldata);
    cfg.staking_contract.serialize(ref output: calldata);
    cfg.token_address.serialize(ref output: calldata);

    let memecoin_rewards_contract = declare(contract: "MemeCoinRewards").unwrap().contract_class();
    let result = memecoin_rewards_contract.deploy(constructor_calldata: @calldata);
    assert_panic_with_error(result, Error::STAKING_TOKEN_MISMATCH.describe());
}

#[test]
fn test_fund() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let amount = cfg.default_stake;
    let stake_duration = StakeDuration::OneMonth;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = cfg.default_fund;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.funder);
    token_dispatcher.approve(spender: cfg.rewards_contract, amount: fund_amount.into());
    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.funder);
    rewards_dispatcher.fund(amount: fund_amount);
    assert!(token_dispatcher.balance_of(account: cfg.rewards_contract) == fund_amount.into());
}

#[test]
#[should_panic(expected: "Can only be called by the funder")]
fn test_fund_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.dummy_address,
    );
    rewards_dispatcher.fund(amount: cfg.default_fund);
}

#[test]
#[should_panic(expected: "Can't close reward cycle with no stakes")]
fn test_fund_no_points() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.funder);
    rewards_dispatcher.fund(amount: 1000);
}

#[test]
fn test_get_token_address() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let token_address = rewards_dispatcher.get_token_address();
    assert!(token_address == cfg.token_address);
}
