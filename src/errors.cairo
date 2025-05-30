use starkware_utils::errors::{Describable, ErrorDisplay};

#[derive(Drop)]
pub(crate) enum Error {
    CALLER_IS_NOT_OWNER,
    CALLER_IS_NOT_REWARDS_CONTRACT,
    CLOSE_EMPTY_CYCLE,
    INVALID_STAKE_DURATION,
}

impl DescribableError of Describable<Error> {
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::CALLER_IS_NOT_OWNER => "Can only be called by the owner",
            Error::CALLER_IS_NOT_REWARDS_CONTRACT => "Can only be called by the rewards contract",
            Error::CLOSE_EMPTY_CYCLE => "Can't close reward cycle with no stakes",
            Error::INVALID_STAKE_DURATION => "Invalid stake duration",
        }
    }
}
