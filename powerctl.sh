#!/usr/bin/env bash
# powerctl.sh — privileged power-profile switch for Sleepless.
#
# `on` snapshots only the settings Sleepless changes, then applies the fixed
# managed awake profile. `off` restores that exact snapshot. The state file is
# kept until restoration has been verified, so a failed restore is retryable.
set -euo pipefail

export LC_ALL=C
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

readonly POWERCTL_VERSION="1"
readonly HELPER_ID="com.aboudjem.Sleepless"
readonly DEFAULT_STATE_DIR="/var/db/$HELPER_ID"
readonly DEFAULT_PMSET_BIN="/usr/bin/pmset"
readonly PROFILE_KEYS=(sleep disksleep displaysleep powernap tcpkeepalive womp)
readonly AWAKE_SLEEP="0"
readonly AWAKE_DISKSLEEP="0"
readonly AWAKE_DISPLAYSLEEP="10"
readonly AWAKE_POWERNAP="0"
readonly AWAKE_TCPKEEPALIVE="1"
readonly AWAKE_WOMP="1"

if [[ "${SLEEPLESS_POWERCTL_TEST:-0}" == "1" && "$(id -u)" -ne 0 ]]; then
    readonly PMSET_BIN="${SLEEPLESS_PMSET_BIN:?SLEEPLESS_PMSET_BIN is required in test mode}"
    readonly STATE_DIR="${SLEEPLESS_STATE_DIR:?SLEEPLESS_STATE_DIR is required in test mode}"
    readonly TEST_MODE="1"
else
    readonly PMSET_BIN="$DEFAULT_PMSET_BIN"
    readonly STATE_DIR="$DEFAULT_STATE_DIR"
    readonly TEST_MODE="0"
fi
readonly STATE_FILE="$STATE_DIR/power-state"

# Reports a fatal helper error.
#
# Args:
#   $*: Error message.
die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

# Requires root for commands that change power-management state.
#
# Args:
#   None.
require_root() {
    if [[ "$TEST_MODE" != "1" && "$(id -u)" -ne 0 ]]; then
        die "powerctl must run as root for on/off"
    fi
}

# Creates the protected state directory.
#
# Args:
#   None.
ensure_state_dir() {
    if [[ "$TEST_MODE" == "1" ]]; then
        mkdir -p "$STATE_DIR"
        chmod 0755 "$STATE_DIR"
        return
    fi

    [[ ! -L "$STATE_DIR" ]] || die "refusing symlinked state directory: $STATE_DIR"
    install -d -m 0755 -o root -g wheel "$STATE_DIR"
}

# Reads the live undocumented SleepDisabled flag.
#
# Args:
#   None.
#
# Outputs:
#   `1` when enabled, otherwise `0`.
read_sleep_disabled() {
    "$PMSET_BIN" -g | awk '
        tolower($1) == "sleepdisabled" {
            print ($2 == "1" ? "1" : "0")
            found = 1
            exit
        }
        END {
            if (!found) {
                print "0"
            }
        }
    '
}

