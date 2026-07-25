#!/usr/bin/env bash
# grant.sh — install the root-owned fixed power helper and its exact-argument grant.
#
# It works from a clone or from the app bundle's Contents/Resources directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDOERS_DST="/etc/sudoers.d/sleepless-powerctl"
LEGACY_SUDOERS_DST="/etc/sudoers.d/sleepless-disablesleep"
HELPER_SRC="$SCRIPT_DIR/powerctl.sh"
HELPER_DST="/Library/PrivilegedHelperTools/com.aboudjem.Sleepless.powerctl"
# Resolve the REAL user. Prefer SLEEPLESS_USER (the app passes it, because under the native
# auth sheet this script runs as root with SUDO_USER unset), then SUDO_USER, then the caller.
USER_NAME="${SLEEPLESS_USER:-${SUDO_USER:-$(id -un)}}"
# Never install a root-owned grant (it is useless and not what the user wants): if we somehow
# resolved to root/empty, fall back to the GUI console user, and refuse if still unresolved.
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
  USER_NAME="$(stat -f%Su /dev/console 2>/dev/null || true)"
fi
[ -f "$HELPER_SRC" ] || {
  echo "error: missing bundled helper: $HELPER_SRC" >&2
  exit 1
}
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
  echo "error: could not resolve a non-root user for the grant; refusing to install." >&2
  exit 1
fi

# Run privileged steps with sudo normally, but directly when we are ALREADY root (e.g. the
# app installs this via one native macOS auth sheet, so there is no Terminal + no sudo prompt).
SUDO="sudo"
[ "$(id -u)" -eq 0 ] && SUDO=""

# Source of truth for the grant line: the repo template if present, else the
# identical inline string used from an app bundle.
TEMPLATE="$SCRIPT_DIR/sleepless.sudoers.template"
if [ -f "$TEMPLATE" ]; then
  GRANT="$(sed "s/__USER__/$USER_NAME/" "$TEMPLATE")"
else
  GRANT="$USER_NAME ALL=(root) NOPASSWD: $HELPER_DST on, $HELPER_DST off"
fi

echo "Sleepless will install a root-owned helper at $HELPER_DST (root:wheel, 0755)"
echo "and this passwordless grant at $SUDOERS_DST (root:wheel, 0440):"
echo ""
echo "    $GRANT"
echo ""
echo "It permits ONLY the helper's fixed, validated on/off transitions."
if [ "${1:-}" != "--yes" ] && [ "${1:-}" != "-y" ]; then
  read -r -p "Continue? [y/N] " reply
  case "$reply" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac
fi

TMP="$(mktemp)"
printf '%s\n' "$GRANT" > "$TMP"
if ! $SUDO visudo -cf "$TMP" >/dev/null; then
  echo "error: generated sudoers failed validation; not installing." >&2
  rm -f "$TMP"; exit 1
fi

# An upgrade from <=1.2.7 may leave SleepDisabled=1 without a snapshot. Restore
# the legacy version's defined OFF state while its exact pmset grant still exists.
if [ -f "$LEGACY_SUDOERS_DST" ]; then
  echo "==> Migrating the legacy sleep flag to its defined OFF state"
  $SUDO /usr/bin/pmset -a disablesleep 0
fi

$SUDO install -m 0755 -o root -g wheel "$HELPER_SRC" "$HELPER_DST"
$SUDO install -m 0440 -o root -g wheel "$TMP" "$SUDOERS_DST"
rm -f "$TMP"
$SUDO rm -f "$LEGACY_SUDOERS_DST"
$SUDO visudo -c >/dev/null && echo "✅ grant installed and sudoers parses cleanly ($SUDOERS_DST)."
echo "   Helper installed root-owned at $HELPER_DST."
