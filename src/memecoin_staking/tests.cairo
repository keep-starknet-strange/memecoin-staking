use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeDurationTrait,
};
use memecoin_staking::test_utils::{
    STAKER_SUPPLY, TestCfg, approve_and_stake, deploy_memecoin_staking_contract,
    deploy_mock_erc20_contract, load_value, memecoin_staking_test_setup, verify_stake_info,
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
fn test_get_stake_info_same_duration() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let mut staker_balance: Amount = STAKER_SUPPLY;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Stake 10 times with different amounts.
    let stake_duration = StakeDuration::SixMonths;
    let mut stake_indexes = array![];
    let mut stake_amounts = array![];
    for _ in 0..10_u32 {
        let amount = staker_balance / 3;
        staker_balance -= amount;
        let stake_index = approve_and_stake(
            :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
        );
        stake_amounts.append(value: amount);
        stake_indexes.append(value: stake_index);
    }

    // Verify the stake info for each stake.
    for i in 0..10_u32 {
        let stake_index = *stake_indexes.at(index: i);
        let amount = *stake_amounts.at(index: i);
        let stake_info = staking_dispatcher
            .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index)
            .unwrap();
        verify_stake_info(:stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration);
    }
}

#[test]
fn test_get_stake_info_different_durations() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let mut staker_balance: Amount = STAKER_SUPPLY;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Stake 10 times with different amounts.
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
    let mut stake_amounts = array![];
    let mut stake_indexes = array![];
    for i in 0..10_u32 {
        let amount = staker_balance / 2;
        staker_balance -= amount;
        let stake_duration = *stake_durations.at(index: i);
        let stake_index = approve_and_stake(
            :cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
        );
        stake_amounts.append(value: amount);
        stake_indexes.append(value: stake_index);
    }

    // Verify the stake info for each stake.
    for i in 0..10_u32 {
        let stake_index = *stake_indexes.at(index: i);
        let amount = *stake_amounts.at(index: i);
        let stake_duration = *stake_durations.at(index: i);
        let stake_info = staking_dispatcher
            .get_stake_info(staker_address: cfg.staker_address, :stake_duration, :stake_index)
            .unwrap();
        verify_stake_info(:stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration);
    }
}

#[test]
fn test_get_stake_info_not_exist() {
    // Setup.
    let cfg = memecoin_staking_test_setup();
    let mut staker_balance: Amount = STAKER_SUPPLY;
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    // Verify that the stake info does not exist before staking.
    let stake_info = staking_dispatcher
        .get_stake_info(
            staker_address: cfg.staker_address,
            stake_duration: StakeDuration::OneMonth,
            stake_index: 0,
        );
    assert!(stake_info.is_none());

    // Stake and verify existence.
    let amount: Amount = staker_balance;
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
    let stake_durations = array![
        StakeDuration::ThreeMonths, StakeDuration::SixMonths, StakeDuration::TwelveMonths,
    ];
    for i in 0..stake_durations.len() {
        let stake_duration = *stake_durations.at(index: i);
        let stake_info = staking_dispatcher
            .get_stake_info(
                staker_address: cfg.staker_address, stake_duration: stake_duration, stake_index: 0,
            );
        assert!(stake_info.is_none());

        let stake_info = staking_dispatcher
            .get_stake_info(
                staker_address: cfg.staker_address, stake_duration: stake_duration, stake_index: 1,
            );
        assert!(stake_info.is_none());
    }
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
#[should_panic(expected: "Can't close version with no stakes")]
fn test_new_version_no_stakes() {
    let mut cfg: TestCfg = Default::default();
    let token_address = deploy_mock_erc20_contract(recipient: cfg.staker_address);
    cfg.token_address = token_address;
    let staking_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let config_dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: staking_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: staking_address };

    cheat_caller_address_once(contract_address: staking_address, caller_address: cfg.owner);
    config_dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    cheat_caller_address_once(
        contract_address: staking_address, caller_address: cfg.rewards_contract,
    );
    staking_dispatcher.new_version();
}

#[test]
fn test_new_version() {
    let mut cfg: TestCfg = Default::default();
    let token_address = deploy_mock_erc20_contract(recipient: cfg.staker_address);
    cfg.token_address = token_address;
    let staking_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let config_dispatcher = IMemeCoinStakingConfigDispatcher { contract_address: staking_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: staking_address };

    cheat_caller_address_once(contract_address: staking_address, caller_address: cfg.owner);
    config_dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    let mut version = 0;
    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    stake_and_verify_stake_info(
        contract_address: staking_address,
        staker_address: cfg.staker_address,
        :token_address,
        :amount,
        :duration,
        :version,
    );

    cheat_caller_address_once(
        contract_address: staking_address, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.new_version();
    version += 1;
    assert!(total_points == amount * duration.get_multiplier().unwrap().into());

    let amount: Amount = 1000;
    let duration = StakeDuration::ThreeMonths;
    stake_and_verify_stake_info(
        contract_address: staking_address,
        staker_address: cfg.staker_address,
        :token_address,
        :amount,
        :duration,
        :version,
    );

    cheat_caller_address_once(
        contract_address: staking_address, caller_address: cfg.rewards_contract,
    );
    let total_points = staking_dispatcher.new_version();
    assert!(total_points == amount * duration.get_multiplier().unwrap().into());
}