# Reads one setting from captured `pmset -g custom` output.
#
# Args:
#   $1: Section name, such as `Battery Power`.
#   $2: Setting key.
#
# Outputs:
#   The integer setting value.
read_custom_setting() {
    local section="$1"
    local key="$2"
    awk -v wanted_section="$section" -v wanted_key="$key" '
        /^[^[:space:]].*:$/ {
            current_section = $0
            sub(/:$/, "", current_section)
            next
        }
        current_section == wanted_section && $1 == wanted_key {
            print $2
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' <<<"$CUSTOM_OUTPUT"
}

# Returns whether a power-source section exists in captured custom settings.
#
# Args:
#   $1: Section name.
power_source_exists() {
    local section="$1"
    grep -Fqx "$section:" <<<"$CUSTOM_OUTPUT"
}

# Writes one power-source profile into the snapshot.
#
# Args:
#   $1: Snapshot prefix (`battery`, `charger`, or `ups`).
#   $2: `pmset -g custom` section name.
#   $3: Output file.
append_profile_snapshot() {
    local prefix="$1"
    local section="$2"
    local output_file="$3"
    local key
    local value

    power_source_exists "$section" || return 0
    printf '%s.present=1\n' "$prefix" >>"$output_file"
    for key in "${PROFILE_KEYS[@]}"; do
        if value="$(read_custom_setting "$section" "$key")"; then
            [[ "$value" =~ ^[0-9]+$ ]] || die "unexpected $section $key value: $value"
            printf '%s.%s=%s\n' "$prefix" "$key" "$value" >>"$output_file"
        fi
    done
}

# Atomically snapshots every setting that the awake profile will change.
#
# Args:
#   None.
snapshot_state() {
    local temporary_state
    local sleep_disabled

    [[ ! -e "$STATE_FILE" ]] || return 0
    ensure_state_dir
    CUSTOM_OUTPUT="$("$PMSET_BIN" -g custom)"
    sleep_disabled="$(read_sleep_disabled)"
    [[ "$sleep_disabled" =~ ^[01]$ ]] || die "unexpected SleepDisabled value: $sleep_disabled"

    temporary_state="$(mktemp "$STATE_DIR/.power-state.XXXXXX")"
    {
        printf 'version=%s\n' "$POWERCTL_VERSION"
        printf 'sleep_disabled=%s\n' "$sleep_disabled"
    } >"$temporary_state"
    append_profile_snapshot "battery" "Battery Power" "$temporary_state"
    append_profile_snapshot "charger" "AC Power" "$temporary_state"
    append_profile_snapshot "ups" "UPS Power" "$temporary_state"

    if [[ "$TEST_MODE" == "1" ]]; then
        chmod 0644 "$temporary_state"
        mv -f "$temporary_state" "$STATE_FILE"
    else
        install -m 0644 -o root -g wheel "$temporary_state" "$STATE_FILE"
        rm -f "$temporary_state"
    fi
}

# Reads a whitelisted value from the saved snapshot.
#
# Args:
#   $1: Exact snapshot key.
#
# Outputs:
#   The corresponding integer value.
saved_value() {
    local wanted_key="$1"
    awk -F= -v wanted_key="$wanted_key" '
        $1 == wanted_key {
            print $2
            found = 1
            exit
        }
        END {
            if (!found) {
                exit 1
            }
        }
    ' "$STATE_FILE"
}

# Returns the expected awake-profile value for a key.
#
# Args:
#   $1: Setting key.
#
# Outputs:
#   The expected integer value.
awake_value() {
    case "$1" in
        sleep) printf '%s\n' "$AWAKE_SLEEP" ;;
        disksleep) printf '%s\n' "$AWAKE_DISKSLEEP" ;;
        displaysleep) printf '%s\n' "$AWAKE_DISPLAYSLEEP" ;;
        powernap) printf '%s\n' "$AWAKE_POWERNAP" ;;
        tcpkeepalive) printf '%s\n' "$AWAKE_TCPKEEPALIVE" ;;
        womp) printf '%s\n' "$AWAKE_WOMP" ;;
        *) return 1 ;;
    esac
}

# Applies saved values to one power-source profile.
#
# Args:
#   $1: Snapshot prefix.
#   $2: pmset power-source flag.
restore_profile() {
    local prefix="$1"
    local source_flag="$2"
    local key
    local value
    local args=("$source_flag")

    saved_value "$prefix.present" >/dev/null 2>&1 || return 0
    for key in "${PROFILE_KEYS[@]}"; do
        if value="$(saved_value "$prefix.$key")"; then
            [[ "$value" =~ ^[0-9]+$ ]] || die "invalid saved $prefix.$key value: $value"
            args+=("$key" "$value")
        fi
    done
    [[ "${#args[@]}" -gt 1 ]] && "$PMSET_BIN" "${args[@]}"
}

