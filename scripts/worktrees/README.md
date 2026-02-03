# Git Worktrees - Parallel Development Pattern

Parallel git worktrees for isolated development contexts. Based on Boris Cherny's team workflow pattern.

## Why Worktrees?

**Problem:** Switching branches contaminates your environment
- File watchers trigger rebuilds
- Node modules get reinstalled
- IDE loses context
- Background processes crash
- Tests fail due to timing issues

**Solution:** Parallel worktrees = isolated contexts
- Each worktree has its own working directory
- Switch context by switching directory (`cd`), not branch
- Background processes stay running
- No rebuild thrashing
- Clean mental model

## The Pattern

```
~/Projects/
  mf-chatbot-ui/              # Main repo (read-only reference)
  mf-chatbot-ui-feature-a/    # Active feature work
  mf-chatbot-ui-feature-b/    # Parallel feature work
  mf-chatbot-ui-analysis/     # Read-only analysis/comparison
```

**Workflow:**
1. **feature-a**: Build new feature (IDE, dev server, tests running)
2. **feature-b**: Fix bug in parallel (different IDE window)
3. **analysis**: Compare code, read docs, explore (never edit)
4. **main**: Pull latest, read-only reference

## Quick Start

### Setup

```bash
# Create worktrees for existing repo
./scripts/worktrees/setup-worktrees.sh ~/Projects/mf-chatbot-ui

# Custom names
./scripts/worktrees/setup-worktrees.sh ~/Projects/my-app backend frontend testing

# Single worktree
./scripts/worktrees/setup-worktrees.sh ~/Projects/my-app experiment
```

### Navigation Aliases

Add to `~/.zshrc`:

```bash
alias za='cd ~/Projects/mf-chatbot-ui-feature-a'
alias zb='cd ~/Projects/mf-chatbot-ui-feature-b'
alias zc='cd ~/Projects/mf-chatbot-ui-analysis'
```

Then:

```bash
# Jump to worktree A
za
npm run dev

# Jump to worktree B (new terminal)
zb
npm run test:watch

# Jump to analysis worktree (read-only)
zc
grep -r "old pattern" src/
```

### Cleanup

```bash
# Interactive cleanup (confirms each step)
./scripts/worktrees/teardown-worktrees.sh ~/Projects/mf-chatbot-ui

# Force cleanup (no prompts)
./scripts/worktrees/teardown-worktrees.sh ~/Projects/mf-chatbot-ui --force
```

## Example: mf-chatbot-ui Workflow

### Scenario: Building chat UI + fixing bug simultaneously

**Without worktrees (painful):**
```bash
cd mf-chatbot-ui
git checkout feature/new-chat-ui
npm run dev
# Dev server running...

# Bug report comes in!
^C  # Kill dev server
git stash
git checkout fix/message-timestamp
npm install  # Dependencies changed
npm run dev
# Fix bug, test, commit

git checkout feature/new-chat-ui
git stash pop
npm install  # Re-install original deps
npm run dev
# Where was I? Context lost.
```

**With worktrees (smooth):**
```bash
# Terminal 1: Feature work
za  # mf-chatbot-ui-feature-a
npm run dev
# Dev server running, IDE open, flow state

# Terminal 2: Bug fix (parallel)
zb  # mf-chatbot-ui-feature-b
npm run dev -- --port 3001
# Different dev server, fix bug, commit
# No context switch in Terminal 1!

# Terminal 3: Code exploration
zc  # mf-chatbot-ui-analysis
rg "MessageTimestamp" --type ts
# Read-only, never edit here
```

### Real workflow

```bash
# Monday: Start feature work
za
git checkout -b feature/enhanced-chat
npm run dev
# Work all day...

# Tuesday: Critical bug reported
zb
git checkout -b fix/critical-bug
# Fix immediately in parallel
git commit && git push
# Back to za, feature work continues

# Wednesday: PR review
zc
git fetch origin
git checkout origin/feature/team-member
# Read code, leave comments
# Never commit from analysis worktree

# Thursday: Merge conflicts
za
git fetch origin main
git rebase origin/main
# Resolve conflicts in feature-a
# feature-b unaffected, stays stable
```

## OpenClaw Sub-Agent Pattern

**Use case:** Run multiple AI agents on same repo without collision

### Setup

```bash
# Create worktrees for parallel agent work
./scripts/worktrees/setup-worktrees.sh ~/Projects/api-server \
  agent-refactor agent-tests agent-docs
```

### Sub-Agent Configuration

```bash
# Terminal 1: Main agent (orchestration)
cd ~/Projects/api-server  # Main repo, read-only

# Spawn sub-agents, each targets different worktree
openclaw spawn --label refactor-services \
  --context "workdir=~/Projects/api-server-agent-refactor" \
  --prompt "Refactor user service to use new auth pattern"

openclaw spawn --label write-tests \
  --context "workdir=~/Projects/api-server-agent-tests" \
  --prompt "Add integration tests for payment API"

openclaw spawn --label update-docs \
  --context "workdir=~/Projects/api-server-agent-docs" \
  --prompt "Update API documentation for v2 endpoints"
```

