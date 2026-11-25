# Review rules for this repository

This file is loaded by the `code-review` skill. Repository-specific rules override generic guidance.

## What this repository is

- Terraform provisions Proxmox and Hetzner resources.
- Ansible configures hosts, including a bootstrap playbook for CI/CD agents.
- GitHub Actions builds container images and deploys.
- Super-linter is the deterministic baseline: `ansible-lint`, `checkov`, `hadolint`, `tflint`, `zizmor`, `yamllint`, and `terraform validate`.

## Review priorities, highest first

1. Destructive or replacement changes to stateful resources.
2. Secrets and credential handling.
3. Network exposure and access control.
4. Idempotency and repeatability of Ansible.
5. Supply-chain integrity of GitHub Actions and container images.
6. Everything else.

## Intentional patterns (TODO confirm)

These are guesses from the repository, not confirmed policy. Confirm or correct them.

- `insecure = true` on the Proxmox provider is intentional for a self-signed endpoint. TODO confirm.
- The Terraform Cloud organization and workspace are fixed, not environment-specific. TODO confirm.
- Vault-encrypted strings are the only accepted mechanism for dynamic-inventory tokens. TODO confirm.
- Provider version constraints (`~>`) are deliberate. TODO confirm.
- `terraform fmt -check` has `continue-on-error: true` in CI. TODO decide whether formatting is blocking.
- `ansible-playbook --syntax-check` only checks `main.yml`; other playbooks may be unchecked by CI.

## Off limits

- Do not run `terraform apply`, `terraform destroy`, or `ansible-playbook` against hosts.
- Do not read, print, or copy secret values, vault passwords, or tokens.
- Do not change linter configuration to make a gate pass.
- Do not edit files during review. Fixes happen only after explicit approval of finding IDs.

## Evidence

- No Terraform plan is available. Claims that need a plan (drift, replacement ordering, provider-side defaults, IAM evaluation) go under **Couldn't verify**.
- Static evidence is `path:line` plus a concrete trigger path.
- For Ansible, a non-idempotent task must name the task and the state that changes on a second run.

## Blast-radius tiers

- **Tier 1:** `terraform/**`, `ansible/infrastructure_bootstrap.yml`, `ansible/group_vars/**`, `.github/workflows/**`.
- **Tier 2:** other Ansible roles and playbooks, `dockerfiles/**`.
- **Tier 3:** documentation, lint configuration, formatting.

Tier 1 changes get the three highest-blast-radius lanes and a `max`-effort refuter. Tier 3 changes may be reviewed with a single lane.
