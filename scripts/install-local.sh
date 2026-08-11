#!/usr/bin/env bash
set -euo pipefail

# Installs a locally built rcmd.app and registers it as a login item.
#
# Environment:
#   INSTALL_DIR  destination directory (default /Applications)
#   VERSION      version stamped into Info.plist (default local -> 0.0.0)
#   LOGIN_ITEM   1 to register Launch at Login, 0 to skip (default 1)
#   LAUNCH       1 to start the app after installing, 0 to skip (default 1)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

install_dir="${INSTALL_DIR:-/Applications}"
version="${VERSION:-local}"
login_item="${LOGIN_ITEM:-1}"
launch="${LAUNCH:-1}"

installed_app="${install_dir}/rcmd.app"
stage_dir="${repo_root}/dist/install"
running_pattern="rcmd.app/Contents/MacOS/rcmd"

if [ ! -d "$install_dir" ]; then
  echo "Install directory ${install_dir} does not exist." >&2
  exit 1
fi

if [ ! -w "$install_dir" ]; then
  echo "No write access to ${install_dir}." >&2
  echo "Re-run with sudo, or set INSTALL_DIR=\"\$HOME/Applications\"." >&2
  exit 1
fi

rm -rf "$stage_dir"
mkdir -p "$stage_dir"

built_app="$("${repo_root}/scripts/build-app.sh" "$version" "$stage_dir")"

if pgrep -f "$running_pattern" >/dev/null 2>&1; then
  echo "Stopping running rcmd instance"
  pkill -f "$running_pattern" || true
fi

echo "Installing ${built_app} -> ${installed_app}"
rm -rf "$installed_app"
ditto "$built_app" "$installed_app"

# Let Launch Services pick up the freshly installed bundle before anything
# else refers to it by bundle identifier.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$installed_app" >/dev/null 2>&1 || true

if [ "$login_item" = "1" ]; then
  echo "Registering Launch at Login"
  "${installed_app}/Contents/MacOS/rcmd" --enable-login-item
fi

if [ "$launch" = "1" ]; then
  echo "Launching rcmd"
  open "$installed_app"
fi

echo
echo "Installed rcmd at ${installed_app}."
echo "Grant Accessibility permission in System Settings > Privacy & Security >"
echo "Accessibility if the menu bar item reports it as missing. Because the app"
echo "is ad-hoc signed, macOS asks again after every reinstall."
