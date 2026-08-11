#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

input_version="${1:-${VERSION:-local}}"

if [ "$input_version" = "local" ]; then
  tag="local"
else
  version="${input_version#v}"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be a semantic version like 0.1.0." >&2
    exit 1
  fi
  tag="v${version}"
fi

dist_dir="${repo_root}/dist"
stage_dir="${dist_dir}/rcmd-${tag}-macos"
artifact_path="${dist_dir}/rcmd-${tag}-macos.dmg"

rm -rf "$stage_dir" "$artifact_path"
mkdir -p "$stage_dir"

app_path="$("${repo_root}/scripts/build-app.sh" "$input_version" "$stage_dir")"

cp README.md "${stage_dir}/README.md"
ln -s /Applications "${stage_dir}/Applications"

cat > "${stage_dir}/INSTALL.txt" <<'INSTALL'
This DMG contains an unsigned rcmd.app build.

Drag rcmd.app onto the Applications shortcut, then launch it normally from
/Applications.

The app requires macOS Accessibility permission before global keyboard
shortcuts can work.
INSTALL

hdiutil create \
  -volname "rcmd ${tag}" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$artifact_path" >&2

echo "Packaged ${app_path}" >&2
echo "$artifact_path"
