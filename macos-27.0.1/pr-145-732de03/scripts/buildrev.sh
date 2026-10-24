#!/bin/bash
# buildrev.sh LABEL REV: builds REV from a clean ~/build-src into
# ~/builds/LABEL and installs it with REV's install.sh from a clean ~/src.
source "$HOME/lab/lib.sh"
label=$1 rev=$2
quit_app
# ~/src fetches from GitHub, ~/build-src from ~/src.
for d in "$HOME/src" "$HOME/build-src"; do
  cd "$d" || exit 1
  if [ "$d" = "$HOME/src" ]; then ref=refs/pull/145/head; else ref=refs/remotes/origin/pr/145; fi
  git fetch -q origin "+$ref:refs/remotes/origin/pr/145" || exit 1
  git checkout -q --detach "$rev" && git checkout -q -- . && git clean -qfd || exit 1
  note "$label: $(basename "$d") at $(git rev-parse HEAD) ($(git log -1 --format=%s | cut -c1-70)); status lines $(git status --short --ignored=no | wc -l | tr -d ' ')"
done
cd "$HOME/build-src"
rm -rf "$HOME/builds/$label"
./scripts/build-app.sh --output "$HOME/builds/$label" > "$OUT/build-$label.log" 2>&1
rc=$?
note "$label: build exit $rc"
[ $rc = 0 ] || { tail -30 "$OUT/build-$label.log"; exit 1; }
cd "$HOME/src"
./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/$label/Insomnia.app" > "$OUT/install-$label.log" 2>&1
note "$label: install.sh exit $? (~/src at $(git rev-parse --short HEAD), status lines $(git status --short | wc -l | tr -d ' ')); app CDHash $(codesign -dvvv "$HOME/Applications/Insomnia.app" 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
