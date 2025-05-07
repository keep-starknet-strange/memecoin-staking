use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};
use starknet::{ContractAddress, Store};
use starkware_utils::test_utils::cheat_caller_address_once;

struct TestCfg {
    pub token_address: ContractAddress,
    pub staker_address: ContractAddress,
}

impl TestInitConfigDefault of Default<TestCfg> {
    fn default() -> TestCfg {
        TestCfg {
            token_address: 'TOKEN_ADDRESS'.try_into().unwrap(),
            staker_address: 'STAKER_ADDRESS'.try_into().unwrap(),
        }
    }
}

fn deploy_memecoin_staking_contract(token_address: ContractAddress) -> IMemeCoinStakingDispatcher {
    let mut calldata = ArrayTrait::new();
    token_address.serialize(ref output: calldata);

    let memecoin_staking_contract = declare(contract: "MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract
        .deploy(constructor_calldata: @calldata)
        .unwrap();

    IMemeCoinStakingDispatcher { contract_address: contract_address }
}

fn deploy_mock_erc20_contract(
    initial_supply: u256, recipient: ContractAddress,
) -> IERC20Dispatcher {
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref output: calldata);
    symbol.serialize(ref output: calldata);
    initial_supply.serialize(ref output: calldata);
    recipient.serialize(ref output: calldata);

    let erc20_contract = declare(contract: "DualCaseERC20Mock").unwrap().contract_class();
    let (contract_address, _) = erc20_contract.deploy(constructor_calldata: @calldata).unwrap();

    IERC20Dispatcher { contract_address: contract_address }
}

fn load_value<T, +Serde<T>, +Store<T>>(
    contract_address: ContractAddress, storage_address: felt252,
) -> T {
    let size = Store::<T>::size().into();
    let mut loaded_value = load(target: contract_address, :storage_address, :size).span();
    Serde::<T>::deserialize(ref serialized: loaded_value).unwrap()
}

fn approve_and_stake(
    token_dispatcher: @IERC20Dispatcher,
    staking_dispatcher: @IMemeCoinStakingDispatcher,
    staker_address: ContractAddress,
    amount: Amount,
    duration: StakeDuration,
) -> Index {
    cheat_caller_address_once(
        contract_address: *token_dispatcher.contract_address, caller_address: staker_address,
    );
    token_dispatcher.approve(spender: *staking_dispatcher.contract_address, amount: amount.into());
    cheat_caller_address_once(
        contract_address: *staking_dispatcher.contract_address, caller_address: staker_address,
    );
    staking_dispatcher.stake(:amount, :duration)
}

#[test]
fn test_constructor() {
    let cfg: TestCfg = Default::default();
    let staking_dispatcher = deploy_memecoin_staking_contract(token_address: cfg.token_address);
    let contract_address = staking_dispatcher.contract_address;

    let loaded_stake_index = load_value::<
        Index,
    >(:contract_address, storage_address: selector!("stake_index"));
    assert!(loaded_stake_index == 1);

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
fn test_stake() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(
        initial_supply: 2000, recipient: cfg.staker_address,
    );
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(token_address: token_address);
    let contract_address = staking_dispatcher.contract_address;

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

    let loaded_stake_id = load_value::<
        Index,
    >(:contract_address, storage_address: selector!("stake_index"));
    assert!(loaded_stake_id == 3);

    let loaded_current_version = load_value::<
        Version,
    >(:contract_address, storage_address: selector!("current_version"));
    assert!(loaded_current_version == 0);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_stake_without_approve() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(
        initial_supply: 1000, recipient: cfg.staker_address,
    );
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(:token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(:contract_address, caller_address: cfg.staker_address);
    staking_dispatcher.stake(:amount, :duration);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_stake_insufficient_balance() {
    let cfg: TestCfg = Default::default();
    let token_dispatcher = deploy_mock_erc20_contract(
        initial_supply: 500, recipient: cfg.staker_address,
    );
    let token_address = token_dispatcher.contract_address;
    let staking_dispatcher = deploy_memecoin_staking_contract(:token_address);
    let contract_address = staking_dispatcher.contract_address;

    let amount: Amount = 1000;
    let duration = StakeDuration::OneMonth;
    cheat_caller_address_once(contract_address: token_address, caller_address: cfg.staker_address);
    token_dispatcher.approve(spender: contract_address, amount: amount.into());
    cheat_caller_address_once(:contract_address, caller_address: cfg.staker_address);
    staking_dispatcher.stake(:amount, :duration);
}
