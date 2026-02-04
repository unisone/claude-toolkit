#!/usr/bin/env bash
set -euo pipefail

# Techdebt Scanner - Automated code quality detection
# Usage: ./scan.sh [directory] [options]
#
# Exit Codes:
#   0 - No critical or high-priority issues found
#   1 - Critical issues found (must fix before merge)
#   2 - High-priority issues found (fix this sprint)
#   3 - Invalid arguments or configuration error

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
FILE_SIZE_WARNING=300
FILE_SIZE_CRITICAL=500
FUNCTION_SIZE_WARNING=50
DUPLICATE_THRESHOLD=10
FIX_MODE=false
SUMMARY_ONLY=false
JSON_OUTPUT=false
ENABLE_DUPLICATES=false
THRESHOLD_LEVEL=""

# Check for help first
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  cat <<EOF
Techdebt Scanner - Find and fix code quality issues

USAGE:
  $0 [directory] [options]

OPTIONS:
  --fix               Auto-fix safe issues (imports, formatting)
  --summary           Show summary only, skip detailed output
  --json              Output results in JSON format (for CI integration)
  --duplicates        Enable duplicate code detection (slower)
  --threshold LEVEL   Only report issues at or above level (critical|high|medium|low)
  --help              Show this help text

EXAMPLES:
  $0                                    # Scan current directory
  $0 /path/to/project                   # Scan specific directory
  $0 --fix                              # Scan and auto-fix safe issues
  $0 /path/to/project --summary         # Quick summary only
  $0 --json > report.json               # JSON output for CI
  $0 --threshold high                   # Only show high + critical issues
  $0 --duplicates --threshold critical  # Find dupes, only show critical

EXIT CODES:
  0 - No issues at or above threshold
  1 - Critical issues found (must fix before merge)
  2 - High-priority issues found (fix this sprint)
  3 - Invalid arguments or configuration error

THRESHOLD LEVELS:
  critical - Only show critical issues (file size violations, security vulns)
  high     - Show critical + high priority (type gaps, dead code)
  medium   - Show critical + high + medium (TODOs, outdated deps)
  low      - Show all issues (default)
EOF
  exit 0
fi

# Parse arguments
TARGET_DIR="."

# Process positional and flag arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --summary)
      SUMMARY_ONLY=true
      shift
      ;;
    --json)
      JSON_OUTPUT=true
      SUMMARY_ONLY=true  # JSON mode implies no verbose output
      shift
      ;;
    --duplicates)
      ENABLE_DUPLICATES=true
      shift
      ;;
    --threshold)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --threshold requires a level (critical|high|medium|low)"
        exit 3
      fi
      THRESHOLD_LEVEL="${2,,}"  # Convert to lowercase
      if [[ ! "$THRESHOLD_LEVEL" =~ ^(critical|high|medium|low)$ ]]; then
        echo "Error: Invalid threshold level '$2'"
        echo "Valid levels: critical, high, medium, low"
        exit 3
      fi
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 3
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

# Validate target directory
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Directory not found: $TARGET_DIR"
  exit 3
fi

# Load config if exists
CONFIG_FILE="$TARGET_DIR/.techdebt.json"
if [[ -f "$CONFIG_FILE" ]] && command -v jq &> /dev/null; then
  FILE_SIZE_WARNING=$(jq -r '.fileSize.warning // 300' "$CONFIG_FILE")
  FILE_SIZE_CRITICAL=$(jq -r '.fileSize.critical // 500' "$CONFIG_FILE")
  FUNCTION_SIZE_WARNING=$(jq -r '.functionSize.warning // 50' "$CONFIG_FILE")
  DUPLICATE_THRESHOLD=$(jq -r '.duplicateThreshold // 10' "$CONFIG_FILE")
fi

# Issue counters
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

# Exclude patterns
EXCLUDE_PATTERNS=(
  "node_modules"
  "dist"
  "build"
  ".next"
  "coverage"
  ".git"
  "vendor"
  "*.min.js"
  "*.map"
)

# Build exclude arguments for find
EXCLUDE_ARGS=()
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  EXCLUDE_ARGS+=(-path "*/$pattern" -prune -o)
done

