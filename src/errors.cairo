use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    CALLER_IS_NOT_OWNER,
    CALLER_IS_NOT_FUNDER,
    CALLER_IS_NOT_REWARDS_CONTRACT,
    CALLER_IS_NOT_STAKING_CONTRACT,
    CLOSE_EMPTY_CYCLE,
    INVALID_CYCLE,
    INVALID_STAKE_DURATION,
    REWARDS_TOKEN_MISMATCH,
    STAKING_TOKEN_MISMATCH,
    REWARDS_CONTRACT_NOT_SET,
    REWARDS_CONTRACT_ALREADY_SET,
    STAKE_NOT_FOUND,
    STAKE_NOT_VESTED,
    STAKE_ALREADY_CLAIMED,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::CALLER_IS_NOT_OWNER => "Can only be called by the owner",
            Error::CALLER_IS_NOT_FUNDER => "Can only be called by the funder",
            Error::CALLER_IS_NOT_REWARDS_CONTRACT => "Can only be called by the rewards contract",
            Error::CALLER_IS_NOT_STAKING_CONTRACT => "Can only be called by the staking contract",
            Error::CLOSE_EMPTY_CYCLE => "Can't close reward cycle with no stakes",
            Error::INVALID_CYCLE => "Reward cycle does not exist",
            Error::INVALID_STAKE_DURATION => "Invalid stake duration",
            Error::REWARDS_TOKEN_MISMATCH => "Rewards token mismatch",
            Error::STAKING_TOKEN_MISMATCH => "Staking token mismatch",
            Error::REWARDS_CONTRACT_NOT_SET => "Rewards contract not set",
            Error::REWARDS_CONTRACT_ALREADY_SET => "Rewards contract already set",
            Error::STAKE_NOT_FOUND => "Stake not found",
            Error::STAKE_NOT_VESTED => "Stake not vested",
            Error::STAKE_ALREADY_CLAIMED => "Stake already claimed",
        }
    }
}
