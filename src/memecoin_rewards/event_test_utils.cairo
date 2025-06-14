use memecoin_staking::memecoin_rewards::interface::Events;
use memecoin_staking::types::{Amount, Cycle};
use snforge_std::cheatcodes::events::Event;
use starknet::ContractAddress;
use starkware_utils_testing::test_utils::assert_expected_event_emitted;

pub fn validate_rewards_funded_event(
    spied_event: @(ContractAddress, Event),
    reward_cycle: Cycle,
    total_points: u128,
    total_rewards: Amount,
) {
    let expected_event = Events::RewardsFunded { reward_cycle, total_points, total_rewards };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("RewardsFunded"),
        expected_event_name: "RewardsFunded",
    );
}
