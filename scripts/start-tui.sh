#!/usr/bin/env bash
# Terminal 2: wait for the gateway to be healthy, then launch the OpenClaw TUI.
# Aborts (without starting the TUI) if the gateway pre-flight failed.
# Put OpenClaw + node on PATH FIRST — VS Code task shells don't load ~/.bashrc/nvm.
export PATH="/usr/local/share/npm-global/bin:/usr/local/share/nvm/current/bin:${HOME:-/home/node}/.local/bin:${HOME:-/home/node}/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
set -uo pipefail
# Extra, image-agnostic resolution (best effort; never fatal).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh" 2>/dev/null || true

STATUS="${HOME}/.openclaw/.preflight"
HEALTH="http://127.0.0.1:18789/healthz"
# How long to wait for the gateway, in REAL seconds. 0 (default) = no timeout:
# the TUI waits as long as it takes. A cold gateway start on a 2-core Codespace
# can exceed 2 minutes, which is why a short fixed timeout was a bug.
TIMEOUT="${OPENCLAW_TUI_WAIT:-0}"

# Load the gateway token so the TUI can authenticate to the gateway.
if [[ -f "${HOME}/.openclaw/.env" ]]; then set -a; . "${HOME}/.openclaw/.env"; set +a; fi

GWLOG="${HOME}/.openclaw/gateway.log"
GWLOG_POS=0

# Stream any NEW gateway-log lines into this terminal (prefixed), so you can
# watch the pre-flight / install / startup progress instead of a silent wait.
show_gateway_progress() {
  [[ -f "${GWLOG}" ]] || return 0
  local cur
  cur="$(wc -l < "${GWLOG}" 2>/dev/null || echo 0)"
  if (( cur > GWLOG_POS )); then
    sed -n "$((GWLOG_POS + 1)),${cur}p" "${GWLOG}" 2>/dev/null | sed 's/^/   gateway │ /'
    GWLOG_POS="${cur}"
  fi
}

echo "⏳  Waiting for the OpenClaw gateway to come up ..."
echo "    (streaming the gateway's startup log below — full log: ~/.openclaw/gateway.log)"
if (( TIMEOUT > 0 )); then
  echo "    (will give up after ${TIMEOUT}s — OPENCLAW_TUI_WAIT)"
else
  echo "    (no timeout — a cold gateway start can take a few minutes; Ctrl-C to stop)"
fi

SECONDS=0
LAST_NOTE=0
while :; do
  show_gateway_progress
  if [[ "$(cat "${STATUS}" 2>/dev/null)" == "fail" ]]; then
    reason="$(cat "${HOME}/.openclaw/.preflight_reason" 2>/dev/null || true)"
    if [[ "${reason}" == "nokey" || "${reason}" == "invalid" ]]; then
      # The Gateway terminal is prompting for a key — keep waiting, don't bail.
      if (( SECONDS - LAST_NOTE >= 15 )); then
        echo "🔑  The 'OpenClaw: Gateway' terminal is asking for your API key — enter it there; I'll wait."
        LAST_NOTE=${SECONDS}
      fi
      sleep 1
      continue
    fi
    echo
    echo "⛔  Gateway did not start (key pre-flight failed)."
    echo "    Fix your key:  bash scripts/set-key.sh"
    echo "    Then re-run the 'OpenClaw: Gateway' task (Terminal → Run Task)."
    exit 1
  fi
  if curl -fsS -m 2 -o /dev/null "${HEALTH}" 2>/dev/null \
     || timeout 1 bash -c ':</dev/tcp/127.0.0.1/18789' 2>/dev/null; then
    show_gateway_progress
    echo "✅  Gateway is up (after ~${SECONDS}s) — launching the TUI ..."
    sleep 1
    # Re-read the token now — the gateway may have just generated/persisted it.
    TUI_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"
    [[ -z "${TUI_TOKEN}" && -f "${HOME}/.openclaw/.env" ]] && \
      TUI_TOKEN="$(grep -E '^OPENCLAW_GATEWAY_TOKEN=' "${HOME}/.openclaw/.env" | tail -n1 | cut -d= -f2- || true)"
    if [[ -n "${TUI_TOKEN}" ]]; then exec openclaw tui --token "${TUI_TOKEN}"; else exec openclaw tui; fi
  fi
  if (( TIMEOUT > 0 && SECONDS >= TIMEOUT )); then
    echo "⏱️   Timed out after ${SECONDS}s waiting for the gateway."
    echo "    Check the 'OpenClaw: Gateway' terminal; once it's healthy, run:  openclaw tui"
    exit 1
  fi
  if (( SECONDS - LAST_NOTE >= 15 )); then
    echo "   …still waiting (${SECONDS}s elapsed — a cold start can take a few minutes on a 2-core box)"
    LAST_NOTE=${SECONDS}
  fi
  sleep 1
done
