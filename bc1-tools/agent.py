#!/usr/bin/env python3
"""Build Challenge 1 starter — a tool-calling agent you will extend.

Run from the repo root:  python3 bc1-tools/agent.py "what's in my notes about the demo?"

What works now: a loop where the model chooses tools as JSON actions, with a
full end-to-end trace printed for every step (request size → chosen tool →
result size → next step).

YOUR JOB (see README.md):
  1. Add 2–3 custom tools of your own design (marked TODO below).
  2. Redesign one tool interface to be token-efficient, and show the
     before/after in your write-up. `search_notes_verbose` is deliberately
     wasteful — it returns whole documents when a snippet would do.
"""
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from common.llm import chat, load_prompt, STATS

DATA = pathlib.Path(__file__).resolve().parent / "data"
MAX_STEPS = 12

TOOLS_SPEC = """Available tools (reply with ONE JSON object per turn):
{"tool": "list_notes"}                          -> filenames in the notes folder
{"tool": "search_notes_verbose", "query": "x"}  -> FULL TEXT of every note containing x (wasteful — improve me!)
{"tool": "read_note", "name": "<file>"}         -> full text of one note
{"tool": "finish", "answer": "<final answer>"}  -> end the task
"""
# TODO(you): add 2-3 custom tools. Ideas: word_count, a calculator,
# a token-efficient search that returns (filename, matching line) pairs,
# a note-writer. Update TOOLS_SPEC *and* run_tool together — the spec is
# the model's only knowledge of your interface.


def run_tool(act: dict) -> str:
    t = act.get("tool")
    if t == "list_notes":
        return json.dumps(sorted(p.name for p in DATA.glob("*.txt")))
    if t == "search_notes_verbose":
        q = act.get("query", "").lower()
        out = {p.name: p.read_text() for p in DATA.glob("*.txt")
               if q in p.read_text().lower()}
        return json.dumps(out) if out else "no matches"
    if t == "read_note":
        p = DATA / pathlib.Path(act.get("name", "")).name
        return p.read_text() if p.exists() else "ERROR: no such note"
    return "ERROR: unknown tool " + repr(t)


def parse_action(out: str) -> dict:
    """Return the first valid JSON object with a "tool" key found in `out`.

    Models sometimes emit two JSON objects, or an object followed by prose.
    A greedy first-{-to-last-} regex would swallow all of it and crash
    json.loads with "Extra data" — so decode incrementally instead.
    (Foreshadowing BC3: never trust model output to be well-formed.)
    """
    dec = json.JSONDecoder()
    for m in re.finditer(r"\{", out):
        try:
            obj, _ = dec.raw_decode(out, m.start())
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and "tool" in obj:
            return obj
    return {}


def main():
    task = " ".join(sys.argv[1:]) or "Summarize what my notes say about the capstone demo."
    msgs = [{"role": "system", "content": load_prompt("bc1-agent-system.txt")},
            {"role": "user", "content": TOOLS_SPEC + "\nTASK: " + task}]
    for step in range(1, MAX_STEPS + 1):
        out = chat(msgs)
        act = parse_action(out)
        print(f"── step {step}: request≈{sum(len(x['content']) for x in msgs)} chars"
              f" → chose {act.get('tool')} {({k: v for k, v in act.items() if k not in ('tool', 'answer')})}")
        if act.get("tool") == "finish":
            print("\nANSWER:", act.get("answer", ""))
            break
        obs = run_tool(act)
        print(f"          tool returned {len(obs)} chars")
        msgs += [{"role": "assistant", "content": out},
                 {"role": "user", "content": "OBSERVATION:\n" + obs}]
    else:
        print("hit step limit without finishing")
    print(f"\nSTATS: {STATS}")


if __name__ == "__main__":
    main()
