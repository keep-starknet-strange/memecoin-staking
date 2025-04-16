#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStaking, PointsInfo, StakeDuration, StakeDurationTrait, StakeInfo,
    };
    use memecoin_staking::types::{Amount, Index, Version};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec,
    };
    use starknet::{ContractAddress, get_caller_address};
    use starkware_utils::types::time::time::Time;

    #[storage]
    struct Storage {
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        points_info: Vec<PointsInfo>,
        current_version: Version,
        stake_index: Index,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState) {
        self.current_version.write(0);
        self.stake_index.write(1);
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn stake(ref self: ContractState, amount: Amount, duration: StakeDuration) -> Index {
            let staker_address = get_caller_address();
            let version = self.current_version.read();
            let stake_id = self.stake_update_staker_info(staker_address, duration, version, amount);
            self.stake_update_points_info(version, amount);
            stake_id
        }
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn stake_update_staker_info(
            ref self: ContractState,
            staker_address: ContractAddress,
            duration: StakeDuration,
            version: Version,
            amount: Amount,
        ) -> Index {
            let stake_index = self.stake_index.read();
            let stake_info = StakeInfo {
                id: stake_index,
                version,
                amount,
                stake_duration: duration,
                vesting_time: Time::now().add(duration.to_time_delta()),
            };
            self.stake_index.write(stake_index + 1);
            self.staker_info.entry(staker_address).entry(duration).push(stake_info);
            stake_index
        }

        fn stake_update_points_info(ref self: ContractState, version: Version, amount: Amount) {
            let mut points_info = self.points_info.get(version.into());
            if points_info.is_none() {
                assert!(self.points_info.len() == version.into(), "Version number is too high");
                self.points_info.push(PointsInfo {
                    total_points: amount,
                    pending_points: amount,
                });
            } else {
                let mut points_info = points_info.unwrap().read();
                points_info.total_points += amount;
                points_info.pending_points += amount;
                self.points_info.at(version.into()).write(points_info);
            }
        }
    }
}
