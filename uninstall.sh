#!/usr/bin/env bash
# uninstall.sh — completely back Sleepless out: restore normal sleep, remove the app,
# the login item, AND the passwordless grant. Ends by PROVING the privilege is gone.
set -uo pipefail   # not -e: we want to attempt every cleanup step even if one is absent

APP_NAME="Sleepless"
APP="/Applications/$APP_NAME.app"
BUNDLE_ID="com.aboudjem.Sleepless"
SUDOERS_DST="/etc/sudoers.d/sleepless-disablesleep"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

echo "Sleepless uninstaller"
echo "====================="

# 1. Restore normal sleep BEFORE removing the grant (a reboot would also reset it to 0).
echo "==> Restoring normal sleep (disablesleep 0)"
sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null || sudo /usr/bin/pmset -a disablesleep 0 || true

# 2. Quit the app + remove the login item.
echo "==> Quitting app + removing login item"
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
rm -f "$LAUNCH_AGENT"

# 3. Remove the app.
echo "==> Removing $APP"
rm -rf "$APP"

# 4. Remove the passwordless grant (password required, by design — you're touching sudo).
echo "==> Removing passwordless grant (you may be asked for your password)"
sudo rm -f "$SUDOERS_DST"
sudo visudo -c >/dev/null && echo "    sudoers still parses cleanly"

# 5. Proof of revocation: the previously-passwordless command must now PROMPT.
echo "==> Verifying the grant is gone"
sudo -k
if sudo -n /usr/bin/pmset -a disablesleep 0 2>/dev/null; then
  echo "    ⚠️  unexpected: pmset still ran without a password — check $SUDOERS_DST"
else
  echo "    ✅ revoked: 'sudo -n pmset …' now requires a password again."
fi

echo ""
echo "Done. Sleepless and its grant are removed. UserDefaults (the battery-floor value)"
echo "can be cleared with: defaults delete $BUNDLE_ID 2>/dev/null || true"