# Output header
if [[ "$SUMMARY_ONLY" == false ]]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  TECHDEBT SCAN RESULTS${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "Scanned: $TARGET_DIR"
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
fi

# Temporary files for collecting issues
CRITICAL_FILE=$(mktemp)
HIGH_FILE=$(mktemp)
MEDIUM_FILE=$(mktemp)
LOW_FILE=$(mktemp)

# Cleanup temp files on exit
trap 'rm -f "$CRITICAL_FILE" "$HIGH_FILE" "$MEDIUM_FILE" "$LOW_FILE"' EXIT

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. FILE SIZE CHECK
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_file_sizes() {
  local file_extensions=("*.ts" "*.tsx" "*.js" "*.jsx" "*.py" "*.go" "*.rs" "*.java")
  
  for ext in "${file_extensions[@]}"; do
    while IFS= read -r -d '' file; do
      local lines=$(wc -l < "$file" | tr -d ' ')
      
      if [[ $lines -ge $FILE_SIZE_CRITICAL ]]; then
        echo "[FILE_SIZE] $file ($lines lines)" >> "$CRITICAL_FILE"
        echo "  → File exceeds critical size limit ($FILE_SIZE_CRITICAL lines)" >> "$CRITICAL_FILE"
        echo "  → Split into smaller modules" >> "$CRITICAL_FILE"
        echo "" >> "$CRITICAL_FILE"
        ((CRITICAL_COUNT++))
      elif [[ $lines -ge $FILE_SIZE_WARNING ]]; then
        echo "[FILE_SIZE] $file ($lines lines)" >> "$LOW_FILE"
        echo "  → Approaching size limit (warning: $FILE_SIZE_WARNING lines)" >> "$LOW_FILE"
        echo "  → Consider splitting" >> "$LOW_FILE"
        echo "" >> "$LOW_FILE"
        ((LOW_COUNT++))
      fi
    done < <(find "$TARGET_DIR" "${EXCLUDE_ARGS[@]}" -name "$ext" -type f -print0)
  done
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. DEAD CODE DETECTION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_dead_code() {
  # Find large commented-out blocks (>10 consecutive lines)
  while IFS= read -r -d '' file; do
    awk '
      /^[[:space:]]*\/\// { 
        if (!in_comment) { start=NR; in_comment=1 }
        count++
      }
      !/^[[:space:]]*\/\// {
        if (in_comment && count >= 10) {
          print FILENAME ":" start
          print "  Commented-out block (" count " lines)"
          print "  → Remove dead code"
          print ""
        }
        in_comment=0
        count=0
      }
      END {
        if (in_comment && count >= 10) {
          print FILENAME ":" start
          print "  Commented-out block (" count " lines)"
          print "  → Remove dead code"
          print ""
        }
      }
    ' "$file" >> "$HIGH_FILE" && ((HIGH_COUNT++)) || true
  done < <(find "$TARGET_DIR" "${EXCLUDE_ARGS[@]}" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -type f -print0)

  # Find unreachable code after return (basic pattern)
  grep -rn "return.*;.*[^/]" "$TARGET_DIR" \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build 2>/dev/null | \
    grep -v "return.*return" | head -20 | while read -r line; do
      echo "[DEAD_CODE] $line" >> "$HIGH_FILE"
      echo "  → Possible unreachable code after return" >> "$HIGH_FILE"
      echo "" >> "$HIGH_FILE"
      ((HIGH_COUNT++))
    done || true
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. TODO/FIXME/HACK AUDIT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_technical_debt_markers() {
  local markers="TODO|FIXME|HACK|XXX|OPTIMIZE|BUG"
  
  grep -rn -E "$markers" "$TARGET_DIR" \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
    --include="*.py" --include="*.go" --include="*.rs" --include="*.java" \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build 2>/dev/null | \
    while IFS=: read -r file line content; do
      # Try to get age via git blame
      local age=""
      if command -v git &> /dev/null && git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
        local blame_date=$(git -C "$(dirname "$file")" blame -L "$line,$line" --porcelain "$(basename "$file")" 2>/dev/null | grep "^author-time" | awk '{print $2}')
        if [[ -n "$blame_date" ]]; then
          local days_ago=$(( ( $(date +%s) - blame_date ) / 86400 ))
          age=" (${days_ago}d old)"
        fi
      fi
      
      echo "[TODO] $file:$line$age" >> "$MEDIUM_FILE"
      echo "  $content" >> "$MEDIUM_FILE"
      echo "" >> "$MEDIUM_FILE"
      ((MEDIUM_COUNT++))
    done || true
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. TYPE SAFETY GAPS (TypeScript)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_type_safety() {
  # Find 'any' types
  grep -rn ": any" "$TARGET_DIR" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build 2>/dev/null | \
    head -50 | while IFS=: read -r file line content; do
      echo "[TYPE_GAP] $file:$line" >> "$HIGH_FILE"
      echo "  Uses 'any' type: $content" >> "$HIGH_FILE"
      echo "  → Add explicit type annotation" >> "$HIGH_FILE"
      echo "" >> "$HIGH_FILE"
      ((HIGH_COUNT++))
    done || true

  # Find @ts-ignore and @ts-expect-error
  grep -rn "@ts-ignore\|@ts-expect-error" "$TARGET_DIR" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build 2>/dev/null | \
    while IFS=: read -r file line content; do
      echo "[TYPE_GAP] $file:$line" >> "$HIGH_FILE"
      echo "  Type check suppression: $content" >> "$HIGH_FILE"
      echo "  → Fix underlying type issue" >> "$HIGH_FILE"
      echo "" >> "$HIGH_FILE"
      ((HIGH_COUNT++))
    done || true

  # Find functions missing return types (basic heuristic)
  grep -rn "function \|const .* = (" "$TARGET_DIR" \
    --include="*.ts" --include="*.tsx" \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build 2>/dev/null | \
    grep -v ": .*=>" | grep -v "void\|Promise\|string\|number\|boolean" | \
    head -20 | while IFS=: read -r file line content; do
      echo "[TYPE_GAP] $file:$line" >> "$MEDIUM_FILE"
      echo "  Possible missing return type: $content" >> "$MEDIUM_FILE"
      echo "  → Add explicit return type" >> "$MEDIUM_FILE"
      echo "" >> "$MEDIUM_FILE"
      ((MEDIUM_COUNT++))
    done || true
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. DEPENDENCY CHECK
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_dependencies() {
  if [[ ! -f "$TARGET_DIR/package.json" ]]; then
    return
  fi

  cd "$TARGET_DIR" || return

  # Check for outdated dependencies
  if command -v npm &> /dev/null; then
    local outdated=$(npm outdated --json 2>/dev/null || echo "{}")
    if [[ "$outdated" != "{}" ]] && command -v jq &> /dev/null; then
      local count=$(echo "$outdated" | jq 'length')
      if [[ $count -gt 0 ]]; then
        echo "[DEPENDENCY] package.json" >> "$MEDIUM_FILE"
        echo "  $count outdated dependencies" >> "$MEDIUM_FILE"
        echo "  → Run: npm outdated && npm update" >> "$MEDIUM_FILE"
        echo "" >> "$MEDIUM_FILE"
        ((MEDIUM_COUNT++))
      fi
    fi

    # Check for security vulnerabilities
    local audit=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{"total":0}}}')
    if command -v jq &> /dev/null; then
      local vuln_count=$(echo "$audit" | jq -r '.metadata.vulnerabilities.total // 0')
      if [[ $vuln_count -gt 0 ]]; then
        echo "[DEPENDENCY] package.json" >> "$CRITICAL_FILE"
        echo "  $vuln_count security vulnerabilities" >> "$CRITICAL_FILE"
        echo "  → Run: npm audit fix" >> "$CRITICAL_FILE"
        echo "" >> "$CRITICAL_FILE"
        ((CRITICAL_COUNT++))
      fi
    fi
  fi

  cd - > /dev/null || true
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. DUPLICATE CODE DETECTION
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_duplicates() {
  # Simple hash-based duplicate detection for functions
  # Look for functions >10 lines that appear multiple times
  
  while IFS= read -r -d '' file; do
    # Extract functions (very basic heuristic)
    awk '
      /^[[:space:]]*(function|const|let|var).*{/ {
        start=NR
        func=$0
        brace_count=1
      }
      brace_count > 0 {
        if (NR > start) func = func "\n" $0
        brace_count += gsub(/{/, "{")
        brace_count -= gsub(/}/, "}")
        if (brace_count == 0 && NR - start >= '$DUPLICATE_THRESHOLD') {
          print FILENAME ":" start ":" NR ":" func
          func=""
        }
      }
    ' "$file" 2>/dev/null
  done < <(find "$TARGET_DIR" "${EXCLUDE_ARGS[@]}" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -type f -print0) | \
  awk -F: '{
    hash = $4
    gsub(/[[:space:]]/, "", hash)
    if (seen[hash]) {
      print "[DUPLICATE] " $1 ":" $2 "-" $3
      print "  Similar to " seen[hash]
      print "  → Extract to shared utility"
      print ""
    } else {
      seen[hash] = $1 ":" $2 "-" $3
    }
  }' >> "$CRITICAL_FILE" && ((CRITICAL_COUNT++)) || true
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# RUN ALL CHECKS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$SUMMARY_ONLY" == false ]]; then
  echo "Running checks..."
  echo ""
fi

check_file_sizes
check_dead_code
check_technical_debt_markers
check_type_safety
check_dependencies

# Only run duplicate detection if explicitly enabled
if [[ "$ENABLE_DUPLICATES" == true ]]; then
  check_duplicates
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OUTPUT RESULTS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$SUMMARY_ONLY" == false ]]; then
  # Critical issues
  if [[ $CRITICAL_COUNT -gt 0 ]]; then
    echo -e "${RED}CRITICAL (must fix before merge)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$CRITICAL_FILE"
  fi

  # High priority issues
  if [[ $HIGH_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}HIGH (fix this sprint)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$HIGH_FILE"
  fi

  # Medium priority issues
  if [[ $MEDIUM_COUNT -gt 0 ]]; then
    echo -e "${BLUE}MEDIUM (technical debt)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$MEDIUM_FILE" | head -30
    if [[ $(wc -l < "$MEDIUM_FILE") -gt 30 ]]; then
      echo "... and $((MEDIUM_COUNT - 30)) more"
      echo ""
    fi
  fi

  # Low priority issues
  if [[ $LOW_COUNT -gt 0 ]]; then
    echo -e "${GREEN}LOW (nice to have)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cat "$LOW_FILE" | head -20
    if [[ $(wc -l < "$LOW_FILE") -gt 20 ]]; then
      echo "... and $((LOW_COUNT - 20)) more"
      echo ""
    fi
  fi
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# APPLY THRESHOLD FILTER
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# If threshold is set, zero out counts below threshold
if [[ -n "$THRESHOLD_LEVEL" ]]; then
  case "$THRESHOLD_LEVEL" in
    critical)
      HIGH_COUNT=0
      MEDIUM_COUNT=0
      LOW_COUNT=0
      ;;
    high)
      MEDIUM_COUNT=0
      LOW_COUNT=0
      ;;
    medium)
      LOW_COUNT=0
      ;;
    low)
      # Show all (default)
      ;;
  esac
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OUTPUT JSON OR SUMMARY
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [[ "$JSON_OUTPUT" == true ]]; then
  # JSON output for CI integration
  cat <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "scannedPath": "$TARGET_DIR",
  "summary": {
    "critical": $CRITICAL_COUNT,
    "high": $HIGH_COUNT,
    "medium": $MEDIUM_COUNT,
    "low": $LOW_COUNT,
    "total": $((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))
  },
  "threshold": "${THRESHOLD_LEVEL:-none}",
  "duplicatesEnabled": $ENABLE_DUPLICATES,
  "exitCode": $(( CRITICAL_COUNT > 0 ? 1 : HIGH_COUNT > 0 ? 2 : 0 ))
}
EOF
else
  # Human-readable summary
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  SUMMARY${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}Critical:${NC} $CRITICAL_COUNT"
  echo -e "${YELLOW}High:${NC}     $HIGH_COUNT"
  echo -e "${BLUE}Medium:${NC}   $MEDIUM_COUNT"
  echo -e "${GREEN}Low:${NC}      $LOW_COUNT"
  echo "Total:    $((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT)) issues"
  [[ -n "$THRESHOLD_LEVEL" ]] && echo "Threshold: $THRESHOLD_LEVEL"
  echo ""
