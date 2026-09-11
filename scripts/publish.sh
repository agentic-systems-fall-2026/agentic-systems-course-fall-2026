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
# It refuses (exit 9) to publish a build that is an exact copy of another
# challenge's build, because that is never a real submission.
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

# Look for anything shaped like an API key. Binary-looking files are scanned as
# text (-a), because a stray NUL byte must not turn a key into "no matches".
# Prints matching paths on stdout. Exit 0 = found, 1 = clean, 2 = scan failed.
scan_for_keys() {
  local out rc
  set +e
  out="$(grep -ralE \
      -e 'sk-or-v1-[A-Za-z0-9]{8,}' \
      -e 'sk-ant-[A-Za-z0-9_-]{8,}' \
      -e 'sk-proj-[A-Za-z0-9_-]{8,}' \
      -e 'AKIA[0-9A-Z]{16}' \
      -e 'gh[pousr]_[A-Za-z0-9]{20,}' \
      -e '^[[:space:]]*(export[[:space:]]+)?(OPENROUTER_API_KEY|LITELLM_API_KEY|ANTHROPIC_API_KEY|OPENAI_API_KEY|GITHUB_TOKEN)[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9_-]{12,}' \
      "$1" 2>&1)"
  rc=$?
  set -e
  printf '%s' "${out}"
  return ${rc}
}

# Fingerprint the files a folder would publish, using the same filter as the
# workflow (no *.md, no .env*, no node_modules or .git), so an identical copy of
# another challenge's build can be recognised.
tree_digest() {
  local dir="$1" h
  if command -v sha256sum >/dev/null 2>&1; then h="sha256sum"; else h="shasum -a 256"; fi
  (cd "${dir}" && LC_ALL=C find . -type f -not -iname '*.md' -not -iname '.env*' \
      -not -path '*/node_modules/*' -not -path '*/.git/*' -print | LC_ALL=C sort \
    | while IFS= read -r f; do printf '%s  %s\n' "$(${h} "$f" | cut -d' ' -f1)" "$f"; done) \
    | ${h} | cut -d' ' -f1
}

# Refuse when the build about to go out as TARGET is byte for byte the build
# another challenge already publishes. That is never a legitimate submission,
# and it is exactly what an agent produces when it invents a build to make a
# publish succeed.
refuse_duplicate() {
  local dir="$1" mine other t
  mine="$(tree_digest "${dir}")"
  for t in ${ALLOWED}; do
    [[ "${t}" == "${TARGET}" ]] && continue
    [[ -f "${ROOT}/${t}/index.html" ]] || continue
    other="$(tree_digest "${ROOT}/${t}")"
    if [[ "${mine}" == "${other}" ]]; then
      echo "publish.sh: refusing to publish. The build for ${TARGET} is an exact copy of ${t}/, which is a different build challenge." >&2
      echo "Each challenge needs its own build. If the ${TARGET} build has not been made yet, there is nothing to publish for it." >&2
      echo "Nothing in the repository was changed." >&2
      exit 9
    fi
  done
}

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
staged_elsewhere="$(git diff --cached --name-only | grep -v "^${TARGET}/" | grep -v "^\.publish/" || true)"
if [[ -n "${staged_elsewhere}" ]]; then
  echo "publish.sh: these files are staged for commit but are not part of ${TARGET}/:" >&2
  echo "${staged_elsewhere}" | sed 's/^/   /' >&2
  echo "Publishing would leave them out of the commit and cannot promise to keep them staged." >&2
  echo "Commit them (git commit) or unstage them (git restore --staged <file>), then run this again." >&2
  exit 6
fi

