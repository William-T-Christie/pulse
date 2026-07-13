# Publishing Pulse to your personal GitHub

Everything is staged and committed locally. When you're home and signed into
your **personal** GitHub, this takes about two minutes.

## Steps

```sh
cd ~/Documents/Claude/Projects/Pulse

# 1. Sign in with your PERSONAL GitHub (opens a browser)
gh auth login

# 2. If gh also has your Altera-linked account (William-Christie),
#    make the personal one active:
gh auth switch

# 3. Publish. Nothing happens until you confirm at the prompt.
./tools/publish-to-github.sh
```

Optional safety check — pass your personal username and the script aborts if a
different account is active:

```sh
./tools/publish-to-github.sh your-personal-username
```

## What the script does

1. Confirms which GitHub account is active (and warns if it's the Altera one).
2. Replaces the `__REPO_URL__` / `__PAGES_URL__` placeholders in the README and
   landing page with your real links, and commits that.
3. Creates a **public** repo `pulse` under your account and pushes `main`.
4. Turns on **GitHub Pages** from the `main` branch `/docs` folder.

Commits are already authored as **William Christie <wchristie22@gmail.com>**
(repo-local setting — your global Altera git config is untouched). The history
transparently shows `Co-Authored-By: Claude` trailers.

## The two links you'll get

- **Project page** (use this for the job application):
  `https://<your-username>.github.io/pulse/`
- **Repository**: `https://github.com/<your-username>/pulse`

Give Pages ~1 minute to build after the push. If the page 404s at first, wait a
moment and reload — the first build is the slow one.

## If you'd rather do it by hand

```sh
gh repo create <you>/pulse --public --source=. --remote=origin --push
# then: repo → Settings → Pages → Source: Deploy from a branch → main / /docs
```

Remember to first replace `__REPO_URL__` and `__PAGES_URL__` in
`README.md` and `docs/index.html` if you skip the script.
