#!/usr/bin/env bash
# grant.sh — install ONLY the passwordless grant that lets Sleepless toggle lid-close
# sleep without a prompt. Self-contained: works from a clone OR from inside the app
# bundle (Contents/Resources), so Homebrew-cask users can run it after install.
#
# It writes one tightly scoped sudoers drop-in (root:wheel, 0440) permitting exactly two
# commands and nothing else. See SECURITY.md. Undo with uninstall.sh (or sudo rm the file).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDOERS_DST="/etc/sudoers.d/sleepless-disablesleep"
# Resolve the REAL user. Prefer SLEEPLESS_USER (the app passes it, because under the native
# auth sheet this script runs as root with SUDO_USER unset), then SUDO_USER, then the caller.
USER_NAME="${SLEEPLESS_USER:-${SUDO_USER:-$(id -un)}}"
# Never install a root-owned grant (it is useless and not what the user wants): if we somehow
# resolved to root/empty, fall back to the GUI console user, and refuse if still unresolved.
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
  USER_NAME="$(stat -f%Su /dev/console 2>/dev/null || true)"
fi
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = "root" ]; then
  echo "error: could not resolve a non-root user for the grant; refusing to install." >&2
  exit 1
fi

if ! [[ "$USER_NAME" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]]; then
  echo 'error: invalid account name.' >&2; exit 1
fi

GRANT="$USER_NAME ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
echo "Sleepless will install this passwordless grant (root:wheel, 0440):"
echo "    $GRANT"
if [ "${1:-}" != "--yes" ] && [ "${1:-}" != "-y" ]; then
  read -r -p "Continue? [y/N] " reply
  case "$reply" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac
fi

# A fixed installer body preserves the native password/Touch ID sheet when the operator
# has no interactive Terminal. Only the validated username varies. Never elevate a
# bundled script, an editable template or a user-created temporary file.
BODY="$(cat <<INSTALL_BODY
set -eu
t=\$(/usr/bin/mktemp /private/tmp/sleepless-grant.XXXXXX)
trap '/bin/rm -f "\$t"' EXIT
/usr/bin/printf '%s\\n' '$GRANT' > "\$t"
/usr/sbin/visudo -cf "\$t"
/usr/bin/install -m 0440 -o root -g wheel "\$t" /etc/sudoers.d/sleepless-disablesleep
/usr/sbin/visudo -c
INSTALL_BODY
)"
if [ "$(id -u)" -eq 0 ]; then
  /bin/sh -c "$BODY"
else
  ESCAPED="${BODY//\\/\\\\}"
  ESCAPED="${ESCAPED//\"/\\\"}"
  /usr/bin/osascript -e "do shell script \"$ESCAPED\" with administrator privileges"
fi
echo 'Grant installed. Keep-awake still requires a healthy independent watchdog.'
