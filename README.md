# Agentic Systems Course Repo — SDI 4243/5243 (OU, Fall 2026)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/agentic-systems-fall-2026/agentic-systems-course-fall-2026)

Your personal course repository. Everything you build this semester lives here:
five Build Challenges, your prompts, your Build Journal, and a CI eval gate. By
December 11 this repo *is* your portfolio.

## Before you start: two accounts

**1. GitHub Student Developer Pack — required, free.**
Apply at <https://education.github.com/pack> with your OU email. Approval is
usually minutes but can take a couple of days, so **do this today, not the
night before class.** The Pack is what gives you the Codespaces hours this
course runs on. Without it you will hit a billing wall mid-build.

**2. Your model gateway.**
The course standard is **OpenRouter**, and **$20 in OpenRouter credits is a
required course material** for this term, like a textbook.

- Create an account at <https://openrouter.ai> (Google or GitHub sign-in).
- Credits page → add $20. The card processor adds 5.5% ($0.80 minimum), so
  expect about $21.10. **Do not enable auto top-up.**
- Settings → Keys → create a key. It starts with `sk-or-`.
- Leave privacy settings at their defaults. Do **not** enable the
  prompt-logging discount for course work.

Cannot or would rather not spend the $20? The **OU AI Sandbox** is a fully
supported no-cost alternative and choosing it has no effect on your grade.
Email me and I will issue you a Sandbox key (it starts with `sk-`).

## Get started (once)

1. Click **Use this template → Create a new repository** (your account;
   private is fine). Do **not** fork.
2. On your new repo: **Code → Codespaces → the "···" menu → New with
   options…** — skip the plain "Create codespace" button, because it does not
   prompt for secrets. The creation page shows two **Recommended secrets**.
   Fill in `OPENROUTER_API_KEY` (the course standard) *or* `LITELLM_API_KEY`
   (the Sandbox alternative). If you set both, OpenRouter wins. Then click
   **Create codespace**. Forgot? No problem — the Gateway terminal will ask
   you for a key on first start.
3. Leave **Machine type** at **4-core**. The repo asks for it deliberately:
   an agent loop plus a gateway on 2 cores is slow enough to waste your time.
4. When VS Code asks **"Do you want to allow automatic tasks…?"**, click
   **Allow**. Do not let it time out. See the next section for why.
5. Smoke test: `python3 bc1-tools/agent.py "what do my notes say about the demo?"`

> **On the secrets step.** GitHub only shows the key fields on the **New with
> options…** path — the plain green "Create codespace" button skips them
> entirely. If you have never saved these secrets before you'll see two text
> boxes; if you've used them in another repo you'll see checkboxes instead.
> Either way, entering a value is optional and the codespace will build
> without one — the Gateway terminal will then ask you for a key on first
> start, or you can run `bash scripts/set-key.sh` yourself. Nothing is broken
> if you skip it; you just get asked later.

## What happens when your Codespace boots

This is worth understanding, because it is the thing most likely to confuse you
on day one, and because it is a small agentic system in its own right.

Creating a Codespace does **not** just give you an editor. The container build
runs `.devcontainer/setup.sh`, which installs the OpenClaw CLI, validates your
API key with `scripts/preflight.sh`, renders your personal OpenClaw config with
`scripts/configure.sh`, and then **starts the OpenClaw gateway as a background
daemon**. Two terminals open by themselves:

- **Gateway** — the live log of the agent runtime. When something misbehaves,
  the answer is usually in here. Read it before you retry anything.
- **TUI** — the chat interface where you actually work with your agent.

So: launch the Codespace, wait for the numbered setup steps to finish, and
OpenClaw is already running. You do not install or start anything by hand.

**No terminals appeared?** That is a VS Code security gate, not a broken setup.
Press `Cmd/Ctrl+Shift+P` → **Tasks: Run Task** → **OpenClaw: Gateway**, then
again for **OpenClaw: TUI**. Or run `bash scripts/start-gateway.sh` yourself.
Allowing automatic tasks once covers every future open.

## Models

The default is **`google/gemini-3.8-flash`** — a 1M-token context window, solid
tool calling, and cheap enough that $20 covers the whole term. The configured
fallback is `qwen/qwen3.7-flash`, which is cheaper still.

Change either with `bash scripts/select-model.sh`. You are *expected* to change
them: routing mechanical steps to cheap models and saving the expensive ones for
real reasoning is a graded skill in this course, not an optimization you do
later. Reflexively running the largest available model for everything is missing
the point.

## The scripts

Ten scripts run this repo; you will regularly use three. Full guide:
**[`scripts/README.md`](scripts/README.md)**. The short version:

- `bash scripts/start-tui.sh` — talk to your agent
- `bash scripts/select-model.sh` — change your model
- `bash scripts/sync-template.sh` — pull course updates when I announce one

When something breaks, start with `bash scripts/preflight.sh`.

## Layout

