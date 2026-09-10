---
name: publish-to-pages
description: Publish a build challenge folder to GitHub Pages so it has a stable public URL. Use when the user asks to publish, deploy, put online, share a link, or get a URL for a game or web app they built in this course.
---

# Publish a build to GitHub Pages

The course repository publishes its build folders to GitHub Pages. The
address is stable, needs no extra account, and does not die when the
Codespace sleeps. The script that does the work lives in the repository:

    bash <repo>/scripts/publish.sh <target> <source-dir>

`<repo>` is the course repository, normally the single folder under
/workspaces. Resolve it first (for example `ls -d /workspaces/*/scripts/publish.sh`)
and use that one path; do not pass a glob to the command.
`<target>` is the repository folder the build belongs in:

- `bc0-space-invaders` for the Space Invaders build (Build Challenge 0)
- `bc0b-app` for the web app for one real person (Build Challenge 0b)
- `shipday` or `capstone` later in the course

`<source-dir>` is the folder that contains the build's `index.html`. Builds
made in this workspace usually live under `~/.openclaw/workspace/`.

## Steps

1. Find the folder that contains the build's `index.html`. If you built it
   in this session you already know it. Otherwise look under
   `~/.openclaw/workspace/` and in the repository itself, where an earlier
   build often sits in a folder of the user's own naming (`bc0-invaders`,
   `projects/space-invaders`, and so on). The script searches both places
   too, so running it without a source is a reasonable first attempt. Ask
   the user only if two candidates look equally likely. A folder counts only
   if it is the build the user asked for. A different build challenge's
   folder is not a candidate, however similar the files look.
2. Run the script with the target and that folder, for example:

       bash /workspaces/my-course-repo/scripts/publish.sh bc0-space-invaders ~/.openclaw/workspace/space-invaders

   Always pass the source folder explicitly and tell the user which folder
   you are publishing. Files no longer in that folder are removed from the
   repository copy; `person.md` and `agent-notes.md` in the target are kept.
3. Wait for it to finish (up to five minutes). It copies the build into the
   repository folder, commits only that folder, pulls, pushes, and waits
   until the site serves that exact commit. It ends with one of:
   - `PUBLISHED: <url>` (exit 0): done. Report the line verbatim, say which
     folder you published from, and tell the user to open the URL and check
     that it is their build before pasting it into the Canvas assignment
     with the repository link.
   - `PENDING: <url>` (exit 8): NOT done. Tell the user the publish has not
     finished, show the script's explanation, and suggest
     `gh run list --workflow pages.yml`. Do not call it ready to submit.
   - any other non-zero exit: show the user the script's message. It says
     what to fix (a key in a file, a branch, a git conflict, other files
     staged for commit). The script changes nothing when it refuses, so it is
     safe to fix the cause and run it again.

## Rules

- Never offer a cloudflared tunnel, a Codespace preview link, or any
  `app.github.dev` address as a submission link. Those stop working when
  the Codespace sleeps.
- Do not use Netlify unless the user explicitly asks for it.
- Never write an API key into any file in the repository. If the script
  refuses because a file looks like it holds a key, show the user the
  script's message, help them remove the key from that file, and only then
  run it again.
- If the script says the folder has no `index.html`, either the build is
  not a web page yet, or it is a framework project whose output has not
  been built. Tell the user which folder you looked in; if it has a
  `package.json` with a build script, run the build and publish its output
  folder (`dist/` or `build/`) instead.
- Pages serves static files only. An app that needs a server or an API key
  at runtime will not work there; say so rather than publishing it.
- Never create, scaffold, generate, or copy in a build in order to make a
  publish succeed. Do not copy files from another target's folder, do not
  write a placeholder page, and do not create a new project or page because
  the requested folder is empty or missing. Running an existing project's own
  build step, as described above, is fine; making a build that did not exist
  is not. Publishing is for work the user has already made.
- If you cannot find a build for the target the user named, stop and say so
  plainly: name the target, say where you looked, and ask where their build
  is. Reporting that there is nothing to publish is the correct outcome and
  is more useful than a published page the user did not make. A published
  URL that does not contain the user's own work is a worse failure than no
  URL at all, because it looks finished and gets submitted.
- Do not edit `scripts/publish.sh`.
