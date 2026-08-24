#!/usr/bin/env bash
# Pull course-template fixes into your Classroom repo, file by file.
#
# Your repo was copied from the course template when you accepted the
# assignment; it does NOT track the template afterward. When the template
# gets a fix, sync the affected file(s) with this script.
#
#   bash scripts/sync-template.sh                     # list files that differ
#   bash scripts/sync-template.sh bc1-tools/agent.py  # sync one file + commit
#   bash scripts/sync-template.sh --all               # sync ALL changed files
#   bash scripts/sync-template.sh --push [--all|<paths...>]   # ...and push
#
# Safety: it refuses to run with uncommitted changes, warns before touching
# any file you have committed work to, and commits the sync — so your own
# version is always recoverable from git history.
set -euo pipefail

TEMPLATE_URL="https://github.com/agentic-systems-fall-2026/agentic-systems-course-fall-2026.git"
cd "$(git rev-parse --show-toplevel)"

PUSH=0; ALL=0; PATHS=()
for a in "$@"; do
  case "$a" in
    --push) PUSH=1 ;;
    --all)  ALL=1 ;;
    *) PATHS+=("$a") ;;
  esac
done

git remote get-url template >/dev/null 2>&1 || git remote add template "$TEMPLATE_URL"
git fetch --quiet template main

if [ "$ALL" -eq 1 ]; then
  while IFS= read -r f; do PATHS+=("$f"); done \
    < <(git diff --name-only --diff-filter=MA HEAD template/main)
  [ ${#PATHS[@]} -eq 0 ] && { echo "Already in sync with the template."; exit 0; }
  echo "Syncing ${#PATHS[@]} file(s) from the template..."
fi

if [ ${#PATHS[@]} -eq 0 ]; then
  echo "Template files that changed since your copy (M=modified, A=new):"
  git diff --name-status --diff-filter=MA HEAD template/main | sed 's/^/  /'
  echo
  echo "Sync one with:  bash scripts/sync-template.sh [--push] <path>"
  exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "You have uncommitted changes. Commit them first so nothing is lost:"
  echo '  git add -A && git commit -m "wip"'
  exit 1
fi

for f in "${PATHS[@]}"; do
  if ! git cat-file -e "template/main:$f" 2>/dev/null; then
    echo "SKIP: $f does not exist in the template."
    continue
  fi
  # >1 commit touching the file means you changed it after the initial import.
  if [ "$(git log --oneline HEAD -- "$f" | wc -l)" -gt 1 ]; then
    echo "WARNING: you have committed your own changes to $f."
    echo "Syncing replaces it with the template version (your work stays in git history)."
    read -r -p "Replace $f anyway? [y/N] " ans
    [ "${ans:-n}" = "y" ] || { echo "SKIP: $f"; continue; }
  fi
  git checkout template/main -- "$f"
  echo "synced: $f"
done

if git diff --cached --quiet; then
  echo "Nothing changed — you already match the template."
  exit 0
fi

if [ "$ALL" -eq 1 ]; then
  git commit -m "sync from course template (all changed files)"
else
  git commit -m "sync from course template: ${PATHS[*]}"
fi
if [ "$PUSH" -eq 1 ]; then
  git push
  echo "Pushed. Your GitHub repo is up to date."
else
  echo "Committed. Now run:  git push"
fi
