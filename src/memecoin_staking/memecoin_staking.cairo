#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::{
        IMemeCoinStaking, IMemeCoinStakingConfig, StakeDuration, StakeDurationIterTrait,
        StakeDurationTrait, StakeInfo, StakeInfoImpl,
    };
    use memecoin_staking::types::{Amount, Index, Version};
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
        staker_info: Map<ContractAddress, StakerInfo>,
        /// Stores the total points for each version.
        points_info: Vec<u128>,
        /// The current version number.
        current_version: Version,
        /// The token dispatcher.
        token_dispatcher: IERC20Dispatcher,
    }

    #[starknet::storage_node]
    struct StakerInfo {
        /// The running index for the stake IDs.
        stake_index: Index,
        /// The stake info for each stake duration.
        stake_info: Map<StakeDuration, Vec<StakeInfo>>,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, owner: ContractAddress, token_address: ContractAddress,
    ) {
        self.owner.write(value: owner);
        self.current_version.write(value: 0);
        self.token_dispatcher.write(value: IERC20Dispatcher { contract_address: token_address });
        self.points_info.push(value: 0);
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
        fn stake(ref self: ContractState, amount: Amount, duration: StakeDuration) -> Index {
            let staker_address = get_caller_address();
            let version = self.current_version.read();
            let multiplier = duration.get_multiplier();
            assert!(multiplier.is_some(), "Invalid stake duration");
            let points = amount * multiplier.unwrap().into();
            let stake_id = self.update_staker_info(:staker_address, :duration, :version, :amount);
            self.update_points_info(:version, :points);
            self.transfer_to_contract(sender: staker_address, :amount);
            // TODO: Emit event.
            stake_id
        }

        fn get_stake_info(self: @ContractState) -> Span<StakeInfo> {
            let staker_address = get_caller_address();
            let mut result = array![];
            let staker_info = self.staker_info.entry(staker_address);
            for duration in StakeDurationIterTrait::new() {
                let stakes = staker_info.stake_info.entry(duration);
                for i in 0..stakes.len() {
                    result.append(stakes.at(i).read());
                }
            }
            result.span()
        }

        fn new_version(ref self: ContractState) -> Amount {
            assert!(
                get_caller_address() == self.rewards_contract.read(),
                "Can only be called by the rewards contract",
            );
            let curr_version = self.current_version.read();
            let total_points = self.points_info.at(index: curr_version.into()).read();
            assert!(total_points > 0, "Can't close version with no stakes");
            self.current_version.add_and_write(value: 1);
            self.points_info.push(value: 0);
            assert!(
                self.points_info.len() == self.current_version.read().into() + 1,
                "Invalid points info length",
            );
            total_points
        }
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn update_staker_info(
            ref self: ContractState,
            staker_address: ContractAddress,
            duration: StakeDuration,
            version: Version,
            amount: Amount,
        ) -> Index {
            let mut stake_index = self.staker_info.entry(key: staker_address).stake_index.read();
            // The index should start at 1, as unstaking index 0 is reserved for unstaking all.
            if stake_index == 0 {
                // TODO: Maybe emit event for first stake.
                stake_index = 1;
                self.staker_info.entry(key: staker_address).stake_index.write(value: stake_index);
            }
            let stake_info = StakeInfoImpl::new(id: stake_index, :version, :amount, :duration);
            self.staker_info.entry(key: staker_address).stake_index.add_and_write(value: 1);
            self.push_stake_info(:staker_address, :duration, :stake_info);
            stake_index
        }

        fn push_stake_info(
            ref self: ContractState,
            staker_address: ContractAddress,
            duration: StakeDuration,
            stake_info: StakeInfo,
        ) {
            self
                .staker_info
                .entry(key: staker_address)
                .stake_info
                .entry(key: duration)
                .push(value: stake_info);
        }

        fn update_points_info(ref self: ContractState, version: Version, points: Amount) {
            self.points_info.at(index: version.into()).add_and_write(value: points);
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
