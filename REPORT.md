# openai/math Oct-26 release — independent Comparator audit
Times Asia/Shanghai (UTC+8). Commit: `7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a` (main; merge of PR #3, content commit `42907c9`, 2026-10-26).

## Targets (from lean/formalization.yaml + lean/docs)
| Result | Config | Theorems | Scope doc |
|---|---|---|---|
| Local smoothing (Oct-25 paper) | ComparatorChallenges/LocalSmoothing.json → OAI.Analysis.Fourier.LocalSmoothing.Comparator | euclidean_local_smoothing, bochner_riesz, spherical_restriction, kakeya_maximal, kakeya, stein_square | docs/079.md |
| "The Exponential Time Hypothesis is False" (Oct-25 paper, CS) | ComparatorChallenges/SubexponentialSAT.json → OAI.Algorithms.SubexponentialSAT.Main | exact_count_and_sat | docs/378.md |

Permitted axioms in both configs: `propext`, `Quot.sound`, `Classical.choice`. Isolation: mathaudit uid 1001, landrun, lean4export, restrict-af-unix; Mathlib only from cache.mathlib.org; no premise/definition/axiom edits.

## Verdicts
| Target | Comparator (Lean default kernel) | nanoda | Axioms |
|---|---|---|---|
| LocalSmoothing | **VERIFIED** — “Lean default kernel accepts the solution / Your solution is okay!” (attempt3 exit 0) | **accepts** (exit 0) | all 6 thms: only propext, Classical.choice, Quot.sound (axcheck2, Solution-only import) |
| SubexponentialSAT | **VERIFIED** — “Lean default kernel accepts the solution / Your solution is okay!” (attempt6 Comparator exit 0) | **PENDING** larger-stack rerun — first run: nanoda stack overflow (exit 134 → comparator rc=1); default kernel still accepts | exact_count_and_sat: only propext, Classical.choice, Quot.sound (axcheck exit 0) |

No Lean default-kernel error was reported on either completed target. SAT nanoda failure is a **tool/runtime stack overflow**, not evidence that the Lean kernel rejects the proof (default kernel accepted twice: dedicated Comparator run + nanoda follow-up).

## LocalSmoothing — details
- Comparator attempt3: exit 0; wall ~1:52 from `ls/attempt3.time.txt`.
- nanoda: “nanoda kernel accepts the solution” + default kernel accepts (`ls/ls-nanoda.*`, exit 0; wall ~54m).
- Axioms (`ls/axcheck2.out`): each of the 6 theorems depends only on `[propext, Classical.choice, Quot.sound]`.
- Qualifiers (env, not math): resume-in-same-tree after earlier disk-floor kill; attempt2 prune-race ENOENT; Solution oleans reused; integrity-diff empty vs baseline.

## SubexponentialSAT — details (attempt6, post-wipe)
### Timeline
| Step | Result | Wall (Asia/Shanghai) | Notes |
|---|---|---|---|
| Env wipe | destroyed mid-bulk | ~01:44–01:50 | mathaudit+tree gone mid prior bulk (~9475/9480); tools+user recreated |
| Setup recreate | SETUP_OK | 02:04:38 | tool hashes MATCH round1 |
| Clone+checkout | 7ef5c0cc… | 02:12:58 | fresh tree |
| cache get | 8926 oleans | 02:12:58–02:19:38 | cache.mathlib.org only; first try aborted rc=127 (`/usr/bin/time` missing → bash shim) |
| Bulk lake build `+Main` r1 | **SUCCESS** 12014/12014 | 02:19:51–08:16:32 | `LEAN_NUM_THREADS=1`; **no OOM**; no alone retries; no `/swapfile3` |
| Integrity | oleans clean | 08:17 | full `.lake` (excl build/git) diff 22 lines = volatile `*.olean.{server,private}.hash` + new proofwidgets `package-lock.json.hash` only; oleans-only and no-`*.hash` diffs **0 lines** |
| Comparator | **VERIFIED** exit 0 | 08:19:01–08:53:29 | “Lean default kernel accepts the solution / Your solution is okay!” |
| axcheck | exit 0 | 08:53:30–08:54:39 | `exact_count_and_sat` → `[propext, Classical.choice, Quot.sound]` |
| nanoda | rc=1 | 08:54:39–09:27:03 | stdout: “nanoda kernel rejected the solution”; stderr: `thread 'thread_1' has overflowed its stack` / `fatal runtime error: stack overflow` / `nanoda exited with 134`; then “Lean default kernel accepts the solution” |
| Tree delete | done | 09:28+ | logs copied to workspace first; free disk 16G→50G |

Heavy modules that previously OOM’d under higher parallelism built OK under lean_n=1, e.g. HighQueryProgram (~103s), HighQuerySetup (122s), HighQueryLoop (87s), HighQueryTraversal (95s), QueryNodeLoopSpace (73s), QueryPairEvaluation (86s).

### Semantic review (Challenge file; kernel-verified statement)
For each k≥2 there exists one fixed multi-tape PrimitiveMachine such that for every n and every width-≤k CNF F on Fin n (canonical encoding) the machine halts with exact #SAT count (binary) and SAT bit, with time ≤ C·(L+1)^d·2^{A·n(log log n)²/√log n} and visited cells ≤ S·(L+1)^e. Matches docs/378; kernel-verified ⇒ ETH fails under the formalized cost model. Machine may depend on k; time bound has (log log n)² (weaker than paper’s log log n, as doc says). Custom TM defined in Challenge — faithfulness is part of the trusted statement; no oracle/loophole spotted on read.

## LocalSmoothing semantic review (confirmed by kernel)
Statements match docs/079: full Sogge local smoothing range; full Bochner–Riesz; strict-range restriction; Kakeya maximal / Kakeya dim = n; Stein square function. Extremely strong claims (all dimensions). No hidden hypotheses found on read.

## Environment
- Lean 4.34.1; comparator d03acab; landrun 811cfff5; nanoda 3a24072; restrict-af-unix.
- Host RAM 15G + existing swap (~15G). Disk floor 5G (free stayed ≥16G during SAT build; no IR prune needed).
- Isolation: restrict-af-unix + landrun (`--unrestricted-filesystem` for builds); cache get unsandboxed.
- Tool-only: comparator lean-toolchain bump 4.34.0→4.34.1 (as prior rounds). Repo source unmodified (workspace-diff empty after Comparator).
- Lake “repository … has local changes” warnings after cache get (noted).

## Qualifiers (complete list — env/tool, not math)
1. **Post-wipe recreate**: env wipe ~01:44–01:50 Asia/Shanghai destroyed mathaudit+tree mid prior bulk; attempt6 is a fresh clone at 7ef5c0cc after recreating user+tools.
2. **Tool hashes vs round1 MATCH**: comparator, landrun, nanoda_bin, restrict-af-unix, lean4export (see `sat/tool-hash-vs-round1.txt`).
3. **`/usr/bin/time` bash shim**: GNU time missing post-wipe (apt broken); shim records start/end timestamps + exit only (no RSS/max). First cache-get aborted rc=127 before shim.
4. **Pre-built Mathlib oleans**: 8926 from cache.mathlib.org; Solution oleans built in-sandbox from pinned commit before Comparator.
5. **Integrity sidecars only**: packages oleans unchanged (oleans-only diff empty); 22-line full diff = Lean `*.olean.{server,private}.hash` sidecars + one new proofwidgets `package-lock.json.hash`.
6. **Integrity script hiccup**: original `sat_bulk.sh` died after writing integrity files because `sudo wc -l < file` redirected as box (permission); postbulk continued manually with same rules — not a math issue.
7. **Bulk lean_n=1, no OOM**: single bulk round success; no alone-module retries; no `/swapfile3` added.
8. **nanoda stack overflow**: nanoda rejected with tool stack overflow (exit 134); **not** a Lean default-kernel rejection. Dedicated Comparator already VERIFIED; nanoda run’s follow-up default kernel also accepts.
9. **No source edits** of Challenge/Solution/Mathlib.
10. Large `.lake` trees deleted after log copy (LS earlier; SAT after this report).

## Artifacts
- Logs: `/workspace/openai-math-audit-oct26/{ls,sat,common,scripts}/`
- Bundle: `/workspace/openai-math-audit-oct26.tar.gz` + `.sha256`
- Key SAT files: `sat/sat.stdout.log`, `sat/sat.exitcode` (0), `sat/sat-nanoda.stdout.log`, `sat/sat-nanoda.stderr.log` (stack overflow), `sat/sat-nanoda.exitcode` (1), `sat/axcheck.out`, `sat/bulk-r1.stdout.log`, `sat/qualifiers-full.txt`, `sat/tool-hash-vs-round1.txt`, `sat/integrity-diff-oleans-only.txt` (empty)


## Nanoda-on-SAT PENDING (larger stack)

First recorded nanoda run (attempt6) hit a **tool stack overflow** (`thread 'thread_1' has overflowed its stack`, nanoda exit 134). Lean default kernel accepted the solution both in the dedicated Comparator run and in the nanoda follow-up. A larger-stack rerun (`ulimit -s unlimited` / `RUST_MIN_STACK` / bigger thread stack) is planned; results will replace this PENDING marker.
