#!/bin/bash
# PR 100: the Security error text tests on a Mac set to German.
source "$HOME/lab/lib.sh"
quit_app
note "== PR 100 on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)); AppleLanguages was: $(defaults read -g AppleLanguages 2>/dev/null | tr -d '\n ')"
defaults write -g AppleLanguages -array de-DE
defaults write -g AppleLocale de_DE
note "system language set to German: $(defaults read -g AppleLanguages | tr -d '\n ')"
for pair in "b6a7499 main" "d0a506f head"; do
  set -- $pair
  checkout "$1"
  swift build --build-tests > "$OUT/100-build-$2.log" 2>&1 || { note "$2: build failed"; tail -5 "$OUT/100-build-$2.log"; continue; }
  swift test --skip-build --filter 'PackagingTests|UIStatusTests' > "$OUT/100-$2.log" 2>&1
  rc=$?
  note "$2: swift test --filter 'PackagingTests|UIStatusTests' exit $rc; $(grep -E 'Executed [0-9]+ tests' "$OUT/100-$2.log" | tail -1 | sed 's/^ *//')"
  grep -E 'error: ' "$OUT/100-$2.log" | sed -E 's|^.*/Tests/|    Tests/|' | cut -c1-330 | head -8
done
defaults write -g AppleLanguages -array en-US
defaults delete -g AppleLocale
note "language set back to: $(defaults read -g AppleLanguages | tr -d '\n ')"
