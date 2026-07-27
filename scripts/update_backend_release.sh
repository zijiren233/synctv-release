#!/usr/bin/env bash
set -euo pipefail

required_environment=(
  GH_TOKEN
  GITHUB_REPOSITORY
  BACKEND_REPOSITORY
  BACKEND_TAG
  BACKEND_DOCS_URL
  APP_REPOSITORY
  APP_TAG
  APP_VERSION
  APP_BUILD_NUMBER
  SUITE_TAG
)
for variable in "${required_environment[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    printf '%s is required.\n' "$variable" >&2
    exit 1
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

gh api "repos/$BACKEND_REPOSITORY/releases/tags/$BACKEND_TAG" --jq '.body // ""' \
  > "$tmp_dir/backend.md"
gh api "repos/$APP_REPOSITORY/releases/tags/$APP_TAG" --jq '.body // ""' \
  > "$tmp_dir/app.md"

ruby script/release-notes \
  --backend-file "$tmp_dir/backend.md" \
  --app-file "$tmp_dir/app.md" \
  --output "$tmp_dir/merged.md" \
  --backend-repository "$BACKEND_REPOSITORY" \
  --backend-tag "$BACKEND_TAG" \
  --backend-docs-url "$BACKEND_DOCS_URL" \
  --app-repository "$APP_REPOSITORY" \
  --app-tag "$APP_TAG" \
  --app-version "$APP_VERSION" \
  --app-build-number "$APP_BUILD_NUMBER" \
  --suite-repository "$GITHUB_REPOSITORY" \
  --suite-tag "$SUITE_TAG"

gh release edit "$BACKEND_TAG" \
  --repo "$BACKEND_REPOSITORY" \
  --notes-file "$tmp_dir/merged.md"

printf 'Updated %s Release %s with App %s downloads and server deployment guides.\n' \
  "$BACKEND_REPOSITORY" "$BACKEND_TAG" "$APP_TAG"