# ---- Find the build if nothing was given ------------------------------------
# Look in the agent workspace and in the repository itself: a build made before
# this script existed often sits in a folder of the student's own naming.
if [[ -z "${SRC}" && ! -f "${ROOT}/${TARGET}/index.html" ]]; then
  ws="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
  cands=()
  if [[ -d "${ws}" ]]; then
    while IFS= read -r f; do cands+=("${f%/index.html}"); done \
      < <(find "${ws}" -maxdepth 4 -name index.html -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/skills/*' 2>/dev/null | sort -u)
  fi
  while IFS= read -r f; do cands+=("${f%/index.html}"); done \
    < <(find "${ROOT}" -maxdepth 3 -name index.html \
          -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/_site/*' \
          -not -path "${ROOT}/.*" -not -path "${ROOT}/scripts/*" -not -path "${ROOT}/common/*" \
          -not -path "${ROOT}/config/*" -not -path "${ROOT}/openclaw/*" -not -path "${ROOT}/prompts/*" \
          2>/dev/null | sort -u)
  hint=""
  case "${TARGET}" in
    bc0-space-invaders) hint='invader|space|bc0-space' ;;
    bc0b-app) hint='bc0b|[^a-z]0b|^0b|app' ;;
    shipday) hint='ship' ;;
    capstone) hint='capstone' ;;
  esac
  picked=()
  for c in "${cands[@]:-}"; do
    [[ -n "${c}" ]] || continue
    rel="${c#"${ws}"/}"; rel="${rel#"${ROOT}"/}"   # match the project name, never the path above it
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
  [[ ! -L "${dest}" ]] || fail "${TARGET} is a symbolic link. Publishing needs a real folder; remove the link and put the build in ${TARGET}/." 4
  if [[ "${SRC}" == "${dest}" ]]; then
    echo "Source and ${TARGET}/ are the same folder; nothing to copy."
  else
    [[ "${dest}/" != "${SRC}/"* ]] || fail "${SRC} contains ${TARGET}/. Pass the folder that holds only the build (for example its dist/ or build/ folder)." 4
    if find "${SRC}" -type l -not -path '*/node_modules/*' -not -path '*/.git/*' | grep -q .; then
      fail "${SRC} contains symbolic links, which cannot be published. Replace them with ordinary files." 4
    fi
    # Stage first: the source may live inside the target (a dist/ folder, say),
    # so nothing in the target may be removed until the copy is safely elsewhere.
    stage="$(mktemp -d)"
    trap 'rm -rf "${stage}"' EXIT
    (cd "${SRC}" && tar --exclude=node_modules --exclude=.git -cf - .) | (cd "${stage}" && tar -xf -)
    # Check the incoming build before anything in the repository is touched, so
    # a refused publish leaves the previous version exactly as it was.
    set +e; stage_hits="$(scan_for_keys "${stage}")"; stage_rc=$?; set -e
    if [[ ${stage_rc} -eq 0 ]]; then
      echo "publish.sh: refusing to publish. These files in ${SRC} look like they contain an API key:" >&2
      echo "${stage_hits}" | sed "s|^${stage}|   ${SRC}|" >&2
      echo "Remove the key from the file, then run this again. Nothing in the repository was changed." >&2
      rm -rf "${stage}"; exit 5
    elif [[ ${stage_rc} -ne 1 ]]; then
      rm -rf "${stage}"
      fail "the key scan failed (grep exit ${stage_rc}): ${stage_hits}. Nothing in the repository was changed." 5
    fi
    refuse_duplicate "${stage}"
    mkdir -p "${dest}"
    # Remove only what the last publish put here and this one does not, so a file
    # you deleted while building leaves the site, while your source tree, your
    # notes, and anything you put in this folder by hand are left alone.
    manifest="${ROOT}/.publish/${TARGET}.files"
    removed=0
    if [[ -f "${manifest}" ]]; then
      while IFS= read -r rel; do
        [[ -n "${rel}" ]] || continue
        case "${rel}" in person.md|agent-notes.md|*/..*|/*) continue ;; esac
        [[ -e "${stage}/${rel}" ]] && continue
        old_path="${dest}/${rel}"
        [[ -e "${old_path}" ]] || continue
        [[ "${old_path}" == "${SRC}/"* ]] && continue   # never touch the source
        # Only remove a file git can give back: tracked, and saved as committed.
        if [[ -n "$(git status --porcelain --untracked-files=all -- "${TARGET}/${rel}" 2>/dev/null)" ]]; then
          echo "Keeping ${TARGET}/${rel}: it has changes that are not committed, so it is not mine to delete." >&2
          continue
        fi
        rm -f "${old_path}" && removed=$((removed+1))
      done < "${manifest}"
    fi
    (cd "${stage}" && tar -cf - .) | (cd "${dest}" && tar -xf -)
    mkdir -p "${ROOT}/.publish"
    (cd "${stage}" && find . -type f | sed 's|^\./||' | sort) > "${manifest}"
    rm -rf "${stage}"; trap - EXIT
    if [[ ${removed} -gt 0 ]]; then
      echo "Copied ${SRC} into ${TARGET}/ (${removed} file(s) from the previous publish removed)"
    else
      echo "Copied ${SRC} into ${TARGET}/"
    fi
  fi
fi

[[ ! -L "${ROOT}/${TARGET}" ]] || fail "${TARGET} is a symbolic link. Publishing needs a real folder." 4
if find "${ROOT}/${TARGET}" -type l -not -path '*/node_modules/*' 2>/dev/null | grep -q .; then
  echo "publish.sh: refusing to publish. ${TARGET}/ contains symbolic links, which can expose files from outside the folder:" >&2
  find "${ROOT}/${TARGET}" -type l -not -path '*/node_modules/*' | sed "s|^${ROOT}/|   |" >&2
  echo "Replace them with ordinary files, then run this again." >&2
  exit 4
fi
[[ -f "${ROOT}/${TARGET}/index.html" ]] || fail "${TARGET}/index.html does not exist. Put the build's index.html (and its files) in ${TARGET}/, or pass the folder it lives in as the second argument." 4

refuse_duplicate "${ROOT}/${TARGET}"

# ---- Refuse anything that looks like a key ------------------------------------
# Keys live in Codespaces secrets, never in files. A scanner error is a stop, not a pass.
set +e; hits="$(scan_for_keys "${ROOT}/${TARGET}")"; rc=$?; set -e
if [[ ${rc} -eq 0 ]]; then
  echo "publish.sh: refusing to publish. These files look like they contain an API key:" >&2
  echo "${hits}" | sed "s|^${ROOT}/|   |" >&2
  echo "Remove the key from the file, then run this again. Nothing was committed." >&2
  exit 5
elif [[ ${rc} -ne 1 ]]; then
  fail "the key scan failed (grep exit ${rc}): ${hits}. Nothing was committed." 5
fi

# ---- Commit only the target folder ------------------------------------------------
git add -A -- "${TARGET}" ".publish/${TARGET}.files" 2>/dev/null || git add -A -- "${TARGET}"
if git diff --cached --quiet -- "${TARGET}" ".publish/${TARGET}.files"; then
  echo "Nothing new to commit in ${TARGET}/; publishing the version already in the repository."
else
  git commit -q -m "Publish ${TARGET} to GitHub Pages" -- "${TARGET}" ".publish/${TARGET}.files"
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

# The site is current when it serves this commit, or when it serves an earlier
# commit whose published folders are identical to this one's: the workflow only
# runs for commits that touch those folders, so an unrelated commit in between
# never gets its own deployment and must not be waited for.
site_is_current() {
  local served="$1"
  [[ "${served}" == "${sha}" ]] && return 0
  [[ ${#served} -eq 40 ]] || return 1
  git cat-file -e "${served}^{commit}" 2>/dev/null || return 1
  git diff --quiet "${served}" "${sha}" -- bc0-space-invaders bc0b-app shipday capstone .publish 2>/dev/null
}

dispatched=0
served=""
for attempt in $(seq 1 30); do
  served="$(curl -s -m 15 "${BASE}/version.txt?${sha:0:8}" 2>/dev/null | tr -d '[:space:]' || true)"
  if site_is_current "${served}"; then
    code="$(curl -s -o /dev/null -m 15 -w '%{http_code}' "${URL}?${sha:0:8}" || true)"
    if [[ "${code}" == "200" ]]; then
      echo
      [[ "${served}" == "${sha}" ]] || echo "The site already has exactly these files (published as ${served:0:8})."
      echo "PUBLISHED: ${URL}"
      exit 0
    fi
    echo
    fail "the site is live but ${URL} returned ${code}. The folder was not published; check that ${TARGET}/index.html is committed." 8
  fi
  # No deployment is coming for this commit if the push carried nothing the
  # workflow watches. Ask for one, once, rather than waiting out the clock.
  if [[ ${attempt} -eq 4 && ${dispatched} -eq 0 ]] && command -v gh >/dev/null 2>&1; then
    if gh workflow run pages.yml --ref main >/dev/null 2>&1; then
      dispatched=1
      echo
      echo "No publish run had started, so I asked GitHub to start one."
    fi
  fi
  printf '.'
  sleep 10
done
echo
if [[ ${#served} -eq 40 ]]; then
  echo "The site is still serving ${served:0:8}, and the run for ${sha:0:8} has not finished or has failed."
else
  echo "The site is not answering yet. If this is the first publish for this repository, GitHub Pages may not be enabled: ask the instructor."
fi
echo "See what happened:   gh run list --workflow pages.yml"
echo "Start a run by hand: gh workflow run pages.yml --ref main"
echo "PENDING: ${URL}   (not finished; do not submit this yet)"
exit 8
