#!/usr/bin/env bash
# uninstall.sh — restore the saved profile, then remove Sleepless and its privilege.
set -uo pipefail   # not -e: we want to attempt every cleanup step even if one is absent

APP_NAME="Sleepless"
APP="/Applications/$APP_NAME.app"
BUNDLE_ID="com.aboudjem.Sleepless"
SUDOERS_DST="/etc/sudoers.d/sleepless-powerctl"
LEGACY_SUDOERS_DST="/etc/sudoers.d/sleepless-disablesleep"
HELPER_DST="/Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl"
STATE_DIR="/var/db/com.aboudjem.Sleepless"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

echo "Sleepless uninstaller"
echo "====================="

# 1. Restore the captured user profile BEFORE removing its helper or grant.
echo "==> Restoring the saved power profile"
if [ -x "$HELPER_DST" ]; then
  if ! sudo -n "$HELPER_DST" off 2>/dev/null && ! sudo "$HELPER_DST" off; then
    echo "error: couldn't restore the saved power profile; uninstall stopped." >&2
    echo "       The helper and snapshot were kept so restoration can be retried." >&2
    exit 1
  fi
elif [ -f "$STATE_DIR/power-state" ]; then
  echo "error: a saved profile exists but the restore helper is missing: $HELPER_DST" >&2
  exit 1
fi

# 2. Quit the app + remove the login item.
echo "==> Quitting app + removing login item"
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
rm -f "$LAUNCH_AGENT"

# 3. Remove the app.
echo "==> Removing $APP"
rm -rf "$APP"

# 4. Remove the passwordless grant, root-owned helper, and empty state directory.
echo "==> Removing passwordless grant and helper (you may be asked for your password)"
sudo rm -f "$SUDOERS_DST"
sudo rm -f "$LEGACY_SUDOERS_DST"
sudo rm -f "$HELPER_DST"
sudo rmdir "$STATE_DIR" 2>/dev/null || true
sudo visudo -c >/dev/null && echo "    sudoers still parses cleanly"

# 5. Proof of revocation: the previously-passwordless command must now PROMPT.
echo "==> Verifying the grant is gone"
sudo -k
if sudo -n "$HELPER_DST" off 2>/dev/null; then
  echo "    ⚠️  unexpected: helper command still ran without a password — check $SUDOERS_DST"
else
  echo "    ✅ revoked: the managed power command no longer runs passwordlessly."
fi

echo ""
echo "Done. Sleepless and its grant are removed. UserDefaults (the battery-floor value)"
echo "can be cleared with: defaults delete $BUNDLE_ID 2>/dev/null || true"
