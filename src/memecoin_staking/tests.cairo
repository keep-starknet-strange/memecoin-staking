use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeDurationTrait,
    StakeInfo,
};
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};
use starkware_utils::types::time::time::Time;
fn deploy_memecoin_staking_contract(
    owner: ContractAddress, token_address: ContractAddress,
) -> (ContractAddress, IMemeCoinStakingDispatcher) {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    token_address.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    (contract_address, IMemeCoinStakingDispatcher { contract_address: contract_address })
}

fn deploy_mock_erc20_contract(
    initial_supply: u256, owner_address: ContractAddress,
) -> (ContractAddress, IERC20Dispatcher) {
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    owner_address.serialize(ref calldata);

    let erc20_contract = declare("DualCaseERC20Mock").unwrap().contract_class();
    let (contract_address, _) = erc20_contract.deploy(@calldata).unwrap();

    (contract_address, IERC20Dispatcher { contract_address: contract_address })
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

#[test]
fn test_constructor() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let token_address = 'TOKEN_ADDRESS'.try_into().unwrap();
    let (contract_address, _) = deploy_memecoin_staking_contract(owner, token_address);

    let loaded_owner: ContractAddress = (*load(
        target: contract_address,
        storage_address: selector!("owner"),
        size: Store::<ContractAddress>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();

    assert!(loaded_owner == owner);
}

#[test]
fn test_set_rewards_contract() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let token_address = 'TOKEN_ADDRESS'.try_into().unwrap();
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();

    cheat_caller_address(
        contract_address: contract_address, caller_address: owner, span: CheatSpan::TargetCalls(1),
    );
    dispatcher.set_rewards_contract(rewards_contract);

    let loaded_rewards_contract = (*load(
        target: contract_address,
        storage_address: selector!("rewards_contract"),
        size: Store::<ContractAddress>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();

    assert!(loaded_rewards_contract == rewards_contract);
}

#[test]
#[should_panic(expected: "Can only be called by the owner")]
fn test_set_rewards_contract_wrong_caller() {
    let owner: ContractAddress = 'owner'.try_into().unwrap();
    let token_address = 'TOKEN_ADDRESS'.try_into().unwrap();
    let (_, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let rewards_contract: ContractAddress = 'REWARDS_CONTRACT'.try_into().unwrap();
    dispatcher.set_rewards_contract(rewards_contract);
}

#[test]
fn test_stake() {
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let (token_address, token_dispatcher) = deploy_mock_erc20_contract(2000, staker_address);
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
    let stake_id = dispatcher.stake(amount, duration);
    assert!(stake_id == 1);

    let duration = StakeDuration::ThreeMonths;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
    let stake_id = dispatcher.stake(amount, duration);
    assert!(stake_id == 2);

    let loaded_stake_id: Index = (*load(
        target: contract_address,
        storage_address: selector!("stake_index"),
        size: Store::<Index>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    assert!(loaded_stake_id == 3);

    let loaded_current_version: Version = (*load(
        target: contract_address,
        storage_address: selector!("current_version"),
        size: Store::<Version>::size().into(),
    )
        .at(0))
        .try_into()
        .unwrap();
    assert!(loaded_current_version == 0);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let (token_address, _) = deploy_mock_erc20_contract(1000, staker_address);
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(contract_address, staker_address);
    dispatcher.stake(amount, duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let (token_address, token_dispatcher) = deploy_mock_erc20_contract(500, staker_address);
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
    dispatcher.stake(amount, duration);
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

fn stake_and_verify_stake_info(
    contract_address: ContractAddress,
    staker_address: ContractAddress,
    token_address: ContractAddress,
    amount: Amount,
    duration: StakeDuration,
    stake_count: u8,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: contract_address };
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_many(contract_address, staker_address, 2);
    let stake_id = staking_dispatcher.stake(amount, duration);
    let stake_info = staking_dispatcher.get_stake_info();
    verify_stake_info(stake_info.at(stake_count.into()), stake_id, 0, amount, duration);
}

#[test]
fn test_get_stake_info() {
    let owner: ContractAddress = 'OWNER'.try_into().unwrap();
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let (token_address, _) = deploy_mock_erc20_contract(2000, staker_address);
    let (contract_address, dispatcher) = deploy_memecoin_staking_contract(owner, token_address);

    cheat_caller_address_once(token_address, staker_address);
    let stake_info = dispatcher.get_stake_info();
    assert!(stake_info.len() == 0);

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    stake_and_verify_stake_info(
        contract_address, staker_address, token_address, amount, duration, 0,
    );

    let amount: Amount = 500;
    let duration = StakeDuration::ThreeMonths;
    stake_and_verify_stake_info(
        contract_address, staker_address, token_address, amount, duration, 1,
    );

    let amount: Amount = 250;
    let duration = StakeDuration::SixMonths;
    stake_and_verify_stake_info(
        contract_address, staker_address, token_address, amount, duration, 2,
    );

    let amount: Amount = 125;
    let duration = StakeDuration::TwelveMonths;
    stake_and_verify_stake_info(
        contract_address, staker_address, token_address, amount, duration, 3,
    );
}
