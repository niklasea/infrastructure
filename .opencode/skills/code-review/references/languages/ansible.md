# Ansible

## Lane map

| Lane | Focus | When |
|---|---|---|
| `ansible-correctness` | Idempotency, handlers, conditionals, variables, templates | Any playbook, role, or vars change |
| `ansible-security` | Vault, secrets, modes, privilege, untrusted input | Any change touching credentials, files, or privilege |
| `ansible-operability` | Ordering, serial, rollback, blast radius | Any playbook or role change |

## CI already covers

`ansible-lint`, `yamllint`, and `ansible-playbook --syntax-check main.yml` run in CI. Do not flag:

- YAML formatting, spacing, or line length;
- task names, `become` style, or `command`-versus-`shell` preferences that `ansible-lint` already enforces;
- syntax errors that `--syntax-check` catches;
- deprecation warnings already emitted by the linter.

Note: CI only syntax-checks `main.yml`. Other playbooks may be unchecked; if you review one, say so.

## Shared evidence

A finding needs the task name and `path:line`. For idempotency, state the **second-run behavior**: what changes again when the playbook is run twice. For security, trace the variable or file from its source to the sink.

## Correctness

- **Idempotency.** `command`/`shell` without `creates`, `removes`, `changed_when`, or `failed_when`; `state: latest`; repeated `git` clones; non-idempotent `lineinfile`/`blockinfile`; package upgrades.
- **Handlers.** `notify` names match handler names or `listen` topics; handlers run at the end; `meta: flush_handlers` where ordering matters.
- **Conditionals.** `when` types, boolean strings, `failed_when`/`changed_when` precedence, `ignore_errors`, `any_errors_fatal`.
- **Loops.** `loop` versus `with_*`, `item` naming, `loop_control`, empty lists.
- **Variables.** Role defaults versus `group_vars`/`host_vars`/extra vars, undefined variables, `default()`, precedence surprises.
- **Templates.** Jinja quoting, `to_json`, booleans, undefined values, newline handling.
- **Roles.** Dependencies, tags, handlers, `become`, role re-use.
- **Inventory.** Dynamic inventory plugin config, `compose`, keyed groups, vault token, host filtering.
- **Execution.** `serial`, `strategy`, `run_once`, `delegate_to`, `connection`.
- **Facts and state.** `gather_facts`, `set_fact`, caching, facts that persist across runs.

## Security

- **Vault.** Encrypted variables, `!vault` values, vault password files not committed, `ansible-vault encrypt_string` usage.
- **Logging.** `no_log: true` on secret-bearing tasks; secrets in `debug`, `command`, or loop output.
- **Files.** Modes (`0600` for keys), owners, directories that hold credentials.
- **Privilege.** `become` scope, `become_user`, sudoers changes, tasks that run as root unnecessarily.
- **SSH.** Host-key checking, `StrictHostKeyChecking`, private key permissions, agent forwarding.
- **Untrusted input.** Inventory or variable data interpolated into `shell`/`command`; quote filters; `argv` instead of a shell string.
- **Supply chain.** Package repositories and keys, `get_url` without checksums, unpinned `pip`/`npm`/`gem` installs.
- **Network.** Firewall rules, exposed Docker sockets, services bound to `0.0.0.0`.

## Operability

- **Ordering.** Tasks that assume a previous play, role, or handler ran.
- **Rollback.** Is there a reverse path? Are backups taken before destructive changes?
- **Blast radius.** `serial`, `max_fail_percentage`, host patterns, `infrastructure_bootstrap.yml` run ad hoc.
- **Service impact.** Restarts, reloads, and handlers that bounce a service without a maintenance window.
- **Partial runs.** Tags that leave the host in an inconsistent state.
- **Repeatability.** A second run should report no changes unless the host drifted.

## False-positive traps

- `shell` is not automatically non-idempotent; check for `creates`, `changed_when`, or an idempotent command.
- `changed_when: false` can be correct for read-only checks, but it can also hide drift.
- `state: latest` may be intentional for security updates; confirm before flagging.
- `ignore_errors` may be deliberate for optional packages; check the surrounding logic.
- `ansible-lint` style findings are not review findings.
- A dynamic inventory token encrypted with `ansible-vault` is expected in this repository.

## Gate commands

```bash
ansible-lint -c .github/linters/.ansible-lint.yml ansible
yamllint -c ansible/yamllint.conf ansible
(cd ansible && ansible-playbook --syntax-check main.yml)
git diff --check
```
