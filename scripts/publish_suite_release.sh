#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"

dist_dir="${1:?dist directory is required}"
: "${SUITE_TAG:?SUITE_TAG is required}"
: "${SUITE_VERSION:?SUITE_VERSION is required}"
: "${RELEASE_CHANNEL:?RELEASE_CHANNEL is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${RELEASE_SOURCE_SHA:?RELEASE_SOURCE_SHA is required}"

notes="$dist_dir/release-notes.md"
cat >"$notes" <<EOF
# SyncTV $SUITE_VERSION

This suite release contains a tested and immutable mapping of the SyncTV
server and app releases. See \`release-lock.yml\` for component commits,
the server image digest, Helm chart, and app checksums.

## Components

- Server: https://github.com/$BACKEND_REPOSITORY/releases/tag/$BACKEND_TAG
- App: https://github.com/$APP_REPOSITORY/releases/tag/$APP_TAG
- Container: \`$BACKEND_IMAGE@$BACKEND_IMAGE_DIGEST\`
- Helm: \`$BACKEND_CHART:$BACKEND_VERSION\`
EOF

release_args=(
  "$SUITE_TAG"
  "$dist_dir/release-lock.yml"
  "$dist_dir/SHA256SUMS"
  --repo "$GITHUB_REPOSITORY"
  --target "$RELEASE_SOURCE_SHA"
  --title "$SUITE_TAG"
  --notes-file "$notes"
)

if [[ "$RELEASE_CHANNEL" == "prerelease" ]]; then
  release_args+=(--prerelease --latest=false)
fi

if gh release view "$SUITE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
  resolved="$(gh api "repos/$GITHUB_REPOSITORY/commits/$SUITE_TAG" --jq .sha)"
  [[ "$resolved" == "$RELEASE_SOURCE_SHA" ]] || {
    printf 'Suite tag %s points to %s, expected %s.\n' "$SUITE_TAG" "$resolved" "$RELEASE_SOURCE_SHA" >&2
    exit 1
  }
  gh release upload "$SUITE_TAG" "$dist_dir/release-lock.yml" "$dist_dir/SHA256SUMS" \
    --repo "$GITHUB_REPOSITORY" --clobber
  gh release edit "$SUITE_TAG" --repo "$GITHUB_REPOSITORY" \
    --target "$RELEASE_SOURCE_SHA" --title "$SUITE_TAG" --notes-file "$notes"
else
  gh release create "${release_args[@]}"
fi
