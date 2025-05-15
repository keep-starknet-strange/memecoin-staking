use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::{IMemeCoinStakingDispatcher, StakeDuration};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_stake, deploy_all_contracts, deploy_memecoin_rewards_contract, load_value,
};
use memecoin_staking::types::Version;
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

    let fund_amount = 1000;
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.approve(spender: cfg.rewards_contract, amount: fund_amount.into());
    cheat_caller_address_once(contract_address: cfg.rewards_contract, caller_address: cfg.owner);
    rewards_dispatcher.fund(amount: fund_amount);
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
