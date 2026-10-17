#!/bin/bash
# build-all.sh: release bundles of main and the UI-path PR heads, in a
# separate clone so the running tests' ~/src checkout is left alone.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ -d "$HOME/build-src" ] || git clone -q --no-checkout "$HOME/src" "$HOME/build-src"
mkdir -p "$HOME/builds"
cd "$HOME/build-src" || exit 1
for rev in ${*:-b6a7499 9325f63 facab18 3dfc607 b2151cc}; do
  git checkout -q --detach "$rev" || { echo "$rev checkout failed"; continue; }
  rm -rf "$HOME/builds/$rev"
  ./scripts/build-app.sh --output "$HOME/builds/$rev" > "$HOME/builds/$rev.log" 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    (cd "$HOME/builds/$rev" && ditto -c -k --keepParent Insomnia.app "$HOME/builds/$rev.zip")
  fi
  echo "$rev build exit $rc $(date -u +%H:%M:%SZ)"
done
echo "BUILDS DONE"
