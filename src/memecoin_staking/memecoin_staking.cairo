#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStaking, PointsInfo, StakeDuration, StakeDurationIterTrait, StakeDurationTrait,
        StakeInfo,
    };
    use memecoin_staking::types::{Amount, Index, Version};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starkware_utils::types::time::time::Time;

    #[storage]
    struct Storage {
        /// Stores the stake info per stake for each staker.
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        /// Stores the points info (total and pending) for each version.
        points_info: Vec<PointsInfo>,
        /// The current version number.
        current_version: Version,
        /// The index of the next stake.
        stake_index: Index,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, token_address: ContractAddress) {
        self.current_version.write(0);
        self.stake_index.write(1);
        self.token_dispatcher.write(IERC20Dispatcher { contract_address: token_address });
        self.points_info.push(PointsInfo { total_points: 0, pending_points: 0 });
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn stake(ref self: ContractState, amount: Amount, duration: StakeDuration) -> Index {
            let staker_address = get_caller_address();
            let version = self.current_version.read();
            let points = amount * duration.get_multiplier().into();
            self.transfer_from_caller_to_contract(amount);
            let stake_id = self.stake_update_staker_info(staker_address, duration, version, amount);
            self.stake_update_points_info(version, points);
            stake_id
        }

        fn get_stake_info(self: @ContractState) -> Span<StakeInfo> {
            let staker_address = get_caller_address();
            let mut result = array![];
            let staker_info = self.staker_info.entry(staker_address);
            for duration in StakeDurationIterTrait::new() {
                let staker_info = staker_info.entry(duration);
                for i in 0..staker_info.len() {
                    result.append(staker_info.at(i).read());
                }
            }
            result.span()
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
                vesting_time: Time::now().add(duration.to_time_delta()),
            };
            self.stake_index.write(stake_index + 1);
            self.staker_info.entry(staker_address).entry(duration).push(stake_info);
            stake_index
        }

        fn stake_update_points_info(ref self: ContractState, version: Version, points: Amount) {
            let mut points_info = self.points_info.get(version.into());
            if points_info.is_none() {
                assert!(self.points_info.len() == version.into(), "Version number is too high");
                self.points_info.push(PointsInfo { total_points: points, pending_points: points });
            } else {
                let mut points_info = points_info.unwrap().read();
                points_info.total_points += points;
                points_info.pending_points += points;
                self.points_info.at(version.into()).write(points_info);
            }
        }

        fn transfer_from_caller_to_contract(ref self: ContractState, amount: Amount) {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.transfer_from(caller_address, contract_address, amount.into());
        }
    }
}
