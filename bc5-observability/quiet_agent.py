#!/usr/bin/env python3
"""Build Challenge 5 starter — an agent with ZERO observability.

Run from the repo root:  python3 bc5-observability/quiet_agent.py

It plans a three-step research summary and usually produces something. But
when the output is wrong — and sometimes it is — you have nothing: no logs,
no trace, no cost data, no way to say WHICH step went sideways. On purpose.

YOUR JOB (see README.md): instrument this stack — structured trace logging
(JSONL: timestamp, step, model, tokens, latency, decision), a human-in-the-
loop checkpoint before anything is written to disk, and cost/usage pulled
from the gateway (~/.openclaw/gateway.log and/or common.llm.STATS). Then
break something on purpose, diagnose it FROM YOUR OWN TRACE, and write the
incident up: what happened, how the trace showed it, what you changed.
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from common.llm import chat

HERE = pathlib.Path(__file__).resolve().parent
TOPIC = "why long-running agents need checkpoints"


def main():
    plan = chat([{"role": "user", "content":
                  f"List 3 short bullet questions someone should answer to explain: {TOPIC}"}])
    answers = chat([{"role": "user", "content":
                     "Answer each question in 2 sentences:\n" + plan}])
    summary = chat([{"role": "user", "content":
                     "Compress this into a 4-sentence summary for a student:\n" + answers}])
    (HERE / "summary.md").write_text(f"# {TOPIC}\n\n{summary}\n")
    print(summary)
    print("\n(wrote bc5-observability/summary.md — but could you defend HOW it got there?)")


if __name__ == "__main__":
    main()
