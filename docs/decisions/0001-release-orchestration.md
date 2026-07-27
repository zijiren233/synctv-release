# ADR-0001: Manifest-driven cross-repository releases

## Status

Accepted.

## Context

SyncTV has separate server and Flutter application repositories. Each already
owns a mature component pipeline: the server publishes container images and a
Helm chart, while the app publishes signed platform artifacts. A suite release
must identify one tested combination without moving compilation or credentials
out of those repositories.

## Decision

Use this repository as a release control plane. An append-only manifest pins
full component commit SHAs and declares their component versions. Merge to
`main` authorizes the orchestrator to create annotated component tags. Existing
component workflows build and publish their own releases. The orchestrator
waits for those workflows, resolves the multi-platform image digest, and
publishes a suite lock.

After the suite Release exists, the orchestrator copies the marked quick
download and installation sections from the App Release into the Server
Release. Managed HTML comments make the update idempotent, while the original
server notes remain the canonical server changelog.

Protocol synchronization remains a component development concern in
`synctv-app`. The release control plane validates versions and artifacts and
does not compare Protobuf trees.

## Production precedents

- [OpenSearch Build](https://github.com/opensearch-project/opensearch-build)
  uses versioned YAML manifests with exact repository commits for OpenSearch,
  Dashboards, and plugins.
- [OpenStack Releases](https://github.com/openstack/releases) uses a dedicated
  release repository whose reviewed YAML records drive component tagging and
  release publication.
- [Kubernetes Release](https://github.com/kubernetes/release) separates source
  builds from artifact publication and promotion.
- [Sentry Self-Hosted](https://github.com/getsentry/self-hosted) provides a
  distribution repository that pins deployable service images and owns the
  operator-facing installation entry point.

SyncTV adopts exact commit pinning, reviewed release intent, component-owned
builds, staged promotion, and immutable resolved artifacts. The implementation
keeps two component workflows and one suite workflow, matching the current
project scale.

## Consequences

Component versions evolve independently. Suite versions use calendar versioning
to identify verified combinations. A failed component workflow stops promotion;
rerunning the suite workflow resumes from idempotent tags. The final suite
Release records the container digest and component release URLs. The Server
Release is the primary user-facing download entry point for the paired app.