| Path | What it is |
|---|---|
| `bc1-tools/` … `bc5-observability/` | One folder per Build Challenge: a runnable starter + `README.md` with the spec, acceptance check, and rubric |
| `shipday/` | **Ship Day**: research → store → show with Tavily + Supabase + Netlify — spec, `check.py`, and rubric in its `README.md` |
| `common/llm.py` | Shared OpenRouter client (stdlib): `chat()`, `STATS` (cost tracking), `cache=True`, `load_prompt()` |
| `prompts/` + `PROMPTS.md` | Prompts as files + the required changelog. Prompts are software artifacts. |
| `JOURNAL.md` | Your Build Journal (graded, cumulative, also your AI-use disclosure record) |
| `.github/workflows/eval.yml` | CI regression gate — runs your BC4 eval harness on every push |
| `.devcontainer/`, `scripts/`, `.vscode/` | Codespace machinery (OpenClaw + OpenRouter) — you shouldn't need to touch these |

## Working rhythm

Each dated Canvas module tells you what to build. Build it in the matching
folder, commit as you go (small commits with real messages — your history is
part of the evidence), push, and add a `JOURNAL.md` entry. Due 11:59 PM CT.

### Getting instructor updates

Your repo is a **snapshot** of the template at the moment you created it —
instructor fixes pushed to the template afterward do *not* arrive
automatically, and plain `git pull` only syncs **your own** repo. If an
update is announced, run (first time):

```bash
git remote add upstream https://github.com/agentic-systems-fall-2026/agentic-systems-course-fall-2026
git pull upstream main --allow-unrelated-histories
```

and after that just `git pull upstream main`. Grading and assignment
details never require this — they live in Canvas, not in the repo.

**Keys stay out of git.** Your endpoint key (LiteLLM or OpenRouter) lives in
Codespaces secrets and (from BC4 on) a GitHub Actions repository secret.
`.env` files are gitignored. If a key ever lands in a commit: rotate it
(tell the instructor if it's a Sandbox key), then fix history.

## CI eval gate (from BC4)

The included workflow runs `bc4-evals/` on every push — a small live sweep
(~5 cases, cached, capped). Until you add a `LITELLM_API_KEY` (or
`OPENROUTER_API_KEY`) repository secret it passes with a notice, so early
pushes stay green. From BC4 onward
a red X means your change regressed the evals — read the failure, fix or
justify, never just raise the threshold.

## Toolbelt (pre-installed)

Beyond Python/Node/git, setup installs: `cloudflared` (share a running demo:
`cloudflared tunnel --url http://localhost:5000`), `jq` (JSON wrangling),
`gh` (check your CI eval runs: `gh run list`), `sqlite3` (retrieval/memory
labs, agent state), `tmux` (keep long-running agents alive — BC3),
`asciinema` (terminal recordings — an official demo-evidence format:
`asciinema rec demo.cast`, then commit the file), `ripgrep`, `httpie`,
`tree`, `htop`, `entr` (auto-rerun on change:
`ls bc4-evals/*.py | entr python3 bc4-evals/harness.py`), and `flask`
(serve a capstone demo UI behind your tunnel).

## Model notes

Defaults, by endpoint. On **OpenRouter** (the course standard):
`google/gemini-3.8-flash`, with `qwen/qwen3.7-flash` as the automatic fallback.
On the **OU AI Sandbox** (the no-cost alternative): `DeepSeek V4 Flash`, with
`Kimi K2.7 Code` as the fallback. The two are deliberately matched in class, so
whichever endpoint you use, you are learning the same thing. The Codespace picks
the endpoint from your key(s) at startup (OpenRouter first).

**Why a capable model by default.** Most of what you build this term is
multi-step tool use: call a tool, read the result, decide what to do next,
recover when something fails. Small coder models are not reliable at that, and
the way they fail is the problem — instead of stopping with an error, they tend
to invent a plausible result and report success. On the Ship Day assignment,
`Qwen3 Coder 30B` claimed it had no network access (it did), silently replaced
a real web search with five fabricated results, never deployed anything, and
finished with "Website Successfully Built!" above a list of green checkmarks
for work it had not done.

That is worth knowing for its own sake — it is the failure mode Session 11
(observability) and Session 12 (human oversight) are about. It is also why the
fallback matters: **if your agent starts inventing things or claiming it cannot
reach the network, check which model is actually answering.** You may have
failed over. The active model is shown in the TUI status bar.

**Switching models.** Run `scripts/select-model.sh` (or `Ctrl/Cmd+Alt+M`). It
asks which provider you want for your primary, shows that catalog, then asks
the same for your fallback, which you can decline. Primary and fallback may
come from different providers. To set one directly:

```bash
openclaw models set "openrouter/google/gemini-3.8-flash"
openclaw models status
```

The quotes matter — these model ids contain spaces. Changes apply to new
sessions; inside a chat you are already in, switch with `/model`.

**Per-call routing.** Send individual calls to cheaper models with
`chat(..., model=...)` — you'll use that in the Session 7 cost lab.
