#!/bin/bash
set -euo pipefail
R=/home/mathaudit/aud/sat
O=$R/out
BIN=/home/mathaudit/bin
J=SubexponentialSAT
LOG=/tmp/sat_seq_logs
STATE=/workspace/openai-math-audit-oct26/STATE.md
mem_av_kb(){ awk '/MemAvailable/{print $2}' /proc/meminfo; }
lean_n(){ pgrep -c '[l]ean$' 2>/dev/null || pgrep -cf '/bin/lean ' 2>/dev/null || echo 0; }
avail_g(){ df -BG / | awk 'NR==2{gsub(/G/,"",$4);print $4}'; }
log(){ echo "$(date -Is) $*" | tee -a $LOG/driver.log; }
qual(){ echo "$(date -Is) $*" | tee -a $LOG/qualifiers.txt | sudo -u mathaudit tee -a $O/qualifiers.txt >/dev/null; }
state(){ printf '## %s UTC+8 — %s\n' "$(date '+%Y-%m-%d %H:%M')" "$*" >> "$STATE"; }
is_oom_log(){ rg -q 'Killed|out of memory|Lean server printed an error|signal 9|Cannot allocate' "$1" 2>/dev/null; }
wait_no_lean(){ for i in 1 2 3 4 5 6 7 8 9 10; do n=$(pgrep -cf '/bin/lean ' 2>/dev/null || echo 0); [ "$n" = "0" ] && return 0; sleep 5; done; }
drop_caches(){ sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null || true; }
add_temp_swap(){
  if [ -f /swapfile3 ]; then return 0; fi
  free_g=$(avail_g)
  if [ "$free_g" -lt 6 ]; then qual "skip temp swap free=${free_g}G"; return 1; fi
  sudo fallocate -l 8G /swapfile3 || sudo dd if=/dev/zero of=/swapfile3 bs=1M count=8192
  sudo chmod 600 /swapfile3; sudo mkswap /swapfile3; sudo swapon /swapfile3
  qual "added /swapfile3 8G"
}
rm_temp_swap(){ sudo swapoff /swapfile3 2>/dev/null || true; sudo rm -f /swapfile3; }

log "POSTBULK start integrity already recorded; Comparator next"
state "SAT postbulk: Comparator starting"

# Comparator
echo "start=$(date -Is) LEAN_NUM_THREADS=1" | sudo -u mathaudit tee "$O/sat.cmd.txt" >/dev/null
( while true; do echo "$(date -Is) MemAvail_kB=$(mem_av_kb) lean_n=$(lean_n) free=$(avail_g)G"; sleep 20; done ) \
  | sudo -u mathaudit tee "$O/sat.memsamples.txt" >/dev/null &
S=$!
log "Comparator"
set +e
sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit \
  PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin \
  ELAN_HOME=/home/mathaudit/.elan LANG=C.UTF-8 LEAN_NUM_THREADS=1 \
  COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export \
  bash -c "cd '$R/math/lean' && /usr/bin/time -v -o '$O/sat.time.txt' $BIN/restrict-af-unix bash -c 'lake env $BIN/comparator ComparatorChallenges/$J.json'" \
  > $LOG/sat.stdout.log 2> $LOG/sat.stderr.log
RC=$?
set -e
kill $S 2>/dev/null || true
wait $S 2>/dev/null || true
sudo cp $LOG/sat.stdout.log "$O/sat.stdout.log"
sudo cp $LOG/sat.stderr.log "$O/sat.stderr.log"
sudo chown mathaudit:mathaudit "$O/sat.stdout.log" "$O/sat.stderr.log"
echo $RC | sudo -u mathaudit tee "$O/sat.exitcode" >/dev/null
echo "end=$(date -Is) exit_code=$RC" | sudo -u mathaudit tee -a "$O/sat.cmd.txt" >/dev/null
log "Comparator rc=$RC"
tail -30 $LOG/sat.stdout.log >> $LOG/driver.log || true
if [ "$RC" -ne 0 ]; then
  if is_oom_log $LOG/sat.stdout.log || is_oom_log $LOG/sat.stderr.log || [ "$RC" = "137" ]; then
    qual "Comparator OOM — temp swap + retry"; add_temp_swap || true; wait_no_lean; drop_caches
    set +e
    sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit \
      PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin \
      ELAN_HOME=/home/mathaudit/.elan LANG=C.UTF-8 LEAN_NUM_THREADS=1 \
      COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export \
      bash -c "cd '$R/math/lean' && /usr/bin/time -v -o '$O/sat-retry.time.txt' $BIN/restrict-af-unix bash -c 'lake env $BIN/comparator ComparatorChallenges/$J.json'" \
      > $LOG/sat-retry.stdout.log 2> $LOG/sat-retry.stderr.log
    RC=$?; set -e
    sudo cp $LOG/sat-retry.stdout.log "$O/sat-retry.stdout.log" 2>/dev/null || true
    echo $RC | sudo -u mathaudit tee "$O/sat-retry.exitcode" >/dev/null
    [ "$RC" -eq 0 ] || { log "Comparator retry FAILED rc=$RC"; exit 1; }
    echo 0 | sudo -u mathaudit tee "$O/sat.exitcode" >/dev/null
    qual "Comparator OK after OOM retry"
  else
    log "Comparator FAILED rc=$RC"; exit 1
  fi
