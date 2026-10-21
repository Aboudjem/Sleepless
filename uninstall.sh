#!/usr/bin/env bash
# Stop on failure. Recovery and the grant must survive an unsuccessful restoration.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP=/Applications/Sleepless.app
TOOL="$REPO/SleeplessSafety"
[ -x "$TOOL" ] || TOOL="$APP/Contents/Resources/SleeplessSafety"
[ -x "$TOOL" ] || TOOL="$REPO/build/Sleepless.app/Contents/Resources/SleeplessSafety"
[ -x "$TOOL" ] || { echo 'Recovery helper is missing. Nothing removed; repair the app first.' >&2; exit 1; }
echo 'Restoring owned sleep prevention and verifying normal sleep before removal.'
# This fences all new arms and renewals, including an app left running after a failed quit.
"$TOOL" quiesce
if /usr/bin/pgrep -x Sleepless >/dev/null; then
  /usr/bin/osascript -e 'tell application id "com.aboudjem.Sleepless" to quit'
fi
# Re-check under the same lock immediately before unloading the independent watchdog.
"$TOOL" remove-agent
LEGACY_AGENT="$HOME/Library/LaunchAgents/com.aboudjem.Sleepless.plist"
if [ -f "$LEGACY_AGENT" ]; then
  /bin/launchctl bootout "gui/$(id -u)/com.aboudjem.Sleepless" 2>/dev/null || true
  rm -f "$LEGACY_AGENT"
fi
# No sleep-changing command is used to test revocation.
# Keep removal usable from an agent-driven session without a Terminal password prompt.
# The authorization sheet runs a fixed command; it never executes bundled code as root.
/usr/bin/osascript -e 'do shell script "/bin/rm -f /etc/sudoers.d/sleepless-disablesleep && /usr/sbin/visudo -c" with administrator privileges'
rm -rf "$APP"
echo 'Removed app, watchdog and scoped grant. Preferences are retained.'
echo 'A locked-down maintenance marker remains to prevent any old running copy from re-arming.'
