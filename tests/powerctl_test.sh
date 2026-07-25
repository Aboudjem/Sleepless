#!/usr/bin/env bash
# Integration tests for the stateful Sleepless power helper.
set -euo pipefail

readonly REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly POWERCTL="$REPO/powerctl.sh"
readonly FAKE_PMSET="$REPO/tests/fixtures/fake-pmset.sh"

# Reports a failed assertion.
#
# Args:
#   $*: Failure description.
fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# Reads one key from a fake pmset state file.
#
# Args:
#   $1: State-file path.
#   $2: Exact key.
#
# Outputs:
#   The stored value.
state_value() {
    local state_file="$1"
    local wanted_key="$2"
    awk -F= -v wanted_key="$wanted_key" '$1 == wanted_key { print $2; exit }' "$state_file"
}

# Asserts that a fake state key equals an expected value.
#
# Args:
#   $1: State-file path.
#   $2: Exact key.
#   $3: Expected value.
assert_state() {
    local state_file="$1"
    local key="$2"
    local expected="$3"
    local actual

    actual="$(state_value "$state_file" "$key")"
    [[ "$actual" == "$expected" ]] || fail "$key expected $expected, got $actual"
}

# Creates a deliberately asymmetric Battery/AC baseline.
#
# Args:
#   $1: Destination state-file path.
#   $2: Optional initial SleepDisabled value. Defaults to `0`.
write_baseline() {
    local state_file="$1"
    local sleep_disabled="${2:-0}"
    printf '%s\n' \
        "sleep_disabled=$sleep_disabled" \
        "battery.sleep=17" \
        "battery.disksleep=9" \
        "battery.displaysleep=4" \
        "battery.powernap=1" \
        "battery.tcpkeepalive=0" \
        "battery.womp=0" \
        "charger.sleep=43" \
        "charger.disksleep=21" \
        "charger.displaysleep=8" \
        "charger.powernap=1" \
        "charger.tcpkeepalive=1" \
        "charger.womp=1" >"$state_file"
}

# Runs powerctl with isolated fake pmset and snapshot storage.
#
# Args:
#   $1: Fake pmset state-file path.
#   $2: Snapshot directory.
#   $3: powerctl action.
run_powerctl() {
    local state_file="$1"
    local snapshot_dir="$2"
    local action="$3"

    SLEEPLESS_POWERCTL_TEST=1 \
    SLEEPLESS_PMSET_BIN="$FAKE_PMSET" \
    SLEEPLESS_STATE_DIR="$snapshot_dir" \
    FAKE_PMSET_STATE="$state_file" \
        "$POWERCTL" "$action"
}

# Verifies ON applies the awake profile and OFF restores the exact baseline.
#
# Args:
#   None.
test_round_trip_restore() {
    local test_root
    local state_file
    local snapshot_dir
    local key

    test_root="$(mktemp -d)"
    state_file="$test_root/pmset-state"
    snapshot_dir="$test_root/snapshot"
    write_baseline "$state_file"

    run_powerctl "$state_file" "$snapshot_dir" on
    assert_state "$state_file" sleep_disabled 1
    for key in battery.sleep battery.disksleep battery.powernap charger.sleep charger.disksleep charger.powernap; do
        assert_state "$state_file" "$key" 0
    done
    assert_state "$state_file" battery.displaysleep 10
    assert_state "$state_file" charger.displaysleep 10
    assert_state "$state_file" battery.tcpkeepalive 1
    assert_state "$state_file" charger.womp 1
    [[ -f "$snapshot_dir/power-state" ]] || fail "snapshot missing after on"

    # A repeated ON must not replace the original pre-ON snapshot.
    run_powerctl "$state_file" "$snapshot_dir" on
    run_powerctl "$state_file" "$snapshot_dir" off
    assert_state "$state_file" sleep_disabled 0
    assert_state "$state_file" battery.sleep 17
    assert_state "$state_file" battery.disksleep 9
    assert_state "$state_file" battery.displaysleep 4
    assert_state "$state_file" battery.powernap 1
    assert_state "$state_file" battery.tcpkeepalive 0
    assert_state "$state_file" battery.womp 0
    assert_state "$state_file" charger.sleep 43
    assert_state "$state_file" charger.disksleep 21
    assert_state "$state_file" charger.displaysleep 8
    assert_state "$state_file" charger.powernap 1
    assert_state "$state_file" charger.tcpkeepalive 1
    assert_state "$state_file" charger.womp 1
    [[ ! -e "$snapshot_dir/power-state" ]] || fail "snapshot not deleted after verified restore"
    rm -rf "$test_root"
}

# Verifies a pre-existing SleepDisabled value survives a managed ON/OFF round trip.
#
# Args:
#   None.
test_round_trip_preserves_existing_sleep_disabled() {
    local test_root
    local state_file
    local snapshot_dir

    test_root="$(mktemp -d)"
    state_file="$test_root/pmset-state"
    snapshot_dir="$test_root/snapshot"
    write_baseline "$state_file" 1

    run_powerctl "$state_file" "$snapshot_dir" on
    run_powerctl "$state_file" "$snapshot_dir" off
    assert_state "$state_file" sleep_disabled 1
    assert_state "$state_file" battery.sleep 17
    assert_state "$state_file" charger.sleep 43
    [[ ! -e "$snapshot_dir/power-state" ]] || fail "snapshot not deleted after restoring SleepDisabled=1"
    rm -rf "$test_root"
}

