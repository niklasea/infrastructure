# Independent assessment

The goal is to judge the change before exposure to the author's framing. Anchoring is the main reason reviews miss real problems.

## Do this first

Read only the code:

1. The full diff, including untracked files.
2. Every changed file, well beyond the hunks. Read enclosing functions and types.
3. Callers and consumers of any changed API, type, or behavior.
4. Sibling implementations and platform variants that may need the same fix.
5. Shared helpers whose contracts the change depends on.
6. Recent history of the changed files (`recent-commits.txt`, then `git log` if needed).
7. Tests that cover the changed behavior.

## Write `$OUT/assessment.md`

Answer in your own words:

- **What changed?** Old behavior versus new behavior. No adjectives.
- **Why might it be needed?** Infer from the code, not from the request.
- **Is this the right approach?** Simpler alternative? Existing functionality? Does it fit the repository's patterns?
- **What worries you?** Bugs, edge cases, missing validation, concurrency, performance, security, test gaps, operational risk.
- **Blast radius.** What breaks if this is wrong, and who notices?
- **What can you not verify?** Plans, runtime state, external services, provider behavior.

## Then reconcile

Now read the user's message, PR description, or linked issue. Treat each claim as something to verify, not a fact.

- Where the code and the narrative disagree, investigate.
- Do not soften a finding because the intent sounds reasonable.
- Update the assessment only if new evidence genuinely changes it.
- If the narrative reveals a requirement you could not infer, say so; do not invent one.

## Stop conditions

Do not dispatch lanes if:

- the diff is empty;
- the change is generated or vendored and carries no reviewable logic;
- the only changes are formatting, lockfiles, or documentation.

In those cases, say why the review is limited and stop, or run only the `generic` lane for documentation consistency.
