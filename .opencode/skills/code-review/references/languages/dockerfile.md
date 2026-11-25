# Dockerfile

## Lane map

| Lane | Focus | When |
|---|---|---|
| `container-hardening` | Base image, user, secrets, image contents, supply chain | Any `Dockerfile` or `dockerfiles/**` change |

## CI already covers

`hadolint` runs in CI. Do not flag:

- formatting, instruction casing, or `apt-get` style that `hadolint` already reports;
- missing `--no-install-recommends` when the linter flags it;
- generic best-practice warnings already in the CI output.

If `gate.log` says `hadolint` was skipped, you may flag the issue, but say so.

## Checks

- **Base image.** Pinned by digest or a specific version, not `latest`. A floating tag is a supply-chain and reproducibility risk.
- **User.** A non-root `USER` in the final stage; explicit UID/GID where the runtime requires it.
- **Secrets.** No secrets in `ARG` or `ENV`; use BuildKit `--mount=type=secret` for build-time credentials.
- **Build context.** `COPY` only what the image needs; `.dockerignore` excludes `.git`, tests, and local env files.
- **Multi-stage.** Build tools and source do not ship in the final image; the runtime stage contains only runtime dependencies.
- **Packages.** Version pinning where reproducibility matters; cache cleanup in the same layer; no unnecessary compilers in the final image.
- **Entrypoint.** Correct `ENTRYPOINT`/`CMD`, signal handling, no shell wrapper that swallows signals.
- **Runtime hardening.** Read-only root filesystem where possible, dropped capabilities, no `--privileged` assumptions, healthcheck.
- **Supply chain.** Base image source and provenance; image scanning in CI; pinned package repositories.
- **Build args.** No CI secrets passed as build args; build args are visible in image history.

## False-positive traps

- `latest` may be an explicit choice for a local-only image; confirm the deployment context.
- Pinning every OS package can be impractical; focus on the base image and application dependencies.
- Distroless or scratch images may lack a shell and healthcheck by design.
- `hadolint` style findings are not review findings.

## Gate commands

```bash
hadolint Dockerfile
find . -name 'Dockerfile*' -not -path './.git/*' -exec hadolint {} +
git diff --check
```
