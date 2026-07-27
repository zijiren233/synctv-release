#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"

repository="${1:?repository is required}"
workflow="${2:?workflow file is required}"
tag="${3:?tag is required}"
commit="${4:?commit is required}"
timeout_seconds="${5:-10800}"
deadline="$(( $(date +%s) + timeout_seconds ))"
run_id=""

while (( $(date +%s) < deadline )); do
  run_json="$(
    gh api --method GET "repos/$repository/actions/workflows/$workflow/runs" \
      -f event=push \
      -f branch="$tag" \
      -F per_page=20 \
      --jq ".workflow_runs | map(select(.head_sha == \"$commit\")) | sort_by(.created_at) | last // empty"
  )"

  if [[ -n "$run_json" ]]; then
    run_id="$(jq -r .id <<<"$run_json")"
    status="$(jq -r .status <<<"$run_json")"
    conclusion="$(jq -r '.conclusion // ""' <<<"$run_json")"
    url="$(jq -r .html_url <<<"$run_json")"
    printf '%s %s run %s: %s %s\n' "$repository" "$workflow" "$run_id" "$status" "$url"

    if [[ "$status" == "completed" ]]; then
      [[ "$conclusion" == "success" ]] || {
        printf '%s completed with conclusion %s.\n' "$url" "$conclusion" >&2
        exit 1
      }
      exit 0
    fi
  else
    printf 'Waiting for %s %s at %s.\n' "$repository" "$workflow" "$commit"
  fi

  sleep 20
done

printf 'Timed out waiting for %s %s after %s seconds. Last run: %s\n' \
  "$repository" "$workflow" "$timeout_seconds" "${run_id:-unavailable}" >&2
exit 1

