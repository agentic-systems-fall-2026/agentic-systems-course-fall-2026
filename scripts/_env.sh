#!/usr/bin/env bash
# Sourced by the other scripts. Makes `openclaw` (and node) discoverable in
# non-interactive VS Code *task* shells, which don't load ~/.bashrc / nvm.
# On the devcontainer image, npm-global binaries live in the nvm-managed
# node bin (e.g. /usr/local/share/nvm/versions/node/<ver>/bin) — not on the
# default task PATH. We add every plausible location here.
_NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"
for _d in \
  "${HOME}/.local/bin" \
  "${HOME}/.npm-global/bin" \
  /usr/local/share/npm-global/bin \
  "${HOME}/.openclaw/bin" \
  "${_NVM_DIR}"/versions/node/*/bin
do
  if [ -d "${_d}" ]; then
    case ":${PATH}:" in
      *":${_d}:"*) : ;;
      *) PATH="${_d}:${PATH}" ;;
    esac
  fi
done
# Last resort: if openclaw still isn't resolvable, search for it on disk.
if ! command -v openclaw >/dev/null 2>&1; then
  _oc="$(find "${_NVM_DIR}" /usr/local/share/npm-global /usr/local/lib/node_modules "${HOME}/.npm-global" "${HOME}/.local" "${HOME}/.openclaw" -maxdepth 4 -name openclaw -type f 2>/dev/null | head -n1 || true)"
  if [ -n "${_oc:-}" ]; then
    case ":${PATH}:" in *":$(dirname "${_oc}"):"*) : ;; *) PATH="$(dirname "${_oc}"):${PATH}" ;; esac
  fi
  unset _oc
fi
export PATH
unset _d _NVM_DIR
