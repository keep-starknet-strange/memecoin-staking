#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::errors::Error;
    use memecoin_staking::memecoin_rewards::interface::{
        IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
    };
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
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.owner.write(value: owner);
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
        self.total_points_per_reward_cycle.push(value: 0);
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingConfigImpl of IMemeCoinStakingConfig<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            assert!(get_caller_address() == self.owner.read(), "{}", Error::CALLER_IS_NOT_OWNER);
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
                "{}",
                Error::CALLER_IS_NOT_REWARDS_CONTRACT,
            );
            let curr_reward_cycle = self.get_current_reward_cycle();
            let total_points = self
                .total_points_per_reward_cycle
                .at(index: curr_reward_cycle)
                .read();
            assert!(total_points > 0, "{}", Error::CLOSE_EMPTY_CYCLE);
            self.total_points_per_reward_cycle.push(value: 0);
            // TODO: Emit event.

            total_points
        }

        fn claim_rewards(
            ref self: ContractState, stake_duration: StakeDuration, stake_index: Index,
        ) -> Amount {
            let rewards_contract_dispatcher = self.get_rewards_contract_dispatcher();
            let staker_address = get_caller_address();
            let (reward_cycle, points) = self
                .claim_stake(:staker_address, :stake_duration, :stake_index);
            let token_dispatcher = self.token_dispatcher.read();
            let caller_address = get_caller_address();

            let rewards = rewards_contract_dispatcher.claim_rewards(:points, :reward_cycle);
            token_dispatcher.transfer(recipient: caller_address, amount: rewards.into());

            // TODO: Emit event.
            rewards
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
            let reward_cycle = self.get_current_reward_cycle();
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
            assert!(multiplier.is_some(), "{}", Error::INVALID_STAKE_DURATION);
            let points = amount * multiplier.unwrap().into();
            let reward_cycle = self.get_current_reward_cycle();
            self.total_points_per_reward_cycle.at(index: reward_cycle).add_and_write(value: points);
        }

        fn transfer_to_contract(ref self: ContractState, sender: ContractAddress, amount: Amount) {
            let contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .transfer_from(:sender, recipient: contract_address, amount: amount.into());
            // TODO: Maybe emit event.
        }

        fn get_current_reward_cycle(ref self: ContractState) -> Cycle {
            // The vector is initialized in the constructor with one element,
            // so this value will never underflow.
            self.total_points_per_reward_cycle.len() - 1
        }

        fn calculate_points(
            ref self: ContractState, stake_duration: StakeDuration, amount: Amount,
        ) -> u128 {
            let multiplier = stake_duration.get_multiplier();
            assert!(multiplier.is_some(), "{}", Error::INVALID_STAKE_DURATION);
            let points = amount * multiplier.unwrap().into();
            points
        }

        fn rewards_contract_is_set(ref self: ContractState) -> bool {
            self.rewards_contract.read() != 0.try_into().unwrap()
        }

        fn get_rewards_contract_dispatcher(ref self: ContractState) -> IMemeCoinRewardsDispatcher {
            assert!(self.rewards_contract_is_set(), "{}", Error::REWARDS_CONTRACT_NOT_SET);
            IMemeCoinRewardsDispatcher { contract_address: self.rewards_contract.read() }
        }

        fn claim_stake(
            ref self: ContractState,
            staker_address: ContractAddress,
            stake_duration: StakeDuration,
            stake_index: Index,
        ) -> (Cycle, u128) {
            let stake_info = self
                .get_stake_info(staker_address: staker_address, :stake_duration, :stake_index);
            assert!(stake_info.is_some(), "{}", Error::STAKE_NOT_FOUND);
            let mut stake_info = stake_info.unwrap();
            assert!(stake_info.is_vested(), "{}", Error::STAKE_NOT_VESTED);
            assert!(!stake_info.is_claimed(), "{}", Error::STAKE_ALREADY_CLAIMED);
            stake_info.set_claimed();
            let amount = stake_info.get_amount();
            let reward_cycle = stake_info.get_reward_cycle();
            let points = self.calculate_points(:stake_duration, :amount);

            self
                .staker_info
                .entry(key: staker_address)
                .entry(key: stake_duration)
                .at(index: stake_index)
                .write(value: stake_info);

            (reward_cycle, points)
        }
    }
}
