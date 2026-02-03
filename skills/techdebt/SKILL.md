# Techdebt Cleanup Skill

Scan and fix code quality issues at the end of any coding session.

## Purpose

Automated technical debt detection across:
- Duplicated code patterns
- Dead/unreachable code
- Technical debt markers (TODO/FIXME/HACK)
- Type safety gaps
- Dependency hygiene
- File size violations

## Usage

```bash
# Scan current directory
./skills/techdebt/scripts/scan.sh

# Scan specific directory
./skills/techdebt/scripts/scan.sh /path/to/project

# Auto-fix safe issues (unused imports, formatting)
./skills/techdebt/scripts/scan.sh --fix

# Generate markdown report
./skills/techdebt/scripts/report.sh /path/to/project > techdebt-report.md
```

## What It Detects

### 1. Duplicated Code (CRITICAL)
- Functions with identical/similar bodies (>10 lines)
- Copy-pasted blocks (exact matches >5 lines)
- Repeated patterns that should be extracted

**Detection:** Hash-based analysis of code blocks

### 2. Dead Code (HIGH)
- Unused imports
- Unreachable code after returns
- Commented-out blocks (>10 lines)
- Unused functions/variables (if linter available)

**Detection:** AST analysis + grep patterns

### 3. TODO/FIXME/HACK Audit (MEDIUM)
- All technical debt markers with context
- Grouped by file and priority
- Age estimation (via git blame if available)

**Detection:** `grep -rn "TODO\|FIXME\|HACK\|XXX\|OPTIMIZE"`

### 4. Type Safety Gaps (HIGH)
- `any` types in TypeScript
- Missing return types
- Untyped parameters
- `@ts-ignore` / `@ts-expect-error`

**Detection:** Regex patterns + TypeScript compiler warnings

### 5. Dependency Check (MEDIUM)
- Outdated dependencies (`npm outdated`)
- Unused dependencies (`depcheck`)
- Security vulnerabilities (`npm audit`)

**Detection:** npm/yarn tooling

### 6. File Size (LOW)
- Files >300 lines
- Files >500 lines (critical)
- Functions >50 lines

**Detection:** Line counting with context

## Output Format

```
TECHDEBT SCAN RESULTS
=====================
Scanned: /path/to/project
Date: 2026-02-02 17:11:23

CRITICAL (must fix before merge)
---------------------------------
[DUPLICATE] src/utils/validator.ts:45-67
  Identical to src/helpers/validation.ts:23-45
  → Extract to shared utility

[FILE_SIZE] src/components/Dashboard.tsx (547 lines)
  → Split into smaller components

HIGH (fix this sprint)
----------------------
[DEAD_CODE] src/api/old-client.ts:12
  Unused import: import { deprecated } from 'old-lib'
  → Remove import

[TYPE_GAP] src/models/user.ts:34
  Function 'processData' missing return type
  → Add explicit return type

MEDIUM (technical debt)
-----------------------
[TODO] src/features/auth/login.ts:89
  TODO: Add rate limiting
  Age: 23 days

[DEPENDENCY] package.json
  5 outdated dependencies
  → Run: npm update

LOW (nice to have)
------------------
[FILE_SIZE] src/utils/helpers.ts (312 lines)
  Approaching size limit
  → Consider splitting

SUMMARY
-------
Critical: 2
High: 3
Medium: 7
Low: 4
Total: 16 issues

RECOMMENDED ACTIONS
-------------------
1. Fix critical duplicated code in validator/validation
2. Split Dashboard component
3. Run auto-fix: ./skills/techdebt/scripts/scan.sh --fix
4. Address type safety gaps
5. Update dependencies
```

## Auto-Fix Capabilities

Safe auto-fixes (with `--fix` flag):
- Remove unused imports (via linter)
- Format code (via prettier/eslint)
- Fix simple type annotations
- Remove trailing whitespace
- Remove commented-out blocks (if confirmed safe)

