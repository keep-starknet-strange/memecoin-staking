#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::IMemeCoinStakingConfig;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        /// The owner of the contract.
        /// The owner is responsible for setting,
        /// and funding the rewards contract.
        owner: ContractAddress,
        /// The address of the rewards contract associated with the staking contract.
        rewards_contract: ContractAddress,
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingConfigImpl of IMemeCoinStakingConfig<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            // TODO: create errors file and use it here
            assert!(get_caller_address() == self.owner.read(), "Can only be called by the owner");
            self.rewards_contract.write(rewards_contract);
            // TODO: emit event
        }
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }
}
