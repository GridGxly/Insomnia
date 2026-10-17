#!/bin/bash
# run-latest.sh VMNAME: every PR run again after the VM's update to the
# newest macOS point release. The earlier results are in ~/lab-out-<old version>.
cd "$HOME/lab" || exit 1
main=b6a7499
echo "START $(date -u +%H:%M:%SZ) macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
bash t111.sh $main main; bash t111.sh 9325f63 head
bash t111v.sh $main main; bash t111v.sh 9325f63 head
bash t111j.sh $main main 8; bash t111j.sh 9325f63 head 8
bash t98.sh $main main; bash t98.sh facab18 head
bash t98m.sh $main main; bash t98m.sh facab18 head
bash t108.sh $main main; bash t108.sh 3dfc607 head
bash t102.sh $main main; bash t102.sh b2151cc head
bash t59.sh $main main; bash t59.sh 504d8a2 head
if [ "$1" = lab27 ]; then
  bash t100.sh
  bash t122.sh
fi
echo "ALL DONE $(date -u +%H:%M:%SZ)"
