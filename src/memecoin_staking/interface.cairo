use memecoin_staking::types::{Amount, Index, Multiplier, Version};
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
    /// Stakes the specified amount of meme coin for the specified duration.
    /// Returns the stake id.
    fn stake(ref self: TContractState, amount: Amount, duration: StakeDuration) -> Index;

    /// Get info for all stakes for the caller.
    fn get_stake_info(self: @TContractState) -> Span<StakeInfo>;

    /// Bumps version number, returns total points for the previous version.
    fn new_version(ref self: TContractState) -> Amount;
}

/// Different stake durations.
#[derive(starknet::Store, Drop, Hash, Serde, Copy, PartialEq)]
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

    /// Converts the stake duration to a time delta.
    fn to_time_delta(self: @StakeDuration) -> Option<TimeDelta> {
        match self {
            StakeDuration::None => None,
            StakeDuration::OneMonth => Some(Time::days(Self::ONE_MONTH)),
            StakeDuration::ThreeMonths => Some(Time::days(3 * Self::ONE_MONTH)),
            StakeDuration::SixMonths => Some(Time::days(6 * Self::ONE_MONTH)),
            StakeDuration::TwelveMonths => Some(Time::days(12 * Self::ONE_MONTH)),
        }
    }

    /// Gets the points multiplier for the stake duration.
    fn get_multiplier(self: @StakeDuration) -> Option<Multiplier> {
        // TODO: Allow user to configure the multiplier for each stake duration.
        match self {
            StakeDuration::None => None,
            StakeDuration::OneMonth => Some(Self::ONE_MONTH_MULTIPLIER),
            StakeDuration::ThreeMonths => Some(Self::THREE_MONTHS_MULTIPLIER),
            StakeDuration::SixMonths => Some(Self::SIX_MONTHS_MULTIPLIER),
            StakeDuration::TwelveMonths => Some(Self::TWELVE_MONTHS_MULTIPLIER),
        }
    }
}

/// Iterator over all stake duration options.
#[derive(Drop)]
struct StakeDurationIter {
    stake_duration: StakeDuration,
}

#[generate_trait]
pub(crate) impl StakeDurationIterImpl of StakeDurationIterTrait {
    fn new() -> StakeDurationIter {
        StakeDurationIter { stake_duration: StakeDuration::OneMonth }
    }
}

pub(crate) impl StakeDurationIteratorImpl of Iterator<StakeDurationIter> {
    type Item = StakeDuration;

    fn next(ref self: StakeDurationIter) -> Option<StakeDuration> {
        let prev = self.stake_duration;
        match self.stake_duration {
            StakeDuration::OneMonth => { self.stake_duration = StakeDuration::ThreeMonths; },
            StakeDuration::ThreeMonths => { self.stake_duration = StakeDuration::SixMonths; },
            StakeDuration::SixMonths => { self.stake_duration = StakeDuration::TwelveMonths; },
            StakeDuration::TwelveMonths => { self.stake_duration = StakeDuration::None; },
            StakeDuration::None => (),
        }
        if prev == StakeDuration::None {
            None
        } else {
            Some(prev)
        }
    }
}

/// Stake info for each stake.
#[derive(starknet::Store, Drop, Serde)]
pub struct StakeInfo {
    /// The stake id (unique to the staker, used for unstaking).
    id: Index,
    /// The version number.
    /// Stakes in the same version share a points / rewards ratio,
    /// set according to the amount of rewards funded by the owner.
    version: Version,
    /// The amount staked.
    amount: Amount,
    /// The vesting time (the time when rewards can be claimed for this stake).
    vesting_time: Timestamp,
}

#[generate_trait]
pub(crate) impl StakeInfoImpl of StakeInfoTrait {
    fn new(id: Index, version: Version, amount: Amount, duration: StakeDuration) -> StakeInfo {
        let time_delta = duration.to_time_delta();
        assert!(time_delta.is_some(), "Invalid stake duration");
        let vesting_time = Time::now().add(delta: time_delta.unwrap());
        StakeInfo { id, version, amount, vesting_time }
    }

    fn get_id(self: @StakeInfo) -> Index {
        *self.id
    }

    fn get_version(self: @StakeInfo) -> Version {
        *self.version
    }

    fn get_amount(self: @StakeInfo) -> Amount {
        *self.amount
    }

    fn get_vesting_time(self: @StakeInfo) -> Timestamp {
        *self.vesting_time
    }
}
