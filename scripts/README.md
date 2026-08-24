# The `scripts/` directory

Ten scripts run this repo. You will use three of them regularly and can ignore
the rest until something breaks. Every one is safe to re-run.

## The three you will actually use

| Script | Run it when | What it does |
|---|---|---|
| `bash scripts/start-tui.sh` | You want to talk to your agent | Opens the OpenClaw chat interface. This is your main workspace. |
| `bash scripts/select-model.sh` | You want a different model | Interactive picker: choose a provider, then a primary model and a fallback. Writes the choice and restarts the gateway. |
| `bash scripts/sync-template.sh` | I announce a starter-code update | Pulls course updates into your repo without touching your own work. |

## The rest, roughly in the order they fire

| Script | What it does |
|---|---|
| `preflight.sh` | Checks your API key against the provider before anything else starts. OpenRouter first, then the OU AI Sandbox. Most "it won't start" problems are a failed preflight, so read its output. |
| `install-openclaw.sh` | Installs the OpenClaw CLI. Runs once at Codespace creation. |
| `configure.sh` | Renders `config/openclaw.template.json5` into your live `~/.openclaw/openclaw.json`, filling in provider, model, and gateway token. |
| `start-gateway.sh` | Starts the local OpenClaw gateway, the process the TUI talks to. |
| `gateway-daemon.sh` | Keeps the gateway running in the background and restarts it if it dies. |
| `set-key.sh` | Writes or replaces an API key in `~/.openclaw/.env`. Use this if you skipped the key at Codespace creation, or rotated one. |
| `_env.sh` | Not run directly. Sourced by the others to put `openclaw` on `PATH`. |

## When something is wrong, in this order

1. `bash scripts/preflight.sh` — is your key valid and in credit?
2. `bash scripts/set-key.sh` — if preflight says the key is bad or missing.
3. `bash scripts/configure.sh` — if the gateway starts but the model will not resolve.
4. `bash scripts/start-gateway.sh` — read the log it prints; do not just retry.

If all four are clean and it still fails, that is a finding. Post it in the
Course Q&A discussion with the output. Accurate failure reports are worth more
in this course than a fix you cannot explain.

## A note on secrets

No script ever writes a key into the repo. Keys live in `~/.openclaw/.env` and
in your Codespaces secrets, both outside version control. If you ever find a
key inside a tracked file, stop and tell me: that is an incident, and we will
treat it like one.
