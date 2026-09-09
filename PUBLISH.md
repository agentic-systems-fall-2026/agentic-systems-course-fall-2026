# Publish a build to the web

Your course repository publishes its build folders to GitHub Pages. The
address is permanent, it needs no extra account or key, and it does not stop
working when your Codespace sleeps. Deploying is one command, and your agent
can run it for you.

## Tell your agent

Open the OpenClaw TUI and type, adjusting the folder name if needed:

    Run git pull in my course repository under /workspaces, then read PUBLISH.md there and follow it to publish bc0-space-invaders.

The `git pull` and the "read PUBLISH.md" part are only needed the first time
in a Codespace that was created before this file existed. After that, and in
any fresh Codespace, this is enough:

    Publish bc0-space-invaders.

The agent runs `scripts/publish.sh`, which copies your build into the
repository folder, commits, pushes, waits for the site, and prints one line:

    PUBLISHED: https://agentic-systems-fall-2026.github.io/<your-repo-name>/bc0-space-invaders/

Paste that address into the Canvas assignment together with your repository
link. Open it on your phone or another laptop first to confirm it works.

## Do it yourself instead

    bash scripts/publish.sh bc0-space-invaders ~/.openclaw/workspace/<folder-with-index.html>

Leave off the second argument if the files are already in the repository
folder, or if you want the script to look for the build in the agent
workspace on its own. Use `bc0b-app` for Build Challenge 0b.

## What gets published, and what does not

Published: the folders `bc0-space-invaders`, `bc0b-app`, `shipday`, and
`capstone`, and only when they contain an `index.html`. Markdown files
inside them are stripped on the way out.

Never published: `PROMPTS.md`, `JOURNAL.md`, `agent-notes.md`,
`bc0b-app/person.md` (the real person your Build Challenge 0b app is for),
scripts, config, and anything else in the repository. The repository itself
stays private; only the published pages are public.

Before it commits, the script scans the folder for anything that looks like
an API key and refuses if it finds one. Keys belong in Codespaces secrets,
never in a file.

## If something goes wrong

- The agent cannot find the game: tell it the folder name, or run the
  manual command with the folder as the second argument.
- `PENDING:` instead of `PUBLISHED:`: the first publish can take a couple of
  minutes. Wait, then open the address; or run `gh run list` to watch it.
- The script refuses because of a key: remove the key from the file it
  names, then run it again.
- You are on a branch other than `main`: run `git checkout main` first.
  Pages publishes from `main` only.

Links from `cloudflared tunnel`, Codespace previews, or `app.github.dev`
are never accepted for a submission. They die when the Codespace sleeps.
Netlify still works; if you already have a Netlify link that stays up, you
may keep using it.
