#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStaking, IMemeCoinStakingConfig, StakeDuration, StakeDurationTrait, StakeInfo,
    };
    use memecoin_staking::types::{Amount, Index, Version};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starkware_utils::types::time::time::Time;

    #[storage]
    struct Storage {
        /// The owner of the contract.
        /// The owner is responsible for setting,
        /// and funding the rewards contract.
        owner: ContractAddress,
        /// The address of the rewards contract associated with the staking contract.
        rewards_contract: ContractAddress,
        /// Stores the stake info per stake for each staker.
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        /// Stores the total points for each version.
        points_info: Vec<Amount>,
        /// The current version number.
        current_version: Version,
        /// The index of the next stake.
        stake_index: Index,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.owner.write(value: owner);
        self.current_version.write(value: 0);
        self.stake_index.write(value: 1);
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
        self.points_info.push(value: 0);
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingConfigImpl of IMemeCoinStakingConfig<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            // TODO: create errors file and use it here
            assert!(get_caller_address() == self.owner.read(), "Can only be called by the owner");
            self.rewards_contract.write(value: rewards_contract);
            // TODO: emit event
        }
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn stake(ref self: ContractState, amount: Amount, duration: StakeDuration) -> Index {
            let staker_address = get_caller_address();
            let version = self.current_version.read();
            let points = amount * duration.get_multiplier().into();
            self.transfer_from_caller_to_contract(:amount);
            let stake_id = self
                .stake_update_staker_info(:staker_address, :duration, :version, :amount);
            self.stake_update_points_info(:version, :points);
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
                vesting_time: Time::now().add(delta: duration.to_time_delta()),
            };
            self.stake_index.write(value: stake_index + 1);
            self
                .staker_info
                .entry(key: staker_address)
                .entry(key: duration)
                .push(value: stake_info);
            stake_index
        }

        fn stake_update_points_info(ref self: ContractState, version: Version, points: Amount) {
            let mut points_info: Amount = self.points_info.at(index: version.into()).read();
            points_info += points;
            self.points_info.at(index: version.into()).write(value: points_info);
        }

        fn transfer_from_caller_to_contract(ref self: ContractState, amount: Amount) {
            let caller_address = get_caller_address();
            let contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .transfer_from(
                    sender: caller_address, recipient: contract_address, amount: amount.into(),
                );
        }
    }
}

