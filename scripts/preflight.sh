#!/usr/bin/env bash
# Pre-flight: find a working endpoint key BEFORE starting the gateway.
# Order: OpenRouter FIRST (course standard), then the OU AI Sandbox (no-cost alternative).
# Writes (read by start-gateway.sh and the TUI launcher):
#   ~/.openclaw/.preflight     = ok|fail
#   ~/.openclaw/.provider      = litellm|openrouter   (preferred provider)
#   ~/.openclaw/.providers_ok  = space-separated providers whose keys validated
set -uo pipefail

LITELLM_BASE_URL="${LITELLM_BASE_URL:-https://litellm.lib.ou.edu}"
ENV_FILE="${HOME}/.openclaw/.env"
STATUS="${HOME}/.openclaw/.preflight"
PROVIDER_FILE="${HOME}/.openclaw/.provider"
OK_FILE="${HOME}/.openclaw/.providers_ok"
base="${LITELLM_BASE_URL%/}"
mkdir -p "${HOME}/.openclaw"

read_env() { grep -E "^$1=" "${ENV_FILE}" 2>/dev/null | tail -n1 | cut -d= -f2- || true; }

LL_KEY="${LITELLM_API_KEY:-}"; [[ -z "${LL_KEY}" ]] && LL_KEY="$(read_env LITELLM_API_KEY)"
[[ "${LL_KEY}" == "sk-REPLACE_ME" ]] && LL_KEY=""
OR_KEY="${OPENROUTER_API_KEY:-}"; [[ -z "${OR_KEY}" ]] && OR_KEY="$(read_env OPENROUTER_API_KEY)"
[[ "${OR_KEY}" == "sk-or-REPLACE_ME" ]] && OR_KEY=""

fail() { echo "fail" > "${STATUS}"; echo; echo "❌ $1"; echo; exit 1; }

VALID=""

# ---- 1) OpenRouter — course standard ---------------------------------------
if [[ -n "${OR_KEY}" ]]; then
  echo "🔑 Checking OpenRouter key ..."
  # /api/v1/key returns the key's metadata (usage/limit) — a clean auth check.
  or_code="$(curl -s -m 20 -o /tmp/oc_key.json -w '%{http_code}' -H "Authorization: Bearer ${OR_KEY}" https://openrouter.ai/api/v1/key 2>/dev/null || true)"
  or_code="${or_code//[^0-9]/}"; or_code="${or_code:0:3}"; [[ -z "${or_code}" ]] && or_code=000
  if [[ "${or_code}" == "200" ]]; then
    echo "✅ OpenRouter key valid."
    # Best-effort spend readout — it's your own money, so keep an eye on it.
    python3 - << 'PY' 2>/dev/null || true
import json
d = json.load(open("/tmp/oc_key.json")).get("data", {})
usage, limit = d.get("usage"), d.get("limit")
if usage is not None:
    lim = f" of your ${limit:.2f} key limit" if isinstance(limit, (int, float)) else ""
    print(f"💸 OpenRouter spend so far: ${usage:.2f}{lim} (course budget: $20 for the term).")
PY
    VALID="${VALID:+${VALID} }openrouter"
  else
    case "${or_code}" in
      401|403) echo "⚠️  OpenRouter key rejected (HTTP ${or_code}) — invalid or disabled." ;;
      000)     echo "⚠️  Could not reach openrouter.ai (network issue)." ;;
      *)       echo "⚠️  Unexpected response (HTTP ${or_code}) from openrouter.ai." ;;
    esac
  fi
fi
# ---- 2) OU AI Sandbox — no-cost alternative -------------------------------
if [[ -n "${LL_KEY}" && -z "${VALID}" ]]; then
  echo "🔑 Checking OU LiteLLM Sandbox key against ${base} ..."
  ll_code=000
  for url in "${base}/v1/models" "${base}/models"; do
    ll_code="$(curl -s -m 20 -o /tmp/oc_ll_models.json -w '%{http_code}' -H "Authorization: Bearer ${LL_KEY}" "${url}" 2>/dev/null || true)"
    ll_code="${ll_code//[^0-9]/}"; ll_code="${ll_code:0:3}"; [[ -z "${ll_code}" ]] && ll_code=000
    [[ "${ll_code}" == "200" ]] && break
  done
  if [[ "${ll_code}" == "200" ]]; then
    count="$(python3 -c 'import json;print(len(json.load(open("/tmp/oc_ll_models.json")).get("data",[])))' 2>/dev/null || echo "?")"
    echo "✅ OU LiteLLM key valid — ${count} model(s) available."
    VALID="litellm"
  else
    case "${ll_code}" in
      401|403) echo "⚠️  OU LiteLLM key rejected (HTTP ${ll_code}) — falling back. Fix later: bash scripts/set-key.sh" ;;
      000)     echo "⚠️  Could not reach ${base} — falling back." ;;
      *)       echo "⚠️  Unexpected response (HTTP ${ll_code}) from ${base} — falling back." ;;
    esac
  fi
fi


# ---- verdict ----------------------------------------------------------------
if [[ -z "${VALID}" ]]; then
  if [[ -z "${LL_KEY}" && -z "${OR_KEY}" ]]; then
    echo "nokey" > "${HOME}/.openclaw/.preflight_reason"
    fail "No endpoint key set. Provide ONE of:
   • OPENROUTER_API_KEY — your OpenRouter key (sk-or-), the course standard, or
   • LITELLM_API_KEY  — your OU AI Sandbox key (sk-), the no-cost alternative.
   Set it as a Codespaces secret and reopen, or run: bash scripts/set-key.sh"
  else
    echo "invalid" > "${HOME}/.openclaw/.preflight_reason"
    fail "No working endpoint key. See the warnings above, then fix with: bash scripts/set-key.sh"
  fi
fi
rm -f "${HOME}/.openclaw/.preflight_reason"

PREFERRED="${VALID%% *}"   # litellm wins when both validated (listed first)
echo "${PREFERRED}" > "${PROVIDER_FILE}"
echo "${VALID}" > "${OK_FILE}"
echo "ok" > "${STATUS}"
if [[ "${PREFERRED}" == "litellm" ]]; then
  extra=""; [[ "${VALID}" == *openrouter* ]] && extra=" — OpenRouter key also valid (switch any time: bash scripts/select-model.sh)"
  echo "▶️  Endpoint: OU LiteLLM Sandbox (first choice)${extra}"
else
  echo "▶️  Endpoint: OpenRouter (no working OU LiteLLM key found)"
fi
