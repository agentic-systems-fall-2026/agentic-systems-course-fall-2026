# prompts/

Every prompt your systems use lives here as a file — never inline-only in
code. Load them via `common.llm.load_prompt("<file>")`.

Rules (graded in BC2, expected everywhere):
1. One file per prompt, named `<challenge>-<role>.txt` (e.g. `bc1-agent-system.txt`).
2. Every edit gets a row in the root `PROMPTS.md` changelog: what changed,
   why, and the observed effect.
3. Prompts are reviewed like code — small, motivated diffs beat rewrites.
