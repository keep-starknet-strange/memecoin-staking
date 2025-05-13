use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeDurationTrait,
};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_stake, deploy_memecoin_staking_contract, deploy_mock_erc20_contract,
    load_value, stake_and_verify_stake_info, verify_stake_info,
};
use memecoin_staking::types::{Amount, Cycle, Index};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starkware_utils_testing::test_utils::cheat_caller_address_once;

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);

    let loaded_owner = load_value(
        contract_address: cfg.staking_contract, storage_address: selector!("owner"),
    );
    assert!(loaded_owner == cfg.owner);

    let loaded_current_reward_cycle = load_value::<
        Cycle,
    >(contract_address: cfg.staking_contract, storage_address: selector!("current_reward_cycle"));
    assert!(loaded_current_reward_cycle == 0);

    let loaded_token_dispatcher = load_value::<
        IERC20Dispatcher,
    >(contract_address: cfg.staking_contract, storage_address: selector!("token_dispatcher"));
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}

#[test]
fn test_set_rewards_contract() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: cfg.staking_contract };

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    let loaded_rewards_contract = load_value(
        contract_address: cfg.staking_contract, storage_address: selector!("rewards_contract"),
    );
    assert!(loaded_rewards_contract == cfg.rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: cfg.staking_contract };

    dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);
}

#[test]
fn test_stake() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let staker_supply: Amount = 2000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: staker_supply.into());

    let amount: Amount = staker_supply / 2;
    let stake_duration = StakeDuration::OneMonth;
    cheat_caller_address_once(
        contract_address: cfg.token_address, caller_address: cfg.staker_address,
    );
    token_dispatcher.approve(spender: cfg.staking_contract, amount: amount.into());
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 0);

    let stake_duration = StakeDuration::ThreeMonths;
    cheat_caller_address_once(
        contract_address: cfg.token_address, caller_address: cfg.staker_address,
    );
    token_dispatcher.approve(spender: cfg.staking_contract, amount: amount.into());
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 1);

    let loaded_current_reward_cycle = load_value::<
        Cycle,
    >(contract_address: cfg.staking_contract, storage_address: selector!("current_reward_cycle"));
    assert!(loaded_current_reward_cycle == 0);
}

#[test]
fn test_get_stake_info() {
    // Setup.
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Transfer to staker.
    let mut staker_supply: Amount = 2000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: staker_supply.into());

    // Stake and verify one month.
    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::OneMonth;
    let stake_index = approve_and_stake(
        :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    let stake_info = staking_dispatcher
        .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index)
        .unwrap();
    verify_stake_info(:stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration);

    // Stake and verify three months.
    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::ThreeMonths;
    let stake_index = approve_and_stake(
        :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    let stake_info = staking_dispatcher
        .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index)
        .unwrap();
    verify_stake_info(:stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration);

    // Stake and verify six months.
    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::SixMonths;
    let stake_index = approve_and_stake(
        :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    let stake_info = staking_dispatcher
        .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index)
        .unwrap();
    verify_stake_info(:stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration);

    // Stake and verify twelve months.
    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::TwelveMonths;
    let stake_index = approve_and_stake(
        :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    let stake_info = staking_dispatcher
        .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index)
        .unwrap();
    verify_stake_info(:stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration);
}

#[test]
fn test_get_stake_info_not_exist() {
    // Setup.
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Transfer to staker.
    let staker_supply: Amount = 2000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: staker_supply.into());

    // Verify that the stake info does not exist before staking.
    let stake_info = staking_dispatcher
        .get_stake_info(
            staker_address: cfg.staker_address,
            stake_duration: StakeDuration::OneMonth,
            stake_index: 0,
        );
    assert!(stake_info.is_none());

    // Stake and verify existence.
    let amount: Amount = staker_supply;
    let stake_duration = StakeDuration::OneMonth;
    let stake_index = approve_and_stake(
        :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    let stake_info = staking_dispatcher
        .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index);
    assert!(stake_info.is_some());

    // Verify that the stake info does not exist for future index.
    let stake_info = staking_dispatcher
        .get_stake_info(
            staker_address: cfg.staker_address,
            stake_duration: StakeDuration::OneMonth,
            stake_index: 1,
        );
    assert!(stake_info.is_none());

    // Verify that the stake info does not exist for other stake durations.
    let stake_info = staking_dispatcher
        .get_stake_info(
            staker_address: cfg.staker_address,
            stake_duration: StakeDuration::ThreeMonths,
            stake_index: 0,
        );
    assert!(stake_info.is_none());

    let stake_info = staking_dispatcher
        .get_stake_info(
            staker_address: cfg.staker_address,
            stake_duration: StakeDuration::SixMonths,
            stake_index: 0,
        );
    assert!(stake_info.is_none());

    let stake_info = staking_dispatcher
        .get_stake_info(
            staker_address: cfg.staker_address,
            stake_duration: StakeDuration::TwelveMonths,
            stake_index: 0,
        );
    assert!(stake_info.is_none());
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount: Amount = 1000;
    let stake_duration = StakeDuration::OneMonth;
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.stake(:amount, :stake_duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount: u256 = 1;
    let stake_duration = StakeDuration::OneMonth;
    cheat_caller_address_once(
        contract_address: cfg.token_address, caller_address: cfg.staker_address,
    );
    token_dispatcher.approve(spender: cfg.staking_contract, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.stake(amount: amount.try_into().unwrap(), :stake_duration);
}

#[test]
#[should_panic(expected: "Can't close reward cycle with no stakes")]
fn test_close_reward_cycle_no_stakes() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let config_dispatcher = IMemeCoinStakingConfigDispatcher {
        contract_address: cfg.staking_contract,
    };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    config_dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    staking_dispatcher.close_reward_cycle();
}

