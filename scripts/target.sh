#!/bin/bash
# Oct26 audit: one target per fresh clone + fresh .lake. Usage: target.sh <tag> <ChallengeJsonBase>
set -u -o pipefail
TAG="$1"; J="$2"
REV=7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a
R=/home/mathaudit/aud/$TAG; O=$R/out; mkdir -p $O
BIN=/home/mathaudit/bin
log(){ echo "$(date -Is) $*" >> $O/driver.log; }
fail(){ log "STOP: $*"; exit 1; }
log "start target=$TAG json=$J"
cd $R && rm -rf math && git clone -q https://github.com/openai/math.git > $O/clone.log 2>&1 || fail "clone failed (network?)"
cd $R/math && git checkout -q $REV || fail checkout
{ git rev-parse HEAD; git status --porcelain | wc -l; git log -1; } > $O/checkout.txt
cd lean
cp lakefile* lake-manifest.json lean-toolchain $O/ 2>/dev/null
cp ComparatorChallenges/$J.json ComparatorChallenges/$J.lean $O/
{ echo "pre-cache .lake exists?"; ls -la .lake 2>&1; } > $O/pre-cache-lake.txt
log "cache get"
/usr/bin/time -v -o $O/cacheget.time.txt lake exe cache get > $O/cacheget.log 2>&1 || fail "cache get failed"
find .lake/packages -name '*.olean' -newer $O/checkout.txt | wc -l > $O/cache-olean-count.txt
CMD="lake env $BIN/comparator ComparatorChallenges/$J.json"
{ echo "date_start=$(date -Is)"; echo "cwd=$(pwd)"; echo "id=$(id)"; env | sort; echo "--- command ---"; echo "COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export $BIN/restrict-af-unix bash -c '$CMD'"; } > $O/$TAG.cmd.txt
( while true; do echo "$(date -Is) $(grep MemAvailable /proc/meminfo | tr -s ' ') $(df --output=avail -BG / | tail -1)"; sleep 30; done ) > $O/$TAG.memsamples.txt 2>&1 & S=$!
log "comparator run"
COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export /usr/bin/time -v -o $O/$TAG.time.txt $BIN/restrict-af-unix bash -c "$CMD" > $O/$TAG.stdout.log 2> $O/$TAG.stderr.log
RC=$?; kill $S
echo $RC > $O/$TAG.exitcode; echo "date_end=$(date -Is) exit_code=$RC" >> $O/$TAG.cmd.txt
log "comparator done rc=$RC"
{ git -C $R/math status --porcelain; echo "-- diff --"; git -C $R/math diff; echo "(end)"; } > $O/workspace-diff.txt
[ $RC -eq 0 ] || fail "comparator rc=$RC"
# axiom print (sandboxed), loading oleans built by this tree's sandboxed run
mkdir -p $R/ax; python3 - "$J" "$R/ax/Ax.lean" <<'PY'
import json,sys;c=json.load(open('ComparatorChallenges/%s.json'%sys.argv[1]))
open(sys.argv[2],'w').write('import %s\nimport %s\n'%(c['challenge_module'],c['solution_module'])+''.join('#print axioms %s\n'%t for t in c['theorem_names']))
PY
export LEAN_PATH=$(lake env printenv LEAN_PATH 2>/dev/null); PFX=$(lean --print-prefix)
$BIN/restrict-af-unix $BIN/landrun --best-effort --ro / --rw /dev -ldd -add-exec --env PATH --env HOME --env LEAN_PATH --rox "$PFX" -- "$PFX/bin/lean" $R/ax/Ax.lean > $O/axcheck.out 2>&1; echo "axcheck exit=$?" > $O/axcheck-exitcode.txt
unset LEAN_PATH; cp $R/ax/Ax.lean $O/
log "axcheck done"
mkdir -p $R/extra
python3 -c "import json;c=json.load(open('ComparatorChallenges/$J.json'));c['enable_nanoda']=True;json.dump(c,open('$R/extra/$J-nanoda.json','w'),indent=2)"
cp $R/extra/$J-nanoda.json $O/
CMD2="lake env $BIN/comparator $R/extra/$J-nanoda.json"
echo "COMPARATOR_NANODA=$BIN/nanoda_bin ... restrict-af-unix bash -c '$CMD2' (date_start=$(date -Is))" > $O/$TAG-nanoda.cmd.txt
( while true; do echo "$(date -Is) $(grep MemAvailable /proc/meminfo | tr -s ' ')"; sleep 30; done ) > $O/$TAG-nanoda.memsamples.txt 2>&1 & S=$!
log "nanoda run"
COMPARATOR_NANODA=$BIN/nanoda_bin COMPARATOR_LANDRUN=$BIN/landrun COMPARATOR_LEAN4EXPORT=$BIN/lean4export /usr/bin/time -v -o $O/$TAG-nanoda.time.txt $BIN/restrict-af-unix bash -c "$CMD2" > $O/$TAG-nanoda.stdout.log 2> $O/$TAG-nanoda.stderr.log
RC2=$?; kill $S
echo $RC2 > $O/$TAG-nanoda.exitcode; echo "date_end=$(date -Is) exit_code=$RC2" >> $O/$TAG-nanoda.cmd.txt
log "nanoda done rc=$RC2"
du -sh $R/math > $O/tree-size.txt
