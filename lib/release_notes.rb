# frozen_string_literal: true

class ReleaseNotes
  APP_DOWNLOADS_START = "<!-- synctv-app-downloads:start -->"
  APP_DOWNLOADS_END = "<!-- synctv-app-downloads:end -->"
  MANAGED_START = "<!-- synctv-suite-app:start -->"
  MANAGED_END = "<!-- synctv-suite-app:end -->"

  def self.merge(backend_body:, app_body:, backend_repository:, backend_tag:, backend_docs_url:,
                 app_repository:, app_tag:, app_version:, app_build_number:, suite_repository:, suite_tag:)
    downloads = demote_headings(extract_app_downloads(app_body))
    server_notes = remove_managed_block(backend_body).strip

    app_release_url = "https://github.com/#{app_repository}/releases/tag/#{app_tag}"
    suite_release_url = "https://github.com/#{suite_repository}/releases/tag/#{suite_tag}"
    versioned_docs_url = "https://github.com/#{backend_repository}/tree/#{backend_tag}/docs"
    docs_url = backend_docs_url.sub(%r{/+\z}, "")
    app_artifact_version = "v#{app_version}+#{app_build_number}"

    managed_block = <<~MARKDOWN.strip
      #{MANAGED_START}
      ## Download SyncTV App

      > [!TIP]
      > **SyncTV App `#{app_artifact_version}`** is paired with SyncTV Server `#{backend_tag}`.
      > [View complete App release](#{app_release_url}) · [View suite release](#{suite_release_url})

      #{downloads}

      ## Deploy SyncTV Server

      | Environment | Documentation |
      |:---|:---|
      | **Docker Compose** | [Install on a server, NAS, or VM](#{docs_url}/install/quick-start/) |
      | **Helm / Kubernetes** | [Install in a Kubernetes cluster](#{docs_url}/install/helm/) |
      | **Existing installation** | [Upgrade and migration guide](#{docs_url}/operations/upgrades/) |

      [Browse documentation for SyncTV Server `#{backend_tag}`](#{versioned_docs_url})

      ---

      ## Server release notes
      #{MANAGED_END}
    MARKDOWN

    [managed_block, server_notes].reject(&:empty?).join("\n\n") + "\n"
  end

  def self.extract_app_downloads(body)
    normalized = normalize(body)
    marked = extract_marked_app_downloads(normalized)
    return validate_app_downloads(marked) if marked

    lines = normalized.lines(chomp: true)
    start_index = lines.index { |line| /^##[ \t]+Quick downloads[ \t]*$/i.match?(line) }
    raise ArgumentError, "app release notes are missing the Quick downloads section" unless start_index

    installation_index = ((start_index + 1)...lines.length).find do |index|
      /^##[ \t]+Installation notes[ \t]*$/i.match?(lines[index])
    end
    raise ArgumentError, "app release notes are missing the Installation notes section" unless installation_index

    end_index = ((installation_index + 1)...lines.length).find do |index|
      /^##[ \t]+\S/.match?(lines[index])
    end || lines.length

    validate_app_downloads(lines[start_index...end_index].join("\n").strip)
  end

  def self.demote_headings(markdown)
    in_fence = false
    markdown.lines(chomp: true).map do |line|
      in_fence = !in_fence if /^[ \t]*(```|~~~)/.match?(line)
      in_fence ? line : line.sub(/\A([#]{2,5})([ \t]+)/, '#\1\2')
    end.join("\n")
  end

  def self.remove_managed_block(body)
    normalized = normalize(body)
    starts = normalized.scan(MANAGED_START).length
    ends = normalized.scan(MANAGED_END).length
    return normalized if starts.zero? && ends.zero?

    unless starts == 1 && ends == 1 && normalized.index(MANAGED_START) < normalized.index(MANAGED_END)
      raise ArgumentError, "server release notes contain malformed SyncTV managed markers"
    end

    normalized.sub(/#{Regexp.escape(MANAGED_START)}.*?#{Regexp.escape(MANAGED_END)}/m, "").strip
  end

  def self.extract_marked_app_downloads(body)
    starts = body.scan(APP_DOWNLOADS_START).length
    ends = body.scan(APP_DOWNLOADS_END).length
    return if starts.zero? && ends.zero?

    unless starts == 1 && ends == 1 && body.index(APP_DOWNLOADS_START) < body.index(APP_DOWNLOADS_END)
      raise ArgumentError, "app release notes contain malformed download markers"
    end

    start_index = body.index(APP_DOWNLOADS_START) + APP_DOWNLOADS_START.length
    end_index = body.index(APP_DOWNLOADS_END)
    body[start_index...end_index].strip
  end

  def self.validate_app_downloads(markdown)
    unless /^##[ \t]+Quick downloads[ \t]*$/i.match?(markdown)
      raise ArgumentError, "app download block is missing the Quick downloads heading"
    end
    unless /^##[ \t]+Installation notes[ \t]*$/i.match?(markdown)
      raise ArgumentError, "app download block is missing the Installation notes heading"
    end

    markdown
  end

  def self.normalize(body)
    body.to_s.gsub("\r\n", "\n")
  end

  private_class_method :extract_marked_app_downloads, :validate_app_downloads, :normalize
end
