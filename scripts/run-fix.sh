#!/bin/bash
# run-fix.sh: the 2026-10-18 reruns of #74, #117 and #104 after the
# contributors' fixes. Each new head runs with a control: main ad96f8b for
# #74, the reviewed head for #117 and #104. run-fix.sh 74 117 104
cd "$HOME/lab" || exit 1
source "$HOME/lab/lib.sh"
main=ad96f8b
SUP="$HOME/Library/Application Support/Insomnia"
fresh() { quit_app; cp "$HOME/config.pristine.json" "$SUP/config.json"; }
echo "START $(date -u +%H:%M:%SZ) macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
for t in "$@"; do
  case "$t" in
    74) fresh; bash t74.sh 43f7523 head; fresh; bash t74.sh $main main ;;
    117)
      note "$(bash tls-lab.sh up)"
      fresh; bash t117e.sh 1516b95 head; fresh; bash t117e.sh 099f650 reviewed
      note "$(bash tls-lab.sh down)" ;;
    104) fresh; bash t104g.sh 43281e6 head; fresh; bash t104g.sh 3a13fa0 reviewed ;;
    104h) fresh; bash t104h.sh 43281e6 head; fresh; bash t104h.sh 3a13fa0 reviewed ;;
    104dock) fresh; DOCK=shown bash t104h.sh 43281e6 head ;;
    *) fresh; bash "$t" ;;
  esac
done
fresh
echo "ALL DONE $(date -u +%H:%M:%SZ)"
