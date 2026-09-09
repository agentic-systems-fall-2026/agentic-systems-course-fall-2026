#!/usr/bin/env bash
# Publish one build folder to GitHub Pages so it has a stable public URL.
#
#   bash scripts/publish.sh <target-folder> [source-dir]
#   bash scripts/publish.sh --install-skill
#
#   target-folder  bc0-space-invaders | bc0b-app | shipday | capstone
#   source-dir     where the build currently lives (usually somewhere under
#                  ~/.openclaw/workspace). Omit it if the files are already in
#                  the repository folder. Omit it and the script will also try
#                  to find the build in the agent workspace on its own.
#
# What it does: checks the repository and branch, copies the build into the
# repository folder, refuses if any file there looks like it contains an API
# key, commits only that folder, pulls and pushes, waits until GitHub Pages
# serves this exact commit, and prints one line:  PUBLISHED: <url>
# If the site is not serving this commit after a few minutes it prints
# PENDING: <url> and exits 8; that is not a finished publish.
# Only folders that contain an index.html are ever published, and *.md files
# inside them are stripped on the way, so prompts, notes, and the person file
# for Build Challenge 0b stay private. The repository itself stays private.
set -euo pipefail

ORG="agentic-systems-fall-2026"
TEMPLATE_REPO="agentic-systems-course-fall-2026"
ALLOWED="bc0-space-invaders bc0b-app shipday capstone"
SKILL_REL="openclaw/skills/publish-to-pages/SKILL.md"
INVOKED_FROM="$(pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

fail() { echo "publish.sh: $1" >&2; exit "${2:-1}"; }

# Make the OpenClaw agent aware of this script (idempotent, best effort).
install_skill() {
  local ws="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
  [[ -d "${ws}" ]] || { echo "No OpenClaw workspace at ${ws} yet; the skill will install on the first publish."; return 0; }
  [[ -f "${ROOT}/${SKILL_REL}" ]] || return 0
  mkdir -p "${ws}/skills/publish-to-pages"
  if ! cmp -s "${ROOT}/${SKILL_REL}" "${ws}/skills/publish-to-pages/SKILL.md" 2>/dev/null; then
    cp "${ROOT}/${SKILL_REL}" "${ws}/skills/publish-to-pages/SKILL.md"
    echo "Installed OpenClaw skill: publish-to-pages"
  fi
  if [[ -f "${ws}/AGENTS.md" ]] && ! grep -q "publish-to-pages" "${ws}/AGENTS.md"; then
    {
      printf '\n## Publishing\n<!-- publish-to-pages -->\n'
      printf 'When the user asks to publish, deploy, put online, or get a link for a build,\n'
      printf 'use the publish-to-pages skill: run scripts/publish.sh in the course\n'
      printf 'repository at %s and report the PUBLISHED: line it prints.\n' "${ROOT}"
      printf 'A PENDING: line means the publish is not finished; say so.\n'
      printf 'Never offer a cloudflared tunnel or a Codespace preview link as a submission\n'
      printf 'link; those stop working when the Codespace sleeps.\n'
    } >> "${ws}/AGENTS.md"
    echo "Added a Publishing section to ${ws}/AGENTS.md"
  fi
}

if [[ "${1:-}" == "--install-skill" ]]; then install_skill; exit 0; fi
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then usage; exit 2; fi
[[ $# -le 2 ]] || fail "too many arguments. Usage: bash scripts/publish.sh <target-folder> [source-dir]" 2

TARGET="${1%/}"
SRC="${2:-}"
case "${TARGET}" in
  bc0-space-invaders|bc0b-app|shipday|capstone) ;;
  *) fail "'${TARGET}' is not a publishable folder. Use one of: ${ALLOWED}" 2 ;;
esac

# A relative source is relative to where the command was typed, not to the repo.
if [[ -n "${SRC}" && "${SRC}" != /* ]]; then SRC="${INVOKED_FROM}/${SRC}"; fi

cd "${ROOT}"
install_skill || true

# ---- Checks that must pass before anything is copied or changed -------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "${ROOT} is not a git repository." 6
origin="$(git remote get-url origin 2>/dev/null || true)"
origin="${origin%.git}"; origin="${origin%/}"
repo="${origin##*/}"
owner_path="${origin%/*}"; owner="${owner_path##*[/:]}"
[[ "${owner}" == "${ORG}" ]] || fail "origin is '${origin}', which is not in the ${ORG} organization. Run this inside your course repository." 6
[[ "${repo}" != "${TEMPLATE_REPO}" ]] || fail "this is the course template, which never publishes. Run this inside your own course repository." 6
branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "${branch}" == "main" ]] || fail "you are on branch '${branch}'. Publishing happens from main. Run: git checkout main" 6
[[ -z "$(git ls-files -u)" ]] || fail "the repository has unresolved merge conflicts. Resolve them (git status shows the files), then run this again." 6
for op in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD; do
  [[ -e "$(git rev-parse --git-path "${op}")" ]] && fail "a git ${op%%-*} is in progress. Finish or abort it, then run this again." 6
