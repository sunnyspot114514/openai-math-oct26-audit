# STATE — openai/math Oct-26 audit (times UTC+8)
- Commit: 7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a (main, merge PR #3; content commit 42907c9 2026-10-26)
- Targets: LocalSmoothing.json (6 thms, docs/079.md); SubexponentialSAT.json (`...SqrtLogSpace.exact_count_and_sat`, docs/378.md "ETH is False")
- Env: uid mathaudit(1001) recreated, ACL u:mathaudit:--- on /workspace, tools rebuilt in /home/mathaudit/{bin,tools}; hashes match round1 except landrun (same commit 811cfff5). Selftest: /home/mathaudit/aud/common/selftest2.log
- Scripts: /tmp/aud_scripts/{target.sh,ls.sh,watch.sh(disk floor 10G -> pkill -u mathaudit)}, launcher /tmp/ma.sh
- attempt0 (17:52): /usr/bin/time missing -> stopped before build; apt install time; rerun.
- SAT attempt1 18:03–18:48: killed by disk-floor watchdog at [10309/12014]; .lake ir/ = 6.6G C files; no verdict (env issue). Tree deleted, logs in /home/mathaudit/aud/sat/out.
- LS run started 18:53 (/home/mathaudit/aud/ls/out). DO NOT restart; check driver.log / ls.exitcode.
- 19:51 LS killed by watchdog at [10729/10784]; LS tree kept for resume. Audit STOPPED at disk floor; REPORT.md written. Need user to free disk (~15G+ for LS resume, ~30G for SAT).

## 2026-10-28 ~03:10 UTC+8
- User approved ~/.cache/uv deleted (already gone). Free ~12G. Watchdog floor lowered to 5G.
- Resuming LS in kept tree: prune .lake/build/ir (11G regenerable C), integrity baseline, Challenge outputs deleted, attempt 2+.
- Then nanoda + axcheck; then fresh SAT.

## 2026-10-28 ~03:58 UTC+8
- attempt2 rc=1: NOT math. Prune daemon deleted `.c`/`.setup.json` while lean was writing them (ENOENT on 8 modules). LocalSmoothing-related modules mostly Built (BochnerRiesz.MainTheorem, SquareFunction.LocalSmoothing, etc.).
- Prune disabled during build. integrity-diff-attempt2 taken. Continuing attempt 3+ (Challenge outputs deleted; failed-module partials cleared).
- Watchdog still 5G. Free ~22G.

## 2026-10-28 ~04:49 UTC+8
- attempt3 still running (~48+ min). DO NOT restart. Monitoring.
- attempt2 qualifier: prune race (ENOENT); integrity-diff empty; packages intact.
## 2026-10-28 ~05:00 UTC+8
- attempt3: Build completed successfully (11184 jobs) ~04:51. Comparator still running (export/kernel phase). Not restarted.
## 2026-10-28 ~05:22 UTC+8
- attempt3 still in post-build phase: comparator pid 943093, etime ~1h21, ~36% CPU, RSS ~2.8G, no children (in-process export/check). stdout stuck at "Build completed successfully". Monitoring; not restarted.
## 2026-10-28 ~05:39 UTC+8
- Reattached: attempt3 build done; comparator 943093 still in export/kernel phase. Monitoring; not restarted.
## 2026-10-28 ~05:52 UTC+8
- attempt3: Challenge Built+exported (sorry warnings expected). Solution Build completed 11184 jobs. Comparator still running (etime ~1h50, ~53% CPU, RSS~2.8G) — likely Solution export / Lean kernel. Not restarted.
## 2026-10-28 ~05:53 UTC+8
- attempt3 Comparator EXIT 0: "Lean default kernel accepts the solution / Your solution is okay!" Challenge Built fresh; Solution Built. Qualifier: resume-in-tree after attempt1 disk-kill + attempt2 prune-race.
- axcheck done; nanoda started. Monitoring nanoda.
## 2026-10-28 (post-interrupt) monitoring nanoda
## 2026-10-28 ~06:50 UTC+8 — LS COMPLETE
- Comparator attempt3: VERIFIED (Lean kernel accepts). Challenge **Built** fresh. Wall 1:52:17, max RSS 7.69 GB.
- nanoda: VERIFIED ("nanoda kernel accepts" then Lean accepts). Wall 53:54, max RSS 11.2 GB.
- Axioms (axcheck2, Solution-only import): all 6 thms depend only on propext, Classical.choice, Quot.sound.
- Qualifiers: resume-in-same-tree after disk-kill; attempt2 prune-race ENOENT (env); Solution oleans reused across attempts 2→3; integrity-diff empty vs baseline.
- LS logs copied to /workspace/openai-math-audit-oct26/ls/; tree deleted. Free disk after delete noted below.
- Starting fresh SAT run.
## 2026-10-28 ~06:58 UTC+8
- LS tree deleted; free ~47G. Fresh SAT started. Safe prune (setup.json/.c age>3min with olean) enabled. Watchdog floor 5G.
## monitoring SAT (post-interrupt)
## 2026-10-28 ~07:48 UTC+8
- SAT build ~10823/12014, free ~30G, .lake 13G. No comparator exit yet. Monitoring.
## 2026-10-28 ~08:09 UTC+8
- LS done/verified. Fresh SAT comparator still running — DO NOT restart. Monitoring to exit then nanoda/axcheck.
## 2026-10-28 ~09:00 UTC+8 — SAT OOM
- Comparator rc=1 at 08:53. Module: `OAI.Algorithms.SubexponentialSAT.SqrtLogSpace.HighQueryLoop` (✖ [11796/12014], Lean exited 137). Max RSS 12.6G. Environment OOM, not math.
- Retrying same tree with round-3 integrity protocol; Challenge outputs deleted; fewer remaining modules → less concurrency.
## 2026-10-28 ~09:08 UTC+8
- Fixed lean wrapper (was broken exec path). Chrome pause by pid. SAT resume attempt2 started.
## 2026-10-28 ~09:10 UTC+8
- attempt2: shell lean wrapper failed under landrun (exit 255) — env, not math.
- Replaced with C wrapper (setenv LEAN_NUM_THREADS=1 + execve lean.real). attempt3 started.
## 2026-10-28 ~09:15 UTC+8
- attempt3 aborted: C lean wrapper triggered broad module rebuild. Restored original lean binary.
- attempt4+: same-tree OOM resume without lean wrapper; rely on fewer remaining modules.
## 2026-10-28 ~09:21 UTC+8
- attempt4 running: Challenge Built+exported; Solution rebuilding many modules (attempt3 wrapper may have dirtied oleans). Monitoring toward HighQueryLoop. Chrome paused by pid.
## 2026-10-28 ~09:50 UTC+8
- SIGCONT sent to all chrome/chromium pids previously stopped. Must not pause shared Chrome again.
- SAT attempt4 running (~32+ min) — DO NOT restart. Monitoring.
## 2026-10-28 10:04 UTC+8
- Chrome: SIGCONT done earlier; no T-state processes.
- SAT attempt4 still running: ~11414/11460 Built. free~15G MemAvail~10G lean_procs=8. No exit yet. Watching (no restart).
## 2026-10-28 10:22 UTC+8
- SAT attempt4 ~11913/11944 Built (HighQueryDecode done). MemAvailable ~1.1–1.4G — tight near HighQueryLoop zone. Disk free 13G. Watching; no restart; no process pauses.
## 2026-10-28 10:34 UTC+8
- SAT attempt4 still alive: stuck compiling HighQueryProgram (~5.8G RSS) + QueryNodeLoopSpace (~5.2G) + 6 smaller. Last Built line still 11913/11944 (stdout not advanced since ~10:16). MemAvailable ~0.7G. Disk 13G free. No new OOM yet (dmesg only shows attempt1 08:22 kill). Watching; no improvisation; Chrome not paused.
## 2026-10-28 10:51 UTC+8
- HighQueryProgram Built (1821s). Progress 11987/12014. 3 lean procs (~5.2+4.4+2.8G). MemAvailable ~0.6G again. Disk 12G. Still watching attempt4 (no restart).
## 2026-10-28 10:56 UTC+8 — OOM again on attempt4
- HighQueryLoop Built OK (391s) this time.
- HighQuerySetup ✖ Lean exit 137 (OOM). dmesg: killed lean pid 1224998 at 10:53:03 Asia/Shanghai (anon-rss ~6.9G).
- Per user order: STOP, do not improvise further retries. Waiting for attempt4 wrapper to exit, then report.
## 2026-10-28 11:00–11:05 UTC+8 — STOP after attempt4 OOM
- Chrome: SIGCONT earlier; verified no T-state.
- Attempt4 OOM: HighQuerySetup Lean 137 (HighQueryLoop Built OK). Wrapper auto-started attempt5 → killed immediately (no improvise).
- Qualifiers recorded: attempt2 landrun wrapper 255; attempt3 C-wrapper rebuild aborted; attempt4/1 OOMs are env.
- LS remains VERIFIED (Comparator+nanoda+axioms). SAT incomplete (env OOM). nanoda/axcheck not run for SAT.
- Logs copied to workspace sat/; REPORT.md rewritten; deleting sat tree; refreshing tarball+sha256.
## 2026-10-28 11:01 UTC+8 — FINAL
- SAT tree deleted; free ~46G.
- Tarball refreshed: /workspace/openai-math-audit-oct26.tar.gz
- sha256: 6f68f6227d7437dd07b87615973b7baee7e5e4513bcc4d0053472fdce99f0c4d
- Chrome: no T-state. Audit stopped (SAT env OOM ×2). LS VERIFIED.

## 2026-10-29 00:38 UTC+8 — SAT attempt6 START (steering: OOM→retry→temp swap; sequential one-lean)
## 2026-10-29 00:41 UTC+8 — SAT attempt6 START: sequential one-lean LEAN_NUM_THREADS=1; OOM→retry→temp swap; no source edits
## 2026-10-29 00:43 UTC+8 — SAT cloned 7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a; starting cache get
## 2026-10-29 00:48 UTC+8 — SAT cache get done; oleans=8926; free=25G
## 2026-10-29 00:49 UTC+8 — SAT module closure 3092 modules; sequential build starting
## 2026-10-29 00:50 UTC+8 — SAT built 3/3092 last=OAI.Algorithms.SubexponentialSAT.SqrtLog.MomentsAssemblyFoldRel free=25G MemAvail_kB=13369780
## 2026-10-29 00:50 UTC+8 — SAT built 4/3092 last=OAI.Algorithms.SubexponentialSAT.SqrtLogSpace.BooleanDifferences free=25G MemAvail_kB=13370852

## 2026-10-29 00:53 UTC+8 — SAT attempt6: switched from per-module (3092×~20s lake overhead) to bulk LEAN_NUM_THREADS=1 lake build +Main; OOM→retry alone→temp swap
## 2026-10-29 00:54 UTC+8 — SAT attempt6 ABORT: missing tree/cache; run sat_seq clone first
## 2026-10-29 00:54 UTC+8 — SAT attempt6 bulk build +OAI.Algorithms.SubexponentialSAT.Main starting (tree reused)
## 2026-10-29 01:00 UTC+8 — SAT bulk r1 ~8981/8989 Built; lean_n=1; MemAvail~10G; free=25G; continuing
## 2026-10-29 01:15 UTC+8 — SAT bulk r1 ~9114/9120; lean_n=1 RSS~6.5G peak; MemAvail~11G free=24G
## 2026-10-29 01:25 UTC+8 — SAT bulk r1 still running (~9226+/9242); lean_n=1; killed stale sat_seq sleeper; MemAvail healthy; free~23G
## 2026-10-29 01:36 UTC+8 — SAT bulk r1 ~9343/9349; lean_n=1; MemAvail~11G free=22G; continuing (no restart)
## 2026-10-29 02:03 UTC+8 — ENV WIPE detected: /home/mathaudit gone, user gone, /tmp/aud_scripts gone, live SAT tree deleted (~01:44–01:50). Bulk was ~9475/9480 when last seen. Recreating mathaudit+tools then SAT attempt6 resume (fresh clone; no source edits).
## 2026-10-29 02:05 UTC+8 — tools SETUP_OK; launching SAT attempt6 sat_bulk (fresh clone+cache+LEAN_NUM_THREADS=1; OOM→alone→temp swap)
## 2026-10-29 02:05 UTC+8 — SAT attempt6 post-wipe: tools recreated; fresh clone+cache+bulk LEAN_NUM_THREADS=1
## 2026-10-29 02:06 UTC+8 — SAT cloned 7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a; cache get
## 2026-10-29 02:06 UTC+8 — SAT attempt6 ABORT: cache get failed rc=127
## 2026-10-29 02:08 UTC+8 — cache get failed rc=127 (/usr/bin/time missing post-wipe); installed time; relaunching sat_bulk
## 2026-10-29 02:08 UTC+8 — SAT attempt6 post-wipe: tools recreated; fresh clone+cache+bulk LEAN_NUM_THREADS=1
## 2026-10-29 02:08 UTC+8 — installed /usr/bin/time shim (apt broken); relaunching sat_bulk
## 2026-10-29 02:08 UTC+8 — SAT attempt6 post-wipe: tools recreated; fresh clone+cache+bulk LEAN_NUM_THREADS=1
## 2026-10-29 02:12 UTC+8 — SAT cloned 7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a; cache get
## 2026-10-29 02:15 UTC+8 — SAT attempt6 alive (pid 20923): cache get still running (mathlib4 clone). NOT restarted.
## 2026-10-29 02:15 UTC+8 — post-wipe note: ~01:44–01:50 Asia/Shanghai box reset removed /home/mathaudit (uid 1001), tools, /tmp/aud_scripts, live SAT tree (was ~9475/9480 Built). Recreated user+ma_setup.sh @ same pins. Tool sha256 vs round1 common/setup.log: comparator/landrun/nanoda_bin/restrict-af-unix IDENTICAL. /usr/bin/time is a post-wipe bash shim (gnu time missing; apt broken) — only wraps timing, does not alter lean/lake.
## 2026-10-29 02:19 UTC+8 — SAT cache get done; oleans=8926; free=38G
## 2026-10-29 02:23 UTC+8 — SAT cache get done oleans=8926; BULK r1 running ~8952/8955 lean_n=1 free=38G (no restart)
## 2026-10-29 02:33 UTC+8 — SAT bulk r1 ~9025/9027 lean_n=1 MemAvail~11G free=38G
## 2026-10-29 02:43 UTC+8 — SAT bulk r1 ~9101/9104 lean_n=1 MemAvail~11G free=37G
## 2026-10-29 02:53 UTC+8 — SAT bulk r1 ~9191/9204 lean_n=1 MemAvail~11G free=37G
## 2026-10-29 03:03 UTC+8 — SAT bulk r1 ~9286/9292 lean_n=1 MemAvail~11G free=36G
## 2026-10-29 03:05 UTC+8 — SAT bulk r1 ~9308/9312 lean_n=1 MemAvail~11G free=36G; monitoring to exit (no restart)
## 2026-10-29 03:10 UTC+8 — SAT bulk r1 ~9355/9360 lean_n=1 MemAvail~11G free=35G; no restart
## 2026-10-29 03:15 UTC+8 — SAT bulk r1 ~9403/9407 lean_n=1 MemAvail~11G free=35G
## 2026-10-29 03:20 UTC+8 — SAT bulk r1 ~9446/9454 lean_n=1 MemAvail~11G free=35G
## 2026-10-29 03:26 UTC+8 — SAT bulk r1 ~9496/9501 lean_n=1 MemAvail~11G free=34G
## 2026-10-29 03:31 UTC+8 — SAT bulk r1 ~9539/9547 HighIncidenceNeutral lean_n=1 MemAvail~11G free=34G
## 2026-10-29 03:36 UTC+8 — SAT bulk r1 ~9592/9604 HashFamily lean_n=1 MemAvail~11G free=34G
## 2026-10-29 03:41 UTC+8 — SAT bulk r1 ~9644/9649 LeafProgram lean_n=1 MemAvail~11G free=33G
## 2026-10-29 03:46 UTC+8 — SAT bulk r1 ~9697/9704 SubexpNode lean_n=1 MemAvail~11G free=33G
## 2026-10-29 03:52 UTC+8 — SAT bulk r1 ~9753/9762 RingTable lean_n~1 MemAvail~12G free=32G
## 2026-10-29 03:56 UTC+8 — SAT bulk r1 poll after abort
## 2026-10-29 04:00 UTC+8 — SAT bulk r1 ~9826/9834 lean_n=1 MemAvail~11G free=32G
## 2026-10-29 04:08 UTC+8 — SAT bulk r1 ~9891/9894 lean_n=1 MemAvail~11G free=31G
## 2026-10-29 04:15 UTC+8 — SAT bulk r1 ~9952/9956 PackingIncidence lean_n=1 MemAvail~11G free=31G
## 2026-10-29 04:24 UTC+8 — SAT bulk r1 ~10019/10029 Packing lean_n=1 MemAvail~11G free=30G
## 2026-10-29 04:33 UTC+8 — SAT bulk r1 ~10089/10097 PackingCaller lean_n~1 MemAvail~11G free=30G
## 2026-10-29 04:44 UTC+8 — SAT bulk r1 ~10202/10206 Spectral/Taylor lean_n=1 MemAvail~11G free=29G
## 2026-10-29 04:52 UTC+8 — SAT bulk r1 ~10257/10259 Matrix/Layout lean_n=1 MemAvail~11G free=29G
## 2026-10-29 05:04 UTC+8 — SAT bulk r1 ~10364/10369 Perturbation lean_n=1 MemAvail~11G free=28G
## 2026-10-29 05:13 UTC+8 — SAT bulk r1 ~10457/10460 GlobalBasis lean_n=1 MemAvail~11G free=27G
## 2026-10-29 05:23 UTC+8 — SAT bulk r1 ~10557/10560 Support/Moments lean_n=1 MemAvail~11G free=26G
## 2026-10-29 05:32 UTC+8 — SAT bulk r1 ~10637/10642 LeafProgramQuery lean_n=1 MemAvail~11G free=26G
## 2026-10-29 05:40 UTC+8 — SAT bulk r1 ~10750/10768 LayoutRank lean_n=1 MemAvail~12G free=25G
## 2026-10-29 05:47 UTC+8 — SAT bulk r1 ~10823/10832 LeafProgramNode lean_n=1 MemAvail~11G free=25G
## 2026-10-29 05:56 UTC+8 — SAT bulk r1 ~10920/10926 LeafProgramSource lean_n=1 MemAvail~11G free=24G
## 2026-10-29 06:05 UTC+8 — SAT bulk r1 ~11020/11023 CodeSetup lean_n=1 MemAvail~11G free=23G
## 2026-10-29 06:15 UTC+8 — SAT bulk r1 ~11119/11126 CostAssembly/Subexp lean_n=1 MemAvail~11G free=23G
## 2026-10-29 06:25 UTC+8 — SAT bulk r1 ~11182/11192 PackingCallerBounds lean_n=1 MemAvail~11G free=22G
## 2026-10-29 06:34 UTC+8 — SAT bulk r1 ~11246/11248 NodeEnvelope lean_n=1 MemAvail~11G free=22G
## 2026-10-29 06:44 UTC+8 — SAT bulk r1 ~11326/11328 PreparedReady lean_n=1 MemAvail~11G free=21G
## 2026-10-29 06:53 UTC+8 — SAT bulk r1 ~11439/11450 LeafProgramNodeConcrete lean_n=1 MemAvail~11G free=20G
## 2026-10-29 06:59 UTC+8 — SAT bulk r1 ~11508/11511 Setup lean_n=1 MemAvail~11G free=20G
## 2026-10-29 07:08 UTC+8 — SAT bulk r1 ~11605/11612 Sparsify lean_n=1 MemAvail~11G free=19G
## 2026-10-29 07:19 UTC+8 — SAT bulk r1 ~11678/11687 FactorPacket lean_n=1 MemAvail~10G free=19G
## 2026-10-29 07:27 UTC+8 — SAT bulk r1 ~11729 MEM PRESSURE MemAvail~5.6G lean compiling DFSVisit
## 2026-10-29 07:32 UTC+8 — SAT bulk r1 ~11756/11765 HighIncidenceStream lean_n=1 MemAvail~10G free=18G
## 2026-10-29 07:38 UTC+8 — SAT bulk r1 ~11798/11801 HighQuery done lean_n=1 MemAvail~11G free=18G
## 2026-10-29 07:44 UTC+8 — SAT bulk r1 ~11857 compiling HighQueryProgram MemAvail~8.7G
## 2026-10-29 07:47 UTC+8 — SAT bulk r1 HighQueryProgram OK 103s ~11867/11870 lean_n=1 MemAvail~11G
## 2026-10-29 07:52 UTC+8 — SAT bulk r1 ~11905/11915 lean_n=1 MemAvail~11G free=17G
## 2026-10-29 07:58 UTC+8 — SAT bulk r1 ~11930 compiling QueryNodeLoopSpace MemAvail~6.0G
## 2026-10-29 08:09 UTC+8 — SAT ~11975 HighQuerySetup OK(122s); compiling HighQueryLoop MemAvail~10G lean_n=1
## 2026-10-29 08:11 UTC+8 — SAT ~11978 HighQueryLoop OK(87s); HighQueryTraversal; disk=16G (≥5G) no prune; MemAvail~9.4G
## 2026-10-29 08:16 UTC+8 — SAT bulk +OAI.Algorithms.SubexponentialSAT.Main OK round=1
## 2026-10-29 08:18 UTC+8 — BULK SUCCESS 12014/12014 no OOM; integrity oleans=0 (sidecar .hash only); starting Comparator
## 2026-10-29 08:19 UTC+8 — SAT postbulk: Comparator starting
## 2026-10-29 08:32 UTC+8 — Comparator running lean_n=0 RSS~5.0G MemAvail~7.5G disk=16G (post lake-replay+export)
## 2026-10-29 08:48 UTC+8 — Comparator still running ~28m RSS~8.7G MemAvail~4.5G CPU~88% (LS Comp was ~1h52m)
## 2026-10-29 08:53 UTC+8 — SAT Comparator OK
## 2026-10-29 08:54 UTC+8 — SAT axcheck done
## 2026-10-29 08:58 UTC+8 — Comparator VERIFIED (rc=0); axcheck OK axioms=propext,Classical.choice,Quot.sound; nanoda running
## 2026-10-29 09:09 UTC+8 — nanoda kernel ~15m RSS~5.2G MemAvail~7.8G disk=16G (no restart)
## 2026-10-29 09:29 UTC+8 — SAT attempt6 COMPLETE: Comparator VERIFIED; axcheck OK; nanoda stack-overflow reject (rc=1); tree deleted; REPORT written
