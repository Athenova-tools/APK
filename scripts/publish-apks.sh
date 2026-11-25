#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <food|stock|istqb> <debug|release> <app-version> <apk> [version-code]" >&2
  exit 2
}

[[ $# -eq 4 || $# -eq 5 ]] || usage

app=$1
channel=$2
version=$3
apk=$4
version_code=${5:-}

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
if [[ -n "$version_code" && ! "$version_code" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid version code: $version_code" >&2
  exit 2
fi

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
release_pages="$upload_dir/releases-pages.json"
manifest_repo="$(cd "$(dirname "$0")/.." && pwd)"
source "$(dirname "$0")/gh-releases-api.sh"

refresh_release_manifest() {
  apk_index_fetch_releases "$release_pages"
  python3 "$manifest_repo/scripts/update_release_manifest.py" \
    "$app" "$release_pages" "$manifest_repo/${app}-releases.json"
  if ! git -C "$manifest_repo" diff --quiet -- "${app}-releases.json" ||
    ! git -C "$manifest_repo" ls-files --error-unmatch "${app}-releases.json" >/dev/null 2>&1; then
    git -C "$manifest_repo" add -- "${app}-releases.json"
    git -C "$manifest_repo" commit -m "Atualiza manifesto de releases de $title"
    git -C "$manifest_repo" push origin HEAD
    printf 'Release manifest updated: https://athenova-tools.github.io/APK/%s-releases.json\n' "$app"
  fi
}

apk_index_fetch_releases "$release_pages"
matching_digest=$(python3 -c 'import json,sys; app,channel,asset_name,source=sys.argv[1:]; pages=json.load(open(source)); releases=[release for page in pages for release in page]; matches=[]
for release in releases:
 tag=release.get("tag_name", "")
 if release.get("draft") or release.get("prerelease"): continue
 if tag.startswith(f"{app}-{channel}-v") or tag.startswith(f"{app}-v"):
  matches.extend((release.get("published_at", ""), asset.get("digest", "")) for asset in release.get("assets", []) if asset.get("name")==asset_name)
print(max(matches, default=("", ""))[1])' "$app" "$channel" "$asset_name" "$release_pages")
if [[ "$local_digest" == "$matching_digest" ]]; then
  refresh_release_manifest
  printf 'APK generated at: %s\n' "$apk"
  printf 'Publication successful: identical APK already available (%s %s v%s).\n' "$title" "$channel" "$version"
  printf 'APK Index: https://athenova-tools.github.io/APK/\n'
  exit 0
fi

notes="Publicação de $title $channel v$version."
if [[ -n "$version_code" ]]; then
  notes+=$'\nVersionCode: '
  notes+="$version_code"
fi

gh release create "$tag" \
  "$staged_apk" \
  --repo Athenova-tools/APK \
  --title "$title $channel v$version" \
  --notes "$notes" \
  --latest=false

refresh_release_manifest
printf 'APK generated at: %s\n' "$apk"
printf 'Published successfully: %s %s v%s (%s)\n' "$title" "$channel" "$version" "$tag"
printf 'APK Index: https://athenova-tools.github.io/APK/\n'
printf 'Release assets: https://github.com/Athenova-tools/APK/releases/tag/%s\n' "$tag"
