# Generic

Use this only when no language reference matches. Say in the report that the review was language-agnostic.

## Lane map

| Lane | Focus |
|---|---|
| `generic-correctness` | Behavior, error handling, resources, concurrency, tests |
| `generic-security` | Input, authorization, secrets, injection, dependencies |

## CI already covers

Whatever the repository's build, linter, formatter, and test pipeline already enforces. Do not duplicate it. If the gate log shows a skipped tool, say so.

## Shared evidence

A finding needs `path:line`, a concrete trigger, and checkable evidence. Prefer a caller trace or a failing test. If neither is possible, use **Couldn't verify**.

## Correctness

- Does the change do what it claims, including error paths?
- Are inputs validated at trust boundaries?
- Are resources released on every path?
- Is shared state protected, and are async paths cancellation-safe?
- Are timeouts, retries, and limits bounded?
- Do tests cover the behavior change and the failure modes?
- Is there a rollback or recovery path?

## Security

- Untrusted input reaching a shell, query, template, path, or deserializer.
- Missing authorization on a resource access.
- Secrets in code, logs, errors, or build artifacts.
- Weak crypto, disabled verification, permissive CORS, open redirects.
- Dependency or action pinning.

## False-positive traps

- Do not flag style or formatting.
- Do not assume a framework default; check the version and configuration.
- Do not claim a vulnerability without a path from input to impact.
- Do not propose a large refactor as a review fix.

## Gate commands

Use the repository's own checks. Do not invent a toolchain.
