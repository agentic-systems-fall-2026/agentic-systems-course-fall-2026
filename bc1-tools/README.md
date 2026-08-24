# Build Challenge 1 — Tool/Function Calling (50 pts, due Wed Jul 15, 11:59 PM CT)

**Objective.** Design 2–3 custom tools for your agent, get them working, and
trace a tool call end-to-end (request → tool spec → call → result → final
answer). Redesign at least one tool interface to return **token-efficient**
results, and show the measured before/after.

**You are not graded on writing Python.** Build the code however you want —
having an AI write all of it is expected and encouraged. You are graded on
what only you can do: designing the tool interfaces, verifying the result,
measuring the improvement, and explaining every design choice in your own
words.

**Starter state.** `agent.py` runs now: a JSON tool-loop over the sample notes
in `data/`, printing a full trace each step. One tool
(`search_notes_verbose`) is deliberately wasteful.

## The workflow (spec → delegate → verify → measure)

1. **Spec first (before any code).** Write the `TOOLS_SPEC` lines for your
   new tools — the exact JSON the model will send, and one line on what comes
   back. This contract is your core design artifact. Think: what arguments
   does the tool need? What is the *smallest* useful thing it can return?

2. **Delegate.** Have your AI implement the tools. A brief that works well:
   paste in all of `agent.py`, then:
   > *Add these tools to this agent. Only change `TOOLS_SPEC` and
   > `run_tool` — nothing else. Here are my specs: …*
   Scoped instructions plus a contract — that's Day 2's delegation lesson
   applied to your own toolchain.

3. **Verify.** Run `python3 bc1-tools/check.py` — it calls each tool in your
   spec directly and reports PASS/FAIL without spending tokens. If something
   fails, paste the output back to your AI and iterate. Then run the real
   thing: `python3 bc1-tools/agent.py "<your task>"`.

4. **Measure.** Run a task that uses `search_notes_verbose`, note `STATS`
   (calls, tokens). Redesign the interface to be token-efficient (e.g.,
   return filename + matching line instead of whole documents), rerun the
   same task, capture `STATS` again.

## Acceptance check

- `python3 bc1-tools/check.py` passes on your tools.
- `python3 bc1-tools/agent.py "<your task>"` completes using at least one of
  YOUR tools, **chosen by the model** (not hard-coded).
- Write-up includes: one full trace; the before/after `STATS` comparison for
  the wasteful vs. token-efficient tool; and a **delegation log** — which AI
  you used, your key prompts, one thing it got wrong, and how you caught it.
- System prompt changes are in `prompts/` with `PROMPTS.md` entries.

**Rubric (50 pts).** Tool interface design & spec quality (10) · tools work &
are model-discoverable from the spec (10) · token-efficiency redesign with
measured before/after (15) · write-up: trace, delegation log, design choices
explained in your own words (10) · Build Journal entry (5).

Pairing is encouraged; write-ups are individual. Be ready to explain every
line you submit — "the AI wrote it and I don't know why" is the one answer
that costs points.
