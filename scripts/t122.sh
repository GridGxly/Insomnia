#!/bin/bash
# PR 122: the tmux tests with a ~/.tmux.conf that numbers windows and panes from 1.
source "$HOME/lab/lib.sh"
quit_app
printf 'set -g base-index 1\nsetw -g pane-base-index 1\n' > "$HOME/.tmux.conf"
note "== PR 122 on macOS $(sw_vers -productVersion); $(tmux -V); ~/.tmux.conf: $(tr '\n' ';' < "$HOME/.tmux.conf")"
for pair in "b6a7499 main" "4c6f9a2 head"; do
  set -- $pair
  checkout "$1"
  swift build --build-tests > "$OUT/122-build-$2.log" 2>&1 || { note "$2: build failed"; continue; }
  swift test --skip-build --filter Tmux > "$OUT/122-$2.log" 2>&1 &
  tp=$!
  for i in $(seq 420); do
    kill -0 "$tp" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$tp" 2>/dev/null; then
    note "$2: still running after 420 s, at: $(grep -E "Test Case .* started" "$OUT/122-$2.log" | tail -1 | sed 's/^ *//')"
    pkill -TERM -x xctest
    sleep 5
    pkill -KILL -x xctest
  fi
  wait "$tp"
  rc=$?
  note "$2: swift test --filter Tmux exit $rc; $(grep -E 'Executed [0-9]+ tests' "$OUT/122-$2.log" | tail -1 | sed 's/^ *//')"
  grep -E 'error: ' "$OUT/122-$2.log" | sed -E 's|^.*/Tests/|    Tests/|' | cut -c1-200 | sort | uniq -c | sort -rn | head -6
  pkill -x tmux 2>/dev/null
done
rm -f "$HOME/.tmux.conf"
note "removed ~/.tmux.conf"
