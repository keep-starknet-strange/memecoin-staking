use memecoin_staking::errors::Error;
use memecoin_staking::types::{Amount, Cycle, Index, Multiplier};
use starknet::ContractAddress;
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

#[starknet::interface]
pub trait IMemeCoinStakingConfig<TContractState> {
    /// Sets the rewards contract address.
    /// Only callable by the contract owner.
    fn set_rewards_contract(ref self: TContractState, rewards_contract: ContractAddress);
}

#[starknet::interface]
pub trait IMemeCoinStaking<TContractState> {
    /// Stakes the specified amount of meme coin for the specified `stake_duration`.
    /// Returns the `stake_index`.
    fn stake(ref self: TContractState, amount: Amount, stake_duration: StakeDuration) -> Index;

    /// Get the `ContractAddress` of the token used for staking.
    fn get_token_address(self: @TContractState) -> ContractAddress;

    /// Get info for a specific stake for `staker_address`.
    fn get_stake_info(
        self: @TContractState,
        staker_address: ContractAddress,
        stake_duration: StakeDuration,
        stake_index: Index,
    ) -> Option<StakeInfo>;

    /// Bumps current reward cycle, returns total points for the previous cycle.
    fn close_reward_cycle(ref self: TContractState) -> u128;

    /// Get the `ContractAddress` of the rewards contract associated with the staking contract.
    fn get_rewards_contract(self: @TContractState) -> ContractAddress;

    /// Claims the rewards for a specific stake.
    fn claim_rewards(
        ref self: TContractState, stake_duration: StakeDuration, stake_index: Index,
    ) -> Amount;

    /// Get the amount of points in the current open reward cycle.
    fn get_current_cycle_points(self: @TContractState) -> u128;
}

pub mod Events {
    use memecoin_staking::memecoin_staking::interface::StakeDuration;
    use memecoin_staking::types::Index;
    use starknet::ContractAddress;

    #[derive(Debug, Drop, starknet::Event, PartialEq)]
    pub struct NewStake {
        #[key]
        pub staker_address: ContractAddress,
        pub stake_duration: StakeDuration,
        pub stake_index: Index,
    }
}

/// Different stake durations.
#[derive(starknet::Store, Debug, Drop, Hash, Serde, Copy, PartialEq)]
pub enum StakeDuration {
    #[default]
    None,
    OneMonth,
    ThreeMonths,
    SixMonths,
    TwelveMonths,
}

#[generate_trait]
pub(crate) impl StakeDurationImpl of StakeDurationTrait {
    const ONE_MONTH: u64 = 30;
    const ONE_MONTH_MULTIPLIER: Multiplier = 10;
    const THREE_MONTHS_MULTIPLIER: Multiplier = 12;
    const SIX_MONTHS_MULTIPLIER: Multiplier = 15;
    const TWELVE_MONTHS_MULTIPLIER: Multiplier = 20;

    /// Converts the `StakeDuration` to the corresponding time delta.
    fn to_time_delta(self: @StakeDuration) -> Option<TimeDelta> {
        match self {
            StakeDuration::None => None,
            StakeDuration::OneMonth => Some(Time::days(Self::ONE_MONTH)),
            StakeDuration::ThreeMonths => Some(Time::days(3 * Self::ONE_MONTH)),
            StakeDuration::SixMonths => Some(Time::days(6 * Self::ONE_MONTH)),
            StakeDuration::TwelveMonths => Some(Time::days(12 * Self::ONE_MONTH)),
        }
    }

    /// Gets the points multiplier for the `StakeDuration`.
    fn get_multiplier(self: @StakeDuration) -> Option<Multiplier> {
        // TODO: Allow user to configure the multiplier for each `StakeDuration`.
        match self {
            StakeDuration::None => None,
            StakeDuration::OneMonth => Some(Self::ONE_MONTH_MULTIPLIER),
            StakeDuration::ThreeMonths => Some(Self::THREE_MONTHS_MULTIPLIER),
            StakeDuration::SixMonths => Some(Self::SIX_MONTHS_MULTIPLIER),
            StakeDuration::TwelveMonths => Some(Self::TWELVE_MONTHS_MULTIPLIER),
        }
    }
}

/// Stake info for each stake.
#[derive(starknet::Store, Drop, Serde, Copy)]
pub struct StakeInfo {
    /// The reward cycle number.
    /// Stakes in the same reward cycle share a points / rewards ratio,
    /// set according to the amount of rewards funded by the owner.
    reward_cycle: Cycle,
    /// The amount staked.
    amount: Amount,
    /// The vesting time (the time when rewards can be claimed for this stake).
    vesting_time: Timestamp,
    /// Indicates if the stake has been claimed.
    claimed: bool,
}

#[generate_trait]
pub(crate) impl StakeInfoImpl of StakeInfoTrait {
    fn new(reward_cycle: Cycle, amount: Amount, stake_duration: StakeDuration) -> StakeInfo {
        let time_delta = stake_duration.to_time_delta();
        assert!(time_delta.is_some(), "{}", Error::INVALID_STAKE_DURATION);
        let vesting_time = Time::now().add(delta: time_delta.unwrap());
        StakeInfo { reward_cycle, amount, vesting_time, claimed: false }
    }

    fn get_reward_cycle(self: @StakeInfo) -> Cycle {
        *self.reward_cycle
    }

    fn get_amount(self: @StakeInfo) -> Amount {
        *self.amount
    }

    fn get_vesting_time(self: @StakeInfo) -> Timestamp {
        *self.vesting_time
    }

    fn is_vested(self: @StakeInfo) -> bool {
        Time::now() >= self.get_vesting_time()
    }

    fn is_claimed(self: @StakeInfo) -> bool {
        *self.claimed
    }

    fn set_claimed(ref self: StakeInfo) {
        assert!(self.is_vested(), "{}", Error::STAKE_NOT_VESTED);
        assert!(!self.is_claimed(), "{}", Error::STAKE_ALREADY_CLAIMED);
        self.claimed = true;
    }
}
