use memecoin_staking::errors::Error;
use memecoin_staking::memecoin_staking::event_test_utils::{
    validate_new_stake_event, validate_rewards_contract_set_event,
};
use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, IMemeCoinStakingSafeDispatcher,
    IMemeCoinStakingSafeDispatcherTrait, StakeDuration, StakeDurationTrait, StakeInfoImpl,
};
use memecoin_staking::test_utils::{
    TestCfg, advance_time, approve_and_fund, approve_and_stake, calculate_points,
    cheat_staker_approve_staking, deploy_memecoin_rewards_contract,
    deploy_memecoin_staking_contract, deploy_mock_erc20_contract, load_and_verify_value, load_value,
    memecoin_staking_test_setup, verify_stake_info,
};
use memecoin_staking::types::{Amount, Cycle, Index};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{EventSpyTrait, EventsFilterTrait, spy_events};
use starkware_utils::errors::Describable;
use starkware_utils::types::time::time::TimeDelta;
use starkware_utils_testing::event_test_utils::assert_number_of_events;
use starkware_utils_testing::test_utils::{assert_panic_with_error, cheat_caller_address_once};

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);

    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("owner"),
        expected_value: cfg.owner,
    );

    let loaded_token_dispatcher = load_value::<
        IERC20Dispatcher,
    >(contract_address: cfg.staking_contract, storage_address: selector!("token_dispatcher"));
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);

    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("current_reward_cycle"),
        expected_value: 0,
    );

    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("total_points_in_current_reward_cycle"),
        expected_value: 0,
    );
}

#[test]
fn test_set_get_rewards_contract() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);
    let rewards_contract = deploy_memecoin_rewards_contract(ref :cfg);
    let config_dispatcher = IMemeCoinStakingConfigDispatcher {
        contract_address: cfg.staking_contract,
    };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };
    let mut spy = spy_events();

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    config_dispatcher.set_rewards_contract(:rewards_contract);

    let loaded_rewards_contract = staking_dispatcher.get_rewards_contract();
    assert!(loaded_rewards_contract == rewards_contract);

    let events = spy.get_events().emitted_by(contract_address: cfg.staking_contract).events;
    assert_number_of_events(actual: events.len(), expected: 1, message: "Expected 1 event");
    validate_rewards_contract_set_event(spied_event: events[0], :rewards_contract);
}

#[test]
#[should_panic(expected: "Rewards contract already set")]
fn test_set_rewards_contract_already_set() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);
    let rewards_contract = deploy_memecoin_rewards_contract(ref :cfg);
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: cfg.staking_contract };

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    dispatcher.set_rewards_contract(:rewards_contract);

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    dispatcher.set_rewards_contract(:rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);
    let rewards_contract = cfg.rewards_contract;
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: cfg.staking_contract };

    dispatcher.set_rewards_contract(:rewards_contract);
}

#[test]
fn test_stake() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };
    let mut total_points: u128 = 0;

    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    total_points += calculate_points(:amount, :stake_duration);
    cheat_staker_approve_staking(:cfg, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 0);

    let stake_duration = StakeDuration::ThreeMonths;
    cheat_staker_approve_staking(:cfg, :amount);
    total_points += calculate_points(:amount, :stake_duration);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 0);

    let mut spy = spy_events();
    let stake_duration = cfg.default_stake_duration;
    cheat_staker_approve_staking(:cfg, :amount);
    total_points += calculate_points(:amount, :stake_duration);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 1);

    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("current_reward_cycle"),
        expected_value: 0,
    );

    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("total_points_in_current_reward_cycle"),
        expected_value: total_points,
    );

    let events = spy.get_events().emitted_by(contract_address: cfg.staking_contract).events;
    assert_number_of_events(
        actual: events.len(), expected: 1, message: "Expected 1 new stake event",
    );
    validate_new_stake_event(
        spied_event: events[0], :staker_address, :stake_duration, :stake_index,
    );
}

#[test]
fn test_get_stake_info_same_duration() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let mut staker_balance: Amount = cfg.staker_supply;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Stake 10 times with different amounts.
    let stake_duration = StakeDuration::SixMonths;
    let mut stake_indexes = array![];
    let mut stake_amounts = array![];
    for _ in 0..10_u32 {
        let amount = staker_balance / 3;
        staker_balance -= amount;
        let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
        stake_amounts.append(value: amount);
        stake_indexes.append(value: stake_index);
    }

    // Verify the stake info for each stake.
    for i in 0..10_u32 {
        let stake_index = *stake_indexes.at(index: i);
        let amount = *stake_amounts.at(index: i);
        let stake_info = staking_dispatcher
            .get_stake_info(:staker_address, :stake_duration, :stake_index)
            .unwrap();
        verify_stake_info(:stake_info, reward_cycle: 0, :amount, :stake_duration, claimed: false);
    }
}

