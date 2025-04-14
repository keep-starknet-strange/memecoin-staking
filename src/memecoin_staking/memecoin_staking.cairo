#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStaking, PointsInfo, StakeDuration, StakeInfo,
    };
    use memecoin_staking::types::{Index, Version};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, Vec};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        rewards_contract: ContractAddress,
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        points_info: Vec<PointsInfo>,
        current_version: Version,
        stake_index: Index,
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            assert!(self.caller_is_owner(), "Can only be called by the owner");
            self.rewards_contract.write(rewards_contract);
        }
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn caller_is_rewards_contract(self: @ContractState) -> bool {
            let rewards_contract = self.rewards_contract.read();
            let caller = get_caller_address();
            rewards_contract == caller
        }

        fn caller_is_owner(self: @ContractState) -> bool {
            let owner = self.owner.read();
            let caller = get_caller_address();
            owner == caller
        }
    }
}
