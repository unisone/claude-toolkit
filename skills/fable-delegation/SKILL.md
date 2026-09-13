---
name: fable-delegation
description: Delegate long-running autonomous coding work to Claude Fable 5.1. Use for multi-hour workstreams (large refactors, repo migrations, feature builds) where you want the model to carry work through implementation, review, and the merge tail — not just draft code.
license: MIT
metadata:
  author: unisone
---

# Fable Delegation Skill

Claude Fable 5.1 (released September 2026) is built for long-running,
autonomous problem-solving: it scores 55.8% on Terminal-Bench 4.0 and is
reported to carry work through the review-and-merge tail far more reliably
than previous models. This skill is about structuring work so you can
actually delegate it — the model does the marathon, you hold the finish line.

## Effort Levels

Fable 5.1 exposes effort tiers (low / medium / high, with higher tiers
available). Match effort to the task:

| Task | Effort | Why |
|---|---|---|
| Typo fixes, single-file edits | Low | High effort wastes tokens on trivial work |
| Feature implementation, refactors | Medium | Best quality-per-token for most coding |
| Deep debugging, novel architecture | High | Worth it when the problem is genuinely hard |
| Long prose / docs | Medium | Early testing found extra-high effort can *degrade* writing quality — medium produced sharper results |

Default to medium. Raise effort only when the task resists, not preemptively.

## The Delegation Brief

Never delegate with a one-liner. A workstream that runs for hours needs a
brief with four parts:

1. **Mission** — what done looks like, in verifiable terms.
   Bad: "improve the auth module." Good: "migrate auth from sessions to
   JWT; all 40 existing tests pass; new tests cover token refresh."
2. **Boundaries** — what NOT to touch. List protected files, APIs, and
   behaviors explicitly. Long runs drift; boundaries contain the drift.
3. **Checkpoints** — where the model must stop and report: after planning,
   after implementation, before any merge. You approve each gate.
4. **Verification** — the exact commands that prove success
   (`npm test`, `cargo test`, `pytest`). The model runs them; you trust
   the output, not the summary.

## The Review-Merge Tail

Fable 5.1's standout trait is carrying work through review — but "can" is
not "should unsupervised":

- Let it self-review: ask for a PR-description-style summary of its own
  changes, then have it re-read the diff looking for the bugs a reviewer
  would catch.
- Keep the merge gate human for production branches. Autonomous merge is
  for scratch branches and experiments.
- Require the verification commands to pass *after* the final edit, not
  before — last-minute fixes break things.

## Cost Discipline

Fable 5.1 cut cache-read pricing sharply (Anthropic reports ~25% savings on
typical workloads, up to ~45% on highly agentic ones). Long runs are cheaper
than they were — but only if you keep prompts cache-friendly:

- Put stable context (repo conventions, architecture notes) in the system
  prompt or a persistent file, not re-pasted each turn.
- Let checkpoints be short status reports, not full context re-dumps.
- Kill runs that loop. A model retrying the same failing approach for 30
  minutes is a billing event, not progress. Intervene, redirect, resume.

## Know the Model's Edges

- **Fewer false positives, not zero judgment.** Cybersecurity false positives
  are down ~60%, so security-adjacent coding tasks (vuln triage, hardening)
  refuse less often. It still won't develop exploits — don't ask.
- **Invisible watermarking.** Fable 5.1 text carries invisible watermarks,
  with a detection API in private preview. If you're publishing model-written
  content as your own, know that it's detectable.
- **Fable vs Mythos.** Same underlying model, different safeguards. Fable
  5.1 is the generally available one; Mythos 5.1 is restricted to trusted
  access programs. This skill targets Fable 5.1.
- **Long runs need long context hygiene.** At hour four the model is working
  from a summary of hour one. Checkpoints exist so you catch drift early —
  the further it runs unverified, the more rework a correction costs.
