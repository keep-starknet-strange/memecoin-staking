use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeDurationTrait,
    StakeInfo, StakeInfoTrait,
};
use memecoin_staking::types::{Amount, Cycle, Index};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, load};
use starknet::{ContractAddress, Store};
use starkware_utils::types::time::time::Time;
use starkware_utils_testing::test_utils::cheat_caller_address_once;

pub const INITIAL_SUPPLY: u256 = 100000;
pub const STAKER_SUPPLY: Amount = (INITIAL_SUPPLY / 2).try_into().unwrap();

#[derive(Drop, Copy)]
pub struct TestCfg {
    pub owner: ContractAddress,
    pub rewards_contract: ContractAddress,
    pub staking_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub staker_address: ContractAddress,
    pub staker_supply: Amount,
}

impl TestInitConfigDefault of Default<TestCfg> {
    fn default() -> TestCfg {
        TestCfg {
            owner: 'OWNER'.try_into().unwrap(),
            rewards_contract: 'REWARDS_CONTRACT'.try_into().unwrap(),
            staking_contract: 'STAKING_CONTRACT'.try_into().unwrap(),
            token_address: 'TOKEN_ADDRESS'.try_into().unwrap(),
            staker_address: 'STAKER_ADDRESS'.try_into().unwrap(),
            staker_supply: STAKER_SUPPLY,
        }
    }
}

pub fn deploy_memecoin_staking_contract(ref cfg: TestCfg) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    cfg.owner.serialize(ref output: calldata);
    cfg.token_address.serialize(ref output: calldata);

    let memecoin_staking_contract = declare(contract: "MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract
        .deploy(constructor_calldata: @calldata)
        .unwrap();

    cfg.staking_contract = contract_address;
    contract_address
}

pub fn deploy_memecoin_rewards_contract(ref cfg: TestCfg) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    cfg.owner.serialize(ref output: calldata);
    cfg.staking_contract.serialize(ref output: calldata);
    cfg.token_address.serialize(ref output: calldata);

    let memecoin_rewards_contract = declare(contract: "MemeCoinRewards").unwrap().contract_class();
    let (contract_address, _) = memecoin_rewards_contract
        .deploy(constructor_calldata: @calldata)
        .unwrap();

    cfg.rewards_contract = contract_address;
    contract_address
}

pub fn deploy_mock_erc20_contract(owner: ContractAddress) -> ContractAddress {
    // TODO: Use
    // https://foundry-rs.github.io/starknet-foundry/testing/using-cheatcodes.html?highlight=set_balance#cheating-erc-20-token-balance
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref output: calldata);
    symbol.serialize(ref output: calldata);
    INITIAL_SUPPLY.serialize(ref output: calldata);
    owner.serialize(ref output: calldata);

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
    cfg: TestCfg, staker_address: ContractAddress, amount: Amount, stake_duration: StakeDuration,
) -> Index {
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: cfg.staking_contract };
    cheat_staker_approve_staking(:cfg, :amount);
    cheat_caller_address_once(
        contract_address: cfg.staking_contract, caller_address: staker_address,
    );
    staking_dispatcher.stake(:amount, :stake_duration)
}

pub fn verify_stake_info(
    stake_info: StakeInfo, reward_cycle: Cycle, amount: Amount, stake_duration: StakeDuration,
) {
    let upper_vesting_time_bound = Time::now().add(delta: stake_duration.to_time_delta().unwrap());
    let lower_vesting_time_bound = upper_vesting_time_bound
        .sub_delta(other: Time::seconds(count: 1));
    assert!(stake_info.get_reward_cycle() == reward_cycle);
    assert!(stake_info.get_amount() == amount);
    assert!(stake_info.get_vesting_time() >= lower_vesting_time_bound);
    assert!(stake_info.get_vesting_time() <= upper_vesting_time_bound);
}

pub fn memecoin_staking_test_setup() -> TestCfg {
    let mut cfg: TestCfg = Default::default();
    let owner = cfg.owner;
    cfg.token_address = deploy_mock_erc20_contract(:owner);
    deploy_memecoin_staking_contract(ref :cfg);
    let rewards_contract = deploy_memecoin_rewards_contract(ref :cfg);
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    let config_dispatcher = IMemeCoinStakingConfigDispatcher {
        contract_address: cfg.staking_contract,
    };
    cheat_caller_address_once(
        contract_address: config_dispatcher.contract_address, caller_address: owner,
    );
    config_dispatcher.set_rewards_contract(:rewards_contract);

    // Transfer to staker.
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    token_dispatcher.transfer(recipient: cfg.staker_address, amount: cfg.staker_supply.into());

    cfg
}

pub fn cheat_staker_approve_staking(cfg: TestCfg, amount: Amount) {
    let token_dispatcher = IERC20Dispatcher { contract_address: cfg.token_address };
    cheat_caller_address_once(
        contract_address: cfg.token_address, caller_address: cfg.staker_address,
    );
    token_dispatcher.approve(spender: cfg.staking_contract, amount: amount.into());
}

pub fn calculate_points(amount: Amount, stake_duration: StakeDuration) -> u128 {
    let multiplier = stake_duration.get_multiplier().unwrap();
    let points = amount * multiplier.into();

    points
}