#[test]
fn test_get_stake_info_different_durations() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Stake 10 times with different durations.
    let stake_durations = array![
        StakeDuration::OneMonth,
        StakeDuration::ThreeMonths,
        StakeDuration::OneMonth,
        StakeDuration::TwelveMonths,
        StakeDuration::SixMonths,
        StakeDuration::TwelveMonths,
        StakeDuration::SixMonths,
        StakeDuration::ThreeMonths,
        StakeDuration::ThreeMonths,
        StakeDuration::SixMonths,
    ];
    let amount = cfg.default_stake_amount;
    let mut stake_indexes = array![];
    for i in 0..10_u32 {
        let stake_duration = *stake_durations.at(index: i);
        let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
        stake_indexes.append(value: stake_index);
    }

    // Verify the stake info for each stake.
    for i in 0..10_u32 {
        let stake_index = *stake_indexes.at(index: i);
        let stake_duration = *stake_durations.at(index: i);
        let stake_info = staking_dispatcher
            .get_stake_info(:staker_address, :stake_duration, :stake_index)
            .unwrap();
        verify_stake_info(:stake_info, reward_cycle: 0, :amount, :stake_duration, claimed: false);
    }
}

#[test]
fn test_get_stake_info_not_exist() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Verify that the stake info does not exist before staking.
    let stake_info = staking_dispatcher
        .get_stake_info(
            :staker_address, stake_duration: cfg.default_stake_duration, stake_index: 0,
        );
    assert!(stake_info.is_none());

    // Stake and verify existence.
    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    let stake_info = staking_dispatcher
        .get_stake_info(:staker_address, :stake_duration, :stake_index);
    assert!(stake_info.is_some());

    // Verify that the stake info does not exist for future index.
    let stake_info = staking_dispatcher
        .get_stake_info(
            :staker_address, stake_duration: cfg.default_stake_duration, stake_index: 1,
        );
    assert!(stake_info.is_none());

    // Verify that the stake info does not exist for other stake durations.
    let stake_durations = array![
        StakeDuration::ThreeMonths, StakeDuration::SixMonths, StakeDuration::TwelveMonths,
    ];
    for i in 0..stake_durations.len() {
        let stake_duration = *stake_durations.at(index: i);
        let stake_info = staking_dispatcher
            .get_stake_info(:staker_address, :stake_duration, stake_index: 0);
        assert!(stake_info.is_none());

        let stake_info = staking_dispatcher
            .get_stake_info(:staker_address, :stake_duration, stake_index: 1);
        assert!(stake_info.is_none());
    }
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let cfg = memecoin_staking_test_setup();
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.stake(:amount, :stake_duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let cfg = memecoin_staking_test_setup();
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount: Amount = cfg.staker_supply + 1;
    let stake_duration = cfg.default_stake_duration;
    cheat_staker_approve_staking(:cfg, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.stake(:amount, :stake_duration);
}

#[test]
#[should_panic(expected: "Can't close reward cycle with no stakes")]
fn test_close_reward_cycle_no_stakes() {
    let cfg = memecoin_staking_test_setup();
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    staking_dispatcher.close_reward_cycle();
}

#[test]
#[should_panic(expected: "Can only be called by the rewards contract")]
fn test_close_reward_cycle_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    staking_dispatcher.close_reward_cycle();
}

#[test]
fn test_close_reward_cycle() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };
    let mut stake_indexes: Array<Index> = array![];
    let stake_duration = cfg.default_stake_duration;
    let mut reward_cycle = 0;

    // First stake.
    let amount = cfg.default_stake_amount;
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    stake_indexes.append(value: stake_index);

    // Close the first reward cycle and verify the total points.
    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("total_points_in_current_reward_cycle"),
        expected_value: calculate_points(:amount, :stake_duration),
    );
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.close_reward_cycle();
    reward_cycle += 1;
    assert!(total_points == calculate_points(:amount, :stake_duration));
    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("current_reward_cycle"),
        expected_value: reward_cycle,
    );
    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("total_points_in_current_reward_cycle"),
        expected_value: 0,
    );

    // Second stake.
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    stake_indexes.append(value: stake_index);

    // Close the second reward cycle and verify the total points.
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.close_reward_cycle();
    reward_cycle += 1;
    assert!(total_points == calculate_points(:amount, :stake_duration));
    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("current_reward_cycle"),
        expected_value: reward_cycle,
    );
    load_and_verify_value(
        contract_address: cfg.staking_contract,
        storage_address: selector!("total_points_in_current_reward_cycle"),
        expected_value: 0,
    );

    // Verify stake info for each stake.
    for i in 0..stake_indexes.len() {
        let stake_index: Index = *stake_indexes.at(index: i);
        let reward_cycle: Cycle = i.into();
        let stake_info = staking_dispatcher
            .get_stake_info(:staker_address, :stake_duration, :stake_index)
            .unwrap();
        verify_stake_info(:stake_info, :reward_cycle, :amount, :stake_duration, claimed: false);
    }
}

