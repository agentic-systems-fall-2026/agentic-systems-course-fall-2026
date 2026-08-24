# Build Challenge 5 — Observability & Oversight (50 pts, due Wed Jul 29, 11:59 PM CT)

**Objective.** Instrument your agent stack (OpenClaw gateway + your code)
with logging/tracing, add human-in-the-loop checkpoints, and pull cost/usage
data from the gateway. Then diagnose one real failure from your own traces
and write up the incident: what happened, how the trace showed it, what you
changed.

**Starter state.** `quiet_agent.py` — a three-step pipeline with zero
observability. It usually works; when it doesn't, you can't tell where.

**Your job.** (Division of labor: YOU design the trace schema — what would a
stranger need to reconstruct what happened? — and the approval policy; your
AI writes the logging code to your schema. The incident diagnosis in step 4
must be entirely yours: diagnosing from a trace is the human oversight skill
this course exists to teach. Include a delegation log in the write-up.)
1. **Trace:** structured JSONL logging for every step — timestamp, step name,
   model, prompt/response sizes, tokens (from `common.llm.STATS` or response
   usage), latency, and the decision taken.
2. **Oversight:** a human-in-the-loop gate before `summary.md` is written —
   show the pending output + cost so far, require explicit approval, and log
   the human decision in the trace too.
3. **Cost:** pull usage from the gateway (`~/.openclaw/gateway.log`, the
   Control UI on port 18789) and reconcile it against your own counts.
4. **Incident:** break something for real (kill the network mid-step, swap in
   a bad model name, poison a prompt) — then diagnose it *from the trace
   alone* and write the incident report.

**Acceptance check.** A trace file a stranger could follow; an approval gate
that actually blocks; a cost reconciliation (your numbers vs. the gateway's);
and an incident write-up citing specific trace lines. An asciinema recording
of the live diagnosis session (`asciinema rec bc5-incident.cast`) is welcome
supporting evidence.

**Rubric (50 pts).** Trace quality/completeness (15) · working HITL gate,
logged (10) · cost reconciliation (10) · incident diagnosis from trace (10) ·
Build Journal entry (5).
