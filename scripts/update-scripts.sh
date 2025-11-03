#!/usr/bin/env bash
# update-scripts.sh — Update helper scripts from MiguelRodo/CompTemplate
# Portable: Bash ≥3.2 (macOS default), Linux, WSL, Git Bash
#
# This script pulls the latest helper scripts from the CompTemplate repository

set -Eeo pipefail

# --- Configuration ---
UPSTREAM_REPO="https://github.com/MiguelRodo/CompTemplate.git"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
SCRIPTS_SUBDIR="scripts/helper"

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPER_DIR="$SCRIPT_DIR/helper"

# --- Usage ---
usage() {
  cat <<EOF
Usage: $0 [options]

Update helper scripts from the upstream CompTemplate repository.

This script:
  1. Clones/pulls the latest MiguelRodo/CompTemplate repository
  2. Copies scripts from scripts/helper/ to local scripts/helper/
  3. Preserves executable permissions
  4. Creates a commit with the updates

Options:
  -b, --branch <name>  Use specific branch (default: main)
  -n, --dry-run        Show what would be updated without making changes
  -f, --force          Overwrite local changes without prompting
  -h, --help           Show this message

Environment Variables:
  UPSTREAM_BRANCH      Override the default branch (default: main)

Examples:
  $0                    # Update from main branch
  $0 --branch dev       # Update from dev branch
  $0 --dry-run          # Preview updates
  $0 --force            # Force update without prompts

Notes:
  - Only updates files in scripts/helper/ directory
  - Does NOT update main scripts in scripts/ directory
  - Preserves local modifications to other files
  - Creates a git commit with the changes
EOF
}

# --- Parse arguments ---
DRY_RUN=false
FORCE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    -b|--branch)
      shift; UPSTREAM_BRANCH="$1"; shift ;;
    -n|--dry-run)
      DRY_RUN=true; shift ;;
    -f|--force)
      FORCE=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage; exit 1 ;;
  esac
done

# --- Validate environment ---
cd "$PROJECT_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: not inside a Git working tree" >&2
  exit 1
fi

# Check for uncommitted changes
if ! $FORCE && ! git diff --quiet HEAD -- "$HELPER_DIR"; then
  echo "Error: You have uncommitted changes in scripts/helper/" >&2
  echo "Commit or stash your changes, or use --force to overwrite." >&2
  echo "" >&2
  echo "Changed files:" >&2
  git status --short "$HELPER_DIR" >&2
  exit 1
fi

# --- Create temp directory ---
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Fetching scripts from $UPSTREAM_REPO (branch: $UPSTREAM_BRANCH)..."

# --- Clone the upstream repo ---
if ! git clone --depth 1 --branch "$UPSTREAM_BRANCH" --single-branch "$UPSTREAM_REPO" "$TEMP_DIR/CompTemplate" >/dev/null 2>&1; then
  echo "Error: Failed to clone upstream repository" >&2
  echo "Repository: $UPSTREAM_REPO" >&2
  echo "Branch: $UPSTREAM_BRANCH" >&2
  exit 1
fi

UPSTREAM_SCRIPTS="$TEMP_DIR/CompTemplate/$SCRIPTS_SUBDIR"

if [ ! -d "$UPSTREAM_SCRIPTS" ]; then
  echo "Error: Scripts directory not found in upstream repo: $SCRIPTS_SUBDIR" >&2
  exit 1
fi

# --- List files to update ---
echo ""
echo "Files to update:"
SCRIPT_COUNT=0

for script in "$UPSTREAM_SCRIPTS"/*; do
  [ ! -f "$script" ] && continue
  SCRIPT_NAME="$(basename "$script")"
  
  if [ -f "$HELPER_DIR/$SCRIPT_NAME" ]; then
    # Check if different
    if ! diff -q "$script" "$HELPER_DIR/$SCRIPT_NAME" >/dev/null 2>&1; then
      echo "  ✓ $SCRIPT_NAME (modified)"
      SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
    else
      echo "  = $SCRIPT_NAME (unchanged)"
    fi
  else
    echo "  + $SCRIPT_NAME (new)"
    SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
  fi
done

if [ "$SCRIPT_COUNT" -eq 0 ]; then
  echo ""
  echo "✓ All scripts are up to date!"
  exit 0
fi

if $DRY_RUN; then
  echo ""
  echo "This was a dry run. Use without --dry-run to apply changes."
  exit 0
fi

# --- Prompt for confirmation ---
if ! $FORCE; then
  echo ""
  read -p "Update $SCRIPT_COUNT script(s)? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 0
  fi
fi

# --- Copy scripts ---
echo ""
echo "Updating scripts..."

mkdir -p "$HELPER_DIR"

for script in "$UPSTREAM_SCRIPTS"/*; do
  [ ! -f "$script" ] && continue
  SCRIPT_NAME="$(basename "$script")"
  
  cp "$script" "$HELPER_DIR/$SCRIPT_NAME"
  chmod +x "$HELPER_DIR/$SCRIPT_NAME"
  
  echo "  ✓ Updated $SCRIPT_NAME"
done

# --- Commit changes ---
echo ""
echo "Committing changes..."

git add "$HELPER_DIR"

if git diff --staged --quiet; then
  echo "No changes to commit (files may be identical)."
else
  COMMIT_MSG="Update helper scripts from CompTemplate@$UPSTREAM_BRANCH

Updated scripts in scripts/helper/ from:
Repository: $UPSTREAM_REPO
Branch: $UPSTREAM_BRANCH
Date: $(date -u +%Y-%m-%d)"
  
  git commit -m "$COMMIT_MSG"
  
  echo ""
  echo "✅ Scripts updated successfully!"
  echo ""
  echo "Changes committed. Review with:"
  echo "  git show HEAD"
  echo ""
  echo "Push when ready:"
  echo "  git push"
fi
