#!/bin/bash
# PR 91: a stale .private.swiftinterface from an older Swift in the
# toolchain's PackageDescription. Plants one in the VM's Xcode 27 toolchain,
# builds main and the PR, removes it, builds the PR again. t91.sh
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
note() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
OUT="$HOME/lab-out"; mkdir -p "$OUT"
D="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule"
P="$D/arm64-apple-macos.private.swiftinterface"
note "== PR 91 on macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), $(xcodebuild -version | head -1), $(swift --version 2>&1 | head -1)"
trap 'sudo -n rm -f "$P"' EXIT
sed -e 's|^// swift-compiler-version: .*|// swift-compiler-version: Apple Swift version 5.10 (swiftlang-5.10.0.13 clang-1500.3.9.4)|' -e '/v26/d' "$D/arm64-apple-macos.swiftinterface" > /tmp/stale.private.swiftinterface
sudo -n cp /tmp/stale.private.swiftinterface "$P"
note "planted $P (compiler line says Swift 5.10, no v26)"
cd "$HOME/build-src" || exit 1
for rev in 76e517d b5f7b7d; do
  git checkout -q --detach $rev
  rm -rf "$HOME/Library/Caches/org.swift.swiftpm/manifests" .build/manifest.db* 2>/dev/null
  ./scripts/build-app.sh --output "/tmp/b91-$rev" > "$OUT/91-$rev-stale.log" 2>&1
  note "$rev with the stale file: build-app.sh exit $?"
  grep -vE '^\s*$' "$OUT/91-$rev-stale.log" | grep -vE '^\[[0-9]+/[0-9]+\]|^Compiling|^Building|^Write|^Emitting' | tail -14 | sed 's/^/    /'
done
sudo -n rm -f "$P"
note "removed the stale file"
rm -rf "$HOME/Library/Caches/org.swift.swiftpm/manifests" .build/manifest.db* 2>/dev/null
./scripts/build-app.sh --output /tmp/b91-clean > "$OUT/91-b5f7b7d-clean.log" 2>&1
note "b5f7b7d without it: build-app.sh exit $?; advice lines: $(grep -c -iE 'stale|sudo rm|older Swift' "$OUT/91-b5f7b7d-clean.log")"
tail -3 "$OUT/91-b5f7b7d-clean.log" | sed 's/^/    /'
