#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <food|stock|istqb> <debug|release> <app-version> <apk>" >&2
  exit 2
}

[[ $# -eq 4 ]] || usage

app=$1
channel=$2
version=$3
apk=$4

case "$app" in
  food) title="Food" ;;
  stock) title="Stock" ;;
  istqb) title="ISTQB" ;;
  *) usage ;;
esac

case "$channel" in
  debug|release) ;;
  *) usage ;;
esac

[[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?([.-][A-Za-z0-9.-]+)?$ ]] || {
  echo "Invalid app version: $version" >&2
  exit 2
}

if [[ ! -f "$apk" || "$apk" != *.apk ]]; then
  echo "APK file not found or invalid: $apk" >&2
  exit 2
fi
apk=$(realpath -- "$apk")

asset_name="${app}-${channel}.apk"
tag="${app}-${channel}-v${version}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
upload_dir=$(mktemp -d)
trap 'rm -rf "$upload_dir"' EXIT
staged_apk="$upload_dir/$asset_name"
cp -- "$apk" "$staged_apk"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/devtools/android-sdk}}"
apksigner="${APKSIGNER:-}"
if [[ -z "$apksigner" ]]; then
  for candidate in "$sdk_root"/build-tools/*/apksigner; do
    [[ -x "$candidate" ]] && apksigner="$candidate"
  done
fi
if [[ -z "$apksigner" || ! -x "$apksigner" ]]; then
  echo "Could not locate apksigner; set APKSIGNER or ANDROID_SDK_ROOT." >&2
  exit 1
fi

if ! "$apksigner" verify "$staged_apk" >/dev/null 2>&1; then
  if [[ "$channel" != release ]]; then
    echo "Debug APK is not signed: $apk" >&2
    exit 1
  fi
  keystore="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
  if [[ ! -f "$keystore" ]]; then
    echo "Release APK is unsigned and debug keystore is missing: $keystore" >&2
    exit 1
  fi
  "$apksigner" sign \
    --ks "$keystore" \
    --ks-key-alias androiddebugkey \
    --ks-pass pass:android \
    --key-pass pass:android \
    "$staged_apk"
fi
"$apksigner" verify "$staged_apk" >/dev/null

local_digest="sha256:$(sha256sum "$staged_apk" | cut -d ' ' -f 1)"
matching_digest=$(gh api --paginate --slurp "repos/Athenova-tools/APK/releases?per_page=100" \
  | python3 -c 'import json,sys; app,channel,asset_name=sys.argv[1:]; pages=json.load(sys.stdin); releases=[release for page in pages for release in page]; matches=[]
for release in releases:
 tag=release.get("tag_name", "")
 if release.get("draft") or release.get("prerelease"): continue
 if tag.startswith(f"{app}-{channel}-v") or tag.startswith(f"{app}-v"):
  matches.extend((release.get("published_at", ""), asset.get("digest", "")) for asset in release.get("assets", []) if asset.get("name")==asset_name)
print(max(matches, default=("", ""))[1])' "$app" "$channel" "$asset_name")
if [[ "$local_digest" == "$matching_digest" ]]; then
  printf 'APK generated at: %s\n' "$apk"
  printf 'Publication successful: identical APK already available (%s %s v%s).\n' "$title" "$channel" "$version"
  printf 'APK Index: https://athenova-tools.github.io/APK/\n'
  exit 0
fi

gh release create "$tag" \
  "$staged_apk" \
  --repo Athenova-tools/APK \
  --title "$title $channel v$version" \
  --notes "Publicação de $title $channel v$version." \
  --latest=false

printf 'APK generated at: %s\n' "$apk"
printf 'Published successfully: %s %s v%s (%s)\n' "$title" "$channel" "$version" "$tag"
printf 'APK Index: https://athenova-tools.github.io/APK/\n'
printf 'Release assets: https://github.com/Athenova-tools/APK/releases/tag/%s\n' "$tag"
