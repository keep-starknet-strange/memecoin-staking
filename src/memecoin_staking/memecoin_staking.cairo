#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{IMemeCoinStaking, PointsInfo};
    use memecoin_staking::types::{Index, Version};
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    };
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        rewards_contract: ContractAddress,
        current_version: Version,
        stake_index: Index,
        points_info: Vec<PointsInfo>,
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
        fn caller_is_owner(self: @ContractState) -> bool {
            let owner = self.owner.read();
            let caller = get_caller_address();
            owner == caller
        }
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.current_version.write(0);
        self.stake_index.write(1);
        self.points_info.push(PointsInfo { total_points: 0, pending_points: 0 });
    }
}