# Verifies one power-source profile against saved or awake values.
#
# Args:
#   $1: Snapshot prefix.
#   $2: `pmset -g custom` section name.
#   $3: Verification mode (`saved` or `awake`).
verify_profile() {
    local prefix="$1"
    local section="$2"
    local mode="$3"
    local key
    local expected
    local actual

    saved_value "$prefix.present" >/dev/null 2>&1 || return 0
    for key in "${PROFILE_KEYS[@]}"; do
        saved_value "$prefix.$key" >/dev/null 2>&1 || continue
        if [[ "$mode" == "saved" ]]; then
            expected="$(saved_value "$prefix.$key")"
        else
            expected="$(awake_value "$key")"
        fi
        actual="$(read_custom_setting "$section" "$key")"
        [[ "$actual" == "$expected" ]] || {
            printf 'error: verification failed for %s %s: expected %s, got %s\n' \
                "$section" "$key" "$expected" "$actual" >&2
            return 1
        }
    done
}

# Verifies the complete managed power state.
#
# Args:
#   $1: Verification mode (`saved` or `awake`).
verify_state() {
    local mode="$1"
    local expected_sleep_disabled
    local actual_sleep_disabled

    CUSTOM_OUTPUT="$("$PMSET_BIN" -g custom)"
    verify_profile "battery" "Battery Power" "$mode" || return 1
    verify_profile "charger" "AC Power" "$mode" || return 1
    verify_profile "ups" "UPS Power" "$mode" || return 1

    if [[ "$mode" == "saved" ]]; then
        expected_sleep_disabled="$(saved_value "sleep_disabled")"
    else
        expected_sleep_disabled="1"
    fi
    actual_sleep_disabled="$(read_sleep_disabled)"
    [[ "$actual_sleep_disabled" == "$expected_sleep_disabled" ]] || {
        printf 'error: SleepDisabled verification failed: expected %s, got %s\n' \
            "$expected_sleep_disabled" "$actual_sleep_disabled" >&2
        return 1
    }
}

# Applies the managed awake profile after taking a recoverable snapshot.
#
# Args:
#   None.
enable_awake_profile() {
    snapshot_state
    if ! "$PMSET_BIN" -a \
        disablesleep 1 \
        sleep "$AWAKE_SLEEP" \
        disksleep "$AWAKE_DISKSLEEP" \
        displaysleep "$AWAKE_DISPLAYSLEEP" \
        powernap "$AWAKE_POWERNAP" \
        tcpkeepalive "$AWAKE_TCPKEEPALIVE" \
        womp "$AWAKE_WOMP"; then
        if restore_saved_profile; then
            die "failed to apply awake profile; original settings were restored"
        fi
        die "failed to apply awake profile; automatic restore also failed and the snapshot was kept"
    fi
    if ! verify_state "awake"; then
        if restore_saved_profile; then
            die "awake profile verification failed; original settings were restored"
        fi
        die "awake profile verification failed; automatic restore also failed and the snapshot was kept"
    fi
}

# Restores and verifies the snapshot, deleting it only after success.
#
# Args:
#   None.
restore_saved_profile() {
    local original_sleep_disabled
    local version

    if [[ ! -f "$STATE_FILE" ]]; then
        return 0
    fi

    version="$(saved_value "version")"
    [[ "$version" == "$POWERCTL_VERSION" ]] || die "unsupported state version: $version"
    original_sleep_disabled="$(saved_value "sleep_disabled")"
    [[ "$original_sleep_disabled" =~ ^[01]$ ]] || die "invalid saved SleepDisabled value"

    restore_profile "battery" "-b"
    restore_profile "charger" "-c"
    restore_profile "ups" "-u"
    "$PMSET_BIN" -a disablesleep "$original_sleep_disabled"
    verify_state "saved"
    rm -f "$STATE_FILE"
}

# Prints whether a managed snapshot is active.
#
# Args:
#   None.
#
# Outputs:
#   `active` or `inactive`.
print_status() {
    if [[ -f "$STATE_FILE" ]]; then
        printf 'active\n'
        return 0
    fi
    printf 'inactive\n'
    return 1
}

# Dispatches the strict helper command surface.
#
# Args:
#   $1: One of `on`, `off`, or `status`.
main() {
    [[ "$#" -eq 1 ]] || die "usage: powerctl.sh {on|off|status}"
    case "$1" in
        on)
            require_root
            enable_awake_profile
            ;;
        off)
            require_root
            restore_saved_profile
            ;;
        status)
            print_status
            ;;
        *)
            die "usage: powerctl.sh {on|off|status}"
            ;;
    esac
}

main "$@"
