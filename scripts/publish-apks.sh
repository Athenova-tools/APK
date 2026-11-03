#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <food|stock|istqb> <app-version> <debug.apk> <release.apk>" >&2
  exit 2
}

[[ $# -eq 4 ]] || usage

app=$1
version=$2
debug_apk=$3
release_apk=$4

case "$app" in
  food) title="Food" ;;
  stock) title="Stock" ;;
  istqb) title="ISTQB" ;;
  *) usage ;;
esac

[[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?([.-][A-Za-z0-9.-]+)?$ ]] || {
  echo "Invalid app version: $version" >&2
  exit 2
}

for apk in "$debug_apk" "$release_apk"; do
  if [[ ! -f "$apk" || "$apk" != *.apk ]]; then
    echo "APK file not found or invalid: $apk" >&2
    exit 2
  fi
done

tag="${app}-v${version}-$(date -u +%Y%m%dT%H%M%SZ)"
debug_asset="${app}-debug.apk"
release_asset="${app}-release.apk"
upload_dir=$(mktemp -d)
trap 'rm -rf "$upload_dir"' EXIT
cp -- "$debug_apk" "$upload_dir/$debug_asset"
cp -- "$release_apk" "$upload_dir/$release_asset"

gh release create "$tag" \
  "$upload_dir/$debug_asset" \
  "$upload_dir/$release_asset" \
  --repo Athenova-tools/APK \
  --title "$title v$version" \
  --notes "Publicação de $title v$version. Contém os APKs Debug e Release." \
  --latest=false

printf 'Published %s v%s (%s)\n' "$title" "$version" "$tag"
