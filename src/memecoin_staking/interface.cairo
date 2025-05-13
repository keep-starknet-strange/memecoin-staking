use memecoin_staking::types::{Amount, Index, Multiplier, Version};
use starknet::ContractAddress;
use starkware_utils::types::time::time::{Time, TimeDelta, Timestamp};

const ONE_MONTH: u8 = 30;

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
}

/// Different stake durations.
#[derive(starknet::Store, Drop, Hash, Serde, Copy)]
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
    /// Converts the stake duration to a time delta.
    fn to_time_delta(self: @StakeDuration) -> Option<TimeDelta> {
        match self {
            StakeDuration::None => None,
            StakeDuration::OneMonth => Some(Time::days(ONE_MONTH.into())),
            StakeDuration::ThreeMonths => Some(Time::days(ONE_MONTH.into() * 3)),
            StakeDuration::SixMonths => Some(Time::days(ONE_MONTH.into() * 6)),
            StakeDuration::TwelveMonths => Some(Time::days(ONE_MONTH.into() * 12)),
        }
    }

    /// Gets the points multiplier for the stake duration.
    fn get_multiplier(self: @StakeDuration) -> Option<Multiplier> {
        // TODO: Allow user to configure the multiplier for each stake duration.
        match self {
            StakeDuration::None => None,
            StakeDuration::OneMonth => Some(10),
            StakeDuration::ThreeMonths => Some(12),
            StakeDuration::SixMonths => Some(15),
            StakeDuration::TwelveMonths => Some(20),
        }
    }
}

/// Stake info for each stake.
#[derive(starknet::Store, Drop)]
pub struct StakeInfo {
    /// The stake id (unique to the contract, used for unstaking).
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
}
