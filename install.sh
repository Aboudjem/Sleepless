#!/usr/bin/env bash
# Source installation/upgrade; downloaded .app users retain native in-app setup.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP=/Applications/Sleepless.app
BUNDLE_ID=com.aboudjem.Sleepless
LEGACY_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
echo 'Build and install Sleepless, its two-command sleep grant, and its per-user recovery watchdog.'
echo 'An upgrade first restores owned sleep prevention. Unowned state is left unchanged and blocks installation.'
read -r -p 'Continue? [y/N] ' reply
case "$reply" in [yY]*) ;; *) exit 1 ;; esac
"$REPO/build.sh"
RESOURCES="$REPO/build/Sleepless.app/Contents/Resources"
# Fence old GUI sessions and verify normal sleep before touching the installed app.
"$RESOURCES/SleeplessSafety" quiesce
if /usr/bin/pgrep -x Sleepless >/dev/null; then
  /usr/bin/osascript -e 'tell application id "com.aboudjem.Sleepless" to quit'
fi
"$REPO/grant.sh" --yes
# Authorization must be usable for BOTH directions, not merely valid sudoers syntax.
"$RESOURCES/SleeplessSafety" permissions
/usr/bin/ditto "$REPO/build/Sleepless.app" "$APP"
"$APP/Contents/Resources/watchdog-agent.sh" install
# Migrate the old installer login item; the native Launch at login setting remains optional.
if [ -f "$LEGACY_AGENT" ]; then
  /bin/launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
  rm -f "$LEGACY_AGENT"
fi
open "$APP"
echo 'Installed. Keep-awake remains off. Use the existing Launch at login switch if wanted.'
