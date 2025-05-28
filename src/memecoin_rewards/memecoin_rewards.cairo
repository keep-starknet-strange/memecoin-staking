#[starknet::contract]
pub mod MemeCoinRewards {
    use memecoin_staking::errors::Error;
    use memecoin_staking::memecoin_rewards::interface::IMemeCoinRewards;
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
    };
    use memecoin_staking::types::{Amount, Cycle};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starkware_utils::math::utils::mul_wide_and_floor_div;

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
        fn fund(ref self: ContractState, amount: Amount) {
            let funder = self.funder.read();
            assert!(get_caller_address() == funder, "{}", Error::CALLER_IS_NOT_FUNDER);
            let total_points = self.staking_dispatcher.read().close_reward_cycle();
            self
                .reward_cycle_info
                .push(value: RewardCycleInfo { total_rewards: amount, total_points });
            self
                .token_dispatcher
                .read()
                .transfer_from(
                    sender: funder, recipient: get_contract_address(), amount: amount.into(),
                );
            // TODO: Emit event.
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
            assert!(reward_cycle < self.reward_cycle_info.len(), "{}", Error::INVALID_CYCLE);

            let reward_cycle_info = self.reward_cycle_info.at(index: reward_cycle).read();
            let rewards = mul_wide_and_floor_div(
                lhs: points,
                rhs: reward_cycle_info.total_rewards,
                div: reward_cycle_info.total_points,
            )
                .unwrap();

            let token_dispatcher = self.token_dispatcher.read();
            token_dispatcher.transfer(recipient: staking_contract, amount: rewards.into());
            // TODO: Emit event.
            rewards
        }
    }
}
