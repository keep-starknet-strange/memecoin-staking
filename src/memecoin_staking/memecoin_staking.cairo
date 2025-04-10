#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{PointsInfo, StakeDuration, StakeInfo};
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
