# Ship Day — Research → Store → Show (15 pts, due Fri Jul 24, 11:59 PM CT)

**The full, current assignment text lives on Canvas — work from that.**
This folder holds the self-check (`check.py`) and the secret-name
reference (`.env.example`).

**The pipeline.** Research a topic you pick with **Tavily** → store what
you find in a **plain local file** (JSON or SQLite — your agent's choice;
note which and why for your delegation log) → generate a static page into
`public/` → **deploy `public/` to Netlify** with the Netlify CLI. Submit
your live URL plus a 6-line delegation log (which agent, a prompt
that worked, one thing that broke and how you fixed it, and your
storage choice and why) on Canvas.

**Two accounts, three secrets.** No database service, no credit card.
All three are **Codespaces secrets**, set at
<https://github.com/settings/codespaces> — grant each one Repository
access to your assignment repo, then restart your Codespace so they load.

| Secret | What it is |
|---|---|
| `TAVILY_API_KEY` | web search for your agent (tavily.com, free tier) |
| `NETLIFY_AUTH_TOKEN` | personal access token — deploys your site |
| `NETLIFY_SITE_ID` | which project to deploy to (from `netlify sites:create`) |

See `shipday/.env.example` for where each value comes from, step by step.

**Netlify CLI.**
```
npm install -g netlify-cli
netlify sites:create --name YOURNAME-shipday   # prints your Site ID
```

**Verify before you submit.**
```
python3 shipday/check.py https://your-site.netlify.app
```
It checks the same things the grader does: secrets present, live page
loads with real linked results, and the page was generated from your
stored data — not typed by hand.

**Key hygiene.** Never commit a secret. Everything in `public/` is on the
internet — keep your data file and scripts out of it. If a key ever lands
in a commit, revoke it at its source and issue a new one.
