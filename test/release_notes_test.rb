# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/release_notes"

class ReleaseNotesTest < Minitest::Test
  APP_DOWNLOADS = <<~MARKDOWN
    ## Quick downloads

    > [!TIP]
    > Choose the Universal build.

    | Platform | Download |
    |:---|:---:|
    | Android | [Download](https://example.test/app.apk) |

    ## Installation notes

    - Verify `SHA256SUMS.txt`.
  MARKDOWN

  APP_CHANGES = <<~MARKDOWN
    ## What's Changed

    * Fix playback.
  MARKDOWN

  def merge(backend_body: "## What's Changed\n\n* Add server feature.\n", app_body: APP_DOWNLOADS + APP_CHANGES)
    ReleaseNotes.merge(
      backend_body: backend_body,
      app_body: app_body,
      backend_repository: "zijiren233/synctv",
      backend_tag: "v1.0.1-rc.1",
      backend_docs_url: "https://docs.syncs.tv/",
      app_repository: "zijiren233/synctv-app",
      app_tag: "v1.1.1-rc.1",
      app_version: "1.1.1-rc.1",
      app_build_number: 8,
      suite_repository: "zijiren233/synctv-release",
      suite_tag: "v2026.07.1"
    )
  end

  def test_merges_downloads_before_unchanged_server_notes
    result = merge

    assert_operator result.index("## Download SyncTV App"), :<, result.index("## Server release notes")
    assert_includes result, "### Quick downloads"
    assert_includes result, "### Installation notes"
    assert_includes result, "https://example.test/app.apk"
    assert_includes result, "## What's Changed\n\n* Add server feature."
    refute_includes result, "Fix playback"
  end

  def test_adds_component_and_suite_links_with_paired_versions
    result = merge

    assert_includes result, "SyncTV App `v1.1.1-rc.1+8`"
    assert_includes result, "SyncTV Server `v1.0.1-rc.1`"
    assert_includes result, "https://github.com/zijiren233/synctv-app/releases/tag/v1.1.1-rc.1"
    assert_includes result, "https://github.com/zijiren233/synctv-release/releases/tag/v2026.07.1"
  end

  def test_adds_server_deployment_and_versioned_documentation_links
    result = merge

    assert_includes result, "## Deploy SyncTV Server"
    assert_includes result, "https://docs.syncs.tv/install/quick-start/"
    assert_includes result, "https://docs.syncs.tv/install/helm/"
    assert_includes result, "https://docs.syncs.tv/operations/upgrades/"
    assert_includes result, "https://github.com/zijiren233/synctv/tree/v1.0.1-rc.1/docs"
  end

  def test_prefers_explicit_app_markers
    app_body = <<~MARKDOWN
      #{ReleaseNotes::APP_DOWNLOADS_START}
      #{APP_DOWNLOADS}
      #{ReleaseNotes::APP_DOWNLOADS_END}

      ## Localized generated notes

      * A change.
    MARKDOWN

    result = merge(app_body: app_body)

    assert_includes result, "### Quick downloads"
    refute_includes result, "Localized generated notes"
  end

  def test_replaces_managed_block_idempotently
    first = merge
    second = merge(backend_body: first)

    assert_equal first, second
    assert_equal 1, second.scan(ReleaseNotes::MANAGED_START).length
    assert_equal 1, second.scan("## Server release notes").length
  end

  def test_rejects_missing_download_section
    error = assert_raises(ArgumentError) { merge(app_body: APP_CHANGES) }

    assert_includes error.message, "missing the Quick downloads section"
  end

  def test_rejects_incomplete_managed_markers
    backend_body = "#{ReleaseNotes::MANAGED_START}\nold content\n"

    error = assert_raises(ArgumentError) { merge(backend_body: backend_body) }

    assert_includes error.message, "malformed SyncTV managed markers"
  end
end
