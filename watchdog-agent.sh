#!/usr/bin/env bash
# Unprivileged agent lifecycle. All state transitions are serialized by the native helper.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$REPO/SleeplessSafety"
[ -x "$TOOL" ] || TOOL="$REPO/build/Sleepless.app/Contents/Resources/SleeplessSafety"
[ -x "$TOOL" ] || { echo 'Build Sleepless before managing its watchdog.' >&2; exit 1; }
case "${1:-}" in
  install) exec "$TOOL" install-agent ;;
  uninstall) exec "$TOOL" remove-agent ;;
  status) exec "$TOOL" ready ;;
  *) echo 'Usage: watchdog-agent.sh install|uninstall|status' >&2; exit 64 ;;
esac
