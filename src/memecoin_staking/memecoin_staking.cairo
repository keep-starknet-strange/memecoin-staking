#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{PointsInfo, StakeDuration, StakeInfo};
    use memecoin_staking::types::{Index, Version};
    use starknet::ContractAddress;
    use starknet::storage::{Map, Vec};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        rewards_contract: ContractAddress,
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        points_info: Vec<PointsInfo>,
        current_version: Version,
        stake_index: Index,
    }
}
