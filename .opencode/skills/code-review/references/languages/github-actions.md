# GitHub Actions

## Lane map

| Lane | Focus | When |
|---|---|---|
| `actions-supply-chain` | Pinning, permissions, untrusted events, secret exposure | Any `.github/workflows/**` change |

## CI already covers

`zizmor` and the GitHub Actions linter run in CI. Do not flag:

- YAML formatting;
- missing `name` fields or expression syntax that the linter catches;
- generic zizmor findings already reported;
- deprecation warnings for actions the repository has deliberately not upgraded.

If `gate.log` says `zizmor` was skipped, you may flag the issue, but say the scanner did not run.

## Shared evidence

Trace from the event trigger to the job, step, and sink. Cite the workflow file and line. A workflow is only vulnerable if untrusted data reaches a privileged context.

## Supply chain

- **Action pinning.** Third-party actions pinned to a full 40-character commit SHA, not a tag or branch. First-party `actions/*` may use a major tag if the repository accepts that risk.
- **Permissions.** Explicit least-privilege `permissions`, default `{}`, no `write-all`, no unnecessary `id-token: write` or `contents: write`.
- **Untrusted events.** `pull_request_target`, `workflow_run`, `issue_comment`, `repository_dispatch`, and `schedule` combined with checkout or execution of untrusted code.
- **Expression injection.** `${{ github.event.* }}`, `${{ inputs.* }}`, or PR-controlled values interpolated directly into `run:`; use an intermediate `env` variable and quote it.
- **Secrets.** `secrets: inherit`, secrets passed to untrusted steps, secrets in logs, environment protection rules, `GITHUB_TOKEN` scope.
- **Caching.** Cache keys derived from untrusted input; `restore-keys` that can poison a trusted cache.
- **Artifacts.** Downloading artifacts from untrusted workflows or PRs and executing them.
- **Runners.** Self-hosted runners on public repositories; runners that persist state between jobs.
- **Containers.** Unpinned container images or actions from untrusted sources.
- **Matrix and inputs.** `fromJSON` of untrusted data used to select runners, shells, or commands.
- **Failure masking.** `continue-on-error`, `|| true`, or `set +e` that hides a security or build failure.
- **Timeouts and concurrency.** Missing `timeout-minutes`; concurrent deploys that can race.

## False-positive traps

- `pull_request_target` is not automatically vulnerable. It is safe when the workflow does not check out or execute PR-controlled code.
- `permissions: {}` is good, not a bug.
- A tag-pinned first-party action may be an accepted policy.
- `zizmor` may already report the same finding; do not duplicate it as a new blocker.
- `secrets: inherit` can be acceptable for a reusable workflow in the same repository; check the callee.

## Gate commands

```bash
zizmor .github/workflows
actionlint
git diff --check
```
