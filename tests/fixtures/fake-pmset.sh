#!/usr/bin/env bash
# Minimal stateful pmset double for powerctl integration tests.
set -euo pipefail

: "${FAKE_PMSET_STATE:?FAKE_PMSET_STATE is required}"

# Reads a value from the fake state file.
#
# Args:
#   $1: Exact state key.
#
# Outputs:
#   The stored value.
get_value() {
    local wanted_key="$1"
    awk -F= -v wanted_key="$wanted_key" '$1 == wanted_key { print $2; exit }' "$FAKE_PMSET_STATE"
}

# Replaces one value in the fake state file.
#
# Args:
#   $1: Exact state key.
#   $2: New value.
set_value() {
    local wanted_key="$1"
    local new_value="$2"
    local temporary_file="${FAKE_PMSET_STATE}.tmp"

    awk -F= -v wanted_key="$wanted_key" -v new_value="$new_value" '
        BEGIN { replaced = 0 }
        $1 == wanted_key {
            print wanted_key "=" new_value
            replaced = 1
            next
        }
        { print }
        END {
            if (!replaced) {
                print wanted_key "=" new_value
            }
        }
    ' "$FAKE_PMSET_STATE" >"$temporary_file"
    mv "$temporary_file" "$FAKE_PMSET_STATE"
}

# Prints one fake power-source profile.
#
# Args:
#   $1: Display section name.
#   $2: State-key prefix.
print_profile() {
    local section="$1"
    local prefix="$2"
    local key

    printf '%s:\n' "$section"
    for key in sleep disksleep displaysleep powernap tcpkeepalive womp; do
        printf ' %s %s\n' "$key" "$(get_value "$prefix.$key")"
    done
}

# Applies key/value arguments to the selected fake profiles.
#
# Args:
#   $1: Source selector (`all`, `battery`, `charger`, or `ups`).
#   Remaining args: pmset-style key/value pairs.
apply_values() {
    local source="$1"
    shift
    local key
    local value
    local prefix
    local prefixes=()

    case "$source" in
        all) prefixes=(battery charger) ;;
        battery) prefixes=(battery) ;;
        charger) prefixes=(charger) ;;
        ups) prefixes=(ups) ;;
        *) exit 2 ;;
    esac

    while [[ "$#" -gt 0 ]]; do
        key="$1"
        value="$2"
        shift 2
        if [[ "$key" == "disablesleep" ]]; then
            set_value "sleep_disabled" "$value"
            continue
        fi
        for prefix in "${prefixes[@]}"; do
            set_value "$prefix.$key" "$value"
        done
    done
}

if [[ "${1:-}" == "-g" && "$#" -eq 1 ]]; then
    printf 'System-wide power settings:\n SleepDisabled\t\t%s\n' "$(get_value sleep_disabled)"
    exit 0
fi

if [[ "${1:-}" == "-g" && "${2:-}" == "custom" ]]; then
    print_profile "Battery Power" "battery"
    print_profile "AC Power" "charger"
    exit 0
fi

case "${1:-}" in
    -a) source="all" ;;
    -b) source="battery" ;;
    -c) source="charger" ;;
    -u) source="ups" ;;
    *) exit 2 ;;
esac
shift

if [[ "${FAKE_PMSET_FAIL_ENABLE:-0}" == "1" && "$source" == "all" && "$*" == *"disablesleep 1"* ]]; then
    exit 9
fi
if [[ "${FAKE_PMSET_FAIL_RESTORE:-0}" == "1" && "$source" == "battery" ]]; then
    exit 10
fi
apply_values "$source" "$@"
if [[ "${FAKE_PMSET_CORRUPT_ENABLE:-0}" == "1" && "$source" == "all" && "$*" == *"disablesleep 1"* ]]; then
    set_value "battery.sleep" "99"
fi
