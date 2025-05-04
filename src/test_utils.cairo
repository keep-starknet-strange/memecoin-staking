use memecoin_staking::memecoin_staking::interface::IMemeCoinStakingDispatcher;
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::ContractAddress;

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
