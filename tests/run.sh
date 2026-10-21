#!/usr/bin/env bash
# No sudo execution, LaunchAgent installation or real sleep-setting changes.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$REPO/build/ModuleCache"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -warnings-as-errors -module-cache-path "$REPO/build/ModuleCache" -parse-as-library \
  "$REPO/SafetyCore.swift" "$REPO/tests/SafetyTests.swift" -o "$TMP/safety-tests"
"$TMP/safety-tests"
/usr/bin/python3 "$REPO/tests/LifecycleTests.py"
for script in "$REPO"/*.sh "$REPO"/tests/*.sh; do bash -n "$script"; done
if [ "${1:-}" = "--unit-only" ]; then
  echo 'Native power-source checks omitted in headless CI; run tests/run.sh in the desktop test environment.'
  exit 0
fi
swiftc -warnings-as-errors -module-cache-path "$REPO/build/ModuleCache" -parse-as-library -framework IOKit \
  "$REPO/SafetyCore.swift" "$REPO/MacSafetyEnvironment.swift" "$REPO/tests/NativeChecks.swift" -o "$TMP/native-checks"
"$TMP/native-checks"
