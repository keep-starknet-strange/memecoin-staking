use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};

fn deploy_memecoin_staking_contract(
    owner: ContractAddress,
    token_address: ContractAddress,
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
    cheat_caller_address(
        contract_address: contract_address,
        caller_address: caller_address,
        span: CheatSpan::TargetCalls(1),
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
