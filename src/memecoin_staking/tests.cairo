use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeDurationTrait,
    StakeInfo,
};
use memecoin_staking::test_utils::*;
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{CheatSpan, cheat_caller_address, load};
use starknet::{ContractAddress, Store};
use starkware_utils::types::time::time::Time;

struct TestCfg {
    pub owner: ContractAddress,
    pub rewards_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub staker_address: ContractAddress,
}

impl TestInitConfigDefault of Default<TestCfg> {
    fn default() -> TestCfg {
        TestCfg {
            token_address: 'TOKEN_ADDRESS'.try_into().unwrap(),
            staker_address: 'STAKER_ADDRESS'.try_into().unwrap(),
            owner: 'OWNER'.try_into().unwrap(),
            rewards_contract: 'REWARDS_CONTRACT'.try_into().unwrap(),
        }
    }
}

fn deploy_memecoin_staking_contract(
    owner: ContractAddress, token_address: ContractAddress,
) -> IMemeCoinStakingDispatcher {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    token_address.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    IMemeCoinStakingDispatcher { contract_address: contract_address }
}

fn deploy_mock_erc20_contract(
    initial_supply: u256, owner_address: ContractAddress,
) -> IERC20Dispatcher {
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    owner_address.serialize(ref calldata);

    let erc20_contract = declare("DualCaseERC20Mock").unwrap().contract_class();
    let (contract_address, _) = erc20_contract.deploy(@calldata).unwrap();

    IERC20Dispatcher { contract_address: contract_address }
}

fn cheat_caller_address_once(contract_address: ContractAddress, caller_address: ContractAddress) {
    cheat_caller_address_many(contract_address, caller_address, 1);
}

fn cheat_caller_address_many(
    contract_address: ContractAddress, caller_address: ContractAddress, times: u8,
) {
    cheat_caller_address(
        contract_address: contract_address,
        caller_address: caller_address,
        span: CheatSpan::TargetCalls(times.into()),
    );
}

fn load_value<T, +Serde<T>, +Store<T>>(
    contract_address: ContractAddress, storage_address: felt252,
) -> T {
    let size = Store::<T>::size().into();
    let mut loaded_value = load(
        target: contract_address, storage_address: storage_address, size: size,
    )
        .span();
    Serde::<T>::deserialize(ref loaded_value).unwrap()
}

#[test]
fn test_constructor() {
    let cfg: TestCfg = Default::default();
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, cfg.token_address);
    let contract_address = staking_dispatcher.contract_address;

    let loaded_owner = load_value::<ContractAddress>(contract_address, selector!("owner"));
    assert!(loaded_owner == cfg.owner);

    let loaded_current_version = load_value::<
        Version,
    >(contract_address, selector!("current_version"));
    assert!(loaded_current_version == 0);

    let loaded_stake_index = load_value::<Index>(contract_address, selector!("stake_index"));
    assert!(loaded_stake_index == 1);

    let loaded_token_dispatcher = load_value::<
        IERC20Dispatcher,
    >(contract_address, selector!("token_dispatcher"));
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}

#[test]
fn test_set_rewards_contract() {
    let cfg: TestCfg = Default::default();
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, cfg.token_address);
    let contract_address = staking_dispatcher.contract_address;

    cheat_caller_address_once(contract_address, cfg.owner);
    staking_dispatcher.set_rewards_contract(cfg.rewards_contract);

    let loaded_rewards_contract = load_value::<
        ContractAddress,
    >(contract_address, selector!("rewards_contract"));

    assert!(loaded_rewards_contract == cfg.rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let cfg: TestCfg = Default::default();
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, cfg.token_address);

    staking_dispatcher.set_rewards_contract(cfg.rewards_contract);
}

