# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"
require "yaml"
require_relative "../lib/release_manifest"

class ReleaseManifestTest < Minitest::Test
  def setup
    @data = {
      "schema_version" => 1,
      "release" => { "version" => "2026.08.0", "channel" => "stable" },
      "components" => {
        "backend" => {
          "repository" => "synctv-org/synctv",
          "commit" => "a" * 40,
          "version" => "1.0.1",
          "tag" => "v1.0.1",
          "image" => "ghcr.io/synctv-org/synctv",
          "chart" => "oci://ghcr.io/synctv-org/synctv/charts/synctv"
        },
        "app" => {
          "repository" => "synctv-org/synctv-app",
          "commit" => "b" * 40,
          "version" => "1.1.1",
          "build_number" => 8,
          "tag" => "v1.1.1"
        }
      }
    }
  end

  def test_valid_manifest_exports_workflow_values
    manifest = ReleaseManifest.new(@data).validate!

    assert_equal "v2026.08.0", manifest.output_values.fetch("suite_tag")
    assert_equal 8, manifest.output_values.fetch("app_build_number")
  end

  def test_rejects_mismatched_component_tag
    @data["components"]["app"]["tag"] = "v1.1.2"

    error = assert_raises(ArgumentError) { ReleaseManifest.new(@data).validate! }
    assert_includes error.message, "components.app.tag must equal v1.1.1"
  end

  def test_accepts_multi_digit_semver_components
    @data["components"]["backend"]["version"] = "10.20.30"
    @data["components"]["backend"]["tag"] = "v10.20.30"

    ReleaseManifest.new(@data).validate!
  end

  def test_rejects_partial_semver_match
    @data["components"]["backend"]["version"] = "release-1.0.1"
    @data["components"]["backend"]["tag"] = "vrelease-1.0.1"

    error = assert_raises(ArgumentError) { ReleaseManifest.new(@data).validate! }
    assert_includes error.message, "components.backend.version must be SemVer"
  end

  def test_rejects_unknown_fields
    @data["release"]["state"] = "ready"

    error = assert_raises(ArgumentError) { ReleaseManifest.new(@data).validate! }
    assert_includes error.message, "release.state is unknown"
  end

  def test_rejects_unknown_schema_version
    @data["schema_version"] = 2

    error = assert_raises(ArgumentError) { ReleaseManifest.new(@data).validate! }
    assert_includes error.message, "schema_version must equal 1"
  end

  def test_stable_suite_requires_stable_components
    @data["components"]["backend"]["version"] = "1.0.1-rc.1"
    @data["components"]["backend"]["tag"] = "v1.0.1-rc.1"

    error = assert_raises(ArgumentError) { ReleaseManifest.new(@data).validate! }
    assert_includes error.message, "components.backend.version must be stable"
  end

  def test_load_rejects_yaml_aliases
    file = Tempfile.new(["release", ".yml"])
    file.write("release: &release\n  version: 2026.08.0\ncopy: *release\n")
    file.close

    error = assert_raises(ArgumentError) { ReleaseManifest.load(file.path) }
    assert_includes error.message, "invalid YAML"
  ensure
    file&.unlink
  end
end
