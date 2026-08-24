# Build Challenge 4 — Evaluation (50 pts, due Fri Jul 24, 11:59 PM CT)

**Objective.** Build an evaluation harness for your capstone slice:
assertions, an LLM-as-judge calibrated against a handful of your own human
labels, and an error-analysis pass. Run a **scoped sweep** (dozens of cases,
with response caching) against OpenRouter and report metrics with
thresholds — then wire the harness into CI as a **regression gate**.

**Starter state.** `harness.py` (three-layer harness, runnable now against a
plain model call), `cases.jsonl` (8 seed cases showing the patterns:
must_contain / must_not_contain / max_chars / judge_criteria), and
`test_eval.py` (the pytest wrapper CI runs).

**Your job.** (Wiring `target()` to your system is a fine delegation task
for your AI. Everything else in this BC is deliberately human work: the
cases, the labels, and the error analysis are YOUR judgment — an eval built
by the same kind of model it evaluates, unchecked, is circular.)
1. Point `target()` at YOUR system and grow `cases.jsonl` to dozens of cases
   that cover its real failure modes (including at least one refusal case
   and one formatting case).
2. Calibrate the judge: hand-label ~10 outputs **yourself**, report
   agreement, adjust criteria until you trust it.
3. Do the error-analysis pass on `last_run.json` — your write-up's most
   valuable section is what the *failures* taught you.
4. **CI regression gate:** add your `OPENROUTER_API_KEY` as a GitHub Actions
   *repository secret* (Settings → Secrets and variables → Actions). The
   included workflow then runs a small live sweep (~5 cases, temp 0, cached,
   capped so a push costs pennies) on every push. Never commit the key — key
   hygiene is part of the grade and previews Session 9.

**Acceptance check.** Sweep report with pass rate vs. threshold + judge
calibration numbers; a link to a **green** Actions run; and a link to one
**deliberately broken** run proving the gate catches a regression.

**Rubric (50 pts).** Case quality & coverage (15) · judge calibration honesty
(10) · error analysis depth (10) · CI gate working, green + broken runs, key
hygiene (10) · Build Journal entry (5).
