# Single-model review

This pack uses one model family: `deepseek/deepseek-flash`. That removes model diversity, which is a real limitation. Compensate with evidence and task diversity, and be honest about the ceiling.

## What max effort does and does not buy

DeepSeek's `max` effort prepends an instruction to deliberate exhaustively and write out the full reasoning process. It buys depth, not independence: the same weights still share the same blind spots.

- Use `high` for lanes and the fixer.
- Use `max` for the refuter.
- If the harness supports a per-run model override, a single lane may be escalated to `max` for high-blast-radius changes: auth, network exposure, destructive state changes, soundness, public API. Otherwise leave it at `high`; do not silently claim it ran at `max`.

## Compensation

1. **Evidence-bound refutation.** A finding survives only if the refuter can point to a guard, caller, test, plan delta, or concrete trigger. Self-critique without external evidence is unreliable.
2. **Two lenses.** Run refutation as two different questions:
   - "Find the guard or caller that makes this finding false."
   - "Construct the smallest input or plan that makes it true."
3. **Deterministic tools are the second reviewer.** The compiler, tests, linters, scanners, and policy checks are independent of the model. They decide what the model may not contradict.
4. **No blocker without an artifact.** If the best evidence is "this looks risky," it is a nit or a question.
5. **Track outcomes.** Across a validation set, the refuter should reject or downgrade a meaningful share of findings. If it confirms everything, it is not working.

## Observed on the validation set

Two lanes were run at `high` and `max` on the same seeded diff, same prompt, same model:

| Lane | `high` | `max` |
|---|---|---|
| Terraform security | Found the world-open SSH blocker | Found the same blocker; added more detail and a second rule suggestion |
| Ansible correctness | Found the non-idempotent task **and** the lost `mode: "0644"` | Found the non-idempotent task; **missed the lost mode** |

This is a small sample, but it matches the expectation: `max` adds depth, not breadth, and can narrow onto one aspect. Keep lanes at `high`; spend `max` on the refuter.

## Do not

- Do not run the same prompt twice and call it independent review.
- Do not let the lane model approve its own finding without refutation.
- Do not use `max` on mechanical lanes; it invents work.
- Do not claim a second model reviewed the change.

## Reporting

Say plainly that the review used a single model family, which lanes ran at `high` or `max`, and which findings were refuted. Treat the result as advisory; a human owns the merge.