#[test]
fn test_stake() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(2000, cfg.staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, cfg.staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, cfg.staker_address);
    let stake_id = staking_dispatcher.stake(amount, duration);
    assert!(stake_id == 1);

    let duration = StakeDuration::ThreeMonths;
    cheat_caller_address_once(token_address, cfg.staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, cfg.staker_address);
    let stake_id = staking_dispatcher.stake(amount, duration);
    assert!(stake_id == 2);

    let loaded_stake_id = load_value::<Index>(contract_address, selector!("stake_index"));
    assert!(loaded_stake_id == 3);

    let loaded_current_version = load_value::<
        Version,
    >(contract_address, selector!("current_version"));
    assert!(loaded_current_version == 0);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(1000, cfg.staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(contract_address, cfg.staker_address);
    staking_dispatcher.stake(amount, duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(500, cfg.staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, cfg.staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, cfg.staker_address);
    staking_dispatcher.stake(amount, duration);
}

fn verify_stake_info(
    stake_info: @StakeInfo, id: Index, version: Version, amount: Amount, duration: StakeDuration,
) {
    let lower_vesting_time_bound = Time::now().add(duration.to_time_delta() - Time::seconds(1));
    let upper_vesting_time_bound = Time::now().add(duration.to_time_delta());
    assert!(stake_info.id == @id);
    assert!(stake_info.version == @version);
    assert!(stake_info.amount == @amount);
    assert!(stake_info.vesting_time >= @lower_vesting_time_bound);
    assert!(stake_info.vesting_time <= @upper_vesting_time_bound);
}

fn find_stake_by_id(stake_info: @Span<StakeInfo>, id: Index) -> Option<@StakeInfo> {
    for i in 0..stake_info.len() {
        if stake_info.at(i).id == @id {
            return Some(stake_info.at(i));
        }
    }
    None
}

fn stake_and_verify_stake_info(
    contract_address: ContractAddress,
    staker_address: ContractAddress,
    token_address: ContractAddress,
    amount: Amount,
    duration: StakeDuration,
    version: Version,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: contract_address };
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_many(contract_address, staker_address, 2);
    let stake_id = staking_dispatcher.stake(amount, duration);
    let stake_info = staking_dispatcher.get_stake_info();
    let stake_info = find_stake_by_id(@stake_info, stake_id);
    verify_stake_info(stake_info.unwrap(), stake_id, version, amount, duration);
}

#[test]
fn test_get_stake_info() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(2000, cfg.staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(cfg.owner, token_address);
    let contract_address = staking_dispatcher.contract_address;

    cheat_caller_address_once(token_address, cfg.staker_address);
    let stake_info = staking_dispatcher.get_stake_info();
    assert!(stake_info.len() == 0);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    stake_and_verify_stake_info(
        contract_address, cfg.staker_address, token_address, amount, duration, 0,
    );

    let amount: Amount = 500;
    let duration = StakeDuration::ThreeMonths;
    stake_and_verify_stake_info(
        contract_address, cfg.staker_address, token_address, amount, duration, 0,
    );

    let amount: Amount = 250;
    let duration = StakeDuration::SixMonths;
    stake_and_verify_stake_info(
        contract_address, cfg.staker_address, token_address, amount, duration, 0,
    );

    let amount: Amount = 125;
    let duration = StakeDuration::TwelveMonths;
    stake_and_verify_stake_info(
        contract_address, cfg.staker_address, token_address, amount, duration, 0,
    );
}

#[test]
#[should_panic(expected: "Can't close version with no stakes")]
fn test_new_version_no_stakes() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let token_dispatcher = deploy_mock_erc20_contract(2000, staker_address);
    let staking_dispatcher = deploy_memecoin_staking_contract(
        owner, token_dispatcher.contract_address,
    );

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    cheat_caller_address_once(staking_dispatcher.contract_address, owner);
    staking_dispatcher.set_rewards_contract(rewards_contract);

    cheat_caller_address_once(staking_dispatcher.contract_address, rewards_contract);
    staking_dispatcher.new_version();
}

#[test]
fn test_new_version() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let token_dispatcher = deploy_mock_erc20_contract(2000, staker_address);
    let staking_dispatcher = deploy_memecoin_staking_contract(
        owner, token_dispatcher.contract_address,
    );

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    cheat_caller_address_once(staking_dispatcher.contract_address, owner);
    staking_dispatcher.set_rewards_contract(rewards_contract);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    stake_and_verify_stake_info(
        staking_dispatcher.contract_address,
        staker_address,
        token_dispatcher.contract_address,
        amount,
        duration,
        0,
    );

    cheat_caller_address_once(staking_dispatcher.contract_address, rewards_contract);
    let total_points = staking_dispatcher.new_version();
    assert!(total_points == amount * duration.get_multiplier().into());

    let amount: Amount = 1000;
    let duration = StakeDuration::ThreeMonths;
    stake_and_verify_stake_info(
        staking_dispatcher.contract_address,
        staker_address,
        token_dispatcher.contract_address,
        amount,
        duration,
        1,
    );

    cheat_caller_address_once(staking_dispatcher.contract_address, rewards_contract);
    let total_points = staking_dispatcher.new_version();
    assert!(total_points == amount * duration.get_multiplier().into());
}
