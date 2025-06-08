use memecoin_staking::memecoin_staking::interface::{Events, StakeDuration};
use memecoin_staking::types::{Amount, Index};
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

pub fn validate_rewards_contract_set_event(
    spied_event: @(ContractAddress, Event), rewards_contract: ContractAddress,
) {
    let expected_event = Events::RewardsContractSet { rewards_contract };
    assert_expected_event_emitted(
        :spied_event,
        :expected_event,
        expected_event_selector: @selector!("RewardsContractSet"),
        expected_event_name: "RewardsContractSet",
    )
}

pub fn validate_claimed_rewards_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    stake_duration: StakeDuration,
    stake_index: Index,
    rewards: Amount,
) {
    let expected_event = Events::ClaimedRewards {
        staker_address, stake_duration, stake_index, rewards,
    };
    assert_expected_event_emitted(
        spied_event: spied_event,
        :expected_event,
        expected_event_selector: @selector!("ClaimedRewards"),
        expected_event_name: "ClaimedRewards",
    )
}

pub fn validate_stake_unstaked_event(
    spied_event: @(ContractAddress, Event),
    staker_address: ContractAddress,
    stake_duration: StakeDuration,
    stake_index: Index,
) {
    let expected_event = Events::StakeUnstaked { staker_address, stake_duration, stake_index };
    assert_expected_event_emitted(
        spied_event: spied_event,
        :expected_event,
        expected_event_selector: @selector!("StakeUnstaked"),
        expected_event_name: "StakeUnstaked",
    )
}
