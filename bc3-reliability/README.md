# Build Challenge 3 — Reliability & Rollback (50 pts, due Tue Jul 21, 11:59 PM CT)

**Objective.** Start from the provided broken-agent skeleton: diagnose its
failure modes, then add retries, timeouts, fallbacks, and a harness with a
rollback path. Your agent must checkpoint to disk and **survive a Codespace
stop/restart mid-task** — demonstrate recovery from that interruption and
from at least one injected failure.

**Starter state.** `broken_agent.py` processes `requests.jsonl` and usually
"succeeds" — while hiding at least six reliability flaws (the docstring lists
the categories; find them in the code).

**Protocol.**
1. **Diagnose before fixing.** List every flaw you find and the bad day that
   triggers it (network blip, chatty model reply, crash mid-run, restart…).
   Finding them is open-book: read the code, or ask your AI to review it —
   both are legitimate. What's graded is **verification**: for each flaw, show
   the trigger actually breaking the starter (or explain precisely why it
   would). An AI-generated flaw list you can't demonstrate earns nothing —
   never trust a reviewer you didn't check, human or machine.
2. Build `fixed_agent.py` (delegate the coding; you own the failure-mode
   analysis and the recovery demos): timeouts + retries with backoff, JSON validation
   with a fallback path, staged output with rollback (never destroy the last
   good report), and a checkpoint file so a restart resumes where it left off
   without re-spending tokens.
3. **Demonstrate recovery twice:** (a) kill/stop the Codespace mid-run and
   show it resumes correctly; (b) inject one failure (e.g., point BASE at a
   bad URL for a few items, or corrupt a model reply) and show the harness
   handles it and the report stays valid. A helper is provided for the failure
   injection: `python3 bc3-reliability/hang-server.py` stands up a local
   endpoint that hangs, resets, stalls, or returns junk on demand (run it
   with `--help` for the modes). `nc` is also on the toolbelt if you prefer a
   one-liner.

**Acceptance check.** Both recovery demos captured in the write-up — an
**asciinema recording is the preferred evidence** (`asciinema rec
bc3-recovery.cast`, commit the .cast file; trace excerpts or screenshots
also accepted) — report never left corrupt/half-written, and re-running
after success is idempotent. Include a **delegation log**: which AI wrote
what, and how you verified each fix does what it claims.

> **Recording tip.** If you drive the kill/restart from a shell script,
> do **not** use `set -e` in that script: when you kill the background
> agent the shell exits on that line and your asciinema capture stops
> right before the resume, which is the most important half of the demo.
> Record with `set +e` (or no `set -e`) around the kill so the recovery
> is captured.

**Rubric (50 pts).** Diagnosis completeness (15) · fixes: retries/timeouts/
validation/fallback (15) · checkpoint + rollback with demonstrated recovery
(15) · Build Journal entry (5).
