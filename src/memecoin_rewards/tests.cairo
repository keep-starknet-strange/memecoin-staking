use memecoin_staking::memecoin_staking::interface::IMemeCoinStakingDispatcher;
use memecoin_staking::test_utils::{TestCfg, deploy_memecoin_rewards_contract, load_value};
use openzeppelin::token::erc20::interface::IERC20Dispatcher;

#[test]
fn test_constructor() {
    let mut cfg: TestCfg = Default::default();
    let contract_address = deploy_memecoin_rewards_contract(
        owner: cfg.owner, staking_address: cfg.staking_contract, token_address: cfg.token_address,
    );
    cfg.rewards_contract = contract_address;

    let loaded_owner = load_value(:contract_address, storage_address: selector!("owner"));
    assert!(loaded_owner == cfg.owner);

    let loaded_staking_dispatcher: IMemeCoinStakingDispatcher = load_value(
        :contract_address, storage_address: selector!("staking_dispatcher"),
    );
    assert!(loaded_staking_dispatcher.contract_address == cfg.staking_contract);

    let loaded_token_dispatcher: IERC20Dispatcher = load_value(
        :contract_address, storage_address: selector!("token_dispatcher"),
    );
    assert!(loaded_token_dispatcher.contract_address == cfg.token_address);
}
