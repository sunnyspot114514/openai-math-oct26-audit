#!/bin/bash
# SAT attempt6 (post-wipe resume): LEAN_NUM_THREADS=1 lake build +Main.
# On OOM: retry failed module alone; temp swap; never edit source. Runs as box.
set -u -o pipefail
J=SubexponentialSAT
REV=7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a
R=/home/mathaudit/aud/sat
O=$R/out
BIN=/home/mathaudit/bin
STATE=/workspace/openai-math-audit-oct26/STATE.md
DISK_FLOOR_G=5
SWAP_EXTRA=/swapfile3
MAIN=OAI.Algorithms.SubexponentialSAT.Main
ATTEMPT=6

mkdir -p /tmp/sat_seq_logs
sudo -u mathaudit mkdir -p "$O"

log(){ echo "$(date -Is) $*" | tee -a /tmp/sat_seq_logs/driver.log | sudo -u mathaudit tee -a "$O/driver.log" >/dev/null; }
state(){ echo "## $(date '+%Y-%m-%d %H:%M') UTC+8 — $*" >> "$STATE"; }
die(){ log "ABORT: $*"; echo "$*" | sudo -u mathaudit tee "$O/ABORTED.txt" >/dev/null; state "SAT attempt$ATTEMPT ABORT: $*"; exit 1; }
avail_g(){ df --output=avail -BG / | tail -1 | tr -dc '0-9'; }
mem_av_kb(){ awk '/MemAvailable/{print $2}' /proc/meminfo; }
lean_n(){ local n; n=$(pgrep -c -x lean 2>/dev/null || true); echo "${n:-0}"; }
qual(){ echo "$(date -Is) $*" | tee -a /tmp/sat_seq_logs/qualifiers.txt | sudo -u mathaudit tee -a "$O/qualifiers.txt" >/dev/null; }
disk_ok(){ local a; a=$(avail_g); [ "$a" -ge "$DISK_FLOOR_G" ] || die "disk floor breached: ${a}G"; }
drop_caches(){ sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null || true; }

run_timed(){
  # usage: run_timed outfile cmd...
  local out="$1"; shift
  if [ -x /usr/bin/time ]; then
    /usr/bin/time -v -o "$out" "$@"
    return $?
  fi
  echo "time_unavailable $(date -Is)" > "$out"
  "$@"
  return $?
}

wait_no_lean(){ local i=0; while [ "$(lean_n)" -gt 0 ]; do i=$((i+1)); [ $i -gt 180 ] && break; sleep 1; done; }

add_temp_swap(){
  if [ -e "$SWAP_EXTRA" ]; then
    grep -q "$SWAP_EXTRA" /proc/swaps || sudo /sbin/swapon "$SWAP_EXTRA"
    qual "temp swap present/active $SWAP_EXTRA"; return 0
  fi
  local free_g need_g; free_g=$(avail_g); need_g=8
  [ $((free_g - need_g)) -lt "$DISK_FLOOR_G" ] && need_g=$((free_g - DISK_FLOOR_G))
  [ "$need_g" -ge 1 ] || { qual "cannot add temp swap free=${free_g}G"; return 1; }
  log "creating temp swap ${need_g}G at $SWAP_EXTRA"
  sudo dd if=/dev/zero of="$SWAP_EXTRA" bs=1G count="$need_g" status=none
  sudo chmod 600 "$SWAP_EXTRA"; sudo /sbin/mkswap "$SWAP_EXTRA"; sudo /sbin/swapon "$SWAP_EXTRA"
  qual "added temp swap ${need_g}G at $SWAP_EXTRA"; disk_ok
}
rm_temp_swap(){
  grep -q "$SWAP_EXTRA" /proc/swaps 2>/dev/null && sudo /sbin/swapoff "$SWAP_EXTRA" && qual "swapoff $SWAP_EXTRA"
  [ -e "$SWAP_EXTRA" ] && sudo rm -f "$SWAP_EXTRA" && qual "removed $SWAP_EXTRA"
}

