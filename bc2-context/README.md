# Build Challenge 2 — Context & Prompt Design (50 pts, due Fri Jul 17, 11:59 PM CT)

**Objective.** Deliberately induce a context-window failure on a multi-step
task (drift, forgotten instructions, or overflow), then fix it using
techniques from the pre-read (compaction, just-in-time retrieval,
note-taking, system-prompt altitude). Document what broke, what you changed,
and evidence it's fixed.

**Starter state.** `overload_task.py` stuffs 30 policy documents into one
request when only 3 matter — including expired/rescinded look-alike policies
with different numbers. Run it a few times and capture the failure — wrong
citations (the AS-12/AS-27 traps), invented provisions, ignored
instructions, or overflow. Strong models sometimes survive it; if yours
does, reproduce the failure with a smaller model
(`COURSE_MODEL="gemma4-small" python3 bc2-context/overload_task.py`) —
which is itself the lesson: context robustness varies by model, and your
fix must not depend on the model being heroic. Note the starter's token
cost either way (~25k tokens per question!) — your fix should crush that.

**Your fix** goes in `fixed_task.py`. As in BC1, the code itself is a
delegation job: pick the strategy **yourself** (compaction, retrieval,
note-taking, prompt altitude — that choice is what's graded), then have your
AI copy `overload_task.py` to `fixed_task.py` and apply it. Keep the starter
intact as the "before" so the comparison is honest. Any strategy from the
pre-read is fair game; retrieval can be keyword-based (OpenRouter has no
embedding model — that constraint is real and worth noting in your write-up).

**Prompts are software artifacts.** The analyst prompt lives in
`prompts/bc2-analyst.txt`. Every change you make to it (and any prompt you
add) gets a `PROMPTS.md` entry; your write-up must cite **at least two**
entries as evidence of the fix.

**Acceptance check.**
- A documented failure from the starter (output + why it failed).
- `python3 bc2-context/fixed_task.py` answers with exactly AS-7 / AS-18 /
  AS-24 and correct details, at a fraction of the starter's token cost
  (compare `STATS`).
- ≥2 cited `PROMPTS.md` entries.
- A **delegation log** in the write-up: which AI built the fix, your key
  prompts, the strategy you chose and why, and how you verified the result.

**Rubric (50 pts).** Failure reproduced & explained (15) · fix works and is
cheaper, with measured before/after (20) · prompt changelog discipline (10) ·
Build Journal entry (5).
