#!/usr/bin/env bash

apk_index_fetch_releases() {
  local destination=$1
  local attempt=1
  local max_attempts=${APK_INDEX_API_RETRIES:-5}
  local delay=${APK_INDEX_RETRY_DELAY_SECONDS:-2}
  local response error_file status
  response=$(mktemp)
  error_file=$(mktemp)

  while (( attempt <= max_attempts )); do
    if gh api --paginate --slurp "repos/Athenova-tools/APK/releases?per_page=100" \
      >"$response" 2>"$error_file"; then
      cat "$response" >"$destination"
      rm -f -- "$response" "$error_file"
      return 0
    else
      status=$?
    fi

    cat "$error_file" >&2
    if ! grep -Eiq 'HTTP 5[0-9][0-9]|timed out|timeout|connection reset|temporary failure' "$error_file"; then
      rm -f -- "$response" "$error_file"
      return "$status"
    fi
    if (( attempt == max_attempts )); then
      echo "GitHub releases API still failing after ${attempt} attempts." >&2
      rm -f -- "$response" "$error_file"
      return "$status"
    fi

    echo "Transient GitHub releases API error; retrying in ${delay}s (attempt $((attempt + 1))/$max_attempts)." >&2
    sleep "$delay"
    delay=$((delay * 2))
    (( attempt += 1 ))
  done
}
