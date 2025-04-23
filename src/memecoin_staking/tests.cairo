use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_stake, deploy_memecoin_staking_contract, deploy_mock_erc20_contract,
    load_value, verify_stake_info,
};
use memecoin_staking::types::{Amount, Cycle};
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
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let mut staker_supply: Amount = 2000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: staker_supply.into());

    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::OneMonth;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_info = staking_dispatcher.get_stake_info(:stake_duration, :stake_index).unwrap();
    verify_stake_info(
        stake_info: @stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration,
    );

    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::ThreeMonths;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_info = staking_dispatcher.get_stake_info(:stake_duration, :stake_index).unwrap();
    verify_stake_info(
        stake_info: @stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration,
    );

    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::SixMonths;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_info = staking_dispatcher.get_stake_info(:stake_duration, :stake_index).unwrap();
    verify_stake_info(
        stake_info: @stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration,
    );

    let amount: Amount = staker_supply / 2;
    staker_supply -= amount;
    let stake_duration = StakeDuration::TwelveMonths;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_info = staking_dispatcher.get_stake_info(:stake_duration, :stake_index).unwrap();
    verify_stake_info(
        stake_info: @stake_info, :stake_index, reward_cycle: 0, :amount, :stake_duration,
    );
}

#[test]
fn test_get_stake_info_not_exist() {
    let mut cfg: TestCfg = Default::default();
    cfg.token_address = deploy_mock_erc20_contract(owner: cfg.owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let staker_supply: Amount = 2000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: staker_supply.into());

    let stake_info = staking_dispatcher
        .get_stake_info(stake_duration: StakeDuration::OneMonth, stake_index: 0);
    assert!(stake_info.is_none());

    let amount: Amount = staker_supply;
    let stake_duration = StakeDuration::OneMonth;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :stake_duration,
    );
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    let stake_info = staking_dispatcher.get_stake_info(:stake_duration, :stake_index);
    assert!(stake_info.is_some());

    let stake_info = staking_dispatcher
        .get_stake_info(stake_duration: StakeDuration::OneMonth, stake_index: 1);
    assert!(stake_info.is_none());

    let stake_info = staking_dispatcher
        .get_stake_info(stake_duration: StakeDuration::ThreeMonths, stake_index: 0);
    assert!(stake_info.is_none());

    let stake_info = staking_dispatcher
        .get_stake_info(stake_duration: StakeDuration::SixMonths, stake_index: 0);
    assert!(stake_info.is_none());

    let stake_info = staking_dispatcher
        .get_stake_info(stake_duration: StakeDuration::TwelveMonths, stake_index: 0);
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
fn test_new_version_no_stakes() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let (token_address, token_dispatcher) = deploy_mock_erc20_contract(2000, staker_address);
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    cheat_caller_address_once(contract_address, owner);
    dispatcher.set_rewards_contract(rewards_contract);

    cheat_caller_address_once(contract_address, rewards_contract);
    dispatcher.new_version();
}

#[test]
fn test_new_version() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let (token_address, token_dispatcher) = deploy_mock_erc20_contract(2000, staker_address);
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    cheat_caller_address_once(contract_address, owner);
    dispatcher.set_rewards_contract(rewards_contract);

    cheat_caller_address_once(contract_address, rewards_contract);
    let total_points = dispatcher.new_version();
    assert!(total_points == 0);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
    let stake_id = dispatcher.stake(amount, duration);
    assert!(stake_id == 1);
}
