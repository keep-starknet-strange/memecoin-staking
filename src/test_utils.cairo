use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration,
};
use memecoin_staking::types::{Amount, Index};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};
use starknet::{ContractAddress, Store};
use starkware_utils::test_utils::cheat_caller_address_once;

pub struct TestCfg {
    pub owner: ContractAddress,
    pub rewards_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub staker_address: ContractAddress,
}

impl TestInitConfigDefault of Default<TestCfg> {
    fn default() -> TestCfg {
        TestCfg {
            owner: 'OWNER'.try_into().unwrap(),
            rewards_contract: 'REWARDS_CONTRACT'.try_into().unwrap(),
            token_address: 'TOKEN_ADDRESS'.try_into().unwrap(),
            staker_address: 'STAKER_ADDRESS'.try_into().unwrap(),
        }
    }
}

pub fn deploy_memecoin_staking_contract(
    owner: ContractAddress, token_address: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref output: calldata);
    token_address.serialize(ref output: calldata);

    let memecoin_staking_contract = declare(contract: "MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract
        .deploy(constructor_calldata: @calldata)
        .unwrap();

    contract_address
}

pub fn deploy_mock_erc20_contract(
    initial_supply: u256, recipient: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref output: calldata);
    symbol.serialize(ref output: calldata);
    initial_supply.serialize(ref output: calldata);
    recipient.serialize(ref output: calldata);

    let erc20_contract = declare(contract: "DualCaseERC20Mock").unwrap().contract_class();
    let (contract_address, _) = erc20_contract.deploy(constructor_calldata: @calldata).unwrap();

    contract_address
}

pub fn load_value<T, +Serde<T>, +Store<T>>(
    contract_address: ContractAddress, storage_address: felt252,
) -> T {
    let size = Store::<T>::size().into();
    let mut loaded_value = load(target: contract_address, :storage_address, :size).span();
    Serde::deserialize(ref serialized: loaded_value).unwrap()
}

pub fn approve_and_stake(
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
