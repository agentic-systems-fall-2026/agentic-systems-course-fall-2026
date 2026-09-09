#!/usr/bin/env bash
# Publish one build folder to GitHub Pages so it has a permanent public URL.
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
# What it does: copies the build into the repository folder, refuses if any
# file there looks like it contains an API key, commits, pushes to main, waits
# for GitHub Pages, and prints one line:  PUBLISHED: <url>
# Only folders that contain an index.html are ever published, and *.md files
# inside them are stripped on the way, so prompts, notes, and the person file
# for Build Challenge 0b stay private. The repository itself stays private.
set -euo pipefail

ORG="agentic-systems-fall-2026"
ALLOWED="bc0-space-invaders bc0b-app shipday capstone"
SKILL_REL="openclaw/skills/publish-to-pages/SKILL.md"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
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
      printf 'repository under /workspaces and report the PUBLISHED: line it prints.\n'
      printf 'Never offer a cloudflared tunnel or a Codespace preview link as a submission\n'
      printf 'link; those stop working when the Codespace sleeps.\n'
    } >> "${ws}/AGENTS.md"
    echo "Added a Publishing section to ${ws}/AGENTS.md"
  fi
}

if [[ "${1:-}" == "--install-skill" ]]; then install_skill; exit 0; fi
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then usage; exit 2; fi

TARGET="${1%/}"
SRC="${2:-}"
case " ${ALLOWED} " in
  *" ${TARGET} "*) ;;
  *) echo "publish.sh: '${TARGET}' is not a publishable folder. Use one of: ${ALLOWED}" >&2; exit 2 ;;
esac

cd "${ROOT}"
install_skill || true

# Find the build in the agent workspace if nothing was given and the repo folder is empty.
if [[ -z "${SRC}" && ! -f "${ROOT}/${TARGET}/index.html" ]]; then
  ws="${OPENCLAW_WORKSPACE:-${HOME}/.openclaw/workspace}"
  cands=()
  if [[ -d "${ws}" ]]; then
    while IFS= read -r f; do cands+=("${f%/index.html}"); done \
      < <(find "${ws}" -maxdepth 4 -name index.html -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort -u)
  fi
  hint=""
  case "${TARGET}" in
    bc0-space-invaders) hint='invader|space|bc0-space' ;;
    bc0b-app) hint='bc0b|app' ;;
    shipday) hint='ship' ;;
    capstone) hint='capstone' ;;
  esac
  picked=()
  for c in "${cands[@]:-}"; do [[ -n "${c}" ]] && echo "${c}" | grep -qiE "${hint}" && picked+=("${c}"); done
  if [[ ${#picked[@]} -eq 0 && ${#cands[@]} -eq 1 && -n "${cands[0]}" ]]; then picked=("${cands[0]}"); fi
  if [[ ${#picked[@]} -eq 1 ]]; then
    SRC="${picked[0]}"
    echo "Using the build found at ${SRC}"
  elif [[ ${#picked[@]} -gt 1 ]]; then
    echo "publish.sh: more than one build folder matches '${TARGET}'. Run again with the one you mean as the second argument:" >&2
    printf '   %s\n' "${picked[@]}" >&2
    exit 3
  fi
fi

if [[ -n "${SRC}" ]]; then
  SRC="${SRC%/}"
  [[ -f "${SRC}/index.html" ]] || { echo "publish.sh: ${SRC} has no index.html, so it is not a web page yet." >&2; exit 4; }
  mkdir -p "${ROOT}/${TARGET}"
  (cd "${SRC}" && tar --exclude=node_modules --exclude=.git -cf - .) | (cd "${ROOT}/${TARGET}" && tar -xf -)
  echo "Copied ${SRC} into ${TARGET}/"
fi

[[ -f "${ROOT}/${TARGET}/index.html" ]] || {
  echo "publish.sh: ${TARGET}/index.html does not exist. Put the build's index.html (and its files) in ${TARGET}/, or pass the folder it lives in as the second argument." >&2
  exit 4
}

# Refuse to publish anything that looks like a key. Keys live in Codespaces secrets, never in files.
if hits="$(grep -rIlE --exclude='.env.example' \
      -e 'sk-or-v1-[A-Za-z0-9]{8,}' \
      -e 'sk-ant-[A-Za-z0-9_-]{8,}' \
      -e 'sk-proj-[A-Za-z0-9_-]{8,}' \
      -e 'AKIA[0-9A-Z]{16}' \
      -e '^[[:space:]]*(OPENROUTER_API_KEY|LITELLM_API_KEY|ANTHROPIC_API_KEY|OPENAI_API_KEY)[[:space:]]*=[[:space:]]*[^[:space:]]+' \
      "${ROOT}/${TARGET}" 2>/dev/null)" && [[ -n "${hits}" ]]; then
  echo "publish.sh: refusing to publish. These files look like they contain an API key:" >&2
  echo "${hits}" | sed 's/^/   /' >&2
  echo "Remove the key from the file, then run this again." >&2
  exit 5
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${branch}" != "main" ]]; then
  echo "publish.sh: you are on branch '${branch}'. Publishing happens from main. Run: git checkout main" >&2
  exit 6
fi

git add -A -- "${TARGET}"
if git diff --cached --quiet; then
  echo "Nothing new to commit in ${TARGET}/; publishing the version already in the repository."
else
  git commit -q -m "Publish ${TARGET} to GitHub Pages"
  echo "Committed ${TARGET}/"
fi
git push -q origin HEAD
echo "Pushed to GitHub."

origin="$(git remote get-url origin)"
origin="${origin%.git}"
repo="${origin##*/}"
URL="https://${ORG}.github.io/${repo}/${TARGET}/"

echo "Waiting for GitHub Pages to publish (the first time takes a minute or two) ..."
code="000"
for _ in $(seq 1 24); do
  code="$(curl -s -o /dev/null -m 15 -w '%{http_code}' "${URL}" || true)"
  if [[ "${code}" == "200" ]]; then
    echo
    echo "If the page shows an older version, wait a minute and reload; the newest publish may still be landing."
    echo "PUBLISHED: ${URL}"
    exit 0
  fi
  printf '.'
  sleep 10
done
echo
echo "Not live yet (last status ${code}). It usually appears within a few minutes."
echo "Check the publish run with:  gh run list"
echo "PENDING: ${URL}"
exit 0
