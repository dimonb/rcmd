#!/usr/bin/env bash
set -euo pipefail

# Builds rcmd.app from the SwiftPM release product.
#
# Usage: build-app.sh <version|local> <staging-dir>
#
# Everything except the final app bundle path goes to stderr so callers can
# capture the path with a command substitution.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

input_version="${1:-local}"
stage_dir="${2:-}"

if [ -z "$stage_dir" ]; then
  echo "usage: build-app.sh <version|local> <staging-dir>" >&2
  exit 2
fi

if [ "$input_version" = "local" ]; then
  version=""
else
  version="${input_version#v}"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be a semantic version like 0.1.0." >&2
    exit 1
  fi
fi

swift build -c release >&2

bin_path="$(swift build -c release --show-bin-path)"
binary_path="${bin_path}/rcmd-app"
resource_bundle_path="${bin_path}/rcmd_RcmdApp.bundle"

if [ ! -x "$binary_path" ]; then
  echo "Release binary not found at ${binary_path}" >&2
  exit 1
fi

if [ ! -d "$resource_bundle_path" ]; then
  echo "Resource bundle not found at ${resource_bundle_path}" >&2
  exit 1
fi

app_path="${stage_dir}/rcmd.app"
contents_dir="${app_path}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"
iconset_path="${stage_dir}/AppIcon.iconset"

rm -rf "$app_path" "$iconset_path"
mkdir -p "$macos_dir" "$resources_dir"

cp "$binary_path" "${macos_dir}/rcmd"
chmod +x "${macos_dir}/rcmd"
cp packaging/Info.plist "${contents_dir}/Info.plist"

# The `.lproj` folders must live inside the app bundle. Without them the app
# falls back to the absolute SwiftPM build path baked into `Bundle.module` and
# traps on launch on any machine that does not have this checkout.
lproj_count=0
for lproj_path in "$resource_bundle_path"/*.lproj; do
  if [ -d "$lproj_path" ]; then
    cp -R "$lproj_path" "${resources_dir}/"
    lproj_count=$((lproj_count + 1))
  fi
done

if [ "$lproj_count" -eq 0 ]; then
  echo "No .lproj folders found in ${resource_bundle_path}" >&2
  exit 1
fi

"${repo_root}/scripts/generate-app-icon.swift" "$iconset_path" >&2
iconutil -c icns "$iconset_path" -o "${resources_dir}/AppIcon.icns" >&2
rm -rf "$iconset_path"

if [ -n "$version" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "${contents_dir}/Info.plist" >&2
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${version}" "${contents_dir}/Info.plist" >&2
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$app_path" >/dev/null 2>&1 || true
fi

echo "$app_path"
