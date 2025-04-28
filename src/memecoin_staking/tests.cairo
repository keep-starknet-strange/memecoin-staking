use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};

fn deploy_memecoin_staking_contract(token_address: ContractAddress) -> IMemeCoinStakingDispatcher {
    let mut calldata = ArrayTrait::new();
    token_address.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    IMemeCoinStakingDispatcher { contract_address: contract_address }
}

fn deploy_mock_erc20_contract(
    initial_supply: u256, recipient: ContractAddress,
) -> IERC20Dispatcher {
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    initial_supply.serialize(ref calldata);
    recipient.serialize(ref calldata);

    let erc20_contract = declare("DualCaseERC20Mock").unwrap().contract_class();
    let (contract_address, _) = erc20_contract.deploy(@calldata).unwrap();

    IERC20Dispatcher { contract_address: contract_address }
}

fn cheat_caller_address_once(contract_address: ContractAddress, caller_address: ContractAddress) {
    cheat_caller_address(
        contract_address: contract_address,
        caller_address: caller_address,
        span: CheatSpan::TargetCalls(1),
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
fn test_stake() {
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let token_dispatcher = deploy_mock_erc20_contract(2000, staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
    let stake_id = staking_dispatcher.stake(amount, duration);
    assert!(stake_id == 1);

    let duration = StakeDuration::ThreeMonths;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
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
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let token_dispatcher = deploy_mock_erc20_contract(1000, staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(contract_address, staker_address);
    staking_dispatcher.stake(amount, duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let staker_address: ContractAddress = 'STAKER_ADDRESS'.try_into().unwrap();
    let token_dispatcher = deploy_mock_erc20_contract(500, staker_address);
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(token_address, staker_address);
    token_dispatcher.approve(contract_address, amount.into());
    cheat_caller_address_once(contract_address, staker_address);
    staking_dispatcher.stake(amount, duration);
}
