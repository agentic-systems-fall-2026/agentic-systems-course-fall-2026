#!/usr/bin/env bash
# Interactively save an endpoint API key, then (re)write config.
# Accepts EITHER key — the type is detected from its prefix:
#   sk-or-...  → OpenRouter (create at https://openrouter.ai — Settings → Keys)
#   sk-...     → OU LiteLLM Sandbox (issued by the course)
# The Codespace prefers the OU LiteLLM key when both are present.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${HOME}/.openclaw/.env"
mkdir -p "${HOME}/.openclaw"

echo "Enter your API key — OU LiteLLM Sandbox (sk-...) or OpenRouter (sk-or-...)."
echo "Input is hidden."
read -rs -p "API key: " KEY </dev/tty
echo

if [[ -z "${KEY}" ]]; then
  echo "No key entered. Aborting." >&2
  exit 1
fi

if [[ "${KEY}" == sk-or-* ]]; then
  VAR="OPENROUTER_API_KEY"; LABEL="OpenRouter"
elif [[ "${KEY}" == sk-* ]]; then
  VAR="LITELLM_API_KEY"; LABEL="OU LiteLLM Sandbox"
else
  echo "That doesn't look like either key type (sk-... / sk-or-...)."
  read -rp "Save it anyway as [1] OU LiteLLM or [2] OpenRouter? [1/2/N] " yn </dev/tty
  case "${yn}" in
    1) VAR="LITELLM_API_KEY";   LABEL="OU LiteLLM Sandbox" ;;
    2) VAR="OPENROUTER_API_KEY"; LABEL="OpenRouter" ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# Update (or add) just this variable in ~/.openclaw/.env.
umask 077
touch "${ENV_FILE}"
grep -vE "^${VAR}=" "${ENV_FILE}" > "${ENV_FILE}.tmp" || true
printf '%s=%s\n' "${VAR}" "${KEY}" >> "${ENV_FILE}.tmp"
mv "${ENV_FILE}.tmp" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

# Let preflight re-decide which endpoint to use with the new key.
rm -f "${HOME}/.openclaw/.provider" "${HOME}/.openclaw/.providers_ok"

echo "Saved ${LABEL} key."
bash "${REPO_DIR}/scripts/configure.sh"
echo "If the gateway is already running, restart it (Ctrl-C the Gateway terminal,"
echo "then: bash scripts/start-gateway.sh) to pick up the new key."
