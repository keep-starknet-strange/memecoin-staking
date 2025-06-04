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
        rewards_contract: Option<ContractAddress>,
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
        self.rewards_contract.write(value: None);
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingConfigImpl of IMemeCoinStakingConfig<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            assert!(get_caller_address() == self.owner.read(), "{}", Error::CALLER_IS_NOT_OWNER);
            let current_rewards_contract = self.rewards_contract.read();
            assert!(current_rewards_contract.is_none(), "{}", Error::REWARDS_CONTRACT_ALREADY_SET);

            // This is redundant, and can't be tested since the rewards constructor will fail if the
            // token doesn't match, but is still good to have.
            let rewards_contract_dispatcher = IMemeCoinRewardsDispatcher {
                contract_address: rewards_contract,
            };
            let token_address = rewards_contract_dispatcher.get_token_address();
            assert!(
                token_address == self.token_dispatcher.read().contract_address,
                "{}",
                Error::REWARDS_TOKEN_MISMATCH,
            );

            self.rewards_contract.write(value: Some(rewards_contract));
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
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn get_rewards_contract(ref self: ContractState) -> ContractAddress {
            let rewards_contract = self.rewards_contract.read();
            assert!(rewards_contract.is_some(), "{}", Error::REWARDS_CONTRACT_NOT_SET);

            rewards_contract.unwrap()
        }

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
    }
}
