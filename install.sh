#!/usr/bin/env bash
# install.sh — build Sleepless, install it to /Applications, add the passwordless
# grant that lets it toggle lid-close sleep, and (optionally) start it at login.
#
# This is the ONLY script that touches sudo. It tells you exactly what it will write
# before it writes it. To back everything out, run ./uninstall.sh.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Sleepless"
APP="/Applications/$APP_NAME.app"
BUNDLE_ID="com.aboudjem.Sleepless"
SUDOERS_DST="/etc/sudoers.d/sleepless-disablesleep"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
USER_NAME="$(id -un)"

echo "Sleepless installer"
echo "==================="
echo "This will:"
echo "  1. Build $APP_NAME.app and copy it to /Applications."
echo "  2. Install a passwordless sudo grant at $SUDOERS_DST so the app can flip"
echo "     lid-close sleep without prompting. The grant (root:wheel, 0440) is EXACTLY:"
echo ""
echo "       $USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
echo ""
echo "     That is the only thing it permits — turn lid-close sleep on or off. Nothing else."
echo "  3. Add a login item (~/Library/LaunchAgents/$BUNDLE_ID.plist) so it starts at login."
echo ""
read -r -p "Continue? [y/N] " reply
case "$reply" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac

# 1. Build into /Applications.
echo "==> Building into /Applications"
DEST=/Applications "$REPO/build.sh" /Applications

# 2. Passwordless grant. Generate from the template (substitute the current user),
#    validate syntax, then install root:wheel 0440. visudo -cf checks syntax only,
#    so we install with explicit perms via `install`.
echo "==> Installing passwordless grant (you'll be asked for your password once)"
TMP_SUDOERS="$(mktemp)"
sed "s/__USER__/$USER_NAME/" "$REPO/sleepless.sudoers.template" > "$TMP_SUDOERS"
if ! sudo visudo -cf "$TMP_SUDOERS" >/dev/null; then
  echo "error: generated sudoers file failed validation; not installing." >&2
  rm -f "$TMP_SUDOERS"; exit 1
fi
sudo install -m 0440 -o root -g wheel "$TMP_SUDOERS" "$SUDOERS_DST"
rm -f "$TMP_SUDOERS"
sudo visudo -c >/dev/null && echo "    sudoers OK ($SUDOERS_DST, root:wheel 0440)"

# 3. Login item.
echo "==> Installing login item"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>            <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key> <array><string>/usr/bin/open</string><string>-a</string><string>$APP</string></array>
    <key>RunAtLoad</key>        <true/>
    <key>KeepAlive</key>        <false/>
    <key>ProcessType</key>      <string>Interactive</string>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT" 2>/dev/null || true

# Launch now.
open "$APP"

echo ""
echo "✅ Installed. The moon is in your menu bar — click it to toggle."
echo "   Turn ON, close the lid: your Mac stays awake on battery (auto-off at the floor you set)."
echo "   To remove everything (including the grant): ./uninstall.sh"
