#[starknet::contract]
pub mod MemeCoinStaking {
    use memecoin_staking::memecoin_staking::interface::IMemeCoinStaking;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        /// The owner of the contract.
        owner: ContractAddress,
        /// The address of the rewards contract associated with the staking contract.
        rewards_contract: ContractAddress,
    }

    #[abi(embed_v0)]
    impl MemeCoinStakingImpl of IMemeCoinStaking<ContractState> {
        fn set_rewards_contract(ref self: ContractState, rewards_contract: ContractAddress) {
            assert!(self.caller_is_owner(), "Can only be called by the owner");
            self.rewards_contract.write(rewards_contract);
        }
    }

    #[generate_trait]
    impl InternalMemeCoinStakingImpl of InternalMemeCoinStakingTrait {
        fn caller_is_owner(self: @ContractState) -> bool {
            let owner = self.owner.read();
            let caller = get_caller_address();
            owner == caller
        }
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }
}
