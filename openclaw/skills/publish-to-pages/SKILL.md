---
name: publish-to-pages
description: Publish a build challenge folder to GitHub Pages so it has a permanent public URL. Use when the user asks to publish, deploy, put online, share a link, or get a URL for a game or web app they built in this course.
---

# Publish a build to GitHub Pages

The course repository publishes its build folders to GitHub Pages. The
address is permanent, needs no extra account, and does not die when the
Codespace sleeps. The script that does the work lives in the repository:

    bash /workspaces/<repo>/scripts/publish.sh <target> <source-dir>

`<repo>` is the course repository under /workspaces (there is normally one).
`<target>` is the repository folder the build belongs in:

- `bc0-space-invaders` for the Space Invaders build (Build Challenge 0)
- `bc0b-app` for the web app for one real person (Build Challenge 0b)
- `shipday` or `capstone` later in the course

`<source-dir>` is the folder that contains the build's `index.html`. Builds
made in this workspace usually live under `~/.openclaw/workspace/`.

## Steps

1. Find the folder that contains the build's `index.html`. If you built it
   in this session you already know it. Otherwise look under
   `~/.openclaw/workspace/` and the repository folder itself. Ask the user
   only if two candidates look equally likely.
2. Run the script with the target and that folder, for example:

       bash /workspaces/*/scripts/publish.sh bc0-space-invaders ~/.openclaw/workspace/space-invaders

3. Wait for it to finish. It copies the build into the repository folder,
   commits, pushes, and polls the site. It prints a final line that starts
   with `PUBLISHED:` (or `PENDING:` if the site is still building).
4. Report that line to the user verbatim, and tell them to paste the URL
   into the Canvas assignment together with the repository link.

## Rules

- Never offer a cloudflared tunnel, a Codespace preview link, or any
  `app.github.dev` address as a submission link. Those stop working when
  the Codespace sleeps.
- Do not use Netlify unless the user explicitly asks for it.
- Never write an API key into any file in the repository. If the script
  refuses because a file looks like it holds a key, show the user the
  script's message, help them remove the key from that file, and only then
  run it again.
- If the script says the folder has no `index.html`, the build is not a web
  page yet; tell the user which folder you looked in and ask where the
  page is.
- Do not edit `scripts/publish.sh`.