parse_oom_module(){
  local logf="$1" m
  m=$(rg -B5 'exited with code 137' "$logf" 2>/dev/null | rg -o 'OAI\.Algorithms\.SubexponentialSAT(\.[A-Za-z0-9_]+)+' | tail -1 || true)
  [ -z "$m" ] && m=$(rg '✖|error:' "$logf" 2>/dev/null | rg -o 'OAI\.Algorithms\.SubexponentialSAT(\.[A-Za-z0-9_]+)+' | tail -1 || true)
  echo "$m"
}
is_oom_log(){ grep -qE 'exited with code 137|Killed' "$1" 2>/dev/null; }

run_bulk_main(){
  local tag="$1"
  wait_no_lean; disk_ok
  [ "$(mem_av_kb)" -lt 2500000 ] && drop_caches
  log "BULK lake build +$MAIN tag=$tag lean_n=$(lean_n) MemAvail_kB=$(mem_av_kb) free=$(avail_g)G"
  echo "start=$(date -Is) tag=$tag LEAN_NUM_THREADS=1 bulk +$MAIN" | sudo -u mathaudit tee "$O/bulk-${tag}.cmd.txt" >/dev/null
  ( while true; do echo "$(date -Is) MemAvail_kB=$(mem_av_kb) lean_n=$(lean_n) free=$(avail_g)G"; sleep 15; done ) \
    | sudo -u mathaudit tee "$O/bulk-${tag}.memsamples.txt" >/dev/null &
  local S=$!
  set +e
  sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit LOGNAME=mathaudit \
    SHELL=/bin/bash LANG=C.UTF-8 LEAN_NUM_THREADS=1 \
    PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin \
    ELAN_HOME=/home/mathaudit/.elan \
    /usr/bin/time -v -o "$O/bulk-${tag}.time.txt" \
    "$BIN/restrict-af-unix" \
    "$BIN/landrun" --best-effort --unrestricted-filesystem \
      -ldd -add-exec --ignore-missing \
      --env PATH --env HOME --env LEAN_NUM_THREADS --env ELAN_HOME --env LANG --env USER \
      -- bash -c "cd '$R/math/lean' && lake build '+${MAIN}'" \
      > /tmp/sat_seq_logs/bulk-${tag}.stdout.log 2> /tmp/sat_seq_logs/bulk-${tag}.stderr.log
  local RC=$?
  set -e
  kill $S 2>/dev/null || true; wait $S 2>/dev/null || true
  sudo cp /tmp/sat_seq_logs/bulk-${tag}.stdout.log "$O/bulk-${tag}.stdout.log"
  sudo cp /tmp/sat_seq_logs/bulk-${tag}.stderr.log "$O/bulk-${tag}.stderr.log"
  sudo chown mathaudit:mathaudit "$O/bulk-${tag}.stdout.log" "$O/bulk-${tag}.stderr.log" "$O/bulk-${tag}.time.txt" 2>/dev/null || true
  echo $RC | sudo -u mathaudit tee "$O/bulk-${tag}.exitcode" >/dev/null
  echo "end=$(date -Is) exit_code=$RC" | sudo -u mathaudit tee -a "$O/bulk-${tag}.cmd.txt" >/dev/null
  echo $RC > /tmp/sat_seq_logs/bulk-${tag}.exitcode
}

