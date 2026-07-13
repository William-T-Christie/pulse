#!/usr/bin/env bash
#
# Publishes Pulse to your PERSONAL GitHub and turns on GitHub Pages.
#
# Prerequisites (do these first, once you're on your personal machine/account):
#   1. gh auth login          # sign in with your PERSONAL GitHub in the browser
#   2. gh auth switch         # if you have multiple accounts, make personal active
#
# Then just run:   ./tools/publish-to-github.sh
#
# It will NOT do anything until you confirm at the prompt.

set -euo pipefail

REPO_NAME="pulse"
cd "$(cd "$(dirname "$0")/.." && pwd)"   # repo root

# Identify the active GitHub account
if ! command -v gh >/dev/null 2>&1; then
  echo "✗ GitHub CLI (gh) not found. Install it, then: gh auth login"; exit 1
fi
USER="$(gh api user --jq .login 2>/dev/null || true)"
if [ -z "$USER" ]; then
  echo "✗ Not signed in to GitHub. Run:  gh auth login"; exit 1
fi

# Optional guard: pass your expected username to catch a wrong active account.
EXPECT="${1:-}"
if [ -n "$EXPECT" ] && [ "$EXPECT" != "$USER" ]; then
  echo "✗ Active account is '$USER', not '$EXPECT'."
  echo "  Switch first:  gh auth switch -u $EXPECT"; exit 1
fi

if [ "$USER" = "William-Christie" ]; then
  echo "⚠  Active GitHub account is 'William-Christie', which is your Altera linked one."
  echo "   For a personal portfolio repo you probably want a different account."
  echo "   Switch with:  gh auth switch     (or re-run: gh auth login)"
  read -r -p "   Publish under '$USER' anyway? [y/N] " a; [ "$a" = "y" ] || exit 1
fi

REPO_URL="https://github.com/$USER/$REPO_NAME"
PAGES_URL="https://$USER.github.io/$REPO_NAME/"

echo
echo "  Account : $USER"
echo "  Repo    : $USER/$REPO_NAME   (public)"
echo "  Pages   : $PAGES_URL"
echo "  Commits : $(git config user.name) <$(git config user.email)>"
echo
read -r -p "Create this PUBLIC repo and push? [y/N] " ans
[ "$ans" = "y" ] || { echo "Aborted. Nothing was pushed."; exit 0; }

# Fill in the real URLs (placeholders become live links)
sed -i '' "s|__REPO_URL__|$REPO_URL|g;  s|__PAGES_URL__|$PAGES_URL|g" docs/index.html README.md
if ! git diff --quiet; then
  git add docs/index.html README.md
  git commit -q -m "Set published URLs for GitHub Pages"
  echo "✓ URLs written into README and landing page"
fi

# Create (or reuse) the repo and push
if gh repo view "$USER/$REPO_NAME" >/dev/null 2>&1; then
  echo "• Repo already exists, pushing to it."
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REPO_URL.git"
  git push -u origin main
else
  gh repo create "$USER/$REPO_NAME" --public --source=. --remote=origin --push \
    --description "A personal recovery dashboard for Apple Watch. On device recovery, strain and sleep scores."
fi
echo "✓ Pushed to $REPO_URL"

# Turn on GitHub Pages from /docs
if gh api -X POST "repos/$USER/$REPO_NAME/pages" \
     -f "source[branch]=main" -f "source[path]=/docs" >/dev/null 2>&1; then
  echo "✓ GitHub Pages enabled (main branch, /docs folder)"
else
  echo "• Couldn't auto-enable Pages (may already be on, or needs a token scope)."
  echo "  Turn it on manually: repo → Settings → Pages → Source: main / /docs"
fi

echo
echo "Done. Give Pages ~1 minute to build, then:"
echo "  Project page : $PAGES_URL"
echo "  Repository   : $REPO_URL"
echo
echo "For the job application's \"share a link\" field, use the Project page."
