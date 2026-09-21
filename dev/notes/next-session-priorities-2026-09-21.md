# Next-session priorities — 2026-09-21 (supersedes 2026-09-20 + its two addenda)

Written 07:30 PT 2026-09-21 at the end of the 09-20 evening session. Main green. **Container idle** (lane B finished
06:48 PT; every pinned sweep worktree removed). Open PR: **#2884** (`exp/index-stage-veto` results — code-free, not
docs-only: CI + qc-structural + qc-behavioral; structural dispatched 07:20 PT).

## State in one paragraph

The index-stage veto arm is done: **REJECT-as-default, keep as axis** (ledger `2026-09-21-index-stage-veto.sexp`,
README §Verdict, memory `project_index_stage_veto_verdict`). Pre-registered rule (realised AND Calmar better at ≥ 2/3
salts) — only salt 1 clears both; realised 1/3, Calmar 3/3 but at salts 0 and 2 the ratio gain is a **lower-peak
artifact** (the arm never makes the 2020–21 highs; at salt 2 its dollar trough is $0.54M *below* the null's). The
mechanism is clean and reproduces 3/3: it **earns in the 2022 grind** (+$0.42M / +$0.48M / +$0.56M on the 2022–23
window, give-back halves) and **pays on the 2020 V-recovery** (index still Stage 4 for 9–12 weeks after the March low
while the composite has turned; the 2020 monsters go to the null: −$0.5M / −$0.76M / −$1.35M). A regime dial for a
drawdown-averse preset, not a default. Along the way: salt 1 was lost to the chain's 36,000 s guard at 92.5 % (arm
runs ~43 % slower than its null at cap 256), the user chose to build the cache knob first, **#2882 shipped**
(`SNAPSHOT_MAX_MMAP_HANDLES`, default 256; chains use 12,000) and the PIT 26y cell dropped from 8.5–10 h to
**3h37m–4h19m** with byte-identical output; and the **weekly perf-review rule** landed (#2881,
`.claude/rules/perf-review-weekly.md`, ~2 h/week, user-directed).

## P0 — close out #2884

1. `sh dev/scripts/pr_gate_status.sh 2884` → structural (dispatched) → behavioral → merge (`--admin` from `/tmp`).
   Nothing else waits on it, but an unreviewed PR is the default work item (`pr-gate-loop.md`).

## P1 — next work, in order (all need the container; it is free)

1. **#2878 — occupancy / heap on the cache line** (`ready-for-agent`, size S). Add: split `misses` into loaded vs
   not-in-manifest (the 26y cells show `misses=6.30M evictions=0` — the ~551 universe names absent from the 9,364-entry
   manifest are counted as misses on every read, ~11k each; a negative-lookup cache or a `miss_absent` counter makes
   the line read true), plus `mmap_open` peak/avg and `Gc.quick_stat` top-heap. Bit-identical. Dispatch feat-backtest.
2. **Perf weekly, first real pass (~2 h, `perf-review-weekly.md`):** (a) add a broad-5y cell and a PIT-warehouse smoke
   (the 4-month `v1-index-veto-smoke.sexp` shape, cap 256 vs 12,000) to tier 2/3; (b) root-cause the tier-3
   `sp500-2010-2026*` FAIL rows (~4,750 s, masked by `continue-on-error`); (c) log the review in
   `dev/status/backtest-perf.md` §Weekly review.
3. **Top-of-funnel screen** (breakout-gate width, top-N) on the PIT band — read with the 2022–25 regime in mind
   (≥ +20 % winners fell 10 % → 2 %). Pre-register on `a0-pit-null-s{0,1,2}-v11`; chain at cap 12,000 with a
   `CELL_TIMEOUT` sized from the measured arm (arm cells were 3h37m–4h19m; the guard is 60,000 s).
4. **PIT warehouse rebuild with #2862's twin guards armed** (`-twin-require-direct-match -twin-max-group-size 4`) —
   operational; the record band stays on the current `_v11pit` until a rebuild is paired.
5. **Veto follow-on, only if someone wants it:** the one arm worth running is veto + faster re-admission (lift when the
   index closes above the 30-wk MA rather than waiting for MA slope) — a §2.1 Stage 4 → 1 book question first
   (`book-as-authority.md`), then a pre-registered arm. Not another single-lever screen on this base.

## Codex queue

Nothing `ready-for-agent` for Codex. Candidate unchanged: `build_snapshots -twin-only` (`project_pit_chunked_twin_miss`).

## Ops notes

- **Cell guard:** size `CELL_TIMEOUT` from the measured *arm*, ≥ 1.5× its slowest cell — never from the null. The
  36,000 s guard killed a 10 h cell at 92.5 %.
- **Chain defaults now:** `SNAPSHOT_MAX_MMAP_HANDLES=12000` (≥ n_symbols), `CELL_TIMEOUT=${CELL_TIMEOUT:-60000}`,
  `WTREL` overridable (`index-stage-veto-2026-09-16/chain-veto.sh` is the template).
- A `docker exec` cancelled by a tool interrupt may still have run — `ps` inside the container before assuming a launch
  was aborted. Long `sleep`-based background helpers get killed under host memory pressure; use a Monitor on the log.
- Full local `dune runtest` needs `TRADING_DATA_DIR=$PWD/test_data` exported or `barbell_scenario` +
  `portfolio_risk_e2e` fail on a data path (CI green, local red ⇒ env; `feedback_trading_data_dir_for_local_tests`).
- 58 stale `worktree-agent-*` local git branches remain (left alone; delete when convenient). Host free ~60 GB;
  Docker.raw 30 G.
