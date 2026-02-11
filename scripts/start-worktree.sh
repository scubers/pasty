#!/bin/bash
set -e

# Check if branch name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <branch-name>"
  echo "Example: $0 feat/new-feature"
  exit 1
fi

BRANCH_NAME=$1
WORKTREE_PATH="worktree/$BRANCH_NAME"

# Ensure we are in repo root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "=== Setup Worktree: $BRANCH_NAME ==="

# 1. Create branch from master if it doesn't exist
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Branch '$BRANCH_NAME' already exists. Using existing branch."
else
  echo "Creating branch '$BRANCH_NAME' from 'master'..."
  git branch "$BRANCH_NAME" master
fi

# 2. Create worktree
if [ -d "$WORKTREE_PATH" ]; then
  echo "Directory '$WORKTREE_PATH' already exists."
else
  echo "Creating git worktree at '$WORKTREE_PATH'..."
  git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
fi

# 3. Open in default Terminal
echo "Opening Terminal at '$WORKTREE_PATH'..."
open -a iTerm "$WORKTREE_PATH"

echo "Done."
