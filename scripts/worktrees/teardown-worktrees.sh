#!/usr/bin/env bash
set -euo pipefail

# Git Worktree Teardown - Clean up parallel worktrees
# Usage: ./teardown-worktrees.sh <repo-path> [--force]

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Help text
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  cat <<EOF
Git Worktree Teardown - Clean up parallel worktrees

USAGE:
  $0 <repo-path> [--force]

ARGUMENTS:
  repo-path   Path to main git repository
  --force     Skip confirmation prompts

EXAMPLES:
  # Interactive cleanup
  $0 ~/Projects/my-app

  # Force cleanup without prompts
  $0 ~/Projects/my-app --force

WHAT IT DOES:
  1. Lists all worktrees for the repository
  2. Confirms deletion (unless --force)
  3. Removes each worktree directory
  4. Removes worktree branches (with confirmation)
  5. Cleans up git worktree metadata

SAFE GUARDS:
  - Checks for uncommitted changes
  - Confirms before deleting each worktree
  - Offers to keep branches for later use
  - Does not touch main repository

EOF
  exit 0
fi

# Validate arguments
if [[ $# -lt 1 ]]; then
  echo "Error: Repository path required"
  echo "Usage: $0 <repo-path> [--force]"
  echo "Run '$0 --help' for more information"
  exit 1
fi

REPO_PATH="$1"
FORCE_MODE=false

if [[ "${2:-}" == "--force" ]]; then
  FORCE_MODE=true
fi

# Resolve absolute path
REPO_PATH=$(cd "$REPO_PATH" && pwd)
REPO_NAME=$(basename "$REPO_PATH")

# Validate it's a git repo
if [[ ! -d "$REPO_PATH/.git" ]]; then
  echo "Error: $REPO_PATH is not a git repository"
  exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Git Worktree Teardown${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Repository: $REPO_PATH"
echo ""

cd "$REPO_PATH"

# Get list of worktrees (excluding main)
WORKTREES=$(git worktree list --porcelain | grep "^worktree" | awk '{print $2}' | grep -v "^$REPO_PATH$" || true)

if [[ -z "$WORKTREES" ]]; then
  echo -e "${GREEN}No worktrees found to clean up.${NC}"
  echo ""
  git worktree list
  exit 0
fi

echo "Found worktrees:"
echo ""
git worktree list
echo ""

# Confirm deletion
if [[ "$FORCE_MODE" == false ]]; then
  echo -e "${YELLOW}⚠ This will remove all worktrees and optionally delete their branches.${NC}"
  read -p "Continue? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  echo ""
fi

# Track deleted worktrees
DELETED_COUNT=0
BRANCHES_TO_DELETE=()

# Process each worktree
while IFS= read -r worktree_path; do
  if [[ -z "$worktree_path" ]]; then
    continue
  fi

  WORKTREE_NAME=$(basename "$worktree_path")
  
  echo -e "${BLUE}Processing: $WORKTREE_NAME${NC}"
  echo "Path: $worktree_path"
  
  # Get branch name for this worktree
  BRANCH=$(git worktree list --porcelain | grep -A 3 "^worktree $worktree_path$" | grep "^branch" | awk '{print $2}' | sed 's|refs/heads/||' || echo "")
  
  # Check for uncommitted changes
  if [[ -d "$worktree_path" ]]; then
    cd "$worktree_path"
    if [[ -n "$(git status --porcelain)" ]]; then
      echo -e "${YELLOW}⚠ Uncommitted changes detected!${NC}"
      git status --short
      echo ""
      
      if [[ "$FORCE_MODE" == false ]]; then
        read -p "Delete anyway? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "Skipping $WORKTREE_NAME"
          echo ""
          cd "$REPO_PATH"
          continue
        fi
      fi
    fi
    cd "$REPO_PATH"
  fi
  
  # Remove worktree
  echo "Removing worktree..."
  git worktree remove "$worktree_path" --force 2>/dev/null || {
    # If directory doesn't exist, prune it
    git worktree prune
    echo -e "${YELLOW}⚠ Worktree was already removed, pruned metadata${NC}"
  }
  
  if [[ -n "$BRANCH" ]]; then
    BRANCHES_TO_DELETE+=("$BRANCH")
  fi
  
  echo -e "${GREEN}✓ Removed: $WORKTREE_NAME${NC}"
  echo ""
  ((DELETED_COUNT++))
  
done <<< "$WORKTREES"

# Handle branches
if [[ ${#BRANCHES_TO_DELETE[@]} -gt 0 ]]; then
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  Branch Cleanup${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "The following branches were used by worktrees:"
  for branch in "${BRANCHES_TO_DELETE[@]}"; do
    echo "  - $branch"
  done
  echo ""
  
  if [[ "$FORCE_MODE" == false ]]; then
    read -p "Delete these branches? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      for branch in "${BRANCHES_TO_DELETE[@]}"; do
        if git show-ref --verify --quiet "refs/heads/$branch"; then
          git branch -D "$branch" 2>/dev/null && echo "✓ Deleted branch: $branch" || echo "⚠ Failed to delete: $branch"
        fi
      done
    else
      echo "Branches kept. You can delete them later with:"
      for branch in "${BRANCHES_TO_DELETE[@]}"; do
        echo "  git branch -D $branch"
      done
    fi
  else
    # Force mode: delete branches
    for branch in "${BRANCHES_TO_DELETE[@]}"; do
      if git show-ref --verify --quiet "refs/heads/$branch"; then
        git branch -D "$branch" 2>/dev/null && echo "✓ Deleted branch: $branch" || echo "⚠ Failed to delete: $branch"
      fi
    done
  fi
fi

# Final prune
git worktree prune

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✓ Removed $DELETED_COUNT worktree(s)${NC}"
echo ""
echo "Remaining worktrees:"
git worktree list
echo ""

# Reminder about aliases
if [[ $DELETED_COUNT -gt 0 ]]; then
  echo -e "${YELLOW}Remember to remove shell aliases from ~/.zshrc:${NC}"
  echo "  za, zb, zc, etc."
  echo ""
fi

echo -e "${GREEN}Cleanup complete!${NC}"
