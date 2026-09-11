#!/usr/bin/env bash
# Make `from common.llm import ...` work from any folder in this Codespace by
# putting the repository root on PYTHONPATH for every new terminal (~/.bashrc).
# Idempotent and quiet when already done. Called from .devcontainer/setup.sh
# (new Codespaces), from scripts/gateway-daemon.sh and scripts/start-tui.sh
# (every start of an existing Codespace), and from scripts/sync-template.sh.
# The course starter scripts also put the root on sys.path themselves, so this
# is a convenience for code that uses the plain import, not a requirement.
set -uo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="# >>> course PYTHONPATH >>>"
RC="${HOME}/.bashrc"
if ! grep -qF "${MARKER}" "${RC}" 2>/dev/null; then
  {
    echo ""
    echo "${MARKER}"
    echo "case \":\${PYTHONPATH:-}:\" in *\":${REPO_DIR}:\"*) ;; *) export PYTHONPATH=\"${REPO_DIR}\${PYTHONPATH:+:\${PYTHONPATH}}\" ;; esac"
    echo "# <<< course PYTHONPATH <<<"
  } >> "${RC}"
  echo "Added the course repository to PYTHONPATH for new terminals (~/.bashrc)."
fi
exit 0
