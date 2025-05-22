use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    CALLER_IS_NOT_OWNER,
    CALLER_IS_NOT_REWARDS_CONTRACT,
    ATTEMPT_CLOSE_EMPTY_CYCLE,
    INVALID_STAKE_DURATION,
    INVALID_TOTAL_POINTS_PER_REWARD_CYCLE_LENGTH,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::CALLER_IS_NOT_OWNER => "Can only be called by the owner",
            Error::CALLER_IS_NOT_REWARDS_CONTRACT => "Can only be called by the rewards contract",
            Error::ATTEMPT_CLOSE_EMPTY_CYCLE => "Can't close reward cycle with no stakes",
            Error::INVALID_STAKE_DURATION => "Invalid stake duration",
            Error::INVALID_TOTAL_POINTS_PER_REWARD_CYCLE_LENGTH => "Invalid total points per reward cycle length",
        }
    }
}