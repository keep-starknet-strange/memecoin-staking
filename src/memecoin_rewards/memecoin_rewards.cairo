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
        /// The contract's owner.
        /// In charge of funding this contract.
        owner: ContractAddress,
        /// The staking contract dispatcher.
        staking_dispatcher: IMemeCoinStakingDispatcher,
        /// The version info for each version.
        /// Versions are set by the owner funding this contract.
        /// Versions set the ratio between points and rewards for stakes.
        reward_cycle_info: Vec<RewardCycleInfo>,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    /// Stores the total rewards and points per version.
    /// Aids in calculating the ratio of rewards per point.
    #[derive(starknet::Store, Drop)]
    struct RewardCycleInfo {
        total_rewards: Amount,
        total_points: u128,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        staking_address: ContractAddress,
        token_address: ContractAddress,
    ) {
        self.owner.write(value: owner);
        self
            .staking_dispatcher
            .write(value: IMemeCoinStakingDispatcher { contract_address: staking_address });
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
    }

    #[abi(embed_v0)]
    impl MemeCoinRewardsImpl of IMemeCoinRewards<ContractState> {
        fn fund(ref self: ContractState, amount: Amount) {
            let owner = self.owner.read();
            assert!(get_caller_address() == owner, "{}", Error::CALLER_IS_NOT_OWNER);
            let total_points = self.staking_dispatcher.read().close_reward_cycle();
            self
                .reward_cycle_info
                .push(value: RewardCycleInfo { total_rewards: amount, total_points });
            self
                .token_dispatcher
                .read()
                .transfer_from(
                    sender: owner, recipient: get_contract_address(), amount: amount.into(),
                );
            // TODO: Emit event.
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
