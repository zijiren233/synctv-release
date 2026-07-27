#!/usr/bin/env bash
set -euo pipefail

image_ref="${1:?image reference is required}"
raw_manifest="$(mktemp)"
trap 'rm -f "$raw_manifest"' EXIT

docker buildx imagetools inspect "$image_ref" --raw >"$raw_manifest"
digest="sha256:$(sha256sum "$raw_manifest" | awk '{print $1}')"
printf '%s\n' "$digest"

