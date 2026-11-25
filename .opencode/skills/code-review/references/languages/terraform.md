# Terraform

## Lane map

| Lane | Focus | When |
|---|---|---|
| `terraform-correctness` | Resource semantics, references, lifecycle, state, dependencies | Any `.tf`, `.tfvars`, or `.tftpl` change |
| `terraform-security` | Exposure, credentials, secrets, supply chain | Any Terraform change |
| `terraform-operability` | Blast radius, replacement, rollback, cost | Any resource, module, or provider change |

## CI already covers

`terraform fmt`, `terraform validate`, `tflint`, and `checkov` run in CI. Do not flag:

- formatting or alignment;
- provider schema errors, unknown arguments, type errors that `validate` catches;
- generic public-resource or encryption rules that `checkov` reports;
- deprecation warnings already emitted by `validate` or `tflint`.

If `gate.log` says a tool was skipped, you may flag the issue, but mark the evidence accordingly. Do not duplicate a CI finding as a new blocker.

## Shared evidence

Terraform review is **static only** here. No plan is generated. Any claim that needs a plan (replacement, drift, IAM evaluation, ordering, provider-side defaults) must be `needs_validation` and must name:

- the resource address;
- the expected plan effect;
- who can confirm it.

Cite the resource block and attribute. Do not speculate about provider behavior you cannot see.

## Correctness

- **References and types.** Undeclared variables, wrong types, null defaults, missing `sensitive`, incorrect `for_each` keys.
- **Addressing.** `count` index churn, unstable `for_each` keys, conditional resources, `one()`/`try()` behavior.
- **Lifecycle.** `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, and whether a change forces replacement.
- **State.** Renames without `moved`, imports without `import`, backend or workspace changes, stateful resources (disks, volumes, DNS, certificates).
- **Dependencies.** Implicit references versus `depends_on`; provider aliases; module outputs; ordering that is assumed but not expressed.
- **Versions.** Terraform constraint (`~> 1.14`), provider constraints, lockfile changes, major/minor drift.
- **Templates.** `cloud-init.tftpl` variables, `user_data` changes that force replacement, quoting and escaping.
- **Modules.** Source pinning, input validation, outputs that leak sensitive values.
- **Provider specifics.** Proxmox VM disks, cloud-init, SSH keys, network interfaces, firewall; Hetzner servers, volumes, networks, firewalls, labels.

## Security

- **Ingress.** `0.0.0.0/0`, `::/0`, management ports, Proxmox API or SSH exposed beyond the intended network.
- **Credentials.** Root versus scoped API tokens, tokens in variables versus environment, `sensitive = true`, token permissions.
- **SSH.** Password authentication, agent forwarding, host-key checking, key permissions.
- **Secrets.** Values in `*.tfvars`, state, outputs, cloud-init, `user_data`, templates, or committed lockfiles. Flag secret material, not variable references.
- **Supply chain.** Provider source and version, module source, `terraform.lock.hcl` changes, modules from branches instead of tags.
- **Transport.** `insecure = true`, unverified TLS, plaintext endpoints.
- **Network segmentation.** Flat networks, missing private networks, firewall rules that are broader than the service needs.
- **State.** Remote state access, encryption, who can read it.

## Operability

- **Replacement risk.** Stateful resources that would be destroyed and recreated.
- **Blast radius.** `count`/`for_each` changes that touch many instances; module-wide changes; provider configuration changes.
- **Rollback.** Is there a path back? Are backups or snapshots taken?
- **Cost.** Instance sizes, volumes, egress, idle resources.
- **Naming and labels.** Consistency that affects inventory, billing, or automation.
- **Drift.** Changes that assume current state without expressing it.
- **Partial apply.** Ordering, `depends_on`, and resources that fail halfway.

## False-positive traps

- `insecure = true` on the Proxmox provider may be intentional for a self-signed endpoint. Confirm in `REVIEW.md` before flagging.
- A `count` or `for_each` change can be intentional; require plan evidence before calling it a blocker.
- Provider version constraints are often deliberate.
- `terraform fmt` currently has `continue-on-error` in CI; formatting is not a review finding.
- Tag or label differences are nits unless they break automation.
- `checkov` generic rules may already be accepted or suppressed; do not re-litigate them without reading the suppression.

## Gate commands

```bash
terraform fmt -check -recursive terraform
terraform -chdir=terraform validate -no-color   # only if terraform/.terraform exists
tflint --chdir=terraform
checkov -d terraform --compact
git diff --check
```
