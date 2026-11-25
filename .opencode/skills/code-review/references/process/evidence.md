# Evidence contract

A finding without checkable evidence is not a finding.

## Finding schema

```json
{
  "id": "CR-001",
  "lane": "terraform-security",
  "severity": "blocker",
  "confidence": "high",
  "location": "terraform/proxmox.tf:42",
  "summary": "One sentence describing the defect, not the fix.",
  "trigger": "The concrete input, caller, state, or sequence that reaches the defect.",
  "evidence": "What you checked and what proves it: file:line, caller path, command output, plan delta, test.",
  "suggested_fix": "The smallest change that resolves it.",
  "verification": "How a reviewer can reproduce or confirm the finding.",
  "status": "open"
}
```

Allowed values:

- `severity`: `blocker`, `important`, `nit`
- `confidence`: `high`, `medium`, `low`
- `status`: `open`, `confirmed`, `downgraded`, `rejected`, `needs_validation`, `wontfix`

## Rules

1. **Location** is `path:line` or `path:start-end`. File-level findings need a reason.
2. **Trigger** must be concrete. "Could be misused" is not a trigger. "Caller at `src/A.cs:88` passes `null` when `X` is absent" is.
3. **Evidence** must be checkable by someone else. Acceptable forms:
   - file and line references, including the guard that is missing;
   - a caller trace from entry point to failure;
   - a failing test or a minimal reproduction;
   - a Terraform plan delta or a configuration that produces one;
   - a linter, compiler, or scanner result;
   - a documented contract that the change violates.
4. **No proof, no blocker.** Downgrade to `nit` or list it under **Couldn't verify** with the exact missing fact.
5. **One finding per root cause.** If the same defect appears in ten files, report it once and list the affected files.
6. **Do not restate the diff.** Explain what is wrong and why it matters.
7. **Do not propose a fix you cannot make syntactically valid.** If the fix depends on unknown context, say what must be decided.

## Couldn't verify

Use this for anything the lane should cover but cannot prove:

- Terraform plan behavior, drift, provider-side replacement ordering, IAM evaluation.
- Runtime state, production data, external service behavior.
- A test that cannot run because the toolchain is absent.
- A caller outside the repository.

Each entry needs the missing fact and who can check it. Do not fill the gap with speculation.

## Output

Return a single JSON object:

```json
{
  "lane": "terraform-security",
  "findings": [],
  "couldnt_verify": []
}
```

No prose outside the JSON.
