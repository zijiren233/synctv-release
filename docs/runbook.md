# Release runbook

## Normal release

1. Prepare final version commits in both component repositories.
2. Add one `releases/YYYY.MM.PATCH.yml` manifest and commit it directly to `main`.
3. Review the `Validate release manifests` result.
4. Approve the `release` Environment when approval is configured.
5. Follow the `Promote SyncTV suite` workflow.
6. Verify the server, app, and suite GitHub Releases.

## Retry

Rerun the failed `Promote SyncTV suite` workflow from GitHub Actions. Component
tag creation is idempotent and verifies the existing tag commit. Workflow waits
select runs by component commit SHA. Suite Release publication verifies its tag
target before replacing generated lock assets.

## Component failure

Open the linked component workflow and correct its repository configuration or
secrets. Preserve the release manifest and component tags. Rerun the suite
workflow after the component workflow succeeds.

## Rollback

Select the previous suite Release and deploy the image digest and Helm chart
recorded in its `release-lock.yml`. Client releases remain independently
addressable through their component tags. Publish a new patch suite manifest
when a corrected component combination is ready.
