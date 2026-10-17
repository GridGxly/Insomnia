# Sourced in a lab VM, as admin, over SSH. Helpers for the PR evidence runs.
APP="$HOME/Applications/Insomnia.app"
SUP="$HOME/Library/Application Support/Insomnia"
LOG="$HOME/Library/Logs/Insomnia/insomnia.log"
SRC="$HOME/src"
OUT="$HOME/lab-out"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
mkdir -p "$OUT"

note() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

app_pid() { pgrep -x Insomnia | head -1; }

log_mark() { if [ -f "$LOG" ]; then wc -l < "$LOG" | tr -d ' '; else echo 0; fi; }

log_since() { tail -n +"$(($1 + 1))" "$LOG" 2>/dev/null | grep -v 'status item'; }

key() { osascript -e "tell application \"System Events\" to key code $1" >/dev/null; }

quit_app() {
  [ -z "$(app_pid)" ] && return 0
  osascript -e 'tell application id "com.kgarg.insomnia" to quit' >/dev/null 2>&1
  for _ in $(seq 30); do
    [ -z "$(app_pid)" ] && return 0
    sleep 1
  done
  note "app did not quit"
  return 1
}

checkout() {
  cd "$SRC" || return 1
  git fetch -q origin '+refs/pull/*/head:refs/remotes/origin/pr/*' main
  git checkout -q --detach "$1" || return 1
  note "checkout $(git rev-parse HEAD) ($(git log -1 --format=%s | cut -c1-70)); git status --short lines: $(git status --short | wc -l | tr -d ' ')"
}

install_rev() {
  quit_app || return 1
  checkout "$1" || return 1
  local rc
  if [ -f "$HOME/builds/$1.zip" ] && [ "$(xcode-select -p)" = /Library/Developer/CommandLineTools ]; then
    # No Xcode here: install the bundle built from the same commit in the
    # macOS 27 VM, with this checkout's install.sh.
    rm -rf "$HOME/builds/$1" && mkdir -p "$HOME/builds/$1"
    ditto -x -k "$HOME/builds/$1.zip" "$HOME/builds/$1"
    note "prebuilt bundle: cdhash $(codesign -dvvv "$HOME/builds/$1/Insomnia.app" 2>&1 | awk -F= '/^CDHash=/ {print $2}'), built in the macOS 27 VM with Xcode 27"
    ./scripts/install.sh --allow-unverified-origin --app "$HOME/builds/$1/Insomnia.app" > "$OUT/install-$1.log" 2>&1
    rc=$?
  else
    ./scripts/install.sh > "$OUT/install-$1.log" 2>&1
    rc=$?
  fi
  note "install.sh exit $rc; last line: $(grep -v '^ ' "$OUT/install-$1.log" | grep . | grep -E '^==>' | tail -1)"
  return $rc
}

launch_app() {
  open "$APP"
  for _ in $(seq 30); do
    [ -n "$(app_pid)" ] && break
    sleep 1
  done
  sleep 4
  osascript -e 'tell application "Finder" to activate' >/dev/null
  sleep 1
}

# The status item's left edge, from Accessibility.
eye_x() {
  osascript -e 'tell application "System Events" to tell process "Insomnia" to get position of menu bar item 1 of menu bar 2' 2>/dev/null | cut -d, -f1 | tr -d ' '
}

# Click the eye, optionally type minutes into the Minutes pill, press Enter.
start_session() {
  local x
  x=$(eye_x)
  if [ -z "$x" ]; then note "no status item"; return 1; fi
  "$HOME/click" $((x + 16)) 15
  sleep 1.5
  if [ -n "${1:-}" ]; then
    key 48
    sleep 0.4
    osascript -e "tell application \"System Events\" to keystroke \"$1\"" >/dev/null
    sleep 0.4
  fi
  key 36
}

wait_sleep_disabled() {
  for _ in $(seq 20); do
    pmset -g | grep -q 'SleepDisabled[[:space:]]*1' && return 0
    sleep 1
  done
  return 1
}

sleep_disabled() { pmset -g | awk '/SleepDisabled/ {print $2}'; }

agent_runs() {
  launchctl print "gui/$(id -u)/com.insomnia.backstop" 2>/dev/null | awk -F' = ' '/^\truns =/ {r=$2} /^\tlast exit code =/ {e=$2} END {printf "runs %s, last exit code %s", r, e}'
}

state_note() {
  note "session.json $( [ -e "$SUP/session.json" ] && echo present || echo absent ); SleepDisabled $(sleep_disabled); agent $(agent_runs)"
}

shot() { screencapture -x "$OUT/$1.png"; }

record() {
  "$HOME/click" move 512 500
  sleep 1
  screencapture -v -V "$2" -x "$OUT/$1.mov"
}

# Mean, min and max %CPU of the app over N samples 0.5 s apart.
cpu_mean() {
  local pid i
  pid=$(app_pid)
  for i in $(seq "$1"); do
    ps -o %cpu= -p "$pid"
    sleep 0.5
  done | awk '{s += $1; if (NR == 1 || $1 < mn) mn = $1; if ($1 > mx) mx = $1} END {printf "mean %.1f%%, min %.1f%%, max %.1f%%, %d samples", s / NR, mn, mx, NR}'
}

# Runs the installed backstop.sh once, with launchd's environment, and counts
# the programs it starts (dtrace exec-success on its process tree).
backstop_execs() {
  local fifo=/tmp/bs.fifo out="$OUT/$1.execs" wpid dpid rc n
  rm -f "$fifo"
  mkfifo "$fifo"
  ( read -r _ < "$fifo"; exec env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" SHELL=/bin/zsh TMPDIR="$TMPDIR" PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash "$APP/Contents/Resources/backstop.sh" ) &
  wpid=$!
  sudo -n dtrace -q -o "$out" -n "proc:::exec-success /progenyof($wpid)/ { printf(\"%d %d %s\\n\", pid, ppid, execname); }" 2>/dev/null &
  dpid=$!
  sleep 4
  echo go > "$fifo"
  wait "$wpid"
  rc=$?
  sleep 1
  sudo -n pkill -TERM -x dtrace
  wait "$dpid" 2>/dev/null
  rm -f "$fifo"
  # The first two execs are env and backstop's own bash.
  n=$(awk 'NR > 2 && NF' "$out" | wc -l | tr -d ' ')
  note "$1: backstop.sh exit $rc, programs started: $n $(awk 'NR > 2 && NF {print $3}' "$out" | sort | uniq -c | sort -rn | awk '{printf "%s%s x%s", (NR > 1 ? ", " : "("), $2, $1} END {if (NR) printf ")"}')"
}

wait_log() {
  local mark=$1 pattern=$2 limit=$3 i
  for i in $(seq "$limit"); do
    log_since "$mark" | grep -q -E "$pattern" && return 0
    sleep 1
  done
  return 1
}
