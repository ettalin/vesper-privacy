#!/usr/bin/env bash
# Delete and recreate ettalin/vesper-privacy so no trace of the previous contact
# address survives, not even as an unreachable commit.
#
# The published URL is unchanged — https://ettalin.github.io/vesper-privacy/ —
# because it derives from the repository name, which is recreated identically.
# There is a gap of a few minutes while GitHub Pages rebuilds; that is the only
# cost, and it is why every step below runs back to back with no pauses.
set -euo pipefail

REPO="ettalin/vesper-privacy"
URL="https://ettalin.github.io/vesper-privacy/"
NEW_EMAIL="bkeepersja@gmail.com"
OLD_EMAIL="ttomlin.fuse@gmail.com"

cd "$(dirname "$0")"

echo "→ checking the local copy is the one we want to publish"
grep -q "$NEW_EMAIL" index.html || { echo "  ✗ new address missing from index.html"; exit 1; }
! grep -q "$OLD_EMAIL" index.html || { echo "  ✗ old address still in index.html"; exit 1; }
echo "  ✓ contact is $NEW_EMAIL, old address absent"

# Two GitHub accounts are logged in on this machine, so the delete has to be
# attributed explicitly. And if the repo was already deleted in the browser,
# skip straight to recreating it — either route ends in the same place.
if gh api "repos/$REPO" >/dev/null 2>&1; then
  echo "→ deleting $REPO"
  gh repo delete "$REPO" --yes
else
  echo "→ $REPO is already gone; recreating it"
fi

echo "→ recreating it, public, same name so the URL is identical"
gh repo create "$REPO" --public \
  --description "Privacy policy for Vesper, a private time-tracking Chrome extension"

echo "→ pushing a single clean commit"
rm -rf .git
git init -q
git config user.name "ettalin"
git config user.email "193460067+ettalin@users.noreply.github.com"
git add -A
git commit -q -m "Publish Vesper's privacy policy

The Chrome Web Store will not list an extension without a privacy policy at a
publicly reachable address, so this is a separate public repository — the
extension's own code stays private.

Contains only the policy page. Its history from here is the change record the
policy itself points at."
git branch -M main
git remote add origin "https://github.com/$REPO.git"
git push -q -u origin main

echo "→ turning GitHub Pages back on"
gh api -X POST "repos/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null

echo "→ waiting for it to go live (this is the gap; usually a minute or two)"
for i in $(seq 1 60); do
  if curl -fsSL "$URL" 2>/dev/null | grep -q "$NEW_EMAIL"; then
    echo "  ✓ live after ~$((i * 10))s"
    break
  fi
  sleep 10
done

echo "→ final check"
curl -fsSL "$URL" | python3 -c "
import sys, re
s = sys.stdin.read()
print('  contact  :', re.search(r'mailto:([^\"]+)', s).group(1))
print('  old email:', 'STILL THERE' if '$OLD_EMAIL' in s else 'gone')
print('  bytes    :', len(s))
"
echo "  commits in public history: $(git rev-list --count HEAD)"
echo
echo "Done — $URL"
