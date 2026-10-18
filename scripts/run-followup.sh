#!/bin/bash
# run-followup.sh: follow-up runs after run-full.sh.
cd "$HOME/lab" || exit 1
source "$HOME/lab/lib.sh"
main=76e517d
SUP="$HOME/Library/Application Support/Insomnia"
fresh() { quit_app; cp "$HOME/config.pristine.json" "$SUP/config.json"; }
echo "START $(date -u +%H:%M:%SZ) macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
for t in "$@"; do
  case "$t" in
    84b) fresh; bash t84b.sh aad9e76 $main ;;
    117b) fresh; bash t117b.sh 099f650 head ;;
    104b) fresh; bash t104b.sh 3a13fa0 ;;
    117c) fresh; bash t117c.sh 099f650 ;;
    104c) fresh; bash t104c.sh 3a13fa0 ;;
    117d) fresh; bash t117d.sh 099f650 ;;
    93c) fresh; bash t93c.sh $main main; fresh; bash t93c.sh 2ffa415 head ;;
    93b) fresh; bash t93b.sh $main main; fresh; bash t93b.sh 2ffa415 head ;;
    *) fresh; bash $t ;;
  esac
done
fresh
echo "ALL DONE $(date -u +%H:%M:%SZ)"
