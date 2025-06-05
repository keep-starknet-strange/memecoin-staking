use memecoin_staking::memecoin_staking::interface::{Events, StakeDuration};
use memecoin_staking::types::{Cycle, Index};
use snforge_std::cheatcodes::events::Event;
use starknet::ContractAddress;
use starkware_utils_testing::test_utils::assert_expected_event_emitted;

pub fn validate_new_stake_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    stake_duration: StakeDuration,
    stake_index: Index,
) {
    let expected_event = Events::NewStake { staker_address, stake_duration, stake_index };
    assert_expected_event_emitted(
        spied_event: spied_event,
        :expected_event,
        expected_event_selector: @selector!("NewStake"),
        expected_event_name: "NewStake",
    )
}

pub fn validate_closed_reward_cycle_event(
    spied_event: @(ContractAddress, Event), reward_cycle: Cycle, total_points: u128,
) {
    let expected_event = Events::ClosedRewardCycle { reward_cycle, total_points };
    assert_expected_event_emitted(
        spied_event: spied_event,
        :expected_event,
        expected_event_selector: @selector!("ClosedRewardCycle"),
        expected_event_name: "ClosedRewardCycle",
    )
}
