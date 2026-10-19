#!/bin/bash
# PR 130: install.sh and uninstall.sh with Kong's Insomnia API client open,
# main e242782 as the control, the PR head 434312d after it. Run in lab27.
source "$HOME/lab/lib.sh"
O="$OUT/pr130"; rm -rf "$O"; mkdir -p "$O"
MAIN=e242782; PR=434312d
REQ='anchor apple generic and identifier "com.insomnia.app" and certificate leaf[subject.OU] = "FX44YY62GV"'
KONG=/Applications/Insomnia.app
DMG_URL='https://github.com/Kong/insomnia/releases/download/core%4013.3.1/Insomnia.Core-13.3.1.dmg'
DMG_SHA=ad6e6260f083162e61e879b99f27d69b934ae3cdbf6817ddb284acd8a4302650
OURS="$APP/Contents/MacOS/Insomnia"

# pids by the executable path ps shows (test harness only; the scripts under
# test don't use this).
pids_at() { local p; for p in $(pgrep -x Insomnia); do [ "$(ps -o comm= -p "$p")" = "$1" ] && echo "$p"; done; }
kong_pid() { pids_at "$KONG/Contents/MacOS/Insomnia" | head -1; }
our_pid() { pids_at "$OURS" | head -1; }
procs() { local p; for p in $(pgrep -x Insomnia); do echo "    pid $p: $(ps -o comm= -p "$p")"; done; }
verify_pids() {
  local p rc
  for p in $(pgrep -x Insomnia); do
    codesign --verify "-R=$REQ" "$p" > /tmp/v130.txt 2>&1; rc=$?
    echo "    pid $p ($(ps -o comm= -p "$p")): exit $rc$( [ -s /tmp/v130.txt ] && printf ', %s' "$(tr '\n' ' ' < /tmp/v130.txt)")"
  done
}
leftovers() {
  local f
  for f in /etc/sudoers.d/insomnia "$HOME/Library/LaunchAgents/com.insomnia.backstop.plist" "$APP"; do
    if [ -e "$f" ]; then echo "    present: $f"; else echo "    absent:  $f"; fi
  done
}
run() { # name command...: output to $O/name.log, then shown indented
  local name=$1 t0=$SECONDS rc; shift
  "$@" > "$O/$name.log" 2>&1 < /dev/null; rc=$?
  note "$name: exit $rc after $((SECONDS - t0)) s"
  sed 's/^/    | /' "$O/$name.log"
  return $rc
}
wait_pid() { # fn seconds
  local i; for i in $(seq "$2"); do [ -n "$($1)" ] && return 0; sleep 1; done; return 1
}
quit_ours() {
  [ -z "$(our_pid)" ] && return 0
  osascript -e 'tell application id "com.kgarg.insomnia" to quit' >/dev/null 2>&1
  local i; for i in $(seq 30); do [ -z "$(our_pid)" ] && return 0; sleep 1; done; return 1
}

note "== PR 130 on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(xcodebuild -version | head -1)"

note "-- 0. Builds and a clean start"
cd "$SRC" || exit 1
git fetch -q origin '+refs/pull/*/head:refs/remotes/origin/pr/*' main || { note "fetch failed"; exit 1; }
for rev in $MAIN $PR; do
  git checkout -q --detach $rev || exit 1
  rm -rf "$HOME/builds/pr130-$rev"
  ./scripts/build-app.sh --output "$HOME/builds/pr130-$rev" > "$O/build-$rev.log" 2>&1
  note "build $rev ($(git log -1 --format=%s | cut -c1-60)): exit $?, cdhash $(codesign -dvvv "$HOME/builds/pr130-$rev/Insomnia.app" 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
  rm -rf "$HOME/w130/$rev"; git worktree prune
  git worktree add -q --detach "$HOME/w130/$rev" $rev || exit 1
done
quit_ours || { note "the installed app did not quit"; exit 1; }
if [ -e "$APP" ]; then
  ( cd "$HOME/w130/$MAIN" && run s0-preclean-uninstall ./scripts/uninstall.sh ) | tail -3
fi
leftovers
ls -A "$HOME/Library/Application Support/Insomnia" > "$O/support-before-kong.txt" 2>/dev/null
ls -A "$HOME/Library/Logs/Insomnia" > "$O/logs-before-kong.txt" 2>/dev/null
find "$HOME/Library" -maxdepth 3 -iname '*insomnia*' 2>/dev/null | sort > "$O/library-before-kong.txt"

