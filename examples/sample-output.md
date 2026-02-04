# Sample Techdebt Scanner Output

## Basic Scan

```bash
$ techdebt ~/Projects/my-app
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TECHDEBT SCAN RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scanned: /Users/dev/Projects/my-app
Date: 2025-02-03 22:30:15

Running checks...

CRITICAL (must fix before merge)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[FILE_SIZE] src/components/Dashboard.tsx (547 lines)
  → File exceeds critical size limit (500 lines)
  → Split into smaller components

[FILE_SIZE] src/utils/helpers.ts (623 lines)
  → File exceeds critical size limit (500 lines)
  → Split into smaller modules

[DEPENDENCY] package.json
  3 security vulnerabilities
  → Run: npm audit fix

HIGH (fix this sprint)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[TYPE_GAP] src/models/user.ts:34
  Uses 'any' type: export function processUser(data: any) {
  → Add explicit type annotation

[TYPE_GAP] src/components/Form.tsx:89
  Type check suppression: // @ts-ignore
  → Fix underlying type issue

[DEAD_CODE] src/legacy/oldAuth.ts:45
  Commented-out block (15 lines)
  → Remove dead code

[TYPE_GAP] src/api/client.ts:102
  Possible missing return type: async function fetchData(url) {
  → Add explicit return type

MEDIUM (technical debt)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[TODO] src/components/UserProfile.tsx:67 (12d old)
  // TODO: Add loading state
  
[TODO] src/utils/api.ts:23 (45d old)
  // FIXME: Handle edge case for null values
  
[TODO] src/pages/checkout.tsx:156 (3d old)
  // HACK: Temporary workaround for payment gateway issue

[DEPENDENCY] package.json
  7 outdated dependencies
  → Run: npm outdated && npm update

... and 4 more

LOW (nice to have)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[FILE_SIZE] src/components/Header.tsx (312 lines)
  → Approaching size limit (warning: 300 lines)
  → Consider splitting

[FILE_SIZE] src/hooks/useAuth.ts (345 lines)
  → Approaching size limit (warning: 300 lines)
  → Consider splitting

... and 18 more

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Critical: 3
High:     4
Medium:   8
Low:      20
Total:    35 issues

RECOMMENDED ACTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Fix critical issues before merging
2. Address high-priority issues this sprint
3. Run auto-fix: ./skills/techdebt/scripts/scan.sh --fix
4. Run with duplicates: ./skills/techdebt/scripts/scan.sh --duplicates
5. CI integration: ./skills/techdebt/scripts/scan.sh --json --threshold high
```

## Summary Mode

```bash
$ techdebt ~/Projects/my-app --summary
```

```
Running checks...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Critical: 3
High:     4
Medium:   8
Low:      20
Total:    35 issues

RECOMMENDED ACTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Fix critical issues before merging
2. Address high-priority issues this sprint
3. Run auto-fix: ./skills/techdebt/scripts/scan.sh --fix
4. Run with duplicates: ./skills/techdebt/scripts/scan.sh --duplicates
5. CI integration: ./skills/techdebt/scripts/scan.sh --json --threshold high
```

## JSON Output

```bash
$ techdebt ~/Projects/my-app --json
```

```json
{
  "timestamp": "2025-02-03T22:30:15Z",
  "scannedPath": "/Users/dev/Projects/my-app",
  "summary": {
    "critical": 3,
    "high": 4,
    "medium": 8,
    "low": 20,
    "total": 35
  },
  "threshold": "none",
  "duplicatesEnabled": false,
  "exitCode": 1
}
```

## Threshold Filtering

```bash
$ techdebt ~/Projects/my-app --threshold high --summary
```

```
Running checks...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Critical: 3
High:     4
Medium:   0
Low:      0
Total:    7 issues
Threshold: high

RECOMMENDED ACTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Fix critical issues before merging
2. Address high-priority issues this sprint
3. Run auto-fix: ./skills/techdebt/scripts/scan.sh --fix
4. Run with duplicates: ./skills/techdebt/scripts/scan.sh --duplicates
5. CI integration: ./skills/techdebt/scripts/scan.sh --json --threshold high
```

