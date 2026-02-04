#!/usr/bin/env bash
set -euo pipefail

# Git Worktree Setup - Create parallel development environments
# Based on Boris Cherny's parallel worktree pattern
# Usage: ./setup-worktrees.sh <repo-path> [worktree-names...]

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Help text
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  cat <<EOF
Git Worktree Setup - Create parallel development environments

USAGE:
  $0 <repo-path> [worktree-names...]
  $0 --clean <repo-path> [--force]

ARGUMENTS:
  repo-path          Path to git repository (will be main worktree)
  worktree-names     Names for additional worktrees (default: feature-a feature-b analysis)

OPTIONS:
  --clean            Teardown/remove all worktrees (calls teardown script)
  --force            Skip confirmation prompts (with --clean)
  --help             Show this help text

EXAMPLES:
  # Default setup (3 worktrees: feature-a, feature-b, analysis)
  $0 ~/Projects/my-app

  # Custom worktree names
  $0 ~/Projects/my-app backend frontend testing

  # Single additional worktree
  $0 ~/Projects/my-app experiment

  # Clean up all worktrees
  $0 --clean ~/Projects/my-app

  # Force cleanup without prompts
  $0 --clean ~/Projects/my-app --force

WHAT IT DOES:
  1. Creates parallel worktrees in parent directory
  2. Each worktree gets its own branch off main
  3. Generates shell aliases for quick navigation
  4. Preserves main repo as "read-only" reference

DIRECTORY STRUCTURE:
  ~/Projects/
    my-app/              # Main worktree (read-only)
    my-app-feature-a/    # Worktree 1
    my-app-feature-b/    # Worktree 2
    my-app-analysis/     # Worktree 3

SHELL ALIASES:
  za  # cd to first worktree
  zb  # cd to second worktree
  zc  # cd to third worktree

WHY WORKTREES:
  - Isolated contexts: No branch switching contamination
  - Parallel work: Multiple features simultaneously
  - Clean comparison: Analysis worktree for reference
  - Sub-agent friendly: Each agent gets own worktree

EOF
  exit 0
fi

# Check for --clean mode first
if [[ "${1:-}" == "--clean" ]]; then
  shift
  TEARDOWN_SCRIPT="$(dirname "$0")/teardown-worktrees.sh"
  
  if [[ ! -f "$TEARDOWN_SCRIPT" ]]; then
    echo "Error: Teardown script not found at: $TEARDOWN_SCRIPT"
    exit 1
  fi
  
  # Pass remaining arguments to teardown script
  exec "$TEARDOWN_SCRIPT" "$@"
fi

# Validate arguments
if [[ $# -lt 1 ]]; then
  echo "Error: Repository path required"
  echo "Usage: $0 <repo-path> [worktree-names...]"
  echo "       $0 --clean <repo-path> [--force]"
  echo "Run '$0 --help' for more information"
  exit 1
fi

REPO_PATH="$1"
shift

# Default worktree names
DEFAULT_WORKTREES=("feature-a" "feature-b" "analysis")
WORKTREE_NAMES=("${@:-${DEFAULT_WORKTREES[@]}}")

# Resolve absolute path
REPO_PATH=$(cd "$REPO_PATH" && pwd)
REPO_NAME=$(basename "$REPO_PATH")
PARENT_DIR=$(dirname "$REPO_PATH")

# Validate it's a git repo
if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "Error: $REPO_PATH is not a git repository"
  echo "Initialize a git repository first: git init"
  exit 1
fi

# Check for uncommitted changes in main repo
cd "$REPO_PATH"
if [[ -n "$(git status --porcelain)" ]]; then
  echo -e "${YELLOW}⚠ Warning: Uncommitted changes in main repository${NC}"
  git status --short
  echo ""
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Commit or stash changes first."
    exit 1
  fi
  echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Git Worktree Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Repository: $REPO_PATH"
echo "Worktrees: ${WORKTREE_NAMES[*]}"
echo ""

# Get default branch (main or master)
cd "$REPO_PATH"
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Ensure we're on the default branch
if [[ "$(git branch --show-current)" != "$DEFAULT_BRANCH" ]]; then
  echo "Switching main repo to $DEFAULT_BRANCH..."
  git checkout "$DEFAULT_BRANCH" 2>/dev/null || {
    echo "Warning: Could not switch to $DEFAULT_BRANCH, using current branch"
    DEFAULT_BRANCH=$(git branch --show-current)
  }
fi

# Pull latest
echo "Pulling latest changes..."
git pull --quiet 2>/dev/null || echo "Warning: Could not pull (may not have remote)"

echo ""
echo -e "${GREEN}Creating worktrees...${NC}"
echo ""

# Track created worktrees for alias generation
CREATED_WORKTREES=()

# Create each worktree
for worktree_name in "${WORKTREE_NAMES[@]}"; do
  WORKTREE_PATH="$PARENT_DIR/${REPO_NAME}-${worktree_name}"
  BRANCH_NAME="worktree/$worktree_name"
  
  # Check if worktree already exists
  if [[ -d "$WORKTREE_PATH" ]]; then
    echo -e "${YELLOW}⚠ Worktree already exists: $WORKTREE_PATH${NC}"
    echo "   Skipping..."
    continue
  fi

  # Check if branch already exists
  if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo -e "${YELLOW}⚠ Branch already exists: $BRANCH_NAME${NC}"
    echo "   Using existing branch..."
  else
    echo "Creating branch: $BRANCH_NAME"
  fi

  # Create worktree
  echo "Creating worktree: $WORKTREE_PATH"
  git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$DEFAULT_BRANCH" 2>/dev/null || \
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>/dev/null || {
      echo -e "${YELLOW}⚠ Failed to create worktree: $worktree_name${NC}"
      continue
    }

  CREATED_WORKTREES+=("$WORKTREE_PATH")
  echo -e "${GREEN}✓ Created: $WORKTREE_PATH${NC}"
  echo ""
done

# Generate shell aliases
if [[ ${#CREATED_WORKTREES[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No new worktrees created.${NC}"
  echo ""
  echo "Existing worktrees:"
  git worktree list
  exit 0
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Shell Aliases${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Add these to your ~/.zshrc or ~/.bashrc:"
echo ""

ALIAS_LETTERS=("a" "b" "c" "d" "e" "f" "g" "h")
for i in "${!CREATED_WORKTREES[@]}"; do
  WORKTREE_PATH="${CREATED_WORKTREES[$i]}"
  ALIAS_LETTER="${ALIAS_LETTERS[$i]}"
  echo "alias z$ALIAS_LETTER='cd $WORKTREE_PATH'"
done

echo ""
echo "Then reload your shell:"
echo "  source ~/.zshrc"
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
git worktree list
echo ""

echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Add aliases to ~/.zshrc"
echo "  2. Start working in parallel worktrees"
echo "  3. Use main repo ($REPO_PATH) as read-only reference"
echo ""
echo "To clean up later:"
echo "  $(dirname "$0")/teardown-worktrees.sh $REPO_PATH"
echo ""