Unsafe fixes (manual only):
- Duplicated code extraction
- File splitting
- Refactoring logic

## Integration

### Post-Commit Hook
```bash
#!/bin/bash
# .git/hooks/post-commit
./skills/techdebt/scripts/scan.sh --summary
```

### CI/CD Gate
```yaml
# .github/workflows/techdebt.yml
- name: Techdebt Check
  run: |
    ./skills/techdebt/scripts/scan.sh
    if [ $? -gt 0 ]; then
      echo "Critical tech debt detected"
      exit 1
    fi
```

### Agent Workflow
```markdown
At end of coding session:
1. Run techdebt scan
2. Fix critical + high issues
3. Log medium issues to backlog
4. Commit fixes separately
```

## Dependencies

**Required:**
- bash (4.0+)
- grep, find, wc (standard POSIX)
- jq (JSON parsing)
- git (for blame/age analysis)

**Optional (enhanced features):**
- node/npx (dependency checks)
- eslint/typescript (type analysis)
- depcheck (unused deps)
- cloc (advanced metrics)

## Configuration

Create `.techdebt.json` in project root:

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
    "build",
    ".next",
    "coverage"
  ],
  "autoFix": {
    "unusedImports": true,
    "formatting": false,
    "commentedCode": false
  }
}
```

## Limitations

- **Language support:** Best for TypeScript/JavaScript; basic support for Python/Go/Rust
- **Duplicate detection:** Hash-based, may miss semantic duplicates
- **Dead code:** Requires static analysis; may miss dynamic imports
- **False positives:** Review before bulk fixing

## Best Practices

1. **Run frequently:** After each feature, before each PR
2. **Prioritize critical:** Don't let perfect be enemy of good
3. **Track trends:** Log issue counts over time
4. **Team calibration:** Review false positives together
5. **Automate safe fixes:** Let tools handle formatting/imports
6. **Manual review unsafe:** Duplicates and refactoring need human judgment

## Agent Instructions

When running techdebt cleanup:

1. **Scan phase:**
   ```bash
   cd /path/to/repo
   ./skills/techdebt/scripts/scan.sh > /tmp/techdebt-scan.txt
   ```

2. **Review critical issues:**
   - Read output
   - Prioritize by severity
   - Check if issues block merge

3. **Auto-fix safe issues:**
   ```bash
   ./skills/techdebt/scripts/scan.sh --fix
   ```

4. **Manual fixes:**
   - Address duplicated code
   - Split large files
   - Add missing types
   - Update dependencies

5. **Generate report:**
   ```bash
   ./skills/techdebt/scripts/report.sh > docs/techdebt-$(date +%Y-%m-%d).md
   ```

6. **Commit:**
   ```bash
   git add .
   git commit -m "chore: techdebt cleanup - fixed N issues"
   ```

## Examples

### Scenario: Post-Feature Cleanup

```bash
# 1. Finish feature work
git add src/features/new-feature
git commit -m "feat: add new feature"

# 2. Run techdebt scan
./skills/techdebt/scripts/scan.sh

# Output shows:
# - 2 critical (duplicated validation logic)
# - 3 high (missing types)
# - 5 medium (TODOs)

# 3. Fix critical duplicates
# Extract shared validator.ts

# 4. Auto-fix types and imports
./skills/techdebt/scripts/scan.sh --fix

# 5. Commit cleanup
git commit -m "chore: techdebt - extract validator, add types"

# 6. Log remaining issues
./skills/techdebt/scripts/report.sh >> memory/techdebt-backlog.md
```

### Scenario: PR Review

```bash
# Before submitting PR, ensure clean state
./skills/techdebt/scripts/scan.sh --summary

# If critical issues exist, fix before PR
# Medium/Low can be tracked as follow-up issues
```

## See Also

- `skills/dev-workflow/SKILL.md` - Development workflow
- `skills/reflect-learn/SKILL.md` - Learning from errors
- `.learnings/ERRORS.md` - Historical mistakes to avoid
