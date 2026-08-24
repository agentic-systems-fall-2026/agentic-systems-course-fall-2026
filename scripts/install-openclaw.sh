#!/usr/bin/env bash
# Install OpenClaw via the OFFICIAL installer (openclaw.ai/install.sh).
# NOTE: the npm package literally named "openclaw" on the public registry is a
# 0.0.0 placeholder stub — do NOT `npm install -g openclaw`.
#
# The official installer occasionally leaves an INCOMPLETE package (its first npm
# attempt fails, the retry installs over a partial dir / poisoned cache → a
# missing dist chunk like dist/argv-*.js). So we fully clean (dir + npm cache)
# before each attempt, verify the install actually loads, and retry if not.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/_env.sh" 2>/dev/null || true

# Healthy = on PATH, real version (not 0.0.0), and the module graph actually loads.
integrity_ok() {
  command -v openclaw >/dev/null 2>&1 || return 1
  local v out
  v="$(openclaw --version 2>/dev/null || true)"
  case "${v}" in *0.0.0*|"") return 1 ;; esac
  out="$(openclaw --help 2>&1 || true)"
  case "${out}" in *"Cannot find module"*|*ERR_MODULE_NOT_FOUND*) return 1 ;; esac
  return 0
}

if integrity_ok; then
  echo "OpenClaw already installed and healthy: $(openclaw --version 2>/dev/null)"
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "❌ npm not found on PATH — cannot install OpenClaw."; exit 1
fi

for attempt in 1 2 3; do
  echo "==> OpenClaw install attempt ${attempt}/3 (clean)…"
  # Full clean: remove any partial/stub package AND clear the npm cache.
  npm rm -g openclaw >/dev/null 2>&1 || true
  NGR="$(npm root -g 2>/dev/null || true)"
  [ -n "${NGR}" ] && rm -rf "${NGR}/openclaw" "${NGR}"/.openclaw-* 2>/dev/null || true
  npm cache clean --force >/dev/null 2>&1 || true

  OPENCLAW_NO_ONBOARD=1 OPENCLAW_NO_PROMPT=1 \
    bash -c 'curl -fsSL --proto "=https" --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt' || true

  # shellcheck disable=SC1091
  source "${HERE}/_env.sh" 2>/dev/null || true
  if integrity_ok; then
    echo "✓ OpenClaw installed and verified: $(openclaw --version 2>/dev/null)"
    exit 0
  fi
  echo "   install looked incomplete (missing module / stub) — cleaning and retrying…"
done

echo "✗ OpenClaw install failed after 3 clean attempts."
echo "  Manual: npm rm -g openclaw; npm cache clean --force; curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt"
exit 1
