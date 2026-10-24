#!/bin/bash
# ctl.sh REV LABEL: installs the bundle built from REV (building it in
# ~/build-src first if there is none) with that commit's install.sh, then
# runs the pill click probe.
source "$HOME/lab/lib.sh"
rev=$1 label=$2
quit_app
if [ ! -d "$HOME/builds/$rev/Insomnia.app" ]; then
  if [ -f "$HOME/builds/$rev.zip" ]; then
    mkdir -p "$HOME/builds/$rev" && ditto -x -k "$HOME/builds/$rev.zip" "$HOME/builds/$rev"
  else
    (cd "$HOME/src" && git fetch -q origin +refs/pull/93/head:refs/remotes/origin/pr/93)
    (cd "$HOME/build-src" && git fetch -q origin +refs/remotes/origin/pr/93:refs/remotes/origin/pr/93 && git checkout -q --detach "$rev" && ./scripts/build-app.sh --output "$HOME/builds/$rev" > "$HOME/builds/$rev.log" 2>&1; echo "build $rev exit $?")
  fi
fi
cd "$HOME/src" && git checkout -q --detach "$rev" || exit 1
note "$label: ~/src at $(git rev-parse HEAD), status lines $(git status --short | wc -l | tr -d ' ')"
./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/$rev/Insomnia.app" > "$OUT/install-$rev.log" 2>&1
note "$label: install.sh exit $?"
bash "$HOME/lab/t145p.sh" "$label"
