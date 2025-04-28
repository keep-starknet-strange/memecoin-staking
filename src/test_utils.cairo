use memecoin_staking::memecoin_rewards::interface::IMemeCoinRewardsDispatcher;
use memecoin_staking::memecoin_staking::interface::IMemeCoinStakingDispatcher;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, load};
use starknet::{ContractAddress, Store};

pub(crate) struct TestCfg {
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

pub(crate) fn load_value<T, +Serde<T>, +Store<T>>(
    contract_address: ContractAddress, storage_address: felt252,
) -> T {
    let size = Store::<T>::size().into();
    let mut loaded_value = load(
        target: contract_address, storage_address: storage_address, size: size,
    )
        .span();
    Serde::<T>::deserialize(ref loaded_value).unwrap()
}


pub(crate) fn deploy_memecoin_staking_contract(
    owner: ContractAddress, token_address: ContractAddress,
) -> IMemeCoinStakingDispatcher {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    token_address.serialize(ref calldata);

    let memecoin_staking_contract = declare("MemeCoinStaking").unwrap().contract_class();
    let (contract_address, _) = memecoin_staking_contract.deploy(@calldata).unwrap();

    IMemeCoinStakingDispatcher { contract_address: contract_address }
}

pub(crate) fn deploy_mock_erc20_contract(
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

pub(crate) fn deploy_memecoin_rewards_contract(
    owner: ContractAddress, staking_address: ContractAddress, token_address: ContractAddress,
) -> IMemeCoinRewardsDispatcher {
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    staking_address.serialize(ref calldata);
    token_address.serialize(ref calldata);

    let memecoin_rewards_contract = declare("MemeCoinRewards").unwrap().contract_class();
    let (contract_address, _) = memecoin_rewards_contract.deploy(@calldata).unwrap();

    IMemeCoinRewardsDispatcher { contract_address: contract_address }
}

pub(crate) fn deploy_all_contracts(
    owner: ContractAddress, initial_supply: u256,
) -> (IMemeCoinStakingDispatcher, IMemeCoinRewardsDispatcher, IERC20Dispatcher) {
    let token = deploy_mock_erc20_contract(initial_supply, owner);
    let staking = deploy_memecoin_staking_contract(owner, token.contract_address);
    let rewards = deploy_memecoin_rewards_contract(
        owner, staking.contract_address, token.contract_address,
    );

    (staking, rewards, token)
}

pub(crate) fn cheat_caller_address_once(
    contract_address: ContractAddress, caller_address: ContractAddress,
) {
    cheat_caller_address_many(contract_address, caller_address, 1);
}

pub(crate) fn cheat_caller_address_many(
    contract_address: ContractAddress, caller_address: ContractAddress, times: u8,
) {
    cheat_caller_address(
        contract_address: contract_address,
        caller_address: caller_address,
        span: CheatSpan::TargetCalls(times.into()),
    );
}