fi
state "SAT Comparator OK"
sudo -u mathaudit bash -c "{ git -C '$R/math' status --porcelain; echo '--'; git -C '$R/math' diff; echo '(end)'; } > '$O/workspace-diff.txt'"

# axcheck
log "axcheck"
sudo -u mathaudit mkdir -p "$R/ax"
sudo -u mathaudit tee "$R/ax/Ax.lean" >/dev/null << 'LEAN'
import OAI.Algorithms.SubexponentialSAT.Main
#print axioms OAI.Algorithms.SubexponentialSAT.SqrtLogSpace.exact_count_and_sat
LEAN
sudo -u mathaudit env -i HOME=/home/mathaudit PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin \
  ELAN_HOME=/home/mathaudit/.elan LANG=C.UTF-8 \
  bash -c "
    cd '$R/math/lean'
    export LEAN_PATH=\$(lake env printenv LEAN_PATH 2>/dev/null)
    PFX=\$(lean --print-prefix)
    $BIN/restrict-af-unix $BIN/landrun --best-effort --ro / --rw /dev -ldd -add-exec \
      --env PATH --env HOME --env LEAN_PATH --rox \"\$PFX\" -- \
      \"\$PFX/bin/lean\" '$R/ax/Ax.lean' > '$O/axcheck.out' 2>&1
    echo axcheck exit=\$? > '$O/axcheck-exitcode.txt'
    cp '$R/ax/Ax.lean' '$O/'
  "
log "axcheck done"; state "SAT axcheck done"
sudo cat "$O/axcheck.out" | tee -a $LOG/driver.log || true

# nanoda
log "nanoda prepare"
sudo -u mathaudit mkdir -p "$R/extra"
sudo -u mathaudit env -i HOME=/home/mathaudit PATH=/home/mathaudit/.elan/bin:/usr/bin:/bin \
  bash -c "cd '$R/math/lean' && python3 -c \"import json;c=json.load(open('ComparatorChallenges/$J.json'));c['enable_nanoda']=True;json.dump(c,open('$R/extra/$J-nanoda.json','w'),indent=2)\"; cp '$R/extra/$J-nanoda.json' '$O/'"
echo "start=$(date -Is)" | sudo -u mathaudit tee "$O/sat-nanoda.cmd.txt" >/dev/null
( while true; do echo "$(date -Is) MemAvail_kB=$(mem_av_kb) lean_n=$(lean_n)"; sleep 20; done ) \
  | sudo -u mathaudit tee "$O/sat-nanoda.memsamples.txt" >/dev/null &
S=$!
log "nanoda"
set +e
sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit \
  PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin \
  ELAN_HOME=/home/mathaudit/.elan LANG=C.UTF-8 LEAN_NUM_THREADS=1 \
  COMPARATOR_NANODA=$BIN/nanoda_bin COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export \
  bash -c "cd '$R/math/lean' && /usr/bin/time -v -o '$O/sat-nanoda.time.txt' $BIN/restrict-af-unix bash -c 'lake env $BIN/comparator $R/extra/$J-nanoda.json'" \
  > $LOG/sat-nanoda.stdout.log 2> $LOG/sat-nanoda.stderr.log
RC2=$?; set -e
kill $S 2>/dev/null || true
wait $S 2>/dev/null || true
sudo cp $LOG/sat-nanoda.stdout.log "$O/sat-nanoda.stdout.log"
sudo cp $LOG/sat-nanoda.stderr.log "$O/sat-nanoda.stderr.log"
sudo chown mathaudit:mathaudit "$O/sat-nanoda.stdout.log" "$O/sat-nanoda.stderr.log"
echo $RC2 | sudo -u mathaudit tee "$O/sat-nanoda.exitcode" >/dev/null
log "nanoda rc=$RC2"
tail -40 $LOG/sat-nanoda.stdout.log >> $LOG/driver.log || true
[ "$RC2" -eq 0 ] || { log "nanoda FAILED rc=$RC2"; exit 1; }
state "SAT nanoda OK"
rm_temp_swap || true
sudo -u mathaudit bash -c "du -sh '$R/math' > '$O/tree-size.txt'"
echo SAT_DONE | sudo -u mathaudit tee /home/mathaudit/aud/SAT_DONE >/dev/null
log "SAT_DONE"; state "SAT attempt6 COMPLETE (Comparator+nanoda+axcheck)"
