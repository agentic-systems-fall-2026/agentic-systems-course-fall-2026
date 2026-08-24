"""Shared LLM client for all Build Challenges. Stdlib only — no pip installs.

Endpoint auto-detect (matches the Codespace's gateway behavior):
  1. OU LiteLLM Sandbox — used when LITELLM_API_KEY is set (first choice)
  2. OpenRouter        — used otherwise (your own OPENROUTER_API_KEY)

Usage (from any bc*/ script):
    import sys, pathlib; sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    from common.llm import chat, STATS

    reply = chat([{"role": "user", "content": "hello"}])
    print(STATS)  # {'calls': 1, 'tokens': 123}

Features you will need across the course:
  - STATS: running call/token counts (Day 9 cost lab & BC4 sweeps read these)
  - cache=True: disk cache keyed on the exact request (BC4 requires caching;
    it is also the biggest lever in the Day 9 cost-cut exercise)
  - model=...: route a call to a cheaper model (on LiteLLM: an id from the
    Sandbox catalog; on OpenRouter: any slug from openrouter.ai/models)
"""
import hashlib
import json
import os
import pathlib
import time
import urllib.error
import urllib.request

_LL_KEY = os.environ.get("LITELLM_API_KEY", "")
if _LL_KEY and _LL_KEY != "sk-REPLACE_ME":
    PROVIDER = "OU LiteLLM Sandbox"
    _KEY_VAR = "LITELLM_API_KEY"
    BASE = os.environ.get("LITELLM_BASE_URL", "https://litellm.lib.ou.edu")
    DEFAULT_MODEL = os.environ.get("COURSE_MODEL", "Qwen3 Coder 30B")
else:
    PROVIDER = "OpenRouter"
    _KEY_VAR = "OPENROUTER_API_KEY"
    BASE = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api")
    DEFAULT_MODEL = os.environ.get("COURSE_MODEL", "qwen/qwen3-coder")
CACHE_DIR = pathlib.Path(__file__).resolve().parents[1] / ".cache" / "llm"

STATS = {"calls": 0, "tokens": 0, "cache_hits": 0}


def _key() -> str:
    key = os.environ.get(_KEY_VAR, "")
    if not key:
        raise RuntimeError(
            f"{_KEY_VAR} is not set. In a Codespace it comes from your "
            "Codespaces secret; in GitHub Actions, from a repository secret."
        )
    return key


def chat(messages, model=DEFAULT_MODEL, max_tokens=700, temperature=0,
         cache=False, timeout=120, retries=2):
    """One chat completion against the course endpoint. Returns the assistant text."""
    body = {"model": model, "messages": messages,
            "max_tokens": max_tokens, "temperature": temperature}
    raw = json.dumps(body, sort_keys=True).encode()

    if cache:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        slot = CACHE_DIR / (hashlib.sha256(raw).hexdigest() + ".json")
        if slot.exists():
            STATS["cache_hits"] += 1
            return json.loads(slot.read_text())["text"]

    last = None
    for attempt in range(retries + 1):
        for base in (BASE + "/v1", BASE):
            try:
                req = urllib.request.Request(
                    base + "/chat/completions", data=raw,
                    headers={"Authorization": "Bearer " + _key(),
                             "Content-Type": "application/json"})
                resp = json.load(urllib.request.urlopen(req, timeout=timeout))
                text = resp["choices"][0]["message"]["content"]
                usage = resp.get("usage", {})
                STATS["calls"] += 1
                STATS["tokens"] += usage.get("total_tokens", 0)
                if cache:
                    slot.write_text(json.dumps(
                        {"text": text, "usage": usage, "model": model}))
                return text
            except urllib.error.HTTPError as e:
                # 4xx won't improve on retry; surface it immediately.
                if 400 <= e.code < 500:
                    raise RuntimeError(f"{PROVIDER} rejected the request "
                                       f"({e.code}): {e.read()[:300]}") from e
                last = e
            except Exception as e:  # timeouts, connection resets, 5xx
                last = e
        if attempt < retries:
            time.sleep(2 ** attempt)
    raise RuntimeError(f"{PROVIDER} unreachable after {retries + 1} attempts: {last}")


def load_prompt(name: str) -> str:
    """Load a prompt file from prompts/. Prompts are software artifacts:
    edit them there (never inline) and log every change in PROMPTS.md."""
    p = pathlib.Path(__file__).resolve().parents[1] / "prompts" / name
    return p.read_text()
