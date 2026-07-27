# Contributing

Release manifests are append-only records. Add one manifest per pull request
under `releases/`; preserve existing manifests and suite tags.

Component commits must already contain their final version metadata. Server
manifests require matching Cargo workspace, Helm chart, and app versions. App
manifests require a matching `pubspec.yaml` version and build number.

Run `make validate` before opening a pull request. Run `make actionlint` after
changing GitHub Actions workflows.

