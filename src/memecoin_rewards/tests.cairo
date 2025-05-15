use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, StakeDuration, StakeDurationTrait,
};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_fund, approve_and_stake, deploy_all_contracts,
    deploy_memecoin_rewards_contract, get_all_dispatchers, load_value,
};
use memecoin_staking::types::{Amount, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starkware_utils_testing::test_utils::cheat_caller_address_once;

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_rewards_contract(
        owner: cfg.owner, staking_address: cfg.staking_contract, token_address: cfg.token_address,
    );
    cfg.rewards_contract = contract_address;

    let loaded_owner = load_value(:contract_address, storage_address: selector!("owner"));
    assert!(loaded_owner == cfg.owner);

    let loaded_staking_dispatcher: IMemeCoinStakingDispatcher = load_value(
        :contract_address, storage_address: selector!("staking_dispatcher"),
    );
    assert!(loaded_staking_dispatcher.contract_address == cfg.staking_contract);

    let loaded_token_dispatcher: IERC20Dispatcher = load_value(
        :contract_address, storage_address: selector!("token_dispatcher"),
    );
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}

#[test]
fn test_fund() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let (token_dispatcher, staking_dispatcher, _) = get_all_dispatchers(cfg: @cfg);

    let amount = 1000;
    let duration = StakeDuration::OneMonth;
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let fund_amount = 1000;
    approve_and_fund(cfg: @cfg, amount: fund_amount);
    assert!(token_dispatcher.balance_of(account: cfg.rewards_contract) == fund_amount.into());

    let loaded_version: Version = load_value(
        contract_address: cfg.staking_contract, storage_address: selector!("current_version"),
    );
    assert!(loaded_version == 1);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_fund_wrong_caller() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let amount = 1000;
    let duration = StakeDuration::OneMonth;
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staker_address,
    );
    rewards_dispatcher.fund(amount: amount);
}

#[test]
#[should_panic(expected: "Can't close version with no stakes")]
fn test_fund_no_points() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.owner);
    rewards_dispatcher.fund(amount: 1000);
}

#[test]
fn test_query_rewards() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let (token_dispatcher, staking_dispatcher, rewards_dispatcher) = get_all_dispatchers(cfg: @cfg);

    let mut points_per_version: Array<(Version, u128)> = ArrayTrait::new();
    let mut point_count: u128 = 0;
    let mut total_rewards: Amount = 0;

    let amount: Amount = 1000;
    let duration: StakeDuration = StakeDuration::OneMonth;
    point_count += amount * duration.get_multiplier().unwrap().into();
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let amount: Amount = 500;
    let duration: StakeDuration = StakeDuration::ThreeMonths;
    point_count += amount * duration.get_multiplier().unwrap().into();
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let fund_amount = 1000;
    approve_and_fund(cfg: @cfg, amount: fund_amount);
    points_per_version.append((0, point_count));
    total_rewards += fund_amount;
    point_count = 0;

    let amount = 2500;
    let duration = StakeDuration::TwelveMonths;
    point_count += amount * duration.get_multiplier().unwrap().into();
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let fund_amount = 20000;
    approve_and_fund(cfg: @cfg, amount: fund_amount);
    points_per_version.append((1, point_count));
    total_rewards += fund_amount;
    point_count = 0;

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    let rewards = rewards_dispatcher.query_rewards(points_per_version: points_per_version.span());
    assert!(rewards == total_rewards);
}

#[test]
#[should_panic(expected: "Can only be called by the staking contract")]
fn test_query_rewards_wrong_caller() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Version, u128)> = ArrayTrait::new();
    points_per_version.append((0, 1000));
    rewards_dispatcher.query_rewards(points_per_version: points_per_version.span());
}

#[test]
fn test_query_rewards_no_stakes() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Version, u128)> = ArrayTrait::new();
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
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    let mut points_per_version: Array<(Version, u128)> = ArrayTrait::new();
    points_per_version.append((0, 1000));
    points_per_version.append((1, 1000));
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.query_rewards(points_per_version: points_per_version.span());
}

#[test]
#[should_panic(expected: "Invalid amount of points")]
fn test_query_rewards_invalid_points() {
    let mut cfg: TestCfg = Default::default();
    deploy_all_contracts(ref :cfg);
    let (token_dispatcher, staking_dispatcher, rewards_dispatcher) = get_all_dispatchers(cfg: @cfg);

    let amount: Amount = 1000;
    let duration: StakeDuration = StakeDuration::OneMonth;
    let total_points = amount * duration.get_multiplier().unwrap().into();
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let fund_amount = 1000;
    approve_and_fund(cfg: @cfg, amount: fund_amount);

    let mut points_per_version: Array<(Version, u128)> = ArrayTrait::new();
    points_per_version.append((0, total_points + 1));
    points_per_version.append((1, 1000));
    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.query_rewards(points_per_version: points_per_version.span());
}