run_one_mod(){
  local mod="$1" tag="$2"
  wait_no_lean; disk_ok
  [ "$(mem_av_kb)" -lt 2500000 ] && drop_caches
  log "ALONE lake build +$mod tag=$tag lean_n=$(lean_n) MemAvail_kB=$(mem_av_kb) free=$(avail_g)G"
  echo "start=$(date -Is) alone +$mod" | sudo -u mathaudit tee "$O/alone-${tag}.cmd.txt" >/dev/null
  ( while true; do echo "$(date -Is) MemAvail_kB=$(mem_av_kb) lean_n=$(lean_n) free=$(avail_g)G"; sleep 15; done ) \
    | sudo -u mathaudit tee "$O/alone-${tag}.memsamples.txt" >/dev/null &
  local S=$!
  set +e
  sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit LANG=C.UTF-8 LEAN_NUM_THREADS=1 \
    PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin ELAN_HOME=/home/mathaudit/.elan \
    /usr/bin/time -v -o "$O/alone-${tag}.time.txt" \
    "$BIN/restrict-af-unix" \
    "$BIN/landrun" --best-effort --unrestricted-filesystem \
      -ldd -add-exec --ignore-missing \
      --env PATH --env HOME --env LEAN_NUM_THREADS --env ELAN_HOME --env LANG --env USER \
      -- bash -c "cd '$R/math/lean' && lake build '+${mod}'" \
      > /tmp/sat_seq_logs/alone-${tag}.stdout.log 2> /tmp/sat_seq_logs/alone-${tag}.stderr.log
  local RC=$?
  set -e
  kill $S 2>/dev/null || true; wait $S 2>/dev/null || true
  sudo cp /tmp/sat_seq_logs/alone-${tag}.stdout.log "$O/alone-${tag}.stdout.log"
  sudo cp /tmp/sat_seq_logs/alone-${tag}.stderr.log "$O/alone-${tag}.stderr.log"
  sudo chown mathaudit:mathaudit "$O/alone-${tag}.stdout.log" "$O/alone-${tag}.stderr.log" 2>/dev/null || true
  echo $RC | sudo -u mathaudit tee "$O/alone-${tag}.exitcode" >/dev/null
  echo $RC > /tmp/sat_seq_logs/alone-${tag}.exitcode
}

# ----- phase: fresh clone + cache -----
log "sat_bulk start attempt$ATTEMPT (post-wipe recreate)"
qual "env wipe ~01:44–01:50 Asia/Shanghai destroyed mathaudit+tree mid-bulk (~9475/9480); recreating tools+fresh clone"
state "SAT attempt$ATTEMPT post-wipe: tools recreated; fresh clone+cache+bulk LEAN_NUM_THREADS=1"

sudo -u mathaudit rm -rf "$R"
sudo -u mathaudit mkdir -p "$O"
log "clone"
sudo -u mathaudit env -i HOME=/home/mathaudit PATH=/usr/bin:/bin \
  git clone -q https://github.com/openai/math.git "$R/math" > /tmp/sat_seq_logs/clone.log 2>&1 || die "clone failed"
sudo cp /tmp/sat_seq_logs/clone.log "$O/clone.log"; sudo chown mathaudit:mathaudit "$O/clone.log"
sudo -u mathaudit git -C "$R/math" checkout -q "$REV" || die checkout
sudo -u mathaudit bash -c "{ git -C '$R/math' rev-parse HEAD; git -C '$R/math' status --porcelain | wc -l; git -C '$R/math' log -1; } > '$O/checkout.txt'"
HEAD=$(sudo -u mathaudit git -C "$R/math" rev-parse HEAD)
[ "$HEAD" = "$REV" ] || die "HEAD $HEAD != $REV"
sudo -u mathaudit bash -c "cp '$R/math/lean'/lakefile* '$R/math/lean/lake-manifest.json' '$R/math/lean/lean-toolchain' '$O/' 2>/dev/null; cp '$R/math/lean/ComparatorChallenges/$J.json' '$R/math/lean/ComparatorChallenges/$J.lean' '$O/'"
log "checkout OK $HEAD"; state "SAT cloned $HEAD; cache get"

log "cache get"
sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit \
  PATH=/home/mathaudit/.elan/bin:/usr/bin:/bin ELAN_HOME=/home/mathaudit/.elan LANG=C.UTF-8 \
  bash -c "cd '$R/math/lean' && /usr/bin/time -v -o '$O/cacheget.time.txt' lake exe cache get" \
  > /tmp/sat_seq_logs/cacheget.log 2>&1
CRC=$?
sudo cp /tmp/sat_seq_logs/cacheget.log "$O/cacheget.log"; sudo chown mathaudit:mathaudit "$O/cacheget.log"
[ "$CRC" -eq 0 ] || die "cache get failed rc=$CRC"
sudo -u mathaudit bash -c "find '$R/math/lean/.lake/packages' -name '*.olean' | wc -l > '$O/cache-olean-count.txt'"
log "cache oleans=$(sudo cat $O/cache-olean-count.txt)"; disk_ok
state "SAT cache get done; oleans=$(sudo cat $O/cache-olean-count.txt); free=$(avail_g)G"

