#!/usr/bin/env python3
"""BC1 smoke check — verifies your tools are wired in, without spending tokens.

Run from the repo root or bc1-tools/:  python3 bc1-tools/check.py

What it does: reads TOOLS_SPEC, extracts each example JSON action, and calls
run_tool() with it directly (no LLM involved). If your AI-generated code
didn't actually connect a tool, you find out here — in plain English —
instead of via a traceback mid-run.

If a line FAILs, paste this script's output to your AI assistant and ask it
to fix run_tool. Rerun until everything passes, then do a real run with
agent.py.
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import agent  # noqa: E402  (your agent.py)

STARTER_TOOLS = {"list_notes", "search_notes_verbose", "read_note", "finish"}


def specs():
    """Yield (tool_name, example_action) for each JSON example in TOOLS_SPEC."""
    dec = json.JSONDecoder()
    for line in agent.TOOLS_SPEC.splitlines():
        m = re.search(r"\{", line)
        if not m:
            continue
        try:
            obj, _ = dec.raw_decode(line, m.start())
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and "tool" in obj:
            yield obj["tool"], obj


def main() -> int:
    results, custom = [], []
    for name, act in specs():
        if name == "finish":
            continue
        if name not in STARTER_TOOLS:
            custom.append(name)
        placeholder = any(isinstance(v, str) and v.startswith("<")
                          for k, v in act.items() if k != "tool")
        try:
            out = agent.run_tool(act)
        except Exception as e:  # tool crashed outright
            results.append(("FAIL", name, f"crashed: {type(e).__name__}: {e}"))
            continue
        if out.startswith("ERROR: unknown tool"):
            results.append(("FAIL", name, "in TOOLS_SPEC but run_tool doesn't know it"))
        elif out.startswith("ERROR") and placeholder:
            results.append(("SKIP", name, "needs real arguments — test via agent.py"))
        else:
            results.append(("PASS", name, f"returned {len(out)} chars"))

    for status, name, note in results:
        print(f"  {status}: {name} — {note}")

    fails = [r for r in results if r[0] == "FAIL"]
    print()
    if len(custom) < 2:
        print(f"NOTE: {len(custom)} custom tool(s) found in TOOLS_SPEC — the "
              "assignment asks for 2–3 beyond the starter set.")
    if fails:
        print(f"{len(fails)} tool(s) failing. Paste this output to your AI "
              "assistant and ask it to fix run_tool, then rerun this check.")
        return 1
    print("All wired up. Now do a real run: "
          'python3 bc1-tools/agent.py "<your task>"')
    return 0


if __name__ == "__main__":
    sys.exit(main())
