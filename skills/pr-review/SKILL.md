---
name: pr-review
description: Review a GitHub pull request like a senior engineer. Use when asked to review a PR, before merging, or when you want a second opinion on a diff. Examines the diff for correctness, security, test coverage, and repo conventions, then produces a structured review with blocking findings separated from nits.
license: MIT
metadata:
  author: unisone
---

# PR Review Skill

Give any pull request a thorough, senior-engineer-quality review.

## Purpose

Turn a PR diff into a structured review that distinguishes real problems from
style preferences:

- **Correctness** — logic errors, off-by-ones, broken edge cases, race conditions
- **Security** — injection, auth gaps, secret leaks, unsafe deserialization
- **Tests** — coverage of new behavior, meaningful assertions (not just "it runs")
- **Conventions** — matches the repo's existing patterns, naming, and structure
- **Scope** — unrelated changes smuggled into the diff

## Usage

```bash
# Review a PR by number (repo inferred from cwd)
gh pr diff 123 | claude "review this PR"

# Review with full context (files changed + linked issue)
gh pr view 123 --json title,body,baseRefName,headRefName,files
gh pr diff 123
```

Or point the agent at it directly: "review PR #123 in this repo."

## Review Process

### 1. Gather context

- `gh pr view <n> --json title,body,author,baseRefName,headRefName,additions,deletions,files`
- `gh pr diff <n>` for the full diff
- Read the linked issue, if any — the PR should solve the stated problem
- Skim the repo's `CONTRIBUTING.md` / `CLAUDE.md` for conventions worth enforcing

### 2. Read the diff twice

First pass: understand intent — what is this change trying to do?
Second pass: hunt for problems, file by file, against the dimensions below.

### 3. Check each dimension

**Correctness**
- Does the logic handle the edge cases the code claims to handle?
- Are error paths actually reachable and handled, or silently swallowed?
- Any concurrency hazards (shared mutable state, missing locks, TOCTOU)?
- Do the types line up, or is something coerced unsafely?

**Security**
- User input reaching queries, commands, or HTML without sanitization?
- Auth checks on new endpoints or privileged operations?
- Secrets, tokens, or credentials added to the diff?
- Dependencies added — are they reputable and pinned?

**Tests**
- New behavior covered by tests with real assertions?
- Do the tests fail without the fix (not just pass with it)?
- Mocks used appropriately, not masking the unit under test?

**Conventions**
- Follows the patterns already in the codebase (not a new style invented inline)?
- Naming consistent with surrounding code?
- No dead code, debug leftovers, or commented-out blocks?

**Scope**
- Every hunk serves the PR's stated purpose — flag unrelated drive-bys.

### 4. Write the review

Structure findings by severity, most important first:

```markdown
## PR Review: #123 — <title>

**Verdict:** Approve / Request changes / Comment

### 🔴 Blocking
- `src/auth.ts:42` — ...
  Why it blocks: ...

### 🟡 Should fix
- ...

### 🟢 Nits
- ...

### ✅ What's good
- ...
```

Rules for the writeup:

- **Every finding cites a file and line.** No vague "this could be cleaner."
- **Explain why**, not just what. "This is wrong" is not a review.
- **Blocking** = would break prod, leak data, or corrupt state. Be strict here.
- **Nits** = genuine preferences. Label them as such; never block on a nit.
- **Acknowledge good work.** A review that is only criticism teaches nothing.
- If the diff is too large to review well (>500 lines changed), say so and ask
  for it to be split instead of skimming.

### 5. Post it (only when asked)

```bash
# Post the review as a comment
gh pr review 123 --comment --body-file review.md

# Or request changes
gh pr review 123 --request-changes --body-file review.md
```

Never post or merge without explicit approval. Draft the review first,
show it to the user, then post.

## What This Skill Does Not Do

- Approve PRs on its own — the human merges.
- Run the test suite (ask first; suggest `gh pr checks 123` to see CI status).
- Rewrite the PR — findings go in the review, fixes stay with the author
  unless the user explicitly asks for them.
