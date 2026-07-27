# frozen_string_literal: true

require "yaml"

class ReleaseManifest
  SEMVER = /\A(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?\z/
  REPOSITORY = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\z/
  COMMIT = /\A[0-9a-f]{40}\z/
  IMAGE = %r{\A[a-z0-9.-]+(?::\d+)?/[a-z0-9._/-]+\z}
  CHART = %r{\Aoci://[a-z0-9.-]+(?::\d+)?/[a-z0-9._/-]+\z}
  CHANNELS = %w[stable prerelease].freeze

  attr_reader :data

  def self.load(path)
    raw = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
    new(raw).tap(&:validate!)
  rescue Psych::Exception => error
    raise ArgumentError, "invalid YAML: #{error.message}"
  end

  def initialize(data)
    @data = data
  end

  def validate!
    errors = []
    validate_mapping(data, "manifest", %w[schema_version release components], errors)
    errors << "schema_version must equal 1" unless data.is_a?(Hash) && data["schema_version"] == 1
    validate_release(errors)
    validate_components(errors)
    raise ArgumentError, errors.join("\n") unless errors.empty?

    self
  end

  def output_values
    {
      "suite_version" => value("release", "version"),
      "suite_tag" => "v#{value("release", "version")}",
      "release_channel" => value("release", "channel"),
      "backend_repository" => value("components", "backend", "repository"),
      "backend_commit" => value("components", "backend", "commit"),
      "backend_version" => value("components", "backend", "version"),
      "backend_tag" => value("components", "backend", "tag"),
      "backend_image" => value("components", "backend", "image"),
      "backend_chart" => value("components", "backend", "chart"),
      "app_repository" => value("components", "app", "repository"),
      "app_commit" => value("components", "app", "commit"),
      "app_version" => value("components", "app", "version"),
      "app_build_number" => value("components", "app", "build_number"),
      "app_tag" => value("components", "app", "tag")
    }
  end

  private

  def validate_release(errors)
    release = data.is_a?(Hash) ? data["release"] : nil
    validate_mapping(release, "release", %w[version channel], errors)
    return unless release.is_a?(Hash)

    version = release["version"]
    channel = release["channel"]
    errors << "release.version must use YYYY.MM.PATCH" unless suite_version?(version)
    errors << "release.channel must be stable or prerelease" unless CHANNELS.include?(channel)
  end

  def validate_components(errors)
    components = data.is_a?(Hash) ? data["components"] : nil
    validate_mapping(components, "components", %w[backend app], errors)
    return unless components.is_a?(Hash)

    validate_backend(components["backend"], errors)
    validate_app(components["app"], errors)
  end

  def validate_backend(backend, errors)
    keys = %w[repository commit version tag image chart]
    validate_mapping(backend, "components.backend", keys, errors)
    return unless backend.is_a?(Hash)

    validate_component_identity(backend, "components.backend", errors)
    errors << "components.backend.image is invalid" unless backend["image"].is_a?(String) && IMAGE.match?(backend["image"])
    errors << "components.backend.chart is invalid" unless backend["chart"].is_a?(String) && CHART.match?(backend["chart"])
  end

  def validate_app(app, errors)
    keys = %w[repository commit version build_number tag]
    validate_mapping(app, "components.app", keys, errors)
    return unless app.is_a?(Hash)

    validate_component_identity(app, "components.app", errors)
    build_number = app["build_number"]
    errors << "components.app.build_number must be a positive integer" unless build_number.is_a?(Integer) && build_number.positive?
  end

  def validate_component_identity(component, path, errors)
    repository = component["repository"]
    commit = component["commit"]
    version = component["version"]
    tag = component["tag"]

    errors << "#{path}.repository is invalid" unless repository.is_a?(String) && REPOSITORY.match?(repository)
    errors << "#{path}.commit must be a full lowercase commit SHA" unless commit.is_a?(String) && COMMIT.match?(commit)
    errors << "#{path}.version must be SemVer" unless version.is_a?(String) && SEMVER.match?(version)
    errors << "#{path}.tag must equal v#{version}" unless tag == "v#{version}"

    if value("release", "channel") == "stable" && version.is_a?(String) && version.include?("-")
      errors << "#{path}.version must be stable for a stable suite release"
    end
  end

  def validate_mapping(mapping, path, expected_keys, errors)
    unless mapping.is_a?(Hash)
      errors << "#{path} must be a mapping"
      return
    end

    actual_keys = mapping.keys.map(&:to_s)
    (expected_keys - actual_keys).each { |key| errors << "#{path}.#{key} is required" }
    (actual_keys - expected_keys).each { |key| errors << "#{path}.#{key} is unknown" }
  end

  def suite_version?(version)
    return false unless version.is_a?(String) && /\A\d{4}\.\d{2}\.\d+\z/.match?(version)

    month = version.split(".")[1].to_i
    month.between?(1, 12)
  end

  def value(*keys)
    keys.reduce(data) { |current, key| current.is_a?(Hash) ? current[key] : nil }
  end
end