note "-- 1. Kong's Insomnia API client"
rm -rf "$HOME/kong-dl"; mkdir "$HOME/kong-dl"
curl -fsSL -o "$HOME/kong-dl/Insomnia.Core-13.3.1.dmg" "$DMG_URL" || { note "download failed"; exit 1; }
sum=$(shasum -a 256 "$HOME/kong-dl/Insomnia.Core-13.3.1.dmg" | cut -d' ' -f1)
note "downloaded Insomnia.Core-13.3.1.dmg from Kong/insomnia release core@13.3.1, sha256 $sum ($( [ "$sum" = "$DMG_SHA" ] && echo matches the release asset digest || echo DOES NOT MATCH))"
[ "$sum" = "$DMG_SHA" ] || exit 1
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint /tmp/kongdmg "$HOME/kong-dl/Insomnia.Core-13.3.1.dmg" > "$O/hdiutil.log" 2>&1 < /dev/null || { note "attach failed"; cat "$O/hdiutil.log"; exit 1; }
sudo -n rm -rf "$KONG"; ditto /tmp/kongdmg/Insomnia.app "$KONG"; hdiutil detach -quiet /tmp/kongdmg
note "copied to $KONG: $(defaults read "$KONG/Contents/Info" CFBundleIdentifier) $(defaults read "$KONG/Contents/Info" CFBundleShortVersionString), $(lipo -archs "$KONG/Contents/MacOS/Insomnia")"
run s1-kong-codesign-dv codesign -dv --verbose=2 "$KONG"
run s1-kong-spctl spctl -a -vv "$KONG"
open "$KONG"
wait_pid kong_pid 60 || { note "Kong did not start"; exit 1; }
sleep 15
note "Kong running as pid $(kong_pid); pgrep -x Insomnia:"
procs
note "codesign --verify -R='$REQ' <pid>:"
verify_pids | tee "$O/s1-verify.txt"
if ! grep -q ': exit 0' "$O/s1-verify.txt" || grep -qv ': exit 0' "$O/s1-verify.txt"; then
  note "STOP: Kong's client does not pass the requirement"; exit 1
fi
KP=$(kong_pid)
screencapture -x "$O/kong-alone.png"

note "-- 2. Control: main $MAIN, Kong open, this app not running"
cd "$HOME/w130/$MAIN"
run s2-main-install ./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/pr130-$MAIN/Insomnia.app"
leftovers
note "Kong pid $(kong_pid) (was $KP)"
run s2-main-uninstall ./scripts/uninstall.sh
leftovers
note "Kong pid $(kong_pid) (was $KP)"
if [ -e /etc/sudoers.d/insomnia ] && [ ! -e "$APP" ]; then
  sudo -n rm -f /etc/sudoers.d/insomnia
  note "removed the sudoers rule step 2 left behind, so step 3 is a first install"
fi

note "-- 3. PR $PR, Kong open, this app not running"
cd "$HOME/w130/$PR"
run s3-pr-install ./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/pr130-$PR/Insomnia.app"
note "\"Ignoring pid\" lines: $(grep -c 'Ignoring pid' "$O/s3-pr-install.log")"
leftovers
note "Kong pid $(kong_pid) (was $KP)"
open "$APP"
wait_pid our_pid 30 || note "this app did not start"
sleep 8
note "this app running as pid $(our_pid); pgrep -x Insomnia:"
procs
verify_pids | tee "$O/s3-verify.txt"
open "$KONG"
sleep 3
screencapture -x "$O/both-running.png"

note "-- 4. PR $PR, Kong and this app both running"
run s4-pr-install-both ./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/pr130-$PR/Insomnia.app"
note "\"Ignoring pid\" lines: $(grep -c 'Ignoring pid' "$O/s4-pr-install-both.log"); this app pid now: '$(our_pid)'"
leftovers
note "Kong pid $(kong_pid) (was $KP)"
open "$APP"
wait_pid our_pid 30 || note "this app did not start"
sleep 8
note "this app running again as pid $(our_pid)"
procs
run s4-pr-uninstall ./scripts/uninstall.sh
note "\"Ignoring pid\" lines: $(grep -c 'Ignoring pid' "$O/s4-pr-uninstall.log"); this app pid now: '$(our_pid)'"
leftovers
procs
note "Kong pid $(kong_pid) (was $KP)"
ls -A "$HOME/Library/Application Support/Insomnia" > "$O/support-after.txt" 2>/dev/null
ls -A "$HOME/Library/Logs/Insomnia" > "$O/logs-after.txt" 2>/dev/null
find "$HOME/Library" -maxdepth 3 -iname '*insomnia*' 2>/dev/null | sort > "$O/library-after.txt"
note "DONE"
