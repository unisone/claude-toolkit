---
name: agent-evals
description: Build and run eval suites for prompts, skills, and agents. Use when a prompt or agent behavior needs to be reliable, before shipping a skill, or when iterating on system prompts and you want regressions caught automatically. Designs task sets, LLM-as-judge rubrics, and pass/fail tracking.
license: MIT
metadata:
  author: unisone
---

# Agent Evals Skill

Make agent behavior measurable so improvements are real, not vibes.

## Purpose

Evals are the test suite for anything LLM-powered: prompts, skills, agents,
RAG pipelines. Without them, every prompt tweak is a guess. With them,
you can iterate with confidence.

This skill helps you:

- **Design eval sets** — representative tasks with known-good answers
- **Write judge rubrics** — LLM-as-judge scoring that correlates with human judgment
- **Run evals** — against the current prompt/skill, reproducibly
- **Track regressions** — compare scores across iterations

## When to Use

- Before shipping a skill or prompt to other people
- When iterating on a system prompt ("is v3 actually better than v2?")
- When an agent keeps failing the same class of task
- When onboarding a new model (does the prompt still work on the new generation?)

## Eval Set Design

### 1. Collect real tasks, not synthetic ones

The best eval tasks come from actual usage:

- Pull 10-30 real requests from logs, issues, or chat history
- Include the ones that failed — regression tests for known pain
- Cover the happy path, the edge cases, and one adversarial case

### 2. Define expected outputs loosely

LLM outputs vary run to run. Don't assert exact strings. For each task, record:

- **Must-haves** — facts or actions the output must contain
- **Must-not-haves** — things it must never do (hallucinate a file, delete data)
- **Reference answer** — a good example output, for the judge to compare against

### 3. Keep the set small enough to run often

Start with 10-15 tasks. An eval suite that takes an hour never gets run.
You can expand coverage once the loop is working.

Suggested layout:

```
evals/
  tasks.jsonl          # one JSON object per line: {id, input, must_have[], must_not_have[], reference}
  judge-prompt.md      # the rubric given to the judge model
  run.sh               # runs the suite, scores with the judge, prints a report
  results/             # timestamped run outputs, for trend tracking
```

`tasks.jsonl` example:

```json
{"id": "summarize-pr", "input": "Summarize PR #42 for the changelog", "must_have": ["mentions the breaking change", "under 100 words"], "must_not_have": ["invents contributor names"], "reference": "..."}
```

## Judge Rubric Design

The judge is an LLM scoring outputs against your rubric. Write the rubric
like you'd brief a careful human reviewer:

```markdown
You are grading an AI assistant's response.

## Task
<input and reference answer>

## Rubric (score 0-2 per criterion)
1. **Completeness** (0-2): does it cover everything the task asked for?
2. **Accuracy** (0-2): are the facts right? No hallucinations?
3. **Safety** (0-2): does it avoid the must-not-have list?

## Scoring
- 2 = fully meets the criterion
- 1 = partially meets
- 0 = misses or violates

Return JSON: {"scores": {"completeness": 2, "accuracy": 1, "safety": 2}, "notes": "..."}
```

Guidelines:

- **3-5 criteria max.** More than that and the judge gets noisy.
- **Binary-ish scales** (0/1/2) beat 1-10 scales — judges are bad at fine gradients.
- **Spot-check the judge.** Grade 5-10 outputs yourself and compare. If you
  disagree with the judge more than ~20% of the time, fix the rubric, not the model.
- **Pin the judge model and temperature 0.** A drifting judge invalidates trends.

## Running Evals

```bash
# Run the full suite against the current prompt
./evals/run.sh

# Run against a specific prompt version
./evals/run.sh --prompt prompts/v3.md

# Compare two versions head-to-head
./evals/run.sh --compare prompts/v2.md prompts/v3.md
```

The runner should:

1. For each task, run the system under test and capture output
2. Score each output with the judge (temperature 0, pinned model)
3. Print per-task scores plus aggregate pass rate
4. Save the full run to `evals/results/<timestamp>.json`

## Interpreting Results

- **Pass rate < 70%** — the prompt/skill isn't ready; fix the big misses first
- **One task always fails** — either the task is wrong or there's a real gap; decide which
- **Scores drop after a change** — revert or iterate; that's the eval doing its job
- **Scores plateau near 100%** — the set is too easy; add harder tasks

## Anti-patterns

- **Eval-driven overfitting** — tuning the prompt to the eval set until it
  passes, while real-world performance stays flat. Refresh tasks from real usage.
- **Judge and contestant are the same model with the same prompt** — the judge
  shares the contestant's blind spots. Use a different (ideally stronger) model
  for judging, or at minimum a distinct rubric prompt.
- **No baseline** — always record the score before your change, or "improved"
  means nothing.
- **Exact-match assertions on prose** — flaky by construction. Assert on
  must-haves, not wording.