sudo -u mathaudit bash -c "cd '$R/math/lean' && find .lake -type f -not -path '.lake/build/*' -not -path '*/.git/*' -print0 | xargs -0 sha256sum 2>/dev/null | sort -k2 > '$O/baseline-packages.sha256'"
qual "attempt$ATTEMPT bulk LEAN_NUM_THREADS=1; OOM→alone→temp swap; no source edits; post-wipe fresh tree"

# ----- bulk loop -----
bulk_round=0; alone_oom_count=0; max_bulk=30
while [ $bulk_round -lt $max_bulk ]; do
  bulk_round=$((bulk_round+1))
  run_bulk_main "r${bulk_round}"
  rc=$(cat /tmp/sat_seq_logs/bulk-r${bulk_round}.exitcode)
  if [ "$rc" = "0" ]; then
    log "BULK SUCCESS round=$bulk_round"; state "SAT bulk +$MAIN OK round=$bulk_round"; break
  fi
  if ! is_oom_log /tmp/sat_seq_logs/bulk-r${bulk_round}.stdout.log && [ "$rc" != "137" ]; then
    if ! is_oom_log /tmp/sat_seq_logs/bulk-r${bulk_round}.stderr.log; then
      tail -50 /tmp/sat_seq_logs/bulk-r${bulk_round}.stdout.log >> /tmp/sat_seq_logs/driver.log
      die "bulk non-OOM failure rc=$rc round=$bulk_round"
    fi
  fi
  mod=$(parse_oom_module /tmp/sat_seq_logs/bulk-r${bulk_round}.stdout.log)
  [ -n "$mod" ] || mod=$(parse_oom_module /tmp/sat_seq_logs/bulk-r${bulk_round}.stderr.log)
  qual "OOM bulk round=$bulk_round rc=$rc module=${mod:-UNKNOWN}"
  state "SAT OOM bulk round=$bulk_round mod=${mod:-UNKNOWN} — retry alone"
  [ -n "$mod" ] || mod=$MAIN
  rel=$(echo "$mod" | tr '.' '/')
  sudo -u mathaudit bash -c "rm -f '$R/math/lean/.lake/build/lib/lean/${rel}'.* '$R/math/lean/.lake/build/ir/${rel}'.* 2>/dev/null" || true
  wait_no_lean; alone_oom_count=$((alone_oom_count+1)); drop_caches
  if [ $alone_oom_count -ge 2 ] || [ $bulk_round -ge 2 ]; then add_temp_swap || true; fi
  ok_alone=0
  for ar in 1 2 3 4; do
    wait_no_lean
    [ "$(lean_n)" -gt 0 ] && sleep 30 && wait_no_lean
    safe=$(echo "$mod" | tr './' '__')
    run_one_mod "$mod" "${safe}-b${bulk_round}-a${ar}"
    arc=$(cat /tmp/sat_seq_logs/alone-${safe}-b${bulk_round}-a${ar}.exitcode)
    if [ "$arc" = "0" ]; then
      log "ALONE OK +$mod"; qual "alone OK +$mod (bulk_round=$bulk_round alone_try=$ar)"; ok_alone=1; break
    fi
    if is_oom_log /tmp/sat_seq_logs/alone-${safe}-b${bulk_round}-a${ar}.stdout.log || [ "$arc" = "137" ]; then
      qual "OOM alone +$mod try=$ar — add swap and retry"; add_temp_swap || true; drop_caches; wait_no_lean; continue
    fi
    die "alone non-OOM failure +$mod rc=$arc"
  done
  [ "$ok_alone" = "1" ] || die "module +$mod still OOM alone after retries+swap"
done
[ $bulk_round -lt $max_bulk ] || die "exhausted $max_bulk bulk rounds"

# integrity
sudo -u mathaudit bash -c "
  cd '$R/math/lean'
  find .lake -type f -not -path '.lake/build/*' -not -path '*/.git/*' -print0 | xargs -0 sha256sum 2>/dev/null | sort -k2 > '$O/after-prebuild-packages.sha256'
  diff '$O/baseline-packages.sha256' '$O/after-prebuild-packages.sha256' > '$O/integrity-diff-prebuild.txt' || true
