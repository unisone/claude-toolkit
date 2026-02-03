#!/usr/bin/env bash
set -euo pipefail

# Techdebt Report Generator - Markdown output for documentation
# Usage: ./report.sh [directory] > techdebt-report.md

TARGET_DIR="${1:-.}"

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
  cat <<EOF
Techdebt Report Generator - Create markdown documentation

USAGE:
  $0 [directory] > output.md

ARGUMENTS:
  directory   Target directory to scan (default: current directory)

EXAMPLES:
  $0 > techdebt-report.md
  $0 /path/to/project > docs/techdebt-$(date +%Y-%m-%d).md
  $0 | pbcopy  # macOS: copy to clipboard

OUTPUT:
  Markdown-formatted techdebt report to stdout
EOF
  exit 0
fi

# Run scan and capture output
SCAN_OUTPUT=$(mktemp)
"$(dirname "$0")/scan.sh" "$TARGET_DIR" 2>&1 | tee "$SCAN_OUTPUT" > /dev/null

# Generate markdown report
cat <<EOF
# Technical Debt Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')  
**Repository:** $TARGET_DIR  
**Scan Tool:** OpenClaw Techdebt Scanner v1.0

---

## Executive Summary

EOF

# Extract summary counts
CRITICAL=$(grep "^Critical:" "$SCAN_OUTPUT" | awk '{print $2}' || echo "0")
HIGH=$(grep "^High:" "$SCAN_OUTPUT" | awk '{print $2}' || echo "0")
MEDIUM=$(grep "^Medium:" "$SCAN_OUTPUT" | awk '{print $2}' || echo "0")
LOW=$(grep "^Low:" "$SCAN_OUTPUT" | awk '{print $2}' || echo "0")
TOTAL=$((CRITICAL + HIGH + MEDIUM + LOW))

cat <<EOF
| Severity | Count | Priority |
|----------|-------|----------|
| 🔴 Critical | $CRITICAL | **Must fix before merge** |
| 🟡 High | $HIGH | Fix this sprint |
| 🔵 Medium | $MEDIUM | Technical debt backlog |
| 🟢 Low | $LOW | Nice to have |
| **Total** | **$TOTAL** | |

EOF

# Health score calculation
HEALTH_SCORE=$((100 - CRITICAL * 20 - HIGH * 5 - MEDIUM * 2 - LOW * 1))
[[ $HEALTH_SCORE -lt 0 ]] && HEALTH_SCORE=0

if [[ $HEALTH_SCORE -ge 90 ]]; then
  HEALTH_LABEL="🟢 Excellent"
elif [[ $HEALTH_SCORE -ge 70 ]]; then
  HEALTH_LABEL="🟡 Good"
elif [[ $HEALTH_SCORE -ge 50 ]]; then
  HEALTH_LABEL="🟠 Fair"
else
  HEALTH_LABEL="🔴 Needs Attention"
fi

cat <<EOF
**Code Health Score:** $HEALTH_SCORE/100 — $HEALTH_LABEL

---

## 🔴 Critical Issues

EOF

# Extract critical issues
if [[ $CRITICAL -gt 0 ]]; then
  awk '/^CRITICAL/,/^HIGH|^MEDIUM|^LOW|^SUMMARY/' "$SCAN_OUTPUT" | \
    sed '1d;$d' | \
    awk '{
      if ($0 ~ /^\[/) {
        if (issue) print issue "\n"
        issue = "### " $0
      } else if ($0 ~ /^[[:space:]]+→/) {
        issue = issue "\n**Fix:** " substr($0, index($0, "→") + 1)
      } else if ($0 != "") {
        issue = issue "\n" $0
      }
    } END { if (issue) print issue }'
else
  echo "_No critical issues found._ ✅"
fi

cat <<EOF

---

## 🟡 High Priority Issues

EOF

