#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{PointsInfo, StakeDuration, StakeInfo};
    use memecoin_staking::types::{Index, Version};
    use starknet::ContractAddress;
    use starknet::storage::{Map, MutableVecTrait, StoragePointerWriteAccess, Vec};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        rewards_contract: ContractAddress,
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        points_info: Vec<PointsInfo>,
        current_version: Version,
        stake_index: Index,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.current_version.write(0);
        self.stake_index.write(1);
        self.points_info.push(PointsInfo {
            total_points: 0,
            pending_points: 0,
        });
    }
}
