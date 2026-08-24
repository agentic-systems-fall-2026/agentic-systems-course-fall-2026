#!/usr/bin/env bash
# Switch the OpenClaw model.
#
# Asks where your PRIMARY model should come from — OpenRouter (the course
# standard, your own key and credit) or the OU AI Sandbox (no per-token cost) —
# then lets you pick from that catalog. Then asks the same for your FALLBACK,
# which you can decline. Primary and fallback may come from different providers.
#
# Either key works on its own. With only one, the provider question is skipped
# for the primary and reduced to "that provider or no fallback" for the backup.
#
# The gateway hot-reloads. For a chat you are already in, switch with /model.
set -uo pipefail
# Make 'openclaw' findable in non-interactive shells.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true
LITELLM_BASE_URL="${LITELLM_BASE_URL:-https://litellm.lib.ou.edu}"
ENV_FILE="${HOME}/.openclaw/.env"
oubase="${LITELLM_BASE_URL%/}"

read_env() { # read_env VAR -> value from process env or ~/.openclaw/.env
  local var="$1" val="${!1:-}"
  [[ -z "${val}" && -f "${ENV_FILE}" ]] && val="$(grep -E "^${var}=" "${ENV_FILE}" | tail -n1 | cut -d= -f2- || true)"
  printf '%s' "${val}"
}
usage() {
  cat <<'EOF'
Usage: bash scripts/select-model.sh

  Walks you through choosing a primary model and an optional fallback.
  For each, you first choose a provider (OpenRouter or OU AI Sandbox),
  then pick from that provider's catalog.
EOF
}
for arg in "$@"; do
  case "${arg}" in
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option '${arg}'."; usage; exit 1 ;;
  esac
done
# ---- prerequisites --------------------------------------------------------
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Required tool '$1' not found — $2"; exit 1; }; }
need curl    "rebuild the Codespace or install curl."
need python3 "rebuild the Codespace or install python3."
need openclaw "OpenClaw isn't on PATH yet — start the Gateway task first, or run: bash .devcontainer/setup.sh"
# ---- which providers are available? ---------------------------------------
OR_KEY="$(read_env OPENROUTER_API_KEY)"
LL_KEY="$(read_env LITELLM_API_KEY)"
[[ "${OR_KEY}" == "sk-or-REPLACE_ME" ]] && OR_KEY=""
[[ "${LL_KEY}" == "sk-REPLACE_ME"    ]] && LL_KEY=""
HAVE_OR=0; [[ -n "${OR_KEY}" ]] && HAVE_OR=1
HAVE_LL=0; [[ -n "${LL_KEY}" ]] && HAVE_LL=1
if (( ! HAVE_OR && ! HAVE_LL )); then
  echo "❌ No model provider key found."
  echo
  echo "   You need at least one of:"
  echo "     • OU AI Sandbox key (LITELLM_API_KEY) — the no-cost alternative."
  echo "     • Your own OpenRouter key (OPENROUTER_API_KEY) — https://openrouter.ai (Settings → Keys)."
  echo
  echo "   Set one with: bash scripts/set-key.sh"
  exit 1
fi
# ---- catalogs (fetched once, on demand) -----------------------------------
OU=(); OU_LOADED=0
OR_IDS=(); OR_LABELS=(); OR_LOADED=0

