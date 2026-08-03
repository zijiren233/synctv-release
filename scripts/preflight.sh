#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"

required_vars=(
  BACKEND_REPOSITORY BACKEND_COMMIT BACKEND_VERSION BACKEND_TAG
  APP_REPOSITORY APP_COMMIT APP_VERSION APP_BUILD_NUMBER APP_TAG
)
for name in "${required_vars[@]}"; do
  [[ -n "${!name:-}" ]] || { printf '%s is required.\n' "$name" >&2; exit 1; }
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

verify_commit() {
  local repository="$1" commit="$2"
  local resolved
  resolved="$(gh api "repos/$repository/commits/$commit" --jq .sha)"
  [[ "$resolved" == "$commit" ]] || {
    printf '%s resolved commit %s, expected %s.\n' "$repository" "$resolved" "$commit" >&2
    exit 1
  }
}

verify_tag() {
  local repository="$1" tag="$2" commit="$3"
  local resolved
  if resolved="$(gh api "repos/$repository/commits/$tag" --jq .sha 2>/dev/null)"; then
    [[ "$resolved" == "$commit" ]] || {
      printf '%s tag %s points to %s, expected %s.\n' "$repository" "$tag" "$resolved" "$commit" >&2
      exit 1
    }
    printf '%s tag %s already points to the requested commit.\n' "$repository" "$tag"
  fi
}

download_file() {
  local repository="$1" commit="$2" path="$3" output="$4"
  gh api "repos/$repository/contents/$path?ref=$commit" \
    -H 'Accept: application/vnd.github.raw+json' >"$output"
}

verify_commit "$BACKEND_REPOSITORY" "$BACKEND_COMMIT"
verify_commit "$APP_REPOSITORY" "$APP_COMMIT"
verify_tag "$BACKEND_REPOSITORY" "$BACKEND_TAG" "$BACKEND_COMMIT"
verify_tag "$APP_REPOSITORY" "$APP_TAG" "$APP_COMMIT"

download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" Cargo.toml "$tmp_dir/Cargo.toml"
download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" helm/synctv/Chart.yaml "$tmp_dir/Chart.yaml"
download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" docs/package.json "$tmp_dir/package.json"
download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" docs/package-lock.json "$tmp_dir/package-lock.json"
download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" docs/src/lib/project.ts "$tmp_dir/project.ts"
download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" docker-compose.yml "$tmp_dir/docker-compose.yml"
download_file "$BACKEND_REPOSITORY" "$BACKEND_COMMIT" helm/synctv/README.md "$tmp_dir/helm-readme.md"
download_file "$APP_REPOSITORY" "$APP_COMMIT" pubspec.yaml "$tmp_dir/pubspec.yaml"

cargo_version="$(ruby -e '
  text = File.read(ARGV.fetch(0))
  section = text[/^\[workspace\.package\]\s*$.*?(?=^\[|\z)/m] or abort "workspace.package is missing"
  match = section.match(/^version\s*=\s*"([^"]+)"/) or abort "workspace.package.version is missing"
  puts match[1]
' "$tmp_dir/Cargo.toml")"
chart_version="$(ruby -ryaml -e 'puts YAML.load_file(ARGV.fetch(0)).fetch("version")' "$tmp_dir/Chart.yaml")"
chart_app_version="$(ruby -ryaml -e 'puts YAML.load_file(ARGV.fetch(0)).fetch("appVersion")' "$tmp_dir/Chart.yaml")"
docs_package_version="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("version")' "$tmp_dir/package.json")"
docs_lock_version="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("version")' "$tmp_dir/package-lock.json")"
docs_lock_root_version="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("packages").fetch("").fetch("version")' "$tmp_dir/package-lock.json")"
docs_default_app_version="$(sed -n "s/^[[:space:]]*const defaultAppVersion = ['\"]\([^'\"]*\)['\"];.*$/\1/p" "$tmp_dir/project.ts" | head -n 1)"
compose_image_tag="$(ruby -ryaml -e '
  image = YAML.load_file(ARGV.fetch(0)).fetch("services").fetch("synctv").fetch("image")
  match = image.match(/\$\{SYNCTV_IMAGE_TAG:-([^}]+)\}/)
  abort "docker-compose.yml synctv image must use SYNCTV_IMAGE_TAG fallback" unless match
  puts match[1]
' "$tmp_dir/docker-compose.yml")"
helm_readme_version="$(sed -n 's/^[[:space:]]*--version[[:space:]]*\([^[:space:]]*\).*$/\1/p' "$tmp_dir/helm-readme.md" | head -n 1)"
app_artifact_version="$(sed -n 's/^version:[[:space:]]*//p' "$tmp_dir/pubspec.yaml" | head -n 1 | tr -d '\r')"

[[ "$cargo_version" == "$BACKEND_VERSION" ]] || { printf 'Cargo version %s differs from %s.\n' "$cargo_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$chart_version" == "$BACKEND_VERSION" ]] || { printf 'Chart version %s differs from %s.\n' "$chart_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$chart_app_version" == "$BACKEND_VERSION" ]] || { printf 'Chart appVersion %s differs from %s.\n' "$chart_app_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$docs_package_version" == "$BACKEND_VERSION" ]] || { printf 'Docs package version %s differs from %s.\n' "$docs_package_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$docs_lock_version" == "$BACKEND_VERSION" ]] || { printf 'Docs lock version %s differs from %s.\n' "$docs_lock_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$docs_lock_root_version" == "$BACKEND_VERSION" ]] || { printf 'Docs lock root version %s differs from %s.\n' "$docs_lock_root_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$docs_default_app_version" == "$BACKEND_VERSION" ]] || { printf 'Docs default app version %s differs from %s.\n' "$docs_default_app_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$compose_image_tag" == "latest" ]] || { printf 'Compose image fallback %s must equal latest.\n' "$compose_image_tag" >&2; exit 1; }
[[ "$helm_readme_version" == "$BACKEND_VERSION" ]] || { printf 'Helm README version %s differs from %s.\n' "$helm_readme_version" "$BACKEND_VERSION" >&2; exit 1; }
[[ "$app_artifact_version" == "$APP_VERSION+$APP_BUILD_NUMBER" ]] || {
  printf 'App version %s differs from %s+%s.\n' "$app_artifact_version" "$APP_VERSION" "$APP_BUILD_NUMBER" >&2
  exit 1
}

for specification in \
  "$BACKEND_REPOSITORY $BACKEND_COMMIT release.yml" \
  "$BACKEND_REPOSITORY $BACKEND_COMMIT docker.yml" \
  "$APP_REPOSITORY $APP_COMMIT release.yml"; do
  read -r repository commit workflow <<<"$specification"
  gh api "repos/$repository/contents/.github/workflows/$workflow?ref=$commit" --silent
done

printf 'Preflight passed for backend %s and app %s.\n' "$BACKEND_COMMIT" "$APP_COMMIT"
