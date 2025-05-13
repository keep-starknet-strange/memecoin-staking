use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::test_utils::{
    TestCfg, approve_and_stake, deploy_memecoin_staking_contract, deploy_mock_erc20_contract,
    load_value,
};
use memecoin_staking::types::{Amount, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starkware_utils::test_utils::cheat_caller_address_once;

#[test]
fn test_constructor() {
    let cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );

    let loaded_owner = load_value(:contract_address, storage_address: selector!("owner"));
    assert!(loaded_owner == cfg.owner);

    let loaded_current_version = load_value::<
        Version,
    >(:contract_address, storage_address: selector!("current_version"));
    assert!(loaded_current_version == 0);

    let loaded_token_dispatcher = load_value::<
        IERC20Dispatcher,
    >(:contract_address, storage_address: selector!("token_dispatcher"));
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}

#[test]
fn test_set_rewards_contract() {
    let cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address };

    cheat_caller_address_once(:contract_address, caller_address: cfg.owner);
    dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);

    let loaded_rewards_contract = load_value(
        :contract_address, storage_address: selector!("rewards_contract"),
    );

    assert!(loaded_rewards_contract == cfg.rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_staking_contract(
        owner: cfg.owner, token_address: cfg.token_address,
    );
    let dispatcher = IMemeCoinStakingConfigDispatcher { contract_address };

    dispatcher.set_rewards_contract(rewards_contract: cfg.rewards_contract);
}

#[test]
fn test_stake() {
    let cfg: TestCfg = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: 2000, recipient: cfg.staker_address,
    );
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let contract_address = deploy_memecoin_staking_contract(owner: cfg.owner, :token_address);
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address };

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    let stake_id = approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );
    assert!(stake_id == 1);

    let amount: Amount = 1000;
    let duration = StakeDuration::ThreeMonths;
    let stake_id = approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        staker_address: cfg.staker_address,
        :amount,
        :duration,
    );
    assert!(stake_id == 2);

    let loaded_current_version = load_value::<
        Version,
    >(:contract_address, storage_address: selector!("current_version"));
    assert!(loaded_current_version == 0);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let cfg: TestCfg = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: 1000, recipient: cfg.staker_address,
    );
    let contract_address = deploy_memecoin_staking_contract(owner: cfg.owner, :token_address);
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address };

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(:contract_address, caller_address: cfg.staker_address);
    staking_dispatcher.stake(:amount, :duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let cfg: TestCfg = Default::default();
    let token_address = deploy_mock_erc20_contract(
        initial_supply: 500, recipient: cfg.staker_address,
    );
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let contract_address = deploy_memecoin_staking_contract(owner: cfg.owner, :token_address);
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address };

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(contract_address: token_address, caller_address: cfg.staker_address);
    token_dispatcher.approve(spender: contract_address, amount: amount.into());
    cheat_caller_address_once(:contract_address, caller_address: cfg.staker_address);
    staking_dispatcher.stake(:amount, :duration);
}