ensure_ou_catalog() {
  (( OU_LOADED )) && return 0
  echo "Fetching OU models from ${oubase} ..." >&2
  local http=000 url
  for url in "${oubase}/v1/models" "${oubase}/models"; do
    http="$(curl -s -m 20 -o /tmp/ou_models.json -w '%{http_code}' -H "Authorization: Bearer ${LL_KEY}" "${url}" || echo 000)"
    [[ "${http}" == "200" ]] && break
  done
  case "${http}" in
    200) ;;
    401|403) echo "❌ OU Sandbox key rejected (HTTP ${http})." >&2; exit 1 ;;
    000)     echo "❌ Could not reach ${oubase} (network/endpoint issue). Check the URL or try again." >&2; exit 1 ;;
    *)       echo "❌ OU gateway returned HTTP ${http}. Details in /tmp/ou_models.json" >&2; exit 1 ;;
  esac
  mapfile -t OU < <(python3 -c 'import json
for m in json.load(open("/tmp/ou_models.json")).get("data",[]): print(m["id"])' 2>/dev/null | sort -u)
  ((${#OU[@]})) || { echo "❌ No models parsed from the OU response (/tmp/ou_models.json may be malformed)." >&2; exit 1; }
  OU_LOADED=1
}
ensure_or_catalog() {
  (( OR_LOADED )) && return 0
  # Listing is public, but a bad key makes the choice moot — check it first.
  local kc
  kc="$(curl -s -m 15 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${OR_KEY}" https://openrouter.ai/api/v1/key || echo 000)"
  if [[ "${kc}" != "200" ]]; then
    echo "⚠️  OpenRouter key check returned HTTP ${kc} — it may be invalid, disabled, or out of credit." >&2
    (( HAVE_LL )) && echo "    The OU AI Sandbox is available instead." >&2
    local yn=""
    read -rp "Continue with OpenRouter anyway? [y/N] " yn </dev/tty || true
    [[ "${yn}" =~ ^[Yy]$ ]] || return 1
  fi
  echo "Fetching tool-capable OpenRouter models ..." >&2
  if ! curl -fsS -m 30 "https://openrouter.ai/api/v1/models?supported_parameters=tools" -o /tmp/or_models.json; then
    echo "❌ Could not reach OpenRouter (network/endpoint). Try again in a moment." >&2
    return 1
  fi
  local rows=()
  mapfile -t rows < <(python3 - <<'PY'
import json
data = json.load(open("/tmp/or_models.json")).get("data", [])
popular = {"anthropic","openai","google","x-ai","meta-llama","mistralai",
           "qwen","deepseek","z-ai","moonshotai","minimax"}
def perM(v):
    try: return float(v) * 1_000_000
    except Exception: return None
rows = []
for m in data:
    mid = m.get("id", "")
    vendor = mid.split("/")[0] if "/" in mid else mid
    arch = m.get("architecture", {}) or {}
    if "text" not in (arch.get("input_modalities") or []): continue
    if "tools" not in (m.get("supported_parameters") or []): continue
    if vendor not in popular: continue
    pr = m.get("pricing", {}) or {}
    pin, pout = perM(pr.get("prompt")), perM(pr.get("completion"))
    free = (pin == 0 and pout == 0)
    ctx = m.get("context_length") or 0
    ctxs = f"{ctx // 1000}k" if ctx else "?"
    if free: price = "FREE"
    elif pin is not None and pout is not None: price = f"${pin:.2f}/${pout:.2f} /M"
    else: price = "price n/a"
    rows.append((0 if free else 1, pin if pin is not None else 9e9, vendor, mid,
                 f"{price:<16} {mid} ({ctxs})"))
rows.sort(key=lambda r: (r[0], r[1], r[2], r[3]))
# OpenRouter's own Free Models Router: zero-cost, picks a free model per
# request and filters for tool support itself. The ?supported_parameters=tools
# catalog filter excludes routers, so add it explicitly at the top. Other
# openrouter/* routers stay hidden — some fan out to paid models and would
# drain a student key fast.
rows.insert(0, (0, 0.0, "openrouter", "openrouter/free",
                f"{'FREE':<16} openrouter/free (router — picks a free, tool-capable model per request; rate-limited, fine for smoke tests)"))
for r in rows: print(f"{r[3]}\t{r[4]}")
PY
)
  if ! ((${#rows[@]})); then
    echo "❌ No tool-capable models from popular vendors returned (OpenRouter's catalog may have shifted)." >&2
    return 1
  fi
  local row
  OR_IDS=(); OR_LABELS=()
  for row in "${rows[@]}"; do
    OR_IDS+=("${row%%$'\t'*}")
    OR_LABELS+=("${row#*$'\t'}")
  done
  OR_LOADED=1
}
# ---- provider question ----------------------------------------------------
# choose_provider <ROLE> <allow_none 0|1> -> prints "ou" | "or" | "none"
choose_provider() {
  local role="$1" allow_none="$2"
  local opts=() vals=() i ans=""
  if (( HAVE_LL )); then opts+=("OU AI Sandbox (LiteLLM) — course endpoint, no per-token cost"); vals+=("ou"); fi
  if (( HAVE_OR )); then opts+=("OpenRouter — course standard, your own key and credit");             vals+=("or"); fi
  if (( allow_none )); then opts+=("No ${role,,} model");                                      vals+=("none"); fi
  # Only one real choice and nothing to decline: take it silently.
  if (( ${#vals[@]} == 1 )); then printf '%s' "${vals[0]}"; return 0; fi
  echo >&2
  echo "Where should your ${role} model come from?" >&2
  for i in "${!opts[@]}"; do printf "  %d) %s\n" "$((i+1))" "${opts[$i]}" >&2; done
  echo >&2
  while :; do
    read -rp "Choice: " ans </dev/tty || { echo "No input — aborting." >&2; exit 1; }
    ans="${ans// /}"
    if [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#vals[@]} )); then
      printf '%s' "${vals[$((ans-1))]}"; return 0
    fi
    echo "Please enter a number between 1 and ${#vals[@]}." >&2
  done
}
# ---- model pickers --------------------------------------------------------
# pick_ou <ROLE> <multi 0|1> -> prints newline-separated refs (may be empty)
pick_ou() {
  local role="$1" multi="$2" i ans=""
  ensure_ou_catalog
  echo >&2; echo "OU AI Sandbox models:" >&2
  for i in "${!OU[@]}"; do printf "  %3d) %s\n" "$((i+1))" "${OU[$i]}" >&2; done
  echo >&2
  if (( multi )); then
    read -rp "${role} number(s), comma-separated (blank = none): " ans </dev/tty || true
    [[ -z "${ans// /}" ]] && return 0
    local IDX n
    IFS=',' read -ra IDX <<< "${ans}"
    for n in "${IDX[@]}"; do
      n="${n// /}"
      if [[ "${n}" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#OU[@]} )); then
        printf 'litellm/%s\n' "${OU[$((n-1))]}"
      else
        echo "⚠️  Ignoring invalid entry '${n}'." >&2
      fi
    done
    return 0
  fi
  while :; do
    read -rp "${role} model number: " ans </dev/tty || { echo "No input — aborting." >&2; exit 1; }
    ans="${ans// /}"
    if [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#OU[@]} )); then
      printf 'litellm/%s\n' "${OU[$((ans-1))]}"; return 0
    fi
    echo "Please enter a number between 1 and ${#OU[@]}." >&2
  done
}
# pick_or <ROLE> <multi 0|1> -> prints newline-separated refs (may be empty)
pick_or() {
  local role="$1" multi="$2" i ans=""
  ensure_or_catalog || return 1
  echo >&2
  echo "OpenRouter models (tool-capable; free first, then by price — remember it's your own credit):" >&2
  for i in "${!OR_LABELS[@]}"; do printf "  %3d) %s\n" "$((i+1))" "${OR_LABELS[$i]}" >&2; done
  echo >&2
  if (( multi )); then
    read -rp "${role} number(s), comma-separated (blank = none): " ans </dev/tty || true
    [[ -z "${ans// /}" ]] && return 0
    local IDX n
    IFS=',' read -ra IDX <<< "${ans}"
    for n in "${IDX[@]}"; do
      n="${n// /}"
      if [[ "${n}" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#OR_IDS[@]} )); then
        printf 'openrouter/%s\n' "${OR_IDS[$((n-1))]}"
      else
        echo "⚠️  Ignoring invalid entry '${n}'." >&2
      fi
    done
    return 0
  fi
  while :; do
    read -rp "${role} model number: " ans </dev/tty || { echo "No input — aborting." >&2; exit 1; }
    ans="${ans// /}"
    if [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#OR_IDS[@]} )); then
      printf 'openrouter/%s\n' "${OR_IDS[$((ans-1))]}"; return 0
    fi
    echo "Please enter a number between 1 and ${#OR_IDS[@]}." >&2
  done
}
# ---- apply ----------------------------------------------------------------
apply_models() { # apply_models <primary-ref> [fallback-refs...]
  local primary="$1"; shift
  echo
  echo "→ primary: ${primary}"
  if ! openclaw models set "${primary}"; then
    echo "❌ Could not set primary '${primary}'."
    echo "   Run 'openclaw models list' for valid refs, and check the gateway is running."
    exit 1
  fi
  openclaw models fallbacks clear >/dev/null 2>&1 || true
  local f added=0
  for f in "$@"; do
    [[ -n "${f}" ]] || continue
    # A fallback identical to the primary can never help — drop it.
    if [[ "${f}" == "${primary}" ]]; then
      echo "⚠️  Skipping fallback '${f}' — it is the same as your primary."
      continue
    fi
    echo "→ fallback: ${f}"
    if openclaw models fallbacks add "${f}"; then added=$((added+1)); else echo "⚠️  Couldn't add fallback '${f}' — skipped."; fi
  done
  (( added == 0 )) && echo "→ fallback: none"
  echo; echo "Current model configuration:"
  openclaw models status 2>/dev/null || echo "⚠️  'openclaw models status' unavailable (is the gateway running?)."
  echo "(Hot-reloaded for new sessions. For the chat you're in now, switch with /model.)"
}
warn_weak_fallback() {
  local f
  for f in "$@"; do
    if [[ "${f,,}" == *"30b"* || "${f,,}" == *"coder"* ]]; then
      echo
      echo "ℹ️  Note: '${f}' is a small model, used only when your primary is unavailable."
      echo "   If your agent starts inventing results or claiming it has no network access,"
      echo "   check which model is actually answering — you may have failed over."
      return
    fi
  done
}
# ---- primary --------------------------------------------------------------
PRIMARY=""
while [[ -z "${PRIMARY}" ]]; do
  prov="$(choose_provider "PRIMARY" 0)"
  case "${prov}" in
    ou) PRIMARY="$(pick_ou "Primary" 0)" ;;
    or) PRIMARY="$(pick_or "Primary" 0)" || {
          if (( HAVE_LL )); then echo "Falling back to the OU AI Sandbox." >&2; PRIMARY="$(pick_ou "Primary" 0)"; else exit 1; fi
        } ;;
  esac
done
# ---- fallback -------------------------------------------------------------
FB=()
prov="$(choose_provider "FALLBACK" 1)"
case "${prov}" in
  ou)   mapfile -t FB < <(pick_ou "Fallback" 1) ;;
  or)   mapfile -t FB < <(pick_or "Fallback" 1) || FB=() ;;
  none) FB=() ;;
esac
# ---- go -------------------------------------------------------------------
apply_models "${PRIMARY}" ${FB[@]+"${FB[@]}"}
warn_weak_fallback ${FB[@]+"${FB[@]}"}
