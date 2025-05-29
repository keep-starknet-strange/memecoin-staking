use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::{IMemeCoinStakingDispatcher, StakeDuration};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_fund, approve_and_stake, calculate_points,
    deploy_memecoin_rewards_contract, load_value, memecoin_staking_test_setup,
};
use memecoin_staking::types::Amount;
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
fn test_claim_rewards() {
    let cfg = memecoin_staking_test_setup();
    let staker_address = cfg.staker_address;
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };
    let mut staking_contract_balance: Amount = 0;

    // Test full cycle rewards.
    let amount = 1000;
    let stake_duration = StakeDuration::OneMonth;
    approve_and_stake(:cfg, :staker_address, :amount, :stake_duration);
    staking_contract_balance += amount;

    let fund_amount: Amount = 1000;
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
#[should_panic(expected: "Can only be called by the staking contract")]
fn test_claim_rewards_wrong_caller() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    rewards_dispatcher.claim_rewards(points: 1000, reward_cycle: 0);
}

#[test]
#[should_panic(expected: "Reward cycle does not exist")]
fn test_claim_rewards_invalid_cycle() {
    let cfg = memecoin_staking_test_setup();
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: cfg.rewards_contract };

    cheat_caller_address_once(
        contract_address: cfg.rewards_contract, caller_address: cfg.staking_contract,
    );
    rewards_dispatcher.claim_rewards(points: 1000, reward_cycle: 0);
}
