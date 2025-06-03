#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::errors::Error;
    use memecoin_staking::memecoin_rewards::interface::{
        IMemeCoinRewardsDispatcher, IMemeCoinRewardsDispatcherTrait,
    };
    use memecoin_staking::memecoin_staking::interface::{
        Events, IMemeCoinStaking, IMemeCoinStakingConfig, StakeDuration, StakeDurationTrait,
        StakeInfo, StakeInfoImpl,
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
        /// The dispatcher of the rewards contract associated with the staking contract.
        rewards_contract_dispatcher: Option<IMemeCoinRewardsDispatcher>,
        /// Stores the stake info per stake for each staker.
        staker_info: Map<ContractAddress, Map<StakeDuration, Vec<StakeInfo>>>,
        /// Current reward cycle.
        current_reward_cycle: Cycle,
        /// Accumulate points for current reward cycle.
        total_points_in_current_reward_cycle: u128,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RewardsContractSet: Events::RewardsContractSet,
        NewStake: Events::NewStake,
        ClaimedRewards: Events::ClaimedRewards,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.owner.write(value: owner);
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
        self.current_reward_cycle.write(value: 0);
        self.total_points_in_current_reward_cycle.write(value: 0);

        // This contract's functionality is dependent on the rewards contract,
        // it needs to be set after the rewards contract is deployed.
        // This is set to None to indicate that the rewards contract is not set.
        self.rewards_contract_dispatcher.write(value: None);
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingConfigImpl of IMemeCoinStakingConfig<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            assert!(get_caller_address() == self.owner.read(), "{}", Error::CALLER_IS_NOT_OWNER);
            let current_rewards_contract_dispatcher = self.rewards_contract_dispatcher.read();
            assert!(
                current_rewards_contract_dispatcher.is_none(),
                "{}",
                Error::REWARDS_CONTRACT_ALREADY_SET,
            );

            // TODO: Consider removing this check.
            // This is redundant, and can't be tested
            // since the rewards constructor will fail if the token doesn't match,
            // but is still good to have.
            let rewards_contract_dispatcher = IMemeCoinRewardsDispatcher {
                contract_address: rewards_contract,
            };
            let token_address = rewards_contract_dispatcher.get_token_address();
            assert!(
                token_address == self.token_dispatcher.read().contract_address,
                "{}",
                Error::REWARDS_TOKEN_MISMATCH,
            );

            self.rewards_contract_dispatcher.write(value: Some(rewards_contract_dispatcher));

            self.emit(event: Events::RewardsContractSet { rewards_contract });
        }
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn stake(ref self: ContractState, amount: Amount, stake_duration: StakeDuration) -> Index {
            let staker_address = get_caller_address();
            let stake_index = self.update_staker_info(:staker_address, :stake_duration, :amount);
            self.add_to_total_points_per_reward_cycle(:amount, :stake_duration);
            self.transfer_to_contract(sender: staker_address, :amount);

            self.emit(event: Events::NewStake { staker_address, stake_duration, stake_index });

            stake_index
        }

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token_dispatcher.read().contract_address
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
            let rewards_contract = self.get_rewards_contract();
            assert!(
                get_caller_address() == rewards_contract,
                "{}",
                Error::CALLER_IS_NOT_REWARDS_CONTRACT,
            );
            let total_points = self.total_points_in_current_reward_cycle.read();
            assert!(total_points > 0, "{}", Error::CLOSE_EMPTY_CYCLE);

            self.current_reward_cycle.add_and_write(value: 1);
            self.total_points_in_current_reward_cycle.write(value: 0);

            total_points
        }

        fn claim_rewards(
            ref self: ContractState, stake_duration: StakeDuration, stake_index: Index,
        ) -> Amount {
            let staker_address = get_caller_address();
            let mut stake_info = self
                .assert_stake_claimable(:staker_address, :stake_duration, :stake_index);
            self
                .mark_stake_as_claimed(
                    :staker_address, :stake_duration, :stake_index, ref :stake_info,
                );
            let rewards = self.transfer_rewards_from_rewards_contract(:stake_info, :stake_duration);

            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.transfer(recipient: staker_address, amount: rewards.into());

            self
                .emit(
                    event: Events::ClaimedRewards {
                        staker_address, stake_duration, stake_index, rewards,
                    },
                );
            rewards
        }

        fn get_rewards_contract(self: @ContractState) -> ContractAddress {
            self.get_rewards_contract_dispatcher().contract_address
        }
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn get_rewards_contract_dispatcher(self: @ContractState) -> IMemeCoinRewardsDispatcher {
            let rewards_contract_dispatcher = self.rewards_contract_dispatcher.read();
            assert!(rewards_contract_dispatcher.is_some(), "{}", Error::REWARDS_CONTRACT_NOT_SET);

            rewards_contract_dispatcher.unwrap()
        }

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

        fn add_to_total_points_per_reward_cycle(
            ref self: ContractState, amount: Amount, stake_duration: StakeDuration,
        ) {
            let multiplier = stake_duration.get_multiplier();
            assert!(multiplier.is_some(), "{}", Error::INVALID_STAKE_DURATION);
            let points = amount * multiplier.unwrap().into();
            self.total_points_in_current_reward_cycle.add_and_write(value: points);
        }

        fn transfer_to_contract(ref self: ContractState, sender: ContractAddress, amount: Amount) {
            let contract_address = get_contract_address();
            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher
                .transfer_from(:sender, recipient: contract_address, amount: amount.into());
            // TODO: Maybe emit event.
        }

        fn calculate_points(
            ref self: ContractState, stake_duration: StakeDuration, amount: Amount,
        ) -> u128 {
            let multiplier = stake_duration.get_multiplier();
            assert!(multiplier.is_some(), "{}", Error::INVALID_STAKE_DURATION);
            let points = amount * multiplier.unwrap().into();
            points
        }

        fn assert_stake_claimable(
            ref self: ContractState,
            staker_address: ContractAddress,
            stake_duration: StakeDuration,
            stake_index: Index,
        ) -> StakeInfo {
            let stake_info = self.get_stake_info(:staker_address, :stake_duration, :stake_index);
            assert!(stake_info.is_some(), "{}", Error::STAKE_NOT_FOUND);
            let mut stake_info = stake_info.unwrap();
            assert!(stake_info.is_vested(), "{}", Error::STAKE_NOT_VESTED);
            assert!(!stake_info.is_claimed(), "{}", Error::STAKE_ALREADY_CLAIMED);

            stake_info
        }

        fn mark_stake_as_claimed(
            ref self: ContractState,
            staker_address: ContractAddress,
            stake_duration: StakeDuration,
            stake_index: Index,
            ref stake_info: StakeInfo,
        ) -> StakeInfo {
            stake_info.set_claimed();

            self
                .staker_info
                .entry(key: staker_address)
                .entry(key: stake_duration)
                .at(index: stake_index)
                .write(value: stake_info);

            stake_info
        }

        fn transfer_rewards_from_rewards_contract(
            ref self: ContractState, stake_info: StakeInfo, stake_duration: StakeDuration,
        ) -> Amount {
            let amount = stake_info.get_amount();
            let points = self.calculate_points(:stake_duration, :amount);
            let reward_cycle = stake_info.get_reward_cycle();
            let rewards_contract_dispatcher = self.get_rewards_contract_dispatcher();
            let rewards = rewards_contract_dispatcher.claim_rewards(:points, :reward_cycle);

            rewards
        }
    }
}