### Why This Works

1. **No file conflicts**: Each agent works in isolated directory
2. **Independent commits**: Each worktree tracks different branch
3. **Parallel execution**: Agents run simultaneously, no waiting
4. **Clean merges**: Main agent reviews and merges each branch
5. **Safe rollback**: Failed agent work doesn't contaminate other worktrees

### Agent Workflow Example

```markdown
# Main agent session (~/Projects/api-server)

Agent: I need to refactor auth, add tests, and update docs.
       These tasks are independent. I'll spawn sub-agents.

1. Spawn refactor agent → ~/Projects/api-server-agent-refactor
2. Spawn test agent → ~/Projects/api-server-agent-tests
3. Spawn docs agent → ~/Projects/api-server-agent-docs

[Wait for completion signals]

4. Review refactor changes:
   cd ~/Projects/api-server-agent-refactor
   git diff main...worktree/agent-refactor

5. Review test changes:
   cd ~/Projects/api-server-agent-tests
   git diff main...worktree/agent-tests

6. Merge to main:
   cd ~/Projects/api-server
   git merge worktree/agent-refactor
   git merge worktree/agent-tests
   git merge worktree/agent-docs

7. Clean up:
   ./scripts/worktrees/teardown-worktrees.sh ~/Projects/api-server
```

## Advanced Patterns

### Stacked Worktrees (A depends on B)

```bash
# Create feature A
za
git checkout -b feature/api-v2

# Create feature B on top of A (in worktree B)
zb
git checkout -b feature/api-v2-ui feature/api-v2
# Now B has A's changes

# When A is updated:
zb
git rebase feature/api-v2
```

### Long-Running Analysis Worktree

```bash
# Set up permanent analysis worktree
./scripts/worktrees/setup-worktrees.sh ~/Projects/my-app analysis
zc

# Keep it updated but never commit
git fetch origin main
git reset --hard origin/main

# Use for:
# - Searching code
# - Running read-only scripts
# - Testing commands before running in active worktree
```

### CI/CD Integration

```yaml
# .github/workflows/parallel-tests.yml
name: Parallel Tests

jobs:
  test-matrix:
    strategy:
      matrix:
        suite: [unit, integration, e2e]
    steps:
      - uses: actions/checkout@v3
      
      # Create worktree for each test suite
      - name: Setup worktree
        run: |
          git worktree add ../test-${{ matrix.suite }} HEAD
          cd ../test-${{ matrix.suite }}
      
      # Run tests in isolation
      - name: Run ${{ matrix.suite }} tests
        run: |
          cd ../test-${{ matrix.suite }}
          npm run test:${{ matrix.suite }}
```

## Rules of Thumb

### DO

✅ **Use main repo as reference** — Never edit, always up-to-date  
✅ **One worktree per active branch** — Clear mapping  
✅ **Analysis worktree for reading** — Safe exploration  
✅ **Sub-agents get dedicated worktrees** — No conflicts  
✅ **Shell aliases for navigation** — `za`, `zb`, `zc` is fast  

### DON'T

❌ **Don't create too many worktrees** — 3-5 is ideal, >10 is chaos  
❌ **Don't share worktrees between agents** — Each gets its own  
❌ **Don't commit from analysis worktree** — Read-only rule  
❌ **Don't forget to clean up** — Use teardown script  
❌ **Don't hardcode paths** — Use variables for repo paths  

## Troubleshooting

### Worktree out of sync with main

```bash
# Update worktree with latest main
za
git fetch origin main
git rebase origin/main
```

### Stuck worktree (directory deleted manually)

```bash
# Prune dead worktree metadata
cd ~/Projects/my-app
git worktree prune
```

### Branch still exists after teardown

```bash
# List worktree branches
git branch | grep "worktree/"

# Delete manually
git branch -D worktree/feature-a
```

### Can't create worktree (branch exists)

```bash
# Use existing branch
git worktree add ../my-app-experiment existing-branch

# Or delete old branch first
git branch -D old-branch
./scripts/worktrees/setup-worktrees.sh ~/Projects/my-app experiment
```

## See Also

- [Git Worktree Docs](https://git-scm.com/docs/git-worktree)
- Boris Cherny's talk: [Parallel Development with Git Worktrees](https://www.youtube.com/watch?v=1234) (TODO: find actual link)
- `skills/multi-agent/SKILL.md` — Multi-agent development patterns
- `skills/dev-workflow/SKILL.md` — Development workflow

## Scripts

- `setup-worktrees.sh` — Create parallel worktrees
- `teardown-worktrees.sh` — Clean up worktrees
- Both have `--help` for detailed usage

## Philosophy

**Branch switching is context switching.**

Worktrees eliminate context switching by eliminating branch switching.

Instead of:
```
git checkout feature-a  # Context lost
git checkout feature-b  # Context lost
```

You get:
```
cd feature-a  # Context preserved
cd feature-b  # Context preserved
```

**Your brain stays in flow state. Your tools keep running. Your work gets done.**
