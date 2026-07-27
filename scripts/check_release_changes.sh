#!/usr/bin/env bash
set -euo pipefail

base_ref="${1:?base ref is required}"
head_ref="${2:-HEAD}"

mapfile -t changes < <(
  git diff --name-status "$base_ref...$head_ref" -- 'releases/*.yml' 'releases/*.yaml'
)

if ((${#changes[@]} > 1)); then
  printf 'A release pull request must add at most one manifest.\n' >&2
  exit 1
fi

if ((${#changes[@]} == 0)); then
  exit 0
fi

status="${changes[0]%%$'\t'*}"
path="${changes[0]#*$'\t'}"
if [[ "$status" != "A" ]]; then
  printf 'Release manifests are append-only: %s has status %s.\n' "$path" "$status" >&2
  exit 1
fi

ruby script/manifest validate "$path"

