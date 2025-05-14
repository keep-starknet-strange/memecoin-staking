use memecoin_staking::memecoin_rewards::interface::{
    IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
};
use memecoin_staking::memecoin_staking::interface::{
    IMemeCoinStakingConfigDispatcher, IMemeCoinStakingConfigDispatcherTrait,
    IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait, StakeDuration, StakeDurationTrait,
    StakeInfo, StakeInfoTrait,
};
use memecoin_staking::types::{Amount, Index, Version};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load,
};
use starknet::{ContractAddress, Store};
use starkware_utils::types::time::time::Time;
use starkware_utils_testing::test_utils::cheat_caller_address_once;

pub const INITIAL_SUPPLY: u256 = 100000;

#[derive(Drop)]
pub struct TestCfg {
    pub owner: ContractAddress,
    pub rewards_contract: ContractAddress,
    pub staking_contract: ContractAddress,
    pub token_address: ContractAddress,
    pub staker_address: ContractAddress,
    pub second_staker_address: ContractAddress,
}

impl TestInitConfigDefault of Default<TestCfg> {
    fn default() -> TestCfg {
        TestCfg {
            owner: 'OWNER'.try_into().unwrap(),
            rewards_contract: 'REWARDS_CONTRACT'.try_into().unwrap(),
            staking_contract: 'STAKING_CONTRACT'.try_into().unwrap(),
            token_address: 'TOKEN_ADDRESS'.try_into().unwrap(),
            staker_address: 'STAKER_ADDRESS'.try_into().unwrap(),
            second_staker_address: 'SECOND_STAKER_ADDRESS'.try_into().unwrap(),
        }
    }
}

pub fn cheat_caller_address_many(
    contract_address: ContractAddress, caller_address: ContractAddress, count: u8,
) {
    cheat_caller_address(
        :contract_address, :caller_address, span: CheatSpan::TargetCalls(count.into()),
    );
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

pub fn deploy_memecoin_rewards_contract(
    owner: ContractAddress, staking_address: ContractAddress, token_address: ContractAddress,
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref output: calldata);
    staking_address.serialize(ref output: calldata);
    token_address.serialize(ref output: calldata);

    let memecoin_rewards_contract = declare(contract: "MemeCoinRewards").unwrap().contract_class();
    let (contract_address, _) = memecoin_rewards_contract
        .deploy(constructor_calldata: @calldata)
        .unwrap();

    contract_address
}

pub fn deploy_mock_erc20_contract(recipient: ContractAddress) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let name: ByteArray = "NAME";
    let symbol: ByteArray = "SYMBOL";
    name.serialize(ref output: calldata);
    symbol.serialize(ref output: calldata);
    INITIAL_SUPPLY.serialize(ref output: calldata);
    recipient.serialize(ref output: calldata);

    let erc20_contract = declare(contract: "DualCaseERC20Mock").unwrap().contract_class();
    let (contract_address, _) = erc20_contract.deploy(constructor_calldata: @calldata).unwrap();

    contract_address
}

pub fn deploy_all_contracts(
    ref cfg: TestCfg,
) -> (ContractAddress, ContractAddress, ContractAddress) {
    cfg.token_address = deploy_mock_erc20_contract(recipient: cfg.owner);
    cheat_caller_address_once(contract_address: cfg.token_address, caller_address: cfg.owner);
    IERC20Dispatcher { contract_address: cfg.token_address }
        .transfer(recipient: cfg.staker_address, amount: INITIAL_SUPPLY / 2);

    cfg
        .staking_contract =
            deploy_memecoin_staking_contract(owner: cfg.owner, token_address: cfg.token_address);
    cfg
        .rewards_contract =
            deploy_memecoin_rewards_contract(
                owner: cfg.owner,
                staking_address: cfg.staking_contract,
                token_address: cfg.token_address,
            );
    cheat_caller_address_once(contract_address: cfg.staking_contract, caller_address: cfg.owner);
    IMemeCoinStakingConfigDispatcher { contract_address: cfg.staking_contract }
        .set_rewards_contract(rewards_contract: cfg.rewards_contract);

    (cfg.token_address, cfg.staking_contract, cfg.rewards_contract)
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
    let upper_vesting_time_bound = Time::now().add(delta: duration.to_time_delta().unwrap());
    let lower_vesting_time_bound = upper_vesting_time_bound
        .sub_delta(other: Time::seconds(count: 1));
    assert!(stake_info.get_id() == id);
    assert!(stake_info.get_version() == version);
    assert!(stake_info.get_amount() == amount);
    assert!(stake_info.get_vesting_time() >= lower_vesting_time_bound);
    assert!(stake_info.get_vesting_time() <= upper_vesting_time_bound);
}

pub fn stake_and_verify_stake_info(
    contract_address: ContractAddress,
    staker_address: ContractAddress,
    token_address: ContractAddress,
    amount: Amount,
    duration: StakeDuration,
    version: Version,
) {
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: contract_address };
    let stake_id = approve_and_stake(
        token_dispatcher: @token_dispatcher,
        staking_dispatcher: @staking_dispatcher,
        :staker_address,
        :amount,
        :duration,
    );
    cheat_caller_address_once(:contract_address, caller_address: staker_address);
    let stake_info = staking_dispatcher.get_stake_info();
    verify_stake_info(
        stake_info: find_stake_by_id(stake_info: @stake_info, id: stake_id).unwrap(),
        id: stake_id,
        :version,
        :amount,
        :duration,
    );
}

pub fn find_stake_by_id(stake_info: @Span<StakeInfo>, id: Index) -> Option<@StakeInfo> {
    for i in 0..stake_info.len() {
        if stake_info.at(index: i).get_id() == id {
            return Some(stake_info.at(index: i));
        }
    }
    None
}

pub fn get_all_dispatchers(
    cfg: @TestCfg,
) -> (IERC20Dispatcher, IMemeCoinStakingDispatcher, IMemeCoinRewardsDispatcher) {
    let token_dispatcher = IERC20Dispatcher { contract_address: *cfg.token_address };
    let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: *cfg.staking_contract };
    let rewards_dispatcher = IMemeCoinRewardsDispatcher { contract_address: *cfg.rewards_contract };
    (token_dispatcher, staking_dispatcher, rewards_dispatcher)
}

pub fn approve_and_fund(cfg: @TestCfg, amount: Amount) {
    let (token_dispatcher, _, rewards_dispatcher) = get_all_dispatchers(cfg: cfg);
    cheat_caller_address_once(
        contract_address: token_dispatcher.contract_address, caller_address: *cfg.owner,
    );
    token_dispatcher.approve(spender: rewards_dispatcher.contract_address, amount: amount.into());
    cheat_caller_address_once(
        contract_address: rewards_dispatcher.contract_address, caller_address: *cfg.owner,
    );
    rewards_dispatcher.fund(amount: amount);
}