fi

# Recommended actions (skip in JSON mode)
if [[ "$JSON_OUTPUT" == false ]] && ([[ $CRITICAL_COUNT -gt 0 ]] || [[ $HIGH_COUNT -gt 0 ]]); then
  echo -e "${BLUE}RECOMMENDED ACTIONS${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  [[ $CRITICAL_COUNT -gt 0 ]] && echo "1. Fix critical issues before merging"
  [[ $HIGH_COUNT -gt 0 ]] && echo "2. Address high-priority issues this sprint"
  echo "3. Run auto-fix: $0 --fix"
  echo "4. Run with duplicates: $0 --duplicates"
  echo "5. CI integration: $0 --json --threshold high"
  echo ""
fi

# Auto-fix mode (skip in JSON mode)
if [[ "$FIX_MODE" == true ]] && [[ "$JSON_OUTPUT" == false ]]; then
  echo "Auto-fix mode enabled..."
  
  # Fix with eslint if available
  if command -v eslint &> /dev/null; then
    echo "Running eslint --fix..."
    find "$TARGET_DIR" "${EXCLUDE_ARGS[@]}" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -type f -exec eslint --fix {} + 2>/dev/null || true
  fi

  # Fix with prettier if available
  if command -v prettier &> /dev/null; then
    echo "Running prettier --write..."
    find "$TARGET_DIR" "${EXCLUDE_ARGS[@]}" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) -type f -exec prettier --write {} + 2>/dev/null || true
  fi

  echo "Auto-fix complete. Re-run scan to verify."
fi

# Exit code based on severity
if [[ $CRITICAL_COUNT -gt 0 ]]; then
  exit 1
elif [[ $HIGH_COUNT -gt 0 ]]; then
  exit 2
else
  exit 0
fi
