#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStaking, IMemeCoinStakingConfig, StakeDuration, StakeDurationTrait, StakeInfo,
        StakeInfoImpl,
    };
    use memecoin_staking::types::{Amount, Cycle, Index};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starkware_utils::utils::AddToStorage;

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
        /// Stores the total points for each `reward_cycle`.
        total_points_per_reward_cycle: Vec<u128>,
        /// The current `reward_cycle` number.
        current_reward_cycle: Cycle,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.owner.write(value: owner);
        self.current_reward_cycle.write(value: 0);
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
        self.total_points_per_reward_cycle.push(value: 0);
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingConfigImpl of IMemeCoinStakingConfig<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            // TODO: Create errors file and use it here.
            assert!(get_caller_address() == self.owner.read(), "Can only be called by the owner");
            self.rewards_contract.write(value: rewards_contract);
            // TODO: Emit event.
        }
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn stake(ref self: ContractState, amount: Amount, stake_duration: StakeDuration) -> Index {
            let staker_address = get_caller_address();
            let index = self.update_staker_info(:staker_address, :stake_duration, :amount);
            self.update_total_points_per_reward_cycle(:amount, :stake_duration);
            self.transfer_to_contract(sender: staker_address, :amount);
            // TODO: Emit event.
            index
        }

        fn get_stake_info(
            self: @ContractState,
            staker_address: ContractAddress,
            stake_duration: StakeDuration,
            stake_index: Index,
        ) -> Option<StakeInfo> {
            if let Some(stake_info) = self
                .staker_info
                .entry(key: staker_address)
                .entry(key: stake_duration)
                .get(index: stake_index.into()) {
                Some(stake_info.read())
            } else {
                None
            }
        }

        fn close_reward_cycle(ref self: ContractState) -> u128 {
            assert!(
                get_caller_address() == self.rewards_contract.read(),
                "Can only be called by the rewards contract",
            );
            let curr_reward_cycle = self.current_reward_cycle.read();
            let total_points = self
                .total_points_per_reward_cycle
                .at(index: curr_reward_cycle.into())
                .read();
            assert!(total_points > 0, "Can't close reward cycle with no stakes");
            self.current_reward_cycle.add_and_write(value: 1);
            self.total_points_per_reward_cycle.push(value: 0);
            assert!(
                self.total_points_per_reward_cycle.len() == self.current_reward_cycle.read().into()
                    + 1,
                "Invalid total points per reward cycle length",
            );
            // TODO: Emit event.

            total_points
        }
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn update_staker_info(
            ref self: ContractState,
            staker_address: ContractAddress,
            stake_duration: StakeDuration,
            amount: Amount,
        ) -> Index {
            let stake_index = self.get_next_stake_index(:staker_address, :stake_duration);
            let reward_cycle = self.current_reward_cycle.read();
            let stake_info = StakeInfoImpl::new(:reward_cycle, :amount, :stake_duration);
            self.push_stake_info(:staker_address, :stake_duration, :stake_info);
            // TODO: Emit event.
            stake_index
        }

        fn get_next_stake_index(
            ref self: ContractState, staker_address: ContractAddress, stake_duration: StakeDuration,
        ) -> Index {
            self.staker_info.entry(key: staker_address).entry(key: stake_duration).len()
        }

        fn push_stake_info(
            ref self: ContractState,
            staker_address: ContractAddress,
            stake_duration: StakeDuration,
            stake_info: StakeInfo,
        ) {
            self
                .staker_info
                .entry(key: staker_address)
                .entry(key: stake_duration)
                .push(value: stake_info);
        }

        fn update_total_points_per_reward_cycle(
            ref self: ContractState, amount: Amount, stake_duration: StakeDuration,
        ) {
            let multiplier = stake_duration.get_multiplier();
            assert!(multiplier.is_some(), "Invalid stake duration");
            let points = amount * multiplier.unwrap().into();
            let reward_cycle = self.current_reward_cycle.read();
            self
                .total_points_per_reward_cycle
                .at(index: reward_cycle.into())
                .add_and_write(value: points);
        }

        fn transfer_to_contract(ref self: ContractState, sender: ContractAddress, amount: Amount) {
            let contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .transfer_from(:sender, recipient: contract_address, amount: amount.into());
            // TODO: Maybe emit event.
        }
    }
}
