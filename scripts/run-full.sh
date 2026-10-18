#!/bin/bash
# run-full.sh: the 2026-10-17 evening PR runs on macOS 27.0.1, each PR head
# against main 76e517d where a before/after helps.
cd "$HOME/lab" || exit 1
source "$HOME/lab/lib.sh"
main=76e517d
SUP="$HOME/Library/Application Support/Insomnia"
quit_app
[ -f "$HOME/config.pristine.json" ] || cp "$SUP/config.json" "$HOME/config.pristine.json"
fresh() { quit_app; cp "$HOME/config.pristine.json" "$SUP/config.json"; }
echo "START $(date -u +%H:%M:%SZ) macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
fresh; bash t74.sh 73cfa73 head;  fresh; bash t74.sh $main main
fresh; bash t84.sh aad9e76 head;  fresh; bash t84.sh $main main
fresh; bash t116.sh bfceef9 head; fresh; bash t116.sh $main main
fresh; bash t117.sh 099f650 head
fresh; bash t99.sh 34f3f43 head
fresh; bash t104.sh 3a13fa0 head
fresh; bash t120.sh $main main;   fresh; bash t120.sh 5d8c3dd head
bash t91.sh
fresh; bash t93.sh $main main;    fresh; bash t93.sh 2ffa415 head
fresh
echo "ALL DONE $(date -u +%H:%M:%SZ)"
