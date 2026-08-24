#!/usr/bin/env python3
"""Build Challenge 3 starter — the BROKEN agent. It "works"… until it doesn't.

Run from the repo root:  python3 bc3-reliability/broken_agent.py

The task: process the queue of change requests in requests.jsonl — for each
one, ask the model to classify risk, then append approved items to the
report. Simple. On a good day it completes. But this agent is riddled with
reliability flaws, some visible, some waiting for a bad day.

DO NOT simply rewrite it. Diagnose first (README has the protocol), then fix:
retries, timeouts, fallbacks, a harness with a rollback path, and disk
checkpoints so it SURVIVES a Codespace stop/restart mid-task. Keep this file
as the "before"; build yours as fixed_agent.py.

Planted flaws include (find them all — there are more than four):
  - a network call with no timeout and no retry
  - a bare `except: pass` that swallows failures silently
  - output overwritten from scratch each run — a crash mid-run destroys
    yesterday's report (no staging, no rollback)
  - no checkpoint: a restart reprocesses everything (and double-spends tokens)
  - JSON parsed straight from the model with no validation — one chatty
    reply poisons the report
  - partial failure looks like success: the exit banner prints even when
    items silently failed
"""
import json
import pathlib
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from common.llm import _key, BASE, DEFAULT_MODEL  # noqa: using internals is a smell, too

HERE = pathlib.Path(__file__).resolve().parent
REPORT = HERE / "approved_report.md"


def classify(text):
    body = json.dumps({"model": DEFAULT_MODEL, "temperature": 0, "max_tokens": 200,
                       "messages": [{"role": "user", "content":
                                     'Classify this change request. Reply ONLY with JSON '
                                     '{"risk": "low|medium|high", "reason": "<one line>"}\n\n' + text}]})
    req = urllib.request.Request(BASE + "/v1/chat/completions", data=body.encode(),
                                 headers={"Authorization": "Bearer " + _key(),
                                          "Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req))          # FLAW: no timeout, no retry
    out = resp["choices"][0]["message"]["content"]
    return json.loads(out)                                  # FLAW: no validation / no fence-stripping


def main():
    requests_file = HERE / "requests.jsonl"
    items = [json.loads(l) for l in requests_file.read_text().splitlines() if l.strip()]
    REPORT.write_text("# Approved Changes\n\n")             # FLAW: destroys previous report immediately
    approved = 0
    for item in items:                                      # FLAW: no checkpoint — restart = start over
        try:
            verdict = classify(item["request"])
            if verdict["risk"] == "low":
                with REPORT.open("a") as f:
                    f.write(f"- **{item['id']}** ({verdict['risk']}): "
                            f"{item['request'][:80]} — {verdict['reason']}\n")
                approved += 1
        except Exception:
            pass                                            # FLAW: silent failure
    print(f"✅ Done! {approved} low-risk changes approved and written to {REPORT.name}")
    # FLAW: "Done!" prints even if half the queue silently failed.


if __name__ == "__main__":
    main()
