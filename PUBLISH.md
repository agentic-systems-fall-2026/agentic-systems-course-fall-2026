# Publish a build to the web

Your course repository publishes its build folders to GitHub Pages. The
address stays the same for the whole course, it needs no extra account or
key, and it does not stop working when your Codespace sleeps. Deploying is one command, and your agent
can run it for you.

## Tell your agent

Open the OpenClaw TUI and type, adjusting the folder name if needed:

    Run git pull in my course repository under /workspaces, then read PUBLISH.md there and follow it to publish bc0-space-invaders.

The `git pull` and the "read PUBLISH.md" part are only needed the first time
in a Codespace that was created before this file existed. After that, and in
any fresh Codespace, this is enough:

    Publish bc0-space-invaders.

The agent runs `scripts/publish.sh`, which copies your build into the
repository folder (replacing the old copy, but keeping `person.md` and
`agent-notes.md`), commits only that folder, pulls, pushes, waits until the
site serves that exact commit, and prints one line:

    PUBLISHED: https://agentic-systems-fall-2026.github.io/<your-repo-name>/bc0-space-invaders/

Paste that address into the Canvas assignment together with your repository
link. Open it on your phone or another laptop first to confirm it works.

## Do it yourself instead

    bash scripts/publish.sh bc0-space-invaders ~/.openclaw/workspace/<folder-with-index.html>

Leave off the second argument only if the files are already in the
repository folder; then that copy is what gets published, even if you have a
newer one in the agent workspace. Use `bc0b-app` for Build Challenge 0b.

Pages serves static files only (HTML, CSS, JavaScript, images). Anything that
needs a server or an API key at runtime will not run there. Personal data
you put in a JSON or JavaScript file inside the folder is public; only
Markdown files are stripped. All course sites share one browser origin, so
data an app stores in the browser is visible to the other course sites too;
use made-up data for anything sensitive.

## What gets published, and what does not

Published: the folders `bc0-space-invaders`, `bc0b-app`, `shipday`, and
`capstone`, and only when they contain an `index.html`. Markdown files
inside them are stripped on the way out.

Never published: `PROMPTS.md`, `JOURNAL.md`, `agent-notes.md`,
`bc0b-app/person.md` (the real person your Build Challenge 0b app is for),
scripts, config, and anything else in the repository. The repository itself
stays private; only the published pages are public.

Before it commits, the script scans the folder for anything that looks like
an API key and refuses if it finds one; the publish run on GitHub scans the
whole site again before it goes live. Keys belong in Codespaces secrets,
never in a file. If a key ever does get published, revoke it; deleting the
file is not enough.

## If something goes wrong

- The agent cannot find the game: tell it the folder name, or run the
  manual command with the folder as the second argument. If you built in a
  folder of your own naming, that is fine; publishing looks through your
  repository as well as the agent workspace, and copies what it finds into
  the folder the assignment expects.
- `PENDING:` instead of `PUBLISHED:`: the publish has not finished, so do
  not submit yet. Run `gh run list --workflow pages.yml` to see whether the
  run failed, then run the publish again. If it is the very first publish
  for your repository and nothing appears, Pages may not be enabled yet;
  tell the instructor.
- The script says there is a git conflict: run `git status`, fix the files
  it lists, then run the publish again. Your build is already committed.
- The script stops because you have other files staged: commit them
  (`git commit`) or unstage them (`git restore --staged <file>`), then run the
  publish again. It refuses rather than risk losing what you had staged.
- You need to take a site down: delete the folder's `index.html`, commit,
  and push; the next run removes it from the site.
- The script refuses because of a key: remove the key from the file it
  names, then run it again.
- You are on a branch other than `main`: run `git checkout main` first.
  Pages publishes from `main` only.

Links from `cloudflared tunnel`, Codespace previews, or `app.github.dev`
are never accepted for a submission. They die when the Codespace sleeps.
Netlify still works; if you already have a Netlify link that stays up, you
may keep using it.
