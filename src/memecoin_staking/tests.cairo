use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_stake, calculate_points, cheat_staker_approve_staking,
    deploy_memecoin_staking_contract, load_value, memecoin_staking_test_setup, verify_stake_info,
};
use memecoin_staking::types::{Amount, Cycle, Index};
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use starkware_utils_testing::test_utils::cheat_caller_address_once;

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);

    let loaded_owner = load_value(
        contract_address: cfg.staking_contract, storage_address: selector!("owner"),
    );
    assert!(loaded_owner == cfg.owner);

    let loaded_token_dispatcher = load_value::<
        IERC20Dispatcher,
    >(contract_address: cfg.staking_contract, storage_address: selector!("token_dispatcher"));
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}

#[test]
fn test_set_rewards_contract() {
    let mut cfg: TestCfg = Default::default();
    deploy_memecoin_staking_contract(ref :cfg);
    let rewards_contract = cfg.rewards_contract;
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: cfg.staking_contract };

    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    dispatcher.set_rewards_contract(:rewards_contract);

    let loaded_rewards_contract = load_value(
        contract_address: cfg.staking_contract, storage_address: selector!("rewards_contract"),
    );
    assert!(loaded_rewards_contract == rewards_contract);
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
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount = cfg.default_stake;
    let stake_duration = StakeDuration::OneMonth;
    cheat_staker_approve_staking(:cfg, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 0);

    let stake_duration = StakeDuration::ThreeMonths;
    cheat_staker_approve_staking(:cfg, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 0);

    let stake_duration = StakeDuration::OneMonth;
    cheat_staker_approve_staking(:cfg, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_index = staking_dispatcher.stake(:amount, :stake_duration);
    assert!(stake_index == 1);
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
        verify_stake_info(:stake_info, reward_cycle: 0, :amount, :stake_duration);
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
    let amount = cfg.default_stake;
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
        verify_stake_info(:stake_info, reward_cycle: 0, :amount, :stake_duration);
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
        .get_stake_info(:staker_address, stake_duration: StakeDuration::OneMonth, stake_index: 0);
    assert!(stake_info.is_none());

    // Stake and verify existence.
    let amount = cfg.default_stake;
    let stake_duration = StakeDuration::OneMonth;
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    let stake_info = staking_dispatcher
        .get_stake_info(:staker_address, :stake_duration, :stake_index);
    assert!(stake_info.is_some());

    // Verify that the stake info does not exist for future index.
    let stake_info = staking_dispatcher
        .get_stake_info(:staker_address, stake_duration: StakeDuration::OneMonth, stake_index: 1);
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

    let amount = cfg.default_stake;
    let stake_duration = StakeDuration::OneMonth;
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
    let stake_duration = StakeDuration::OneMonth;
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
    let stake_duration = StakeDuration::OneMonth;
    let mut reward_cycle = 0;

    // First stake.
    let amount = cfg.default_stake;
    let stake_index = approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    stake_indexes.append(value: stake_index);

    // Close the first reward cycle and verify the total points.
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.close_reward_cycle();
    reward_cycle += 1;
    assert!(total_points == calculate_points(:amount, :stake_duration));

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

    // Verify stake info for each stake.
    for i in 0..stake_indexes.len() {
        let stake_index: Index = *stake_indexes.at(index: i);
        let reward_cycle: Cycle = i.into();
        let stake_info = staking_dispatcher
            .get_stake_info(:staker_address, :stake_duration, :stake_index)
            .unwrap();
        verify_stake_info(:stake_info, :reward_cycle, :amount, :stake_duration);
    }
}
