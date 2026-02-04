# Claude Toolkit

> Professional AI coding toolkit — techdebt scanner + git worktree parallelization

[![npm version](https://badge.fury.io/js/%40unisone%2Fclaude-toolkit.svg)](https://www.npmjs.com/package/@unisone/claude-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js Version](https://img.shields.io/badge/node-%3E%3D18-brightgreen.svg)](https://nodejs.org/)
[![Code Quality](https://github.com/unisone/claude-toolkit/workflows/Code%20Quality/badge.svg)](https://github.com/unisone/claude-toolkit/actions)

Two essential tools that supercharge AI-powered development workflows. Works with **Claude Code**, **Cursor**, **Codex**, or any AI coding assistant.

## Features

### 🔍 Techdebt Scanner

Automated code quality detection that finds:
- 📋 Duplicated code patterns
- 💀 Dead/unreachable code  
- 📝 TODO/FIXME/HACK markers
- 🔒 Type safety gaps (TypeScript)
- 📦 Dependency hygiene
- 📏 File size violations

**Perfect for:** End-of-session cleanup, PR reviews, CI/CD quality gates

### 🌳 Git Worktree Manager

Create parallel development environments without branch-switching chaos:
- 🚀 Isolated contexts for multi-tasking
- 🤖 Perfect for parallel AI agents
- 🔄 No rebuild thrashing
- 🧠 Preserve mental context

**Perfect for:** Multi-agent workflows, parallel features, bug fixes while developing

## Quick Start

### Install

```bash
# Run directly with npx (no install)
npx @unisone/claude-toolkit techdebt

# Or install globally
npm install -g @unisone/claude-toolkit

# Or clone and use directly
git clone https://github.com/unisone/claude-toolkit
cd claude-toolkit
npm link
```

### Usage

#### Techdebt Scanner

```bash
# Scan current directory
techdebt

# Scan specific project
techdebt /path/to/project

# Auto-fix safe issues (unused imports, formatting)
techdebt --fix

# Summary only
techdebt --summary

# Generate markdown report
npx @unisone/claude-toolkit techdebt > techdebt-report.md
```

**Example output:**

```
CRITICAL (must fix before merge)
---------------------------------
[FILE_SIZE] src/Dashboard.tsx (547 lines)
  → Split into smaller components

[DUPLICATE] src/utils/validator.ts:45-67
  → Extract to shared utility

HIGH (fix this sprint)
----------------------
[TYPE_GAP] src/models/user.ts:34
  Function missing return type
  → Add explicit return type

SUMMARY
-------
Critical: 2
High: 3
Medium: 7
Low: 4
Total: 16 issues
```

#### Worktree Manager

```bash
# Create parallel worktrees
worktrees /path/to/repo

# Custom worktree names
worktrees /path/to/repo backend frontend testing

# Creates structure:
#   repo/              # Main (read-only)
#   repo-backend/      # Worktree 1
#   repo-frontend/     # Worktree 2
#   repo-testing/      # Worktree 3
```

**Then navigate with shell aliases:**

```bash
alias za='cd ~/Projects/repo-backend'
alias zb='cd ~/Projects/repo-frontend'
alias zc='cd ~/Projects/repo-testing'

# Jump between worktrees instantly
za  # → backend work
zb  # → frontend work (in parallel!)
```

**Cleanup when done:**

```bash
# Scripts also available directly
./scripts/worktrees/teardown-worktrees.sh /path/to/repo
```

## Claude Code Integration

### 1. Install the Techdebt Skill

Drop the skill into your Claude workspace:

```bash
# Copy SKILL.md to your .claude/skills/ directory
cp skills/techdebt/SKILL.md ~/.claude/skills/techdebt.md

# Or create a symlink for auto-updates
ln -s $(pwd)/skills/techdebt/SKILL.md ~/.claude/skills/techdebt.md
```

Now Claude can run techdebt scans automatically at the end of coding sessions!

### 2. Multi-Agent Worktree Pattern

Use worktrees to run multiple Claude agents in parallel without conflicts:

```bash
# Setup parallel worktrees
worktrees ~/Projects/my-app agent-refactor agent-tests agent-docs

# Spawn sub-agents, each in their own worktree
claude spawn --label refactor --workdir ~/Projects/my-app-agent-refactor
claude spawn --label tests --workdir ~/Projects/my-app-agent-tests  
claude spawn --label docs --workdir ~/Projects/my-app-agent-docs
```

Each agent works in isolation. No file conflicts. Clean merges.

## Configuration

### Techdebt Scanner

Create `.techdebt.json` in your project root:

```json
{
  "fileSize": {
    "warning": 300,
    "critical": 500
  },
  "functionSize": {
    "warning": 50,
    "critical": 100
  },
  "duplicateThreshold": 10,
  "excludePaths": [
    "node_modules",
    "dist",
    "build"
  ],
  "autoFix": {
    "unusedImports": true,
    "formatting": false
  }
}
```

### CI/CD Integration

**GitHub Actions:**

```yaml
name: Code Quality
on: [pull_request]

jobs:
  techdebt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npx @unisone/claude-toolkit techdebt
```

**Pre-commit hook:**

```bash
#!/bin/bash
# .git/hooks/pre-commit
npx @unisone/claude-toolkit techdebt --summary
```

## Why This Toolkit?

### The AI Coding Velocity Problem

**AI assistants ship fast. Quality control can't keep up.**

When you have Claude, Cursor, or Codex generating thousands of lines per session:
- **Technical debt accumulates faster than humans can review**
- **Parallel agents create branch chaos** (Agent A conflicts with Agent B)
- **Context switching kills productivity** (branch checkout = rebuild = 5min lost)
- **Type safety erodes** (`any` types slip through, `@ts-ignore` proliferates)
- **Dead code piles up** (commented blocks, failed experiments)

This toolkit solves both problems: **automated quality checks** + **conflict-free parallelization**.

### The Parallel Agents Trend

**Worktrees are becoming the standard for AI-native development:**

- **[Codex macOS app](https://codexmac.com)** — Uses worktrees for multi-agent orchestration
- **[AirOps](https://www.airops.com/)** — Built `worktree-cli` for parallel agent workflows
- **[Medium articles](https://medium.com/search?q=git+worktrees+ai)** — Growing coverage of worktree patterns for AI coding
- **[Boris Cherny (2019)](https://spin.atomicobject.com/2016/06/26/parallelize-development-git-worktrees/)** — Pioneered parallel worktree development

**Why now?** AI agents made parallelization essential. Traditional branch-switching workflows break when you have:
- 3 agents refactoring different modules simultaneously
- Production hotfix needed while feature branch is mid-build
- Experimental refactor running alongside stable development

Git worktrees solve this. This toolkit makes them **trivial to use**.

### Comparison: Techdebt Scanner vs Alternatives

| Feature | claude-toolkit | SonarQube | ESLint | GitHub Advanced Security |
|---------|----------------|-----------|--------|--------------------------|
| **Zero config** | ✅ Works out of box | ❌ Complex setup | ⚠️ Needs config | ❌ Enterprise only |
| **Lightweight** | ✅ Bash script | ❌ Java server | ✅ Node package | ❌ Cloud service |
| **AI-workflow native** | ✅ Built for AI coding | ❌ Traditional CI/CD | ⚠️ General purpose | ❌ Security focus |
| **Duplicate detection** | ✅ `--duplicates` flag | ✅ Advanced | ❌ Separate tool | ❌ Not included |
| **File size limits** | ✅ Built-in | ⚠️ Via custom rules | ❌ Manual | ❌ Not applicable |
| **Dead code detection** | ✅ Commented blocks | ✅ Advanced | ⚠️ Limited | ❌ Not included |
| **Type safety gaps** | ✅ TypeScript focused | ✅ Multi-language | ⚠️ Linting only | ❌ Not included |
| **Dependency audit** | ✅ `npm audit` integration | ✅ Advanced | ❌ Separate tool | ✅ Dependabot |
| **JSON output for CI** | ✅ `--json` flag | ✅ REST API | ⚠️ Custom formatter | ✅ API |
| **Threshold filtering** | ✅ `--threshold` flag | ✅ Quality gates | ❌ Manual | ⚠️ Custom rules |
| **Auto-fix** | ✅ `--fix` flag | ⚠️ Limited | ✅ `--fix` flag | ❌ Manual |
| **Cost** | ✅ Free (MIT) | ⚠️ Free tier limited | ✅ Free (MIT) | ❌ Paid enterprise |

**When to use what:**
- **claude-toolkit** — Daily AI coding workflows, fast feedback, zero setup
- **SonarQube** — Enterprise CI/CD, compliance requirements, multi-repo dashboards
- **ESLint** — JavaScript/TypeScript linting, strict style enforcement
- **GitHub Advanced Security** — Security vulnerability scanning, enterprise compliance

**Combine them!** Use `claude-toolkit` for fast local checks, ESLint for style, SonarQube for team dashboards.

### Real-World Use Cases

1. **Post-session cleanup** — Run `techdebt --fix` after Claude builds features
2. **Parallel bug fixing** — Fix prod issues in worktree B while building in worktree A  
3. **Multi-agent refactoring** — Spawn 3 agents in 3 worktrees, merge when done
4. **PR quality gates** — Fail CI if critical techdebt detected
5. **Code archaeology** — Use analysis worktree for safe exploration
6. **A/B implementation testing** — Try two approaches in parallel worktrees, keep the best

## Documentation

- **Techdebt Scanner**: [`skills/techdebt/SKILL.md`](skills/techdebt/SKILL.md)
- **Worktree Manager**: [`scripts/worktrees/README.md`](scripts/worktrees/README.md)
- **CLI Help**: Run `techdebt --help` or `worktrees --help`

## Requirements

- **Node.js**: >=18
- **Git**: 2.20+ (for worktrees)
- **Bash**: 4.0+ (macOS/Linux)

**Optional (enhanced features):**
- `eslint` — Auto-fix linting issues
- `prettier` — Auto-format code  
- `jq` — JSON parsing for advanced features

## Contributing

Contributions welcome! This is a community-driven toolkit.

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for:
- Development workflow
- Conventional commit guidelines
- Testing procedures
- High-priority contribution areas

**Quick start:**
```bash
# Fork and clone
git clone https://github.com/YOUR-USERNAME/claude-toolkit
cd claude-toolkit

# Make changes
git checkout -b feat/my-feature

# Test using dogfooding!
./skills/techdebt/scripts/scan.sh
./skills/techdebt/scripts/scan.sh --fix

# Commit and PR
git commit -m "feat: add Python support"
git push origin feat/my-feature
```

## Documentation

- **[README.md](README.md)** — Main documentation (this file)
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Contribution guidelines
- **[CHANGELOG.md](CHANGELOG.md)** — Release history
- **[examples/](examples/)** — Usage examples and patterns
  - [CI Integration](examples/ci-integration.md)
  - [Worktree Patterns](examples/worktree-patterns.md)
  - [Sample Output](examples/sample-output.md)
- **Skills:**
  - [Techdebt Scanner](skills/techdebt/SKILL.md)
  - [Worktree Manager](scripts/worktrees/README.md)

## License

MIT © [Alex Zay](https://github.com/unisone)

See [LICENSE](LICENSE) for full text.

---

**Built for the AI coding era. Maintained by humans (for now).**

Questions? Open an issue or find me on [X/Twitter](https://twitter.com/alexzay_).