done
staged_elsewhere="$(git diff --cached --name-only | grep -v "^${TARGET}/" || true)"
if [[ -n "${staged_elsewhere}" ]]; then
  echo "publish.sh: these files are staged but are not part of ${TARGET}/, so they are left out of the publish commit:" >&2
  echo "${staged_elsewhere}" | sed 's/^/   /' >&2
fi

# ---- Find the build in the agent workspace if nothing was given -------------
if [[ -z "${SRC}" && ! -f "${ROOT}/${TARGET}/index.html" ]]; then
  ws="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
  cands=()
  if [[ -d "${ws}" ]]; then
    while IFS= read -r f; do cands+=("${f%/index.html}"); done \
      < <(find "${ws}" -maxdepth 4 -name index.html -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/skills/*' 2>/dev/null | sort -u)
  fi
  hint=""
  case "${TARGET}" in
    bc0-space-invaders) hint='invader|space|bc0-space' ;;
    bc0b-app) hint='bc0b|app' ;;
    shipday) hint='ship' ;;
    capstone) hint='capstone' ;;
  esac
  picked=()
  for c in "${cands[@]:-}"; do
    [[ -n "${c}" ]] || continue
    rel="${c#"${ws}"/}"          # match the project name, never the workspace path
    echo "${rel}" | grep -qiE "${hint}" && picked+=("${c}")
  done
  if [[ ${#picked[@]} -eq 0 && ${#cands[@]} -eq 1 && -n "${cands[0]}" ]]; then picked=("${cands[0]}"); fi
  if [[ ${#picked[@]} -eq 1 ]]; then
    SRC="${picked[0]}"
    echo "Using the build found at ${SRC}"
  elif [[ ${#picked[@]} -gt 1 ]]; then
    echo "publish.sh: more than one build folder matches '${TARGET}'. Run again with the one you mean as the second argument:" >&2
    printf '   %s\n' "${picked[@]}" >&2
    exit 3
  fi
elif [[ -z "${SRC}" ]]; then
  echo "Publishing the copy already in ${TARGET}/. If you have a newer build elsewhere, pass its folder as the second argument."
fi

# ---- Copy ---------------------------------------------------------------------
if [[ -n "${SRC}" ]]; then
  SRC="${SRC%/}"
  [[ -d "${SRC}" ]] || fail "${SRC} does not exist." 4
  SRC="$(cd "${SRC}" && pwd -P)"
  [[ -f "${SRC}/index.html" ]] || fail "${SRC} has no index.html, so it is not a web page yet." 4
  dest="${ROOT}/${TARGET}"
  if [[ "${SRC}" == "${dest}" ]]; then
    echo "Source and ${TARGET}/ are the same folder; nothing to copy."
  else
    [[ "${dest}/" != "${SRC}/"* ]] || fail "${SRC} contains the repository folder; choose the folder that holds only the build." 4
    if find "${SRC}" -type l -not -path '*/node_modules/*' -not -path '*/.git/*' | grep -q .; then
      fail "${SRC} contains symbolic links, which cannot be published. Replace them with ordinary files." 4
    fi
    mkdir -p "${dest}"
    # Keep the private course notes in the destination; replace everything else.
    keep=$(mktemp -d)
    for n in person.md agent-notes.md; do [[ -f "${dest}/${n}" ]] && cp "${dest}/${n}" "${keep}/${n}"; done
    find "${dest}" -mindepth 1 -not -name 'person.md' -not -name 'agent-notes.md' -delete 2>/dev/null || true
    (cd "${SRC}" && tar --exclude=node_modules --exclude=.git -cf - .) | (cd "${dest}" && tar -xf -)
    for n in person.md agent-notes.md; do [[ -f "${keep}/${n}" ]] && cp "${keep}/${n}" "${dest}/${n}"; done
    rm -rf "${keep}"
    echo "Copied ${SRC} into ${TARGET}/ (files no longer in the build were removed; person.md and agent-notes.md kept)"
  fi
fi

[[ -f "${ROOT}/${TARGET}/index.html" ]] || fail "${TARGET}/index.html does not exist. Put the build's index.html (and its files) in ${TARGET}/, or pass the folder it lives in as the second argument." 4

# ---- Refuse anything that looks like a key ------------------------------------
# Keys live in Codespaces secrets, never in files. A scanner error is a stop, not a pass.
set +e
hits="$(grep -rIlE \
      -e 'sk-or-v1-[A-Za-z0-9]{8,}' \
      -e 'sk-ant-[A-Za-z0-9_-]{8,}' \
      -e 'sk-proj-[A-Za-z0-9_-]{8,}' \
      -e 'AKIA[0-9A-Z]{16}' \
      -e 'gh[pousr]_[A-Za-z0-9]{20,}' \
      -e '^[[:space:]]*(export[[:space:]]+)?(OPENROUTER_API_KEY|LITELLM_API_KEY|ANTHROPIC_API_KEY|OPENAI_API_KEY|GITHUB_TOKEN)[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9_-]{12,}' \
      "${ROOT}/${TARGET}" 2>&1)"
rc=$?
set -e
if [[ ${rc} -eq 0 ]]; then
  echo "publish.sh: refusing to publish. These files look like they contain an API key:" >&2
  echo "${hits}" | sed 's/^/   /' >&2
  echo "Remove the key from the file, then run this again. The copy in ${TARGET}/ has not been committed." >&2
  exit 5
elif [[ ${rc} -ne 1 ]]; then
  fail "the key scan failed (grep exit ${rc}): ${hits}. Nothing was committed." 5
fi

# ---- Commit only the target folder ------------------------------------------------
git add -A -- "${TARGET}"
if git diff --cached --quiet -- "${TARGET}"; then
  echo "Nothing new to commit in ${TARGET}/; publishing the version already in the repository."
else
  git commit -q -m "Publish ${TARGET} to GitHub Pages" -- "${TARGET}"
  echo "Committed ${TARGET}/"
fi

# ---- Sync and push -------------------------------------------------------------------
# Course fixes are pushed straight into this repository, so a clone is often
# behind origin. One strategy (rebase, local edits autostashed); on conflict,
# put things back and say exactly what to do. Never hide a git error.
if ! git pull --rebase --autostash origin main; then
  git rebase --abort 2>/dev/null || true
  echo "publish.sh: could not bring in the latest changes from GitHub because they conflict with something in this repository." >&2
  echo "Run  git status  to see the files, resolve them, then run this again. Your publish commit is saved locally." >&2
  exit 7
fi
if [[ -n "$(git ls-files -u)" ]]; then
  echo "publish.sh: your uncommitted edits conflict with changes from GitHub in:" >&2
  git ls-files -u | awk '{print "   " $4}' | sort -u >&2
  echo "Resolve them (git status), then run this again. Your publish commit is saved locally." >&2
  exit 7
fi
if ! git push origin HEAD:main; then
  fail "the push was rejected. Run  git pull  in the repository, resolve anything it reports, then run this again." 7
fi
sha="$(git rev-parse HEAD)"
echo "Pushed ${sha:0:8} to GitHub."

# ---- Wait until Pages serves this commit --------------------------------------------
BASE="https://${ORG}.github.io/${repo}"
URL="${BASE}/${TARGET}/"
echo "Waiting for GitHub Pages to publish commit ${sha:0:8} (the first time takes a minute or two) ..."
served=""
for _ in $(seq 1 30); do
  served="$(curl -s -m 15 "${BASE}/version.txt?${sha:0:8}" 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "${served}" == "${sha}" ]]; then
    code="$(curl -s -o /dev/null -m 15 -w '%{http_code}' "${URL}?${sha:0:8}" || true)"
    if [[ "${code}" == "200" ]]; then
      echo
      echo "PUBLISHED: ${URL}"
      exit 0
    fi
    echo
    fail "the site is live for commit ${sha:0:8} but ${URL} returned ${code}. The folder was not published; check that ${TARGET}/index.html is committed." 8
  fi
  printf '.'
  sleep 10
done
echo
if [[ -n "${served}" && ${#served} -eq 40 ]]; then
  echo "The site is still serving an older commit (${served:0:8}). The publish run for ${sha:0:8} has not finished or has failed."
else
  echo "The site is not answering yet. If this is the first publish for this repository, GitHub Pages may not be enabled: ask the instructor."
fi
echo "Check the run with:  gh run list --workflow pages.yml"
echo "PENDING: ${URL}   (not finished; do not submit this yet)"
exit 8
