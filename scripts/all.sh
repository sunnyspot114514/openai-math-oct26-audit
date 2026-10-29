#!/bin/bash
set -u
D=/home/mathaudit/aud; mkdir -p $D/common
bash /tmp/aud_scripts/selftest.sh > $D/common/selftest.log 2>&1
bash /tmp/aud_scripts/target.sh sat SubexponentialSAT; echo "sat driver rc=$?" >> $D/all.log
bash /tmp/aud_scripts/target.sh ls LocalSmoothing; echo "ls driver rc=$?" >> $D/all.log
echo ALLDONE $(date -Is) >> $D/all.log
