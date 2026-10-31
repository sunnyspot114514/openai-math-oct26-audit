# OpenAI Math Oct-26 Independent Audit Bundle

[US English](README.md) | [CN 中文说明](README_zh.md)

Technical note and reproduction materials for an independent Comparator / Lean audit of

[`openai/math`](https://github.com/openai/math)

at frozen commit:

```text
7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a
```

(merge of PR #3 / content commit `42907c9`, 2026-10-26).

## Result at a glance

| Target | Comparator (Lean default kernel) | nanoda | Axioms |
|---|---|---|---|
| **LocalSmoothing** (Oct-25 paper) | **VERIFIED** — “Lean default kernel accepts the solution / Your solution is okay!” | **accepts** (exit 0) | all 6 thms: only `propext`, `Classical.choice`, `Quot.sound` |
| **SubexponentialSAT** (“ETH is False”, Oct-25 CS paper) | **VERIFIED** — same accept string (attempt6 exit 0) | **PENDING** — first run: nanoda stack overflow (exit 134 → comparator rc=1); default kernel still accepted. Larger-stack rerun tracked below / in `REPORT.md` | `exact_count_and_sat`: only `propext`, `Classical.choice`, `Quot.sound` |

**Start here:** [`REPORT.md`](./REPORT.md)

## Separation rule

1. **OpenAI upstream formalization** — `openai/math` @ `7ef5c0c…`, Challenge JSON + Solution modules.
2. **This audit bundle** — independent Linux replay under landrun / restrict-af-unix, axiom print, integrity hashes, and recorded tool versions.

**Do not conflate the two.** This repository is an independent technical audit and reproduction bundle. It is not an OpenAI endorsement and does not replace external mathematical peer review.

## Pinned upstream

```text
openai/math
7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a
```

See also [`UPSTREAM_COMMIT.txt`](./UPSTREAM_COMMIT.txt).

## Environment / tools

- Lean **4.34.1**; comparator **d03acab**; landrun **811cfff5**; nanoda **3a24072**; restrict-af-unix.
- Mathlib oleans from `cache.mathlib.org` only (8926 for SAT tree).
- Isolation: mathaudit uid 1001, landrun, lean4export, restrict-af-unix.
- Host: 15 GiB RAM; builds with `LEAN_NUM_THREADS=1`.

### Tool hashes vs first setup (MATCH)

```text
comparator  afa65e57a1770f5961efe7681626a9a1cd99705262421658abd30b705f66e4a2  MATCH
landrun     c41d19ff16b6529bb9211babde3529c087df2f2f02267a7c7310a0c59e76966e  MATCH
nanoda_bin  af265c649d7c5c329e1d18bcca0ad865f3e6b463f841693024eed92a16179bcf  MATCH
restrict    058b980012a18d668206d3c8b0d5df738cfebb1933efd0a1d411435a2fd3fe78  MATCH
lean4export 8c5d64ba68f4d3a68b3bcb7e1c5f188e35ae573b29470b8d4530a62324c9ddd1
```

Full note: [`sat/tool-hash-vs-round1.txt`](./sat/tool-hash-vs-round1.txt).

## Qualifiers (env / tool — not math)

1. **Post-wipe recreate** — host env wipe ~01:44–01:50 Asia/Shanghai destroyed mathaudit mid prior bulk; attempt6 = fresh clone after recreating user+tools.
2. **Tool hashes MATCH** round1 (above).
3. **`/usr/bin/time` bash shim** — GNU time missing post-wipe; shim records wall/exit only (no RSS).
4. **Pre-built Mathlib oleans** from cache.mathlib.org; Solution oleans built in-sandbox from pinned commit.
5. **Integrity** — packages oleans unchanged; full `.lake` (excl. build/git) had only volatile `*.olean.{server,private}.hash` sidecars + one proofwidgets `package-lock.json.hash`.
6. **Bulk `LEAN_NUM_THREADS=1`, no OOM** — single bulk round 12014/12014; no alone-module retries; no temp `/swapfile3`.
7. **nanoda stack overflow (PENDING larger-stack rerun)** — first nanoda: `thread 'thread_1' has overflowed its stack` / exit 134; Lean default kernel still accepts. See `sat/sat-nanoda.stderr.log`.
8. **No source edits** of Challenge / Solution / Mathlib.
9. Large `.lake` trees deleted after log copy.

## Artifacts in this repo

| Path | Contents |
|---|---|
| [`REPORT.md`](./REPORT.md) | Full bilingual-ready technical report |
| [`STATE.md`](./STATE.md) | Chronological build / monitor notes |
| [`ls/`](./ls/) | LocalSmoothing Comparator / nanoda / axcheck logs |
| [`sat/`](./sat/) | SubexponentialSAT bulk / Comparator / axcheck / nanoda logs |
| [`common/`](./common/) | Setup / selftest / tool notes |
| [`scripts/`](./scripts/) | Driver scripts used on the auditor host |
| [`openai-math-audit-oct26.tar.gz`](./openai-math-audit-oct26.tar.gz) | Packed copy of the audit tree |
| [`openai-math-audit-oct26.tar.gz.sha256`](./openai-math-audit-oct26.tar.gz.sha256) / [`SHA256SUMS.txt`](./SHA256SUMS.txt) | `c90d09fb1affc49436b9037d247bfee9876c91a0af7afc83d2d31d72963a72ca` |

## Nanoda-on-SAT status

**PENDING** larger-stack rerun. First recorded outcome:

```text
Running nanoda kernel on solution
nanoda kernel rejected the solution
… stderr: thread 'thread_1' has overflowed its stack
fatal runtime error: stack overflow
uncaught exception: nanoda exited with 134
Lean default kernel accepts the solution
exit_code=1
```

This is treated as a **tool/runtime limit**, not as Lean default-kernel rejection of the proof. Updates after a `ulimit -s unlimited` / `RUST_MIN_STACK` / larger thread-stack rerun will be written into `REPORT.md` and this README.

## License / stance

Independent audit notes. Upstream Lean / Mathlib remain under their own licenses. Not affiliated with OpenAI.

## SAT nanoda rerun / nanoda 大栈重跑 (2026-10-31)
- 中文：重新编译后用 `ulimit -s unlimited` 加 `RUST_MIN_STACK` 分别为 128M、512M、2G 重跑 nanoda，每次都栈溢出（exit 134）。日志里的 "nanoda kernel rejected" 是 comparator 对这次崩溃的统一提示，不是指出了逻辑错误；同一次运行中 Lean 默认内核接受。结论：SAT 仍只有 Lean 内核单内核确认，nanoda 未完成（工具运行时限制）。
- English: After rebuild, nanoda was rerun with `ulimit -s unlimited` and RUST_MIN_STACK of 128M, 512M and 2G; every run hit a stack overflow (exit 134). The "nanoda kernel rejected" line is comparator's generic message for that crash, not a logical rejection; the Lean default kernel accepted in the same runs. SAT remains single-kernel (Lean) verified; nanoda incomplete due to a tool runtime limit. Logs: `sat/nanoda-rerun/`.
