#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$(cd "$(dirname "$0")" && pwd)
source "$scripts_dir/gh-releases-api.sh"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir "$tmp/bin"
export GH_CALLS_FILE="$tmp/calls"
export APK_INDEX_API_RETRIES=3
export APK_INDEX_RETRY_DELAY_SECONDS=0
export PATH="$tmp/bin:$PATH"

cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
count=0
[[ -f "$GH_CALLS_FILE" ]] && count=$(cat "$GH_CALLS_FILE")
count=$((count + 1))
echo "$count" >"$GH_CALLS_FILE"
if [[ ${GH_MODE:-retry} == deny ]]; then
  echo "HTTP 403 (forbidden)" >&2
  exit 1
fi
if (( count == 1 )); then
  echo "HTTP 500 (server error)" >&2
  exit 1
fi
echo '[[{"tag_name":"stock-release-v1.0"}]]'
GH
chmod +x "$tmp/bin/gh"

export GH_MODE=retry
apk_index_fetch_releases "$tmp/releases.json" 2>"$tmp/retry.log"
[[ $(cat "$GH_CALLS_FILE") == 2 ]]
grep -q '"stock-release-v1.0"' "$tmp/releases.json"
grep -q 'retrying' "$tmp/retry.log"

rm -f "$GH_CALLS_FILE"
export GH_MODE=deny
if apk_index_fetch_releases "$tmp/denied.json" 2>"$tmp/denied.log"; then
  echo "Expected a non-retryable GitHub error to fail." >&2
  exit 1
fi
[[ $(cat "$GH_CALLS_FILE") == 1 ]]

echo "PASS  transient GitHub 5xx errors retry; permission errors fail immediately."
