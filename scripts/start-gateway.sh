#!/usr/bin/env bash
# Terminal 1: validate the key, then run the OpenClaw gateway in the foreground.
# If the key check fails, the gateway is NOT started.
# Put OpenClaw + node on PATH FIRST — VS Code task shells don't load ~/.bashrc/nvm.
export PATH="/usr/local/share/npm-global/bin:/usr/local/share/nvm/current/bin:${HOME:-/home/node}/.local/bin:${HOME:-/home/node}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
set -uo pipefail
# Extra, image-agnostic resolution (best effort; never fatal).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "════════════════════════════════════════════════════"
echo "  OpenClaw Gateway  (OU LiteLLM first, OpenRouter fallback)"
echo "════════════════════════════════════════════════════"

# If a gateway is already up or being started in the background (by the
# devcontainer postStartCommand → scripts/gateway-daemon.sh), don't start a
# second one — attach to its log so this terminal still shows what's happening.
# OPENCLAW_GATEWAY_FOREGROUND=1 marks the daemon's own (background) invocation,
# which must skip this check and actually start the gateway.
_daemon_pid="$(cat "${HOME}/.openclaw/.gateway.pid" 2>/dev/null || true)"
if [[ "${OPENCLAW_GATEWAY_FOREGROUND:-}" != "1" ]] && {
     curl -fsS -m 2 -o /dev/null "http://127.0.0.1:18789/healthz" 2>/dev/null \
     || timeout 1 bash -c ':</dev/tcp/127.0.0.1/18789' 2>/dev/null \
     || { [[ -n "${_daemon_pid}" ]] && kill -0 "${_daemon_pid}" 2>/dev/null; }; }; then
  echo "✅  Gateway is already running (auto-started in the background)."
  echo "    Streaming its log — Ctrl-C stops this view only, NOT the gateway."
  touch "${HOME}/.openclaw/gateway.log" 2>/dev/null || true
  exec tail -n 40 -F "${HOME}/.openclaw/gateway.log"
fi

# Pre-flight, with an interactive first-run rescue: if no (working) key is
# found and we're in a real terminal — the normal case when the "OpenClaw:
# Gateway" task opens on folder open — prompt for a key right here instead of
# aborting. Students paste their OU Sandbox key (sk-) or OpenRouter key
# (sk-or-) and startup continues; nothing to rebuild.
_pf_tries=0
until bash "${REPO_DIR}/scripts/preflight.sh"; do
  reason="$(cat "${HOME}/.openclaw/.preflight_reason" 2>/dev/null || echo unknown)"
  _pf_tries=$((_pf_tries+1))
  if [[ "${OPENCLAW_GATEWAY_FOREGROUND:-}" != "1" ]] && [[ -t 0 || -t 1 ]] \
     && [[ "${reason}" == "nokey" || "${reason}" == "invalid" ]] && (( _pf_tries <= 3 )); then
    echo
    echo "🔑  Let's fix that right now (attempt ${_pf_tries}/3) — paste ONE key:"
    echo "    • OU LiteLLM Sandbox key (starts with sk-) — first choice, from your Sandbox invitation"
    echo "    • OpenRouter key (starts with sk-or-) — also works, from openrouter.ai → Settings → Keys"
    if ! bash "${REPO_DIR}/scripts/set-key.sh"; then
      echo "⛔  No key entered — gateway not started. Run 'bash scripts/set-key.sh' any time, then re-run this task."
      exit 1
    fi
    continue
  fi
  echo "⛔  Gateway aborted — key pre-flight failed (see message above)."
  exit 1
done

if ! command -v openclaw >/dev/null 2>&1; then
  echo "⚙️  openclaw not found — installing it now (one-time, ~1-2 min)…"
  bash "${REPO_DIR}/scripts/install-openclaw.sh" || true
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true
fi
if ! command -v openclaw >/dev/null 2>&1; then
  echo "fail" > "${HOME}/.openclaw/.preflight"
  echo "❌ openclaw still not found after install attempt."
  echo "   PATH=${PATH}"
  echo "   on disk: $(find "${HOME}" /usr/local/share /usr/local/lib -maxdepth 5 -name openclaw -type f 2>/dev/null | head -3 | tr '\n' ' ')"
  echo "   Fix: open a terminal and run  bash .devcontainer/setup.sh"
  exit 1
fi

# Ensure a startable config exists. Render defaults if missing, and always make
# sure the container-critical keys are set. These are surgical — they do NOT
# touch any model selection you made with select-model.sh, UNLESS that
# selection points at a provider whose key just failed pre-flight (then we
# re-render onto the provider that actually works).
PREF_PROVIDER="$(cat "${HOME}/.openclaw/.provider" 2>/dev/null || true)"
OK_PROVIDERS="$(cat "${HOME}/.openclaw/.providers_ok" 2>/dev/null || true)"
if [[ ! -f "${HOME}/.openclaw/openclaw.json" ]]; then
  echo "No config found — rendering defaults…"
  bash "${REPO_DIR}/scripts/configure.sh" || true
else
  cur_provider="$(grep -oE 'primary: "(litellm|openrouter)/' "${HOME}/.openclaw/openclaw.json" 2>/dev/null | grep -oE 'litellm|openrouter' | head -1 || true)"
  if [[ -n "${cur_provider}" && -n "${PREF_PROVIDER}" && "${cur_provider}" != "${PREF_PROVIDER}" ]] \
     && ! grep -qw "${cur_provider}" <<< "${OK_PROVIDERS}"; then
    echo "Current model uses ${cur_provider}, but that key didn't validate — re-pointing at ${PREF_PROVIDER}…"
    OPENCLAW_PROVIDER="${PREF_PROVIDER}" bash "${REPO_DIR}/scripts/configure.sh" || true
  fi
fi
# Load persisted secrets (OpenRouter key + gateway token) into this process.
mkdir -p "${HOME}/.openclaw"
if [[ -f "${HOME}/.openclaw/.env" ]]; then set -a; . "${HOME}/.openclaw/.env"; set +a; fi

# Guarantee a stable gateway client token exists (older configs predate it).
if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
  OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 24 2>/dev/null || (head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'))"
  export OPENCLAW_GATEWAY_TOKEN
  printf 'OPENCLAW_GATEWAY_TOKEN=%s\n' "${OPENCLAW_GATEWAY_TOKEN}" >> "${HOME}/.openclaw/.env"
fi

openclaw config set gateway.mode local                            >/dev/null 2>&1 || true
openclaw config set gateway.bind loopback                         >/dev/null 2>&1 || true
openclaw config set gateway.auth.mode token                       >/dev/null 2>&1 || true
openclaw config set gateway.auth.token "${OPENCLAW_GATEWAY_TOKEN}" >/dev/null 2>&1 || true

echo "🚀  Starting gateway on http://127.0.0.1:18789  (Ctrl-C to stop) ..."
exec openclaw gateway run
