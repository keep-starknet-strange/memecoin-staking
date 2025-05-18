use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::test_utils::{
    INITIAL_SUPPLY, TestCfg, approve_and_stake, deploy_memecoin_staking_contract,
    deploy_mock_erc20_contract, load_value,
};
use memecoin_staking::types::{Amount, Cycle};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starkware_utils::test_utils::cheat_caller_address_once;

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
    deploy_mock_erc20_contract(ref :cfg);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };

    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: 2000);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :duration,
    );
    assert!(stake_index == 0);

    let amount: Amount = 1000;
    let duration = StakeDuration::ThreeMonths;
    let stake_index = approve_and_stake(
        cfg: @cfg, staker_address: cfg.staker_address, :amount, :duration,
    );
    assert!(stake_index == 1);

    let loaded_current_reward_cycle = load_value::<
        Cycle,
    >(contract_address: cfg.staking_contract, storage_address: selector!("current_reward_cycle"));
    assert!(loaded_current_reward_cycle == 0);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let mut cfg: TestCfg = Default::default();
    deploy_mock_erc20_contract(ref :cfg);
    deploy_memecoin_staking_contract(ref :cfg);
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.stake(:amount, :duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let mut cfg: TestCfg = Default::default();
    deploy_mock_erc20_contract(ref :cfg);
    deploy_memecoin_staking_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };

    let amount: u256 = INITIAL_SUPPLY + 1;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(
        contract_address: cfg.token_address, caller_address: cfg.staker_address,
    );
    token_dispatcher.approve(spender: cfg.staking_contract, amount: amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: cfg.staker_address,
    );
    staking_dispatcher.stake(amount: amount.try_into().unwrap(), :duration);
}

