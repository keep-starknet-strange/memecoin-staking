#[starknet::contract]
pub mod MemeCoinRewards {
    use memecoin_staking::memecoin_rewards::interface::IMemeCoinRewards;
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStakingDispatcher, IMemeCoinStakingDispatcherTrait,
    };
    use memecoin_staking::types::{Amount, Version};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        MutableVecTrait, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
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
        version_info: Vec<VersionInfo>,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    /// Stores the total rewards and points per version.
    /// Aids in calculating the ratio of rewards per point.
    #[derive(starknet::Store, Drop)]
    struct VersionInfo {
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
            assert!(get_caller_address() == owner, "Can only be called by the owner");
            let total_points = self.staking_dispatcher.read().close_reward_cycle();
            self.version_info.push(value: VersionInfo { total_rewards: amount, total_points });
            self
                .token_dispatcher
                .read()
                .transfer_from(
                    sender: owner, recipient: get_contract_address(), amount: amount.into(),
                );
            // TODO: Emit event.
        }

        fn query_rewards(
            self: @ContractState, points_per_version: Span<(Version, u128)>,
        ) -> Amount {
            assert!(
                get_caller_address() == self.staking_dispatcher.read().contract_address,
                "Can only be called by the staking contract",
            );
            let mut total_rewards = 0;
            for (version, points) in points_per_version {
                assert!((*version).into() <= self.version_info.len(), "Invalid version");
                if let Some(version_info) = self.version_info.get(index: (*version).into()) {
                    assert!(*points <= version_info.total_points.read(), "Invalid amount of points");
                    total_rewards +=
                        mul_wide_and_floor_div(
                            lhs: *points,
                            rhs: version_info.total_rewards.read(),
                            div: version_info.total_points.read(),
                        )
                        .unwrap();
                }
            }
            total_rewards
        }
    }
}
