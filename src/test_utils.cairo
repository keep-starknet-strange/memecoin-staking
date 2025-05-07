use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeInfo, StakeDurationTrait,
};
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};
use starknet::{ContractAddress, Store};
use starkware_utils::test_utils::cheat_caller_address_once;
use starkware_utils::types::time::time::Time;
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

pub fn verify_stake_info(
    stake_info: @StakeInfo, id: Index, version: Version, amount: Amount, duration: StakeDuration,
) {
    let lower_vesting_time_bound = Time::now().add(duration.to_time_delta() - Time::seconds(1));
    let upper_vesting_time_bound = lower_vesting_time_bound.add(Time::seconds(1));
    assert!(stake_info.id == @id);
    assert!(stake_info.version == @version);
    assert!(stake_info.amount == @amount);
    assert!(stake_info.vesting_time >= @lower_vesting_time_bound);
    assert!(stake_info.vesting_time <= @upper_vesting_time_bound);
}

pub fn stake_and_verify_stake_info(
    contract_address: ContractAddress,
    staker_address: ContractAddress,
    token_address: ContractAddress,
    amount: Amount,
    duration: StakeDuration,
    stake_count: u8,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: contract_address };
    let stake_id = approve_and_stake(
        @token_dispatcher, @staking_dispatcher, staker_address, amount, duration,
    );
    cheat_caller_address_once(contract_address, staker_address);
    let stake_info = staking_dispatcher.get_stake_info();
    verify_stake_info(stake_info.at(stake_count.into()), stake_id, 0, amount, duration);
}

