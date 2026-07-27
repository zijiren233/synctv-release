#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"

repository="${1:?repository is required}"
tag="${2:?tag is required}"
commit="${3:?commit is required}"
suite_version="${4:?suite version is required}"

if resolved="$(gh api "repos/$repository/commits/$tag" --jq .sha 2>/dev/null)"; then
  [[ "$resolved" == "$commit" ]] || {
    printf '%s tag %s points to %s, expected %s.\n' "$repository" "$tag" "$resolved" "$commit" >&2
    exit 1
  }
  printf '%s tag %s already exists at %s.\n' "$repository" "$tag" "$commit"
  exit 0
fi

tag_object="$(
  gh api --method POST "repos/$repository/git/tags" \
    -f tag="$tag" \
    -f message="SyncTV suite $suite_version" \
    -f object="$commit" \
    -f type=commit \
    --jq .sha
)"

gh api --method POST "repos/$repository/git/refs" \
  -f ref="refs/tags/$tag" \
  -f sha="$tag_object" \
  --silent

printf 'Created %s tag %s at %s.\n' "$repository" "$tag" "$commit"