#[test]
fn test_close_reward_cycle() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let config_dispatcher = IMemeCoinStakingConfigDispatcher {
        contract_address: cfg.staking_contract,
    };
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    config_dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    let staker_supply: Amount = 2000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: staker_supply.into());

    let mut reward_cycle = 0;
    let amount: Amount = staker_supply / 2;
    let stake_duration = StakeDuration::OneMonth;
    stake_and_verify_stake_info(:cfg, :amount, :stake_duration, :reward_cycle);

    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.close_reward_cycle();
    reward_cycle += 1;
    assert!(total_points == amount * stake_duration.get_multiplier().unwrap().into());
    let loaded_current_reward_cycle = load_value::<
        Cycle,
    >(contract_address: cfg.staking_contract, storage_address: selector!("current_reward_cycle"));
    assert!(loaded_current_reward_cycle == reward_cycle);

    let stake_duration = StakeDuration::ThreeMonths;
    stake_and_verify_stake_info(:cfg, :amount, :stake_duration, :reward_cycle);

    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.close_reward_cycle();
    reward_cycle += 1;
    assert!(total_points == amount * stake_duration.get_multiplier().unwrap().into());
    let loaded_current_reward_cycle = load_value::<
        Cycle,
    >(contract_address: cfg.staking_contract, storage_address: selector!("current_reward_cycle"));
    assert!(loaded_current_reward_cycle == reward_cycle);
}

#[test]
fn test_query_points() {
    let mut cfg: TestCfg = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: 3000, recipient: cfg.staker_address,
    );
    cfg.token_address = token_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_contract_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let staking_dispatcher = IMemeCoinStakingDispatcher {
        contract_address: staking_contract_address,
    };
    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.owner,
    );
    IMemeCoinStakingConfigDispatcher { contract_address: staking_contract_address }
        .set_rewards_contract(rewards_contract: cfg.rewards_contract);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let mut points = amount * duration.get_multiplier().unwrap().into();
    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.owner,
    );
    let points_info = staking_dispatcher.query_points(version: 0);
    assert!(points_info == points);

    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.new_version();
    assert!(total_points == points);

    let amount: Amount = 2000;
    let duration = StakeDuration::ThreeMonths;
    approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );

    let new_version_points = amount * duration.get_multiplier().unwrap().into();
    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.owner,
    );
    let points_info = staking_dispatcher.query_points(version: 0);
    assert!(points_info == points);

    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.owner,
    );
    let points_info = staking_dispatcher.query_points(version: 1);
    assert!(points_info == new_version_points);
}

#[test]
#[should_panic(expected: "Version number is too high")]
fn test_query_points_high_version() {
    let cfg: TestCfg = Default::default();
    let staking_contract_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let staking_dispatcher = IMemeCoinStakingDispatcher {
        contract_address: staking_contract_address,
    };

    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.owner,
    );
    staking_dispatcher.query_points(version: 1);
}

#[test]
#[should_panic(expected: "Only callable by the owner")]
fn test_query_points_wrong_caller() {
    let cfg: TestCfg = Default::default();
    let staking_contract_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let staking_dispatcher = IMemeCoinStakingDispatcher {
        contract_address: staking_contract_address,
    };

    cheat_caller_address_once(
        contract_address: staking_contract_address, caller_address: cfg.staker_address,
    );
    staking_dispatcher.query_points(version: 0);
}