## With Duplicates Enabled

```bash
$ techdebt ~/Projects/my-app --duplicates --threshold critical
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TECHDEBT SCAN RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scanned: /Users/dev/Projects/my-app
Date: 2025-02-03 22:35:42

Running checks...

CRITICAL (must fix before merge)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[FILE_SIZE] src/components/Dashboard.tsx (547 lines)
  → File exceeds critical size limit (500 lines)
  → Split into smaller components

[FILE_SIZE] src/utils/helpers.ts (623 lines)
  → File exceeds critical size limit (500 lines)
  → Split into smaller modules

[DEPENDENCY] package.json
  3 security vulnerabilities
  → Run: npm audit fix

[DUPLICATE] src/utils/validation.ts:45-67
  Similar to src/helpers/validators.ts:23-45
  → Extract to shared utility

[DUPLICATE] src/components/UserCard.tsx:89-112
  Similar to src/components/ProfileCard.tsx:56-79
  → Extract to shared component

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Critical: 5
High:     0
Medium:   0
Low:      0
Total:    5 issues
Threshold: critical

RECOMMENDED ACTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Fix critical issues before merging
3. Run auto-fix: ./skills/techdebt/scripts/scan.sh --fix
4. Run with duplicates: ./skills/techdebt/scripts/scan.sh --duplicates
5. CI integration: ./skills/techdebt/scripts/scan.sh --json --threshold high
```

## Auto-Fix Mode

```bash
$ techdebt ~/Projects/my-app --fix
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TECHDEBT SCAN RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Scanned: /Users/dev/Projects/my-app
Date: 2025-02-03 22:40:18

Running checks...

... (scan results) ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Critical: 3
High:     4
Medium:   8
Low:      20
Total:    35 issues

Auto-fix mode enabled...
Running eslint --fix...
✓ Fixed 12 linting issues

Running prettier --write...
✓ Formatted 45 files

Auto-fix complete. Re-run scan to verify.
```

## Exit Codes

### Clean Code (Exit 0)

```bash
$ techdebt ~/Projects/clean-app
$ echo $?
0
```

### Critical Issues (Exit 1)

```bash
$ techdebt ~/Projects/my-app
$ echo $?
1
```

### High Priority Issues (Exit 2)

```bash
$ techdebt ~/Projects/my-app --threshold high
$ echo $?
2
```

### Configuration Error (Exit 3)

```bash
$ techdebt ~/Projects/nonexistent
Error: Directory not found: ~/Projects/nonexistent
$ echo $?
3
```

## Integration with Other Tools

### With jq for Parsing

```bash
$ techdebt ~/Projects/my-app --json | jq '.summary'
{
  "critical": 3,
  "high": 4,
  "medium": 8,
  "low": 20,
  "total": 35
}

$ techdebt ~/Projects/my-app --json | jq -r '.summary.critical'
3

$ techdebt ~/Projects/my-app --json | jq 'select(.summary.critical > 0)'
{
  "timestamp": "2025-02-03T22:30:15Z",
  "scannedPath": "/Users/dev/Projects/my-app",
  "summary": {...},
  "threshold": "none",
  "duplicatesEnabled": false,
  "exitCode": 1
}
```

### With fzf for Interactive Navigation

```bash
# Search techdebt issues interactively
$ techdebt ~/Projects/my-app 2>&1 | grep -E '\[.*\]' | fzf --preview 'echo {}'
```

### Piped to Slack/Discord

```bash
#!/bin/bash
RESULT=$(techdebt ~/Projects/my-app --summary --json)
CRITICAL=$(echo "$RESULT" | jq -r '.summary.critical')

if [ "$CRITICAL" -gt 0 ]; then
  curl -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"text\": \"⚠️ Critical techdebt detected: $CRITICAL issues\"}"
fi
```
