use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::{IMemeCoinStakingDispatcher, StakeDuration};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_fund, approve_and_stake, calculate_points,
    deploy_memecoin_rewards_contract, load_value, memecoin_staking_test_setup,
};
use memecoin_staking::types::{Amount, Cycle};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starkware_utils_testing::test_utils::cheat_caller_address_once;

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    cfg.rewards_contract = deploy_memecoin_rewards_contract(ref :cfg);

    let loaded_owner = load_value(
        contract_address: cfg.rewards_contract, storage_address: selector!("owner"),
    );
    assert!(loaded_owner == cfg.owner);

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
fn test_fund() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let amount = 1000;
    let stake_duration = StakeDuration::OneMonth;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = 1000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.approve(spender: cfg.rewards_contract, amount: fund_amount.into());
    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.owner);
    rewards_dispatcher.fund(amount: fund_amount);

    assert!(token_dispatcher.balance_of(account: cfg.rewards_contract) == fund_amount.into());

    let loaded_reward_cycle: Cycle = load_value(
        contract_address: cfg.staking_contract, storage_address: selector!("current_reward_cycle"),
    );
    assert!(loaded_reward_cycle == 1);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_fund_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let amount = 1000;
    let stake_duration = StakeDuration::OneMonth;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staker_address,
    );
    rewards_dispatcher.fund(:amount);
}

#[test]
#[should_panic(expected: "Can't close reward cycle with no stakes")]
fn test_fund_no_points() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.owner);
    rewards_dispatcher.fund(amount: 1000);
}

#[test]
fn test_query_rewards() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Cycle, u128)> = ArrayTrait::new();
    let mut point_count: u128 = 0;
    let mut total_rewards: Amount = 0;

    let amount: Amount = 1000;
    let stake_duration: StakeDuration = StakeDuration::OneMonth;
    point_count += calculate_points(:amount, :stake_duration);
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let amount: Amount = 500;
    let stake_duration: StakeDuration = StakeDuration::ThreeMonths;
    point_count += calculate_points(:amount, :stake_duration);
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = 1000;
    approve_and_fund(:cfg, :fund_amount);
    points_per_version.append((0, point_count));
    total_rewards += fund_amount;
    point_count = 0;

    let amount = 2500;
    let stake_duration = StakeDuration::TwelveMonths;
    point_count += calculate_points(:amount, :stake_duration);
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = 20000;
    approve_and_fund(:cfg, :fund_amount);
    points_per_version.append((1, point_count));
    total_rewards += fund_amount;
    point_count = 0;

    let points_per_version = points_per_version.span();
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    let rewards = rewards_dispatcher.query_rewards(:points_per_version);
    assert!(rewards == total_rewards);
}

#[test]
#[should_panic(expected: "Can only be called by the staking contract")]
fn test_query_rewards_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Cycle, u128)> = ArrayTrait::new();
    points_per_version.append((0, 1000));
    rewards_dispatcher.query_rewards(points_per_version: points_per_version.span());
}

#[test]
fn test_query_rewards_no_stakes() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Cycle, u128)> = ArrayTrait::new();
    points_per_version.append((0, 1000));
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    let rewards = rewards_dispatcher.query_rewards(points_per_version: points_per_version.span());
    assert!(rewards == 0);
}

#[test]
#[should_panic(expected: "Invalid version")]
fn test_query_rewards_invalid_version() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Cycle, u128)> = ArrayTrait::new();
    points_per_version.append((0, 1000));
    points_per_version.append((1, 1000));
    let points_per_version = points_per_version.span();
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.query_rewards(:points_per_version);
}

#[test]
#[should_panic(expected: "Invalid amount of points")]
fn test_query_rewards_invalid_points() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let amount: Amount = 1000;
    let stake_duration: StakeDuration = StakeDuration::OneMonth;
    let total_points = calculate_points(:amount, :stake_duration);
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = 1000;
    approve_and_fund(:cfg, :fund_amount);

    let mut points_per_version: Array<(Cycle, u128)> = ArrayTrait::new();
    points_per_version.append((0, total_points + 1));
    points_per_version.append((1, 1000));
    let points_per_version = points_per_version.span();
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.query_rewards(:points_per_version);
}