#[test]
fn test_get_token_address() {
    let cfg = memecoin_staking_test_setup();
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let token_address = staking_dispatcher.get_token_address();
    assert!(token_address == cfg.token_address);
}

#[test]
fn test_stake_is_vested() {
    let cfg: TestCfg = Default::default();
    let reward_cycle = 0;
    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let stake_info = StakeInfoImpl::new(:reward_cycle, :amount, :stake_duration);
    assert!(!stake_info.is_vested());

    advance_time(time_delta: stake_duration.to_time_delta().unwrap());
    assert!(stake_info.is_vested());
}

#[test]
#[feature("safe_dispatcher")]
fn test_claim_rewards_sanity() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };
    let staking_safe_dispatcher = IMemeCoinStakingSafeDispatcher {
        contract_address: cfg.staking_contract,
    };

    // Stake and fund.
    let amount: Amount = cfg.staker_supply;
    let stake_duration = cfg.default_stake_duration;
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);

    let fund_amount = cfg.default_fund;
    approve_and_fund(:cfg, :fund_amount);

    // Claim rewards before vesting time.
    let one_second = TimeDelta { seconds: 1 };
    advance_time(time_delta: stake_duration.to_time_delta().unwrap() - one_second);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let res = staking_safe_dispatcher.claim_rewards(:stake_duration, :stake_index);
    assert_panic_with_error(res, Error::STAKE_NOT_VESTED.describe());

    // Claim rewards after vesting time.
    advance_time(time_delta: one_second);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let rewards = staking_dispatcher.claim_rewards(:stake_duration, :stake_index);
    assert!(rewards == fund_amount);
    let staker_balance = token_dispatcher.balance_of(account: staker_address);
    assert!(staker_balance == fund_amount.into());

    // Claim rewards again.
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let res = staking_safe_dispatcher.claim_rewards(:stake_duration, :stake_index);
    assert_panic_with_error(res, Error::STAKE_ALREADY_CLAIMED.describe());
}

#[test]
#[should_panic(expected: "Stake not found")]
fn test_claim_rewards_not_found() {
    let cfg = memecoin_staking_test_setup();
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let stake_duration = cfg.default_stake_duration;
    let stake_index = 0;

    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.claim_rewards(:stake_duration, :stake_index);
}

#[test]
#[should_panic(expected: "Rewards contract not set")]
fn test_claim_rewards_rewards_contract_not_set() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(funder: cfg.staker_address);
    deploy_memecoin_staking_contract(ref :cfg);
    let staker_address = cfg.staker_address;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    advance_time(time_delta: stake_duration.to_time_delta().unwrap());

    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: staker_address,
    );
    staking_dispatcher.claim_rewards(:stake_duration, :stake_index);
}

#[test]
fn test_stake_info_claimed() {
    let cfg: TestCfg = Default::default();
    let reward_cycle = 0;
    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let mut stake_info = StakeInfoImpl::new(:reward_cycle, :amount, :stake_duration);
    assert!(!stake_info.is_claimed());

    advance_time(time_delta: stake_duration.to_time_delta().unwrap());
    stake_info.set_claimed();
    assert!(stake_info.is_claimed());
}

#[test]
#[should_panic(expected: "Stake not vested")]
fn test_stake_info_claimed_before_vesting() {
    let cfg: TestCfg = Default::default();
    let reward_cycle = 0;
    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let mut stake_info = StakeInfoImpl::new(:reward_cycle, :amount, :stake_duration);

    stake_info.set_claimed();
}

#[test]
#[should_panic(expected: "Stake already claimed")]
fn test_stake_info_claimed_twice() {
    let cfg: TestCfg = Default::default();
    let reward_cycle = 0;
    let amount = cfg.default_stake_amount;
    let stake_duration = cfg.default_stake_duration;
    let mut stake_info = StakeInfoImpl::new(:reward_cycle, :amount, :stake_duration);

    advance_time(time_delta: stake_duration.to_time_delta().unwrap());
    stake_info.set_claimed();
    stake_info.set_claimed();
}
