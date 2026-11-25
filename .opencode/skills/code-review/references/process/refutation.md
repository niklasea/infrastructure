# Refutation

The refuter's job is to disprove the finding, not to agree with it.

## For one finding

1. Restate the finding without the lane's reasoning or the author's rationale.
2. Read every cited line and the surrounding code.
3. Trace the stated trigger from a real entry point to the failure.
4. Search for whatever already prevents it: validation, a guard, a caller that never passes that input, a test, a default, a platform constraint.
5. Try to build the smallest counterexample:
   - a concrete input or sequence;
   - a caller path with file:line;
   - a Terraform plan delta or a config that would produce one;
   - a failing test, or a command that demonstrates the behavior.
6. If the claim depends on something you cannot inspect, stop and name the missing fact.

## Verdicts

| Verdict | Meaning |
|---|---|
| `confirmed` | The defect is real. Keep the severity, corrected if the evidence warrants it. |
| `downgraded` | Real, but the harm is lower than claimed. Keep as a nit or important with a reason. |
| `rejected` | The finding is wrong: the guard exists, the caller cannot pass the input, or the behavior is intended. Give the reason. |
| `needs_validation` | The claim may be real, but a decisive fact is missing. Name the fact and who can check it. |

## Language notes

- **Terraform:** static proof only. If the finding needs a plan, mark `needs_validation` and name the resource and the expected plan change. Do not run `terraform apply` or `destroy`.
- **Ansible:** reproduce with the task, the variable state, and the expected second-run behavior. A task is not non-idempotent just because it uses `shell`; check for `creates`, `changed_when`, or an idempotent command.
- **C#:** prefer a failing test or a caller trace. If the toolchain is unavailable, inspect the tests and mark `needs_validation` rather than asserting runtime behavior.
- **Rust:** soundness claims need a concrete path to undefined behavior, not just the presence of `unsafe`. If Miri is unavailable, say so. Clippy and compiler findings are not review findings.
- **GitHub Actions:** trace from the event trigger to the secret or shell sink. A `pull_request_target` is not automatically vulnerable; check whether untrusted code is checked out or executed.

## Rules

- The refuter edits nothing.
- The refuter does not see the lane's full report, only the finding.
- A finding that cannot survive refutation is dropped, not softened into a vague warning.
- A confirmed finding keeps its evidence; do not rewrite it into a generic best practice.