"
DIFFL=$(sudo wc -l < "$O/integrity-diff-prebuild.txt")
log "integrity diff lines=$DIFFL"; qual "integrity-diff-prebuild lines=$DIFFL"
[ "$DIFFL" = "0" ] || die "packages integrity diff non-empty"
qual "Solution oleans pre-built in-sandbox from pinned $REV; Comparator loads these"
rm_temp_swap || true

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
  > /tmp/sat_seq_logs/sat.stdout.log 2> /tmp/sat_seq_logs/sat.stderr.log
RC=$?
set -e
kill $S 2>/dev/null || true
sudo cp /tmp/sat_seq_logs/sat.stdout.log "$O/sat.stdout.log"
sudo cp /tmp/sat_seq_logs/sat.stderr.log "$O/sat.stderr.log"
sudo chown mathaudit:mathaudit "$O/sat.stdout.log" "$O/sat.stderr.log"
echo $RC | sudo -u mathaudit tee "$O/sat.exitcode" >/dev/null
echo "end=$(date -Is) exit_code=$RC" | sudo -u mathaudit tee -a "$O/sat.cmd.txt" >/dev/null
log "Comparator rc=$RC"
if [ "$RC" -ne 0 ]; then
  if is_oom_log /tmp/sat_seq_logs/sat.stdout.log || [ "$RC" = "137" ]; then
    qual "Comparator OOM — temp swap + retry"; add_temp_swap || true; wait_no_lean; drop_caches
    set +e
    sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit \
      PATH=/home/mathaudit/.elan/bin:/home/mathaudit/bin:/usr/bin:/bin \
      ELAN_HOME=/home/mathaudit/.elan LANG=C.UTF-8 LEAN_NUM_THREADS=1 \
      COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export \
      bash -c "cd '$R/math/lean' && /usr/bin/time -v -o '$O/sat-retry.time.txt' $BIN/restrict-af-unix bash -c 'lake env $BIN/comparator ComparatorChallenges/$J.json'" \
      > /tmp/sat_seq_logs/sat-retry.stdout.log 2> /tmp/sat_seq_logs/sat-retry.stderr.log
    RC=$?; set -e
    sudo cp /tmp/sat_seq_logs/sat-retry.stdout.log "$O/sat-retry.stdout.log"
    echo $RC | sudo -u mathaudit tee "$O/sat-retry.exitcode" >/dev/null
    [ "$RC" -eq 0 ] || die "Comparator retry rc=$RC"
    echo 0 | sudo -u mathaudit tee "$O/sat.exitcode" >/dev/null
  else die "Comparator rc=$RC"; fi
fi
state "SAT Comparator OK"
sudo -u mathaudit bash -c "{ git -C '$R/math' status --porcelain; echo '--'; git -C '$R/math' diff; echo '(end)'; } > '$O/workspace-diff.txt'"

# axcheck
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

# nanoda
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
  > /tmp/sat_seq_logs/sat-nanoda.stdout.log 2> /tmp/sat_seq_logs/sat-nanoda.stderr.log
RC2=$?; set -e
kill $S 2>/dev/null || true
sudo cp /tmp/sat_seq_logs/sat-nanoda.stdout.log "$O/sat-nanoda.stdout.log"
sudo cp /tmp/sat_seq_logs/sat-nanoda.stderr.log "$O/sat-nanoda.stderr.log"
sudo chown mathaudit:mathaudit "$O/sat-nanoda.stdout.log" "$O/sat-nanoda.stderr.log"
echo $RC2 | sudo -u mathaudit tee "$O/sat-nanoda.exitcode" >/dev/null
log "nanoda rc=$RC2"
[ "$RC2" -eq 0 ] || die "nanoda rc=$RC2"
state "SAT nanoda OK"
rm_temp_swap || true
sudo -u mathaudit bash -c "du -sh '$R/math' > '$O/tree-size.txt'"
echo SAT_DONE | sudo -u mathaudit tee /home/mathaudit/aud/SAT_DONE >/dev/null
log "SAT_DONE"; state "SAT attempt$ATTEMPT COMPLETE (Comparator+nanoda+axcheck)"
