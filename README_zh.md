# OpenAI Math Oct-26 独立技术复核包

[US English](README.md) | [CN 中文说明](README_zh.md)

本仓库保存对 [`openai/math`](https://github.com/openai/math) 的独立 Comparator / Lean 复核材料。审计基线固定在上游提交：

```text
7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a
```

（PR #3 合并 / 内容提交 `42907c9`，2026-10-26）。

## 复核结论一览

| 目标 | Comparator（Lean 默认 kernel） | nanoda | 公理 |
|---|---|---|---|
| **LocalSmoothing**（10-25 分析论文） | **VERIFIED** — “Lean default kernel accepts… / Your solution is okay!” | **接受**（exit 0） | 6 个定理仅依赖 `propext`, `Classical.choice`, `Quot.sound` |
| **SubexponentialSAT**（“ETH is False”，10-25 CS 论文） | **VERIFIED** — 同上（attempt6 exit 0） | **待定 PENDING** — 首次运行 nanoda 栈溢出（exit 134 → comparator rc=1）；默认 kernel 仍接受。更大栈复跑见下文 / `REPORT.md` | `exact_count_and_sat` 仅上述三公理 |

**完整技术说明：** [`REPORT.md`](./REPORT.md)

## 边界（请勿混淆）

1. **OpenAI 上游形式化** — `openai/math` @ `7ef5c0c…`，Challenge JSON + Solution 模块；
2. **本审计包** — 在 landrun / restrict-af-unix 下的独立 Linux 重放、公理打印、完整性哈希与工具版本记录。

这不是 OpenAI 官方认定，也不是对同行评审的替代。

## 冻结上游

```text
openai/math
7ef5c0cc5ca4b0e072b7a050fca09ab24bc6fa3a
```

见 [`UPSTREAM_COMMIT.txt`](./UPSTREAM_COMMIT.txt)。

## 环境 / 工具

- Lean **4.34.1**；comparator **d03acab**；landrun **811cfff5**；nanoda **3a24072**；restrict-af-unix。
- Mathlib olean 仅来自 `cache.mathlib.org`（SAT 树 8926 个）。
- 隔离：mathaudit uid 1001 + landrun + lean4export + restrict-af-unix。
- 主机 15 GiB RAM；编译 `LEAN_NUM_THREADS=1`。

### 工具哈希（相对首次 setup：MATCH）

```text
comparator  afa65e57…e4a2  MATCH
landrun     c41d19ff…966e  MATCH
nanoda_bin  af265c64…9bcf  MATCH
restrict    058b9800…3fe78 MATCH
lean4export 8c5d64ba…ddd1
```

详见 [`sat/tool-hash-vs-round1.txt`](./sat/tool-hash-vs-round1.txt)。

## 限定说明（环境/工具，非数学）

1. **环境擦除后重建** — 约 01:44–01:50（Asia/Shanghai）擦除导致 mid-bulk 中断；attempt6 为重建用户与工具后的全新 clone。
2. **工具哈希 MATCH**。
3. **`/usr/bin/time` 为 bash shim**（无 GNU time；仅记录墙钟与退出码）。
4. **预取 Mathlib olean**；Solution olean 在沙箱内由钉死提交编译。
5. **完整性**：packages olean 未变；仅 Lean 服务端 sidecar `.hash` 与一处 proofwidgets hash 变化。
6. **Bulk 单线程无 OOM** — 12014/12014 一次成功；无 alone 重试；未加 `/swapfile3`。
7. **nanoda 栈溢出（更大栈复跑 PENDING）** — 见 `sat/sat-nanoda.stderr.log`。
8. **未改源码**。
9. 日志拷贝后已删除大型 `.lake`。

## 仓库内容

| 路径 | 内容 |
|---|---|
| [`REPORT.md`](./REPORT.md) | 完整技术报告 |
| [`STATE.md`](./STATE.md) | 编译/监控时间线 |
| [`ls/`](./ls/) | LocalSmoothing 日志 |
| [`sat/`](./sat/) | SubexponentialSAT 日志 |
| [`common/`](./common/) | setup / selftest |
| [`scripts/`](./scripts/) | 审计主机脚本 |
| [`openai-math-audit-oct26.tar.gz`](./openai-math-audit-oct26.tar.gz) | 打包副本 |
| sha256 | `c90d09fb1affc49436b9037d247bfee9876c91a0af7afc83d2d31d72963a72ca` |

## SAT 上的 nanoda 状态

**PENDING** 更大栈复跑。首次记录：

```text
nanoda kernel rejected the solution
thread 'thread_1' has overflowed its stack
nanoda exited with 134
Lean default kernel accepts the solution
exit_code=1
```

视为**工具/运行时限制**，而非 Lean 默认 kernel 拒绝该证明。更大栈（`ulimit -s unlimited` / `RUST_MIN_STACK` 等）复跑结果将写回 `REPORT.md` 与本 README。

## 立场

独立审计笔记。上游 Lean / Mathlib 保留各自许可证。与 OpenAI 无隶属关系。
