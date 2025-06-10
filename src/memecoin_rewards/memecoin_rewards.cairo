#[starknet::contract]
pub mod MemeCoinRewards {
    use memecoin_staking::errors::Error;
    use memecoin_staking::memecoin_rewards::interface::{Events, IMemeCoinRewards};
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
    };
    use memecoin_staking::types::{Amount, Cycle};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starkware_utils::math::utils::mul_wide_and_floor_div;
    use starkware_utils::utils::AddToStorage;

    #[storage]
    struct Storage {
        /// The contract's funder.
        /// In charge of funding this contract.
        funder: ContractAddress,
        /// The staking contract dispatcher.
        staking_dispatcher: IMemeCoinStakingDispatcher,
        /// The reward cycle info for each reward cycle.
        /// Reward cycles are set by the funder funding this contract.
        /// Reward cycles set the ratio between points and rewards for stakes.
        reward_cycle_info: Vec<RewardCycleInfo>,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
        /// Tally of amount of rewards locked.
        locked_rewards: Amount,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        RewardsFunded: Events::RewardsFunded,
    }

    /// Stores the total rewards and points per reward cycle.
    /// Aids in calculating the ratio of rewards per point.
    #[derive(starknet::Store, Drop)]
    struct RewardCycleInfo {
        total_rewards: Amount,
        total_points: u128,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        funder: ContractAddress,
        staking_address: ContractAddress,
        token_address: ContractAddress,
    ) {
        let staking_dispatcher = IMemeCoinStakingDispatcher { contract_address: staking_address };
        let staking_token_address = staking_dispatcher.get_token_address();
        assert!(token_address == staking_token_address, "{}", Error::STAKING_TOKEN_MISMATCH);

        self.funder.write(value: funder);
        self
            .staking_dispatcher
            .write(value: IMemeCoinStakingDispatcher { contract_address: staking_address });
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
    }

    #[abi(embed_v0)]
    impl MemeCoinRewardsImpl of IMemeCoinRewards<ContractState> {
        fn fund(ref self: ContractState, amount: Amount, use_locked_rewards: bool) {
            let funder = self.funder.read();
            assert!(get_caller_address() == funder, "{}", Error::CALLER_IS_NOT_FUNDER);
            let mut amount = amount;

            if use_locked_rewards {
                assert!(amount == 0, "{}", Error::NONZERO_AMOUNT_WITH_LOCKED_REWARDS);
                amount = self.locked_rewards.read();
                assert!(amount > 0, "{}", Error::NO_LOCKED_REWARDS_TO_FUND);
                self.locked_rewards.write(value: 0);
            } else {
                self
                    .token_dispatcher
                    .read()
                    .transfer_from(
                        sender: funder, recipient: get_contract_address(), amount: amount.into(),
                    );
            }

            let total_points = self.close_reward_cycle(:amount);
            self.emit_rewards_funded_event(:total_points, :amount);
        }

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token_dispatcher.read().contract_address
        }

        fn claim_rewards(ref self: ContractState, points: u128, reward_cycle: Cycle) -> Amount {
            let staking_contract = self.staking_dispatcher.read().contract_address;
            assert!(
                get_caller_address() == staking_contract,
                "{}",
                Error::CALLER_IS_NOT_STAKING_CONTRACT,
            );
            let reward_cycle_info = self.assert_rewards_are_claimable(:points, :reward_cycle);

            let rewards = self.calculate_rewards(:points, :reward_cycle_info);
            self.update_reward_cycle_info(:reward_cycle, :points, :rewards);

            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.transfer(recipient: staking_contract, amount: rewards.into());

            rewards
        }

        fn lock_rewards(ref self: ContractState, points: u128, reward_cycle: Cycle) {
            let staking_contract = self.staking_dispatcher.read().contract_address;
            assert!(
                get_caller_address() == staking_contract,
                "{}",
                Error::CALLER_IS_NOT_STAKING_CONTRACT,
            );
            let reward_cycle_info = self.assert_cycle_rewards_lockable(:reward_cycle, :points);

            let rewards = self.calculate_rewards(:points, :reward_cycle_info);
            self.update_reward_cycle_info(:reward_cycle, :points, :rewards);
            self.locked_rewards.add_and_write(value: rewards);
        }

        fn get_locked_rewards(self: @ContractState) -> Amount {
            self.locked_rewards.read()
        }
    }

    #[generate_trait]
    impl InternalMemeCoinRewards of InternalMemeCoinRewardsTrait {
        fn calculate_rewards(
            self: @ContractState, points: u128, reward_cycle_info: RewardCycleInfo,
        ) -> Amount {
            mul_wide_and_floor_div(
                lhs: points,
                rhs: reward_cycle_info.total_rewards,
                div: reward_cycle_info.total_points,
            )
                .unwrap()
        }

        fn update_reward_cycle_info(
            ref self: ContractState, reward_cycle: Cycle, points: u128, rewards: Amount,
        ) {
            let mut reward_cycle_info = self.reward_cycle_info.at(index: reward_cycle).read();
            reward_cycle_info.total_points -= points;
            reward_cycle_info.total_rewards -= rewards;
            self.reward_cycle_info.at(index: reward_cycle).write(value: reward_cycle_info);
        }

        fn assert_cycle_rewards_lockable(
            self: @ContractState, reward_cycle: Cycle, points: u128,
        ) -> RewardCycleInfo {
            assert!(reward_cycle < self.reward_cycle_info.len(), "{}", Error::INVALID_CYCLE);
            let reward_cycle_info = self.reward_cycle_info.at(index: reward_cycle).read();
            assert!(
                points <= reward_cycle_info.total_points,
                "{}",
                Error::LOCK_POINTS_EXCEEDS_CYCLE_POINTS,
            );

            reward_cycle_info
        }

        fn assert_rewards_are_claimable(
            self: @ContractState, points: u128, reward_cycle: Cycle,
        ) -> RewardCycleInfo {
            assert!(reward_cycle < self.reward_cycle_info.len(), "{}", Error::INVALID_CYCLE);
            let reward_cycle_info = self.reward_cycle_info.at(index: reward_cycle).read();
            assert!(
                points <= reward_cycle_info.total_points,
                "{}",
                Error::CLAIM_POINTS_EXCEEDS_CYCLE_POINTS,
            );

            reward_cycle_info
        }

        fn close_reward_cycle(ref self: ContractState, amount: Amount) -> u128 {
            let total_points = self.staking_dispatcher.read().close_reward_cycle();
            self
                .reward_cycle_info
                .push(value: RewardCycleInfo { total_rewards: amount, total_points });

            total_points
        }

        fn emit_rewards_funded_event(ref self: ContractState, total_points: u128, amount: Amount) {
            self
                .emit(
                    event: Events::RewardsFunded {
                        reward_cycle: self.reward_cycle_info.len() - 1,
                        total_points,
                        total_rewards: amount,
                    },
                );
        }
    }
}
