#[starknet::contract]
pub mod MemeCoinRewards {
    use memecoin_staking::memecoin_rewards::interface::{IMemeCoinRewards, VersionInfo};
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
    };
    use memecoin_staking::types::Amount;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        staking_contract: ContractAddress,
        version_info: Vec<VersionInfo>,
        token_dispatcher: IERC20Dispatcher,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, owner: ContractAddress, staking_contract: ContractAddress,
    ) {
        self.owner.write(owner);
        self.staking_contract.write(staking_contract);
    }

    #[abi(embed_v0)]
    impl MemeCoinRewardsImpl of IMemeCoinRewards<ContractState> {
        fn fund(ref self: ContractState, amount: Amount) {
            assert!(self.caller_is_owner(), "Can only be called by the owner");
            let total_points = self.get_staking_contract_dispatcher().new_version();

            self.transfer_from_owner(amount);
            self.version_info.push(VersionInfo { total_points, total_rewards: amount });
        }
    }

    #[generate_trait]
    impl InternalMemeCoinRewardsImpl of InternalMemeCoinRewardsTrait {
        fn caller_is_owner(self: @ContractState) -> bool {
            self.owner.read() == get_caller_address()
        }

        fn get_staking_contract_dispatcher(self: @ContractState) -> IMemeCoinStakingDispatcher {
            IMemeCoinStakingDispatcher { contract_address: self.staking_contract.read() }
        }

        fn transfer_from_owner(self: @ContractState, amount: Amount) {
            let owner = self.owner.read();
            let contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.transfer_from(owner, contract_address, amount.into());
        }
    }
}
