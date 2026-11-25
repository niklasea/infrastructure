# Severity and verdict

## Severity

Grade by harm, not by category.

| Severity | Meaning | Examples |
|---|---|---|
| `blocker` | Would hurt in production, lose data, expose a secret, break availability, or violate a hard contract | Open ingress to a sensitive service; destructive replacement of a stateful resource; auth bypass; unsound `unsafe`; public API break |
| `important` | Real risk or contract violation that should be fixed, but not an immediate incident | Missing timeout; non-idempotent task that usually converges; weak test that would miss a regression; unbounded growth |
| `nit` | Optional improvement, or a real but low-impact issue | Naming, duplication, missing comment, theoretical edge case with negligible probability |

Style, formatting, import order, and lint violations are **not** review findings unless they violate an explicit repository rule that CI does not enforce. If CI enforces it, do not report it.

## Confidence

- `high`: proven by a caller trace, test, plan delta, or documented contract.
- `medium`: strong static evidence, but one assumption remains.
- `low`: plausible, not proven. Low confidence cannot be a blocker.

## Verdict

| Verdict | When |
|---|---|
| `LGTM` | No blockers, no importants, and every remaining item is a nit or verified-clean. High confidence. |
| `Needs Changes` | At least one confirmed blocker. |
| `Needs Human Review` | An important finding remains, confidence is medium/low, the change depends on a plan or runtime state you cannot see, or the approach itself is questionable. |

Rules:

1. The verdict must reflect the most severe unresolved finding.
2. Never combine `LGTM` with an important finding.
3. When unsure, escalate to `Needs Human Review`. A false LGTM is worse than an unnecessary escalation.
4. Separate code correctness from approach completeness. Correct code implementing the wrong approach is not LGTM.
5. An AI review is advisory. A human owns the merge.

## Report shape

- **Blocking:** confirmed blockers only.
- **Important:** confirmed importants, including downgraded-from-blocker with a reason.
- **Nits:** optional items, capped to the highest-value few.
- **Couldn't verify:** missing facts, one line each.

Every item needs an ID, lane, location, evidence, and suggested fix or next check.
