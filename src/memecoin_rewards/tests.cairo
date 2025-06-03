use memecoin_staking::errors::Error;
use memecoin_staking::memecoin_rewards::event_test_utils::validate_rewards_funded_event;
use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::IMemeCoinStakingDispatcher;
use memecoin_staking::test_utils::{
    TestCfg, approve_and_fund, approve_and_stake, calculate_points,
    deploy_memecoin_rewards_contract, deploy_memecoin_staking_contract, load_value,
    memecoin_staking_test_setup,
};
use memecoin_staking::types::Amount;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyTrait, EventsFilterTrait, declare, spy_events,
};
use starkware_utils::errors::Describable;
use starkware_utils_testing::event_test_utils::assert_number_of_events;
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
    let mut spy = spy_events();

    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = cfg.default_fund;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.funder);
    token_dispatcher.approve(spender: cfg.rewards_contract, amount: fund_amount.into());
    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.funder);
    rewards_dispatcher.fund(amount: fund_amount);
    assert!(token_dispatcher.balance_of(account: cfg.rewards_contract) == fund_amount.into());

    let total_points = calculate_points(:amount, :stake_duration);
    let events = spy.get_events().emitted_by(contract_address: cfg.rewards_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "Expected 1 rewards funded event",
    );
    validate_rewards_funded_event(
        spied_event: events[0], reward_cycle: 0, :total_points, total_rewards: fund_amount,
    );
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
    rewards_dispatcher.fund(amount: cfg.default_fund);
}

#[test]
fn test_get_token_address() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let token_address = rewards_dispatcher.get_token_address();
    assert!(token_address == cfg.token_address);
}

#[test]
fn test_claim_rewards() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };
    let mut staking_contract_balance: Amount = 0;

    // Test full cycle rewards.
    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    staking_contract_balance += amount;

    let fund_amount = cfg.default_fund;
    approve_and_fund(:cfg, :fund_amount);

    let points = calculate_points(:amount, :stake_duration);
    let reward_cycle = 0;
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    let rewards = rewards_dispatcher.claim_rewards(:points, :reward_cycle);
    staking_contract_balance += rewards;
    assert!(rewards == fund_amount);
    assert!(token_dispatcher.balance_of(account: cfg.rewards_contract) == 0);
    assert!(
        token_dispatcher
            .balance_of(account: cfg.staking_contract) == staking_contract_balance
            .into(),
    );

    // Test partial cycle rewards.
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    staking_contract_balance += amount;

    approve_and_fund(:cfg, :fund_amount);

    let points = calculate_points(:amount, :stake_duration) / 2;
    let reward_cycle = 1;
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    let rewards = rewards_dispatcher.claim_rewards(:points, :reward_cycle);
    staking_contract_balance += rewards;
    assert!(rewards == fund_amount / 2);
    assert!(token_dispatcher.balance_of(account: cfg.rewards_contract) == fund_amount.into() / 2);
    assert!(
        token_dispatcher
            .balance_of(account: cfg.staking_contract) == staking_contract_balance
            .into(),
    );
}

#[test]
#[should_panic(expected: "Claim points exceeds cycle points")]
fn test_claim_rewards_points_exceeds_cycle_points() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = cfg.default_fund;
    approve_and_fund(:cfg, :fund_amount);

    let points = calculate_points(:amount, :stake_duration) + 1;
    let reward_cycle = 0;
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.claim_rewards(:points, :reward_cycle);
}

#[test]
#[should_panic(expected: "Can only be called by the staking contract")]
fn test_claim_rewards_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    rewards_dispatcher.claim_rewards(points: 0, reward_cycle: 0);
}

#[test]
#[should_panic(expected: "Reward cycle does not exist")]
fn test_claim_rewards_invalid_cycle() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.claim_rewards(points: 0, reward_cycle: 0);
}

#[test]
fn test_update_total_points() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };
    let staker_address = cfg.staker_address;

    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let points = calculate_points(:amount, :stake_duration);
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = cfg.default_fund;
    approve_and_fund(:cfg, :fund_amount);

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.update_total_points(points_unstaked: points / 2, reward_cycle: 0);
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    let rewards = rewards_dispatcher.claim_rewards(points: points / 2, reward_cycle: 0);
    assert!(rewards == fund_amount);
}

#[test]
#[should_panic(expected: "Can only be called by the staking contract")]
fn test_update_total_points_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    rewards_dispatcher.update_total_points(points_unstaked: 0, reward_cycle: 0);
}

#[test]
#[should_panic(expected: "Reward cycle does not exist")]
fn test_update_total_points_invalid_cycle() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.update_total_points(points_unstaked: 0, reward_cycle: 0);
}