# Extract high issues
if [[ $HIGH -gt 0 ]]; then
  awk '/^HIGH/,/^MEDIUM|^LOW|^SUMMARY/' "$SCAN_OUTPUT" | \
    sed '1d;$d' | \
    awk '{
      if ($0 ~ /^\[/) {
        if (issue) print issue "\n"
        issue = "### " $0
      } else if ($0 ~ /^[[:space:]]+→/) {
        issue = issue "\n**Fix:** " substr($0, index($0, "→") + 1)
      } else if ($0 != "") {
        issue = issue "\n" $0
      }
    } END { if (issue) print issue }'
else
  echo "_No high priority issues found._ ✅"
fi

cat <<EOF

---

## 🔵 Medium Priority Issues

EOF

# Extract medium issues (limit to top 10)
if [[ $MEDIUM -gt 0 ]]; then
  awk '/^MEDIUM/,/^LOW|^SUMMARY/' "$SCAN_OUTPUT" | \
    sed '1d;$d' | \
    head -100 | \
    awk '{
      if ($0 ~ /^\[/) {
        if (issue && count < 10) { print issue "\n"; count++ }
        issue = "### " $0
      } else if ($0 ~ /^[[:space:]]+→/) {
        issue = issue "\n**Fix:** " substr($0, index($0, "→") + 1)
      } else if ($0 != "") {
        issue = issue "\n" $0
      }
    } END { if (issue && count < 10) print issue }'
  
  if [[ $MEDIUM -gt 10 ]]; then
    echo ""
    echo "_... and $((MEDIUM - 10)) more medium priority issues._"
  fi
else
  echo "_No medium priority issues found._ ✅"
fi

cat <<EOF

---

## 🟢 Low Priority Issues

EOF

# Extract low issues (summary only)
if [[ $LOW -gt 0 ]]; then
  echo "_Found $LOW low priority issues. Run full scan for details._"
else
  echo "_No low priority issues found._ ✅"
fi

cat <<EOF

---

## 📋 Recommended Actions

EOF

if [[ $CRITICAL -gt 0 ]] || [[ $HIGH -gt 0 ]]; then
  cat <<EOF
1. **Immediate:** Fix $CRITICAL critical issue$([ $CRITICAL -ne 1 ] && echo "s") before merging
2. **This Sprint:** Address $HIGH high priority issue$([ $HIGH -ne 1 ] && echo "s")
3. **Automation:** Run \`./skills/techdebt/scripts/scan.sh --fix\` for safe auto-fixes
4. **Backlog:** Log $MEDIUM medium issues to project tracker
5. **Monitoring:** Re-run scan after fixes to verify improvement

EOF
else
  cat <<EOF
1. ✅ No critical or high priority issues detected
2. 📝 Log $MEDIUM medium issues to technical debt backlog
3. 🔄 Run scan regularly (post-commit, pre-PR)
4. 📊 Track health score over time

EOF
fi

cat <<EOF
---

## 📊 Trend Analysis

| Date | Critical | High | Medium | Low | Health Score |
|------|----------|------|--------|-----|--------------|
| $(date '+%Y-%m-%d') | $CRITICAL | $HIGH | $MEDIUM | $LOW | $HEALTH_SCORE |

_Add previous scans to track improvement over time._

---

## 🛠 Tools Used

- **Scanner:** OpenClaw Techdebt Scanner
- **Checks:** File size, dead code, TODO markers, type safety, dependencies
- **Languages:** TypeScript, JavaScript, Python, Go, Rust, Java
- **Generated:** $(date '+%Y-%m-%d %H:%M:%S')

---

## Next Steps

\`\`\`bash
# Review this report
cat techdebt-report.md

# Fix critical issues
# ... (manual edits)

# Run auto-fix for safe issues
./skills/techdebt/scripts/scan.sh --fix

# Re-scan to verify
./skills/techdebt/scripts/scan.sh

# Commit cleanup
git add .
git commit -m "chore: techdebt cleanup - fixed \$N issues"
\`\`\`

---

**Full scan output:** See \`./skills/techdebt/scripts/scan.sh\` for detailed results.
EOF

# Cleanup
rm -f "$SCAN_OUTPUT"
