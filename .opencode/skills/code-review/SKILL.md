---
name: Code Review
description: Review a diff, branch, commit, or working tree with independent language lanes, adversarial refutation, and confirmation-gated fixes. Use when asked to review code, check a change before commit or merge, or audit a repository.
---

# Code Review

Generic orchestrator. Language rules live in `references/languages/`; process rules live in `references/process/`.

## Non-negotiables

1. Do not edit files before the user approves finding IDs.
2. Do not pass the user's rationale, hypothesis, or PR description to lane agents. They review the code, not the intent.
3. Do not flag what the compiler, analyzers, linters, or CI already catch.
4. No blocker without checkable evidence. A hunch is a nit or a question.
5. `LGTM` only when confident. Otherwise `Needs Human Review`.
6. Lane and refuter agents are read-only. Only `review-fixer` writes. None of them may call `execute`, `opencode_*`, or session-management tools; those permissions are not reliably enforceable, so the instruction is explicit.
7. If a claim depends on a plan or runtime state you cannot see, put it under **Couldn't verify**.

## 1. Scope

From the repository root:

```bash
bash .opencode/scripts/review-context.sh [range]
```

- No range: diff from `merge-base(origin/main, HEAD)` to the working tree, so branch commits, staged changes, and unstaged changes are all included. If `origin/main` is absent, diff against `HEAD`.
- The script writes `context.json`, `diff.patch`, `untracked.patch`, `changed-files.txt`, and `recent-commits.txt` under `/tmp/opencode/review-<sha>/`.
- Read `context.json`. Use its `out_dir` as `$OUT`.
- If `diff.patch` and `untracked.patch` are both empty, stop and say there is nothing to review.
- Ignore `.opencode/**`, `REVIEW.md`, and review artifacts when selecting lanes, unless the user explicitly asks to review the pack itself.
- Create `$OUT/findings.json` immediately with `{"lanes": [], "findings": [], "couldnt_verify": []}`. Update it after each phase so an interrupted run still leaves a report.
- Run `bash .opencode/scripts/review-gate.sh` once before dispatching lanes. Read `gate.log`; a failing gate is not itself a review finding, but it tells lanes what CI already covers and which scanners were skipped.
- Include the `gate.log` path in every lane prompt.

## 2. Independent assessment (before the narrative)

Read `references/process/independent-assessment.md` and follow it.

Write `$OUT/assessment.md` from the code alone: what changed, why it might be needed, whether the approach is sound, what worries you, and the blast radius. Do not read the user's rationale first. Reconcile afterwards, but do not soften findings because the intent sounds reasonable.

## 3. Choose lanes

Read `references/languages/index.md`.

- Match changed paths to language references.
- Read only the **Lane map** and **CI already covers** sections of each matching reference.
- Select at most **three lanes total**. This is a total cap, not a batch size. Do not run a second batch.
- If more than three candidates apply, keep the three with the highest blast radius. Merge related lanes (for example Terraform correctness and operability) or defer the rest and say so in the report.
- Priority order: security, soundness, correctness, tests, API, performance, operability, hardening.
- Docs-only or generated-only changes: run only the `generic` lane, or stop.

## 4. Dispatch lanes

Read `references/process/evidence.md` and `references/process/severity-and-verdict.md`.

Launch one `review-lane` subagent per selected lane, in parallel. Each prompt contains only:

- repository root and `$OUT`
- paths to `diff.patch` and `untracked.patch`
- the `gate.log` path
- the changed-file list
- the language reference path and the lane name/section to apply
- the evidence contract and output schema
- the four rules below

**The four rules, verbatim:**

- **No alibi.** Do not read the user's message, prior conversation, PR description, or issue text. Judge what the code does and what it breaks.
- **Hunt, don't approve.** Assume the diff contains at least one real defect in your lane. Find it, or explain why the lane is clean. An empty report with an empty **Couldn't verify** list is not acceptable.
- **Evidence or it is not a finding.** Every finding needs a location, a concrete trigger, and checkable evidence. If you cannot prove it, say so and mark it as a question.
- **Report, don't edit.** Change no files and run no shell commands.

Wait for every lane. Do not synthesize partial results unless a lane fails; record the failure and continue. Never pass your `assessment.md` or the user's message to a lane.

## 5. Refute

Read `references/process/refutation.md`.

Refute **every blocker**, and up to **five importants** by confidence. If there are more than five blockers, refute the five with the strongest evidence and mark the rest `needs_validation` rather than leaving them unrefuted.

Launch one `review-refuter` subagent per finding, in parallel. Give it the finding, the relevant file paths, the diff path, and the repository root. Do not give it the lane's reasoning beyond the finding itself.

The refuter returns `confirmed`, `downgraded`, `rejected`, or `needs_validation` with evidence.

- `rejected`: drop the finding.
- `downgraded`: keep it as a nit.
- `confirmed`: keep the severity, corrected if needed.
- `needs_validation`: move it to **Couldn't verify** with the missing fact.

If a refuter cannot produce a caller trace, failing test, plan delta, linter result, or concrete trigger, the finding cannot remain a blocker.

## 6. Synthesize

Deduplicate by root cause, not by line. Keep the highest severity and the strongest evidence. Apply `references/process/severity-and-verdict.md`.

Never trust lane-assigned IDs; they collide across lanes. After deduplication, assign global IDs `CR-001`, `CR-002`, ... in severity order: blockers first, then importants, then nits, then **Couldn't verify**. Preserve the original lane name on each finding.

Write `$OUT/findings.json` with the merged findings and print:

```markdown
## Verdict: LGTM | Needs Human Review | Needs Changes

### Blocking
- CR-001 [lane] path:line — summary. Evidence. Suggested fix.

### Important
...

### Nits
...

### Couldn't verify
- CR-004 [lane] — the missing fact and who can check it.
```

State which lanes ran, which were skipped, and whether the refuter changed any outcomes. Mention that same-model review is advisory and a human owns the merge.

## 7. Fix after confirmation

Do not edit anything until the user explicitly approves a list of finding IDs.

Then launch `review-fixer` with:

- the approved IDs
- `$OUT/findings.json`
- the repository root
- the changed-file list

The fixer applies only those findings, runs:

```bash
bash .opencode/scripts/review-gate.sh
```

and reports per-ID status. Then re-review the changed hunks with the same lane, or with `review-refuter` if the fix is small.

## Lane reference format

Each language reference has the same shape:

- **Lane map** — lane names and when they apply
- **CI already covers** — what not to flag
- **Shared evidence** — how to prove a finding in this language
- **Correctness / Security / Operability** (or language-specific equivalents)
- **False-positive traps**
- **Gate commands** — deterministic checks only

If a reference is missing for a changed language, use `references/languages/generic.md`. Do not invent language rules.