# Verifies OFF without a managed snapshot leaves every user setting untouched.
#
# Args:
#   None.
test_off_without_snapshot_is_noop() {
    local test_root
    local state_file
    local snapshot_dir

    test_root="$(mktemp -d)"
    state_file="$test_root/pmset-state"
    snapshot_dir="$test_root/snapshot"
    write_baseline "$state_file" 1

    run_powerctl "$state_file" "$snapshot_dir" off
    assert_state "$state_file" sleep_disabled 1
    assert_state "$state_file" battery.sleep 17
    assert_state "$state_file" charger.sleep 43
    [[ ! -e "$snapshot_dir" ]] || fail "OFF without a snapshot created managed state"
    rm -rf "$test_root"
}

# Verifies a failed ON rolls back and does not strand a snapshot.
#
# Args:
#   None.
test_enable_failure_rolls_back() {
    local test_root
    local state_file
    local snapshot_dir

    test_root="$(mktemp -d)"
    state_file="$test_root/pmset-state"
    snapshot_dir="$test_root/snapshot"
    write_baseline "$state_file"

    if SLEEPLESS_POWERCTL_TEST=1 \
        SLEEPLESS_PMSET_BIN="$FAKE_PMSET" \
        SLEEPLESS_STATE_DIR="$snapshot_dir" \
        FAKE_PMSET_STATE="$state_file" \
        FAKE_PMSET_FAIL_ENABLE=1 \
            "$POWERCTL" on >"$test_root/enable.out" 2>"$test_root/enable.err"; then
        fail "failed enable unexpectedly succeeded"
    fi
    grep -Fq "failed to apply awake profile" "$test_root/enable.err" \
        || fail "failed enable did not report its cause"
    assert_state "$state_file" sleep_disabled 0
    assert_state "$state_file" battery.sleep 17
    assert_state "$state_file" charger.sleep 43
    [[ ! -e "$snapshot_dir/power-state" ]] || fail "snapshot stranded after rollback"
    rm -rf "$test_root"
}

# Verifies ON rejects a profile that pmset reports differently after applying it.
#
# Args:
#   None.
test_enable_verification_failure_rolls_back() {
    local test_root
    local state_file
    local snapshot_dir

    test_root="$(mktemp -d)"
    state_file="$test_root/pmset-state"
    snapshot_dir="$test_root/snapshot"
    write_baseline "$state_file"

    if SLEEPLESS_POWERCTL_TEST=1 \
        SLEEPLESS_PMSET_BIN="$FAKE_PMSET" \
        SLEEPLESS_STATE_DIR="$snapshot_dir" \
        FAKE_PMSET_STATE="$state_file" \
        FAKE_PMSET_CORRUPT_ENABLE=1 \
            "$POWERCTL" on >"$test_root/enable.out" 2>"$test_root/enable.err"; then
        fail "mismatched awake profile unexpectedly passed verification"
    fi
    grep -Fq "awake profile verification failed" "$test_root/enable.err" \
        || fail "verification failure did not report its cause"
    assert_state "$state_file" sleep_disabled 0
    assert_state "$state_file" battery.sleep 17
    assert_state "$state_file" charger.sleep 43
    [[ ! -e "$snapshot_dir/power-state" ]] || fail "snapshot stranded after verification rollback"
    rm -rf "$test_root"
}

# Verifies a failed OFF keeps the snapshot so restoration can be retried.
#
# Args:
#   None.
test_restore_failure_keeps_snapshot() {
    local test_root
    local state_file
    local snapshot_dir

    test_root="$(mktemp -d)"
    state_file="$test_root/pmset-state"
    snapshot_dir="$test_root/snapshot"
    write_baseline "$state_file"

    run_powerctl "$state_file" "$snapshot_dir" on
    if SLEEPLESS_POWERCTL_TEST=1 \
        SLEEPLESS_PMSET_BIN="$FAKE_PMSET" \
        SLEEPLESS_STATE_DIR="$snapshot_dir" \
        FAKE_PMSET_STATE="$state_file" \
        FAKE_PMSET_FAIL_RESTORE=1 \
            "$POWERCTL" off >"$test_root/restore.out" 2>"$test_root/restore.err"; then
        fail "failed restore unexpectedly succeeded"
    fi
    [[ -f "$snapshot_dir/power-state" ]] || fail "snapshot deleted after failed restore"

    run_powerctl "$state_file" "$snapshot_dir" off
    assert_state "$state_file" battery.sleep 17
    assert_state "$state_file" charger.sleep 43
    [[ ! -e "$snapshot_dir/power-state" ]] || fail "snapshot not deleted after retry"
    rm -rf "$test_root"
}

test_round_trip_restore
test_round_trip_preserves_existing_sleep_disabled
test_off_without_snapshot_is_noop
test_enable_failure_rolls_back
test_enable_verification_failure_rolls_back
test_restore_failure_keeps_snapshot
printf 'PASS: powerctl round-trip and rollback tests\n'
