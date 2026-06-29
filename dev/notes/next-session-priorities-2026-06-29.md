# Next-session priorities — 2026-06-29 (overnight session handoff)

Supersedes `next-session-priorities-2026-06-27.md`. Main is green.

## What this session delivered (all merged)
- **#1781** — corrected 5-week weekly-pick series; retired the broken `58ff1e79/2026-06-12` seed (it was a *data artifact*: incomplete GSPC.INDX/context bars → macro gate misread Bearish → 0 longs). The "macro flip" the user asked about **never happened** — Bullish throughout; proven by re-running 06-12 on clean data.
- **#1784** — `generate_weekly_snapshot --bars-snapshot-dir` (snapshot-warehouse mode): weekly screen **2h20m → ~8s**.
- **#1786** — `Screener.config.candidate_ranking` (`Alphabetical` default / `Quality` = RS→earliness→volume tiebreak), default-off axis. The faithful fix for the over-subscribed alphabetical-tiebreak selection.
- **#1788** — Phase-2 WF-CV **breadth grid** (top-500/1000/3000, 2000-2026, 13 folds) → **REJECT default-flip** (ledger `2026-06-29-candidate-ranking-tiebreak-grid`).
- **#1790** — eligible-universe **staleness guard** (`max_staleness_trading_days`, default 0 = bit-identical) + observability. Fixes the silent mega-cap drop (AAPL/MSFT/NVDA were dropped from this weekend's screen for being 2 trading days stale).

## The headline finding (the user's question: "were backtests distorted by the alphabetical tiebreak?")
**Yes materially, but the corpus is NOT degraded — no re-pin.** The alphabetical tiebreak reshuffles per-fold broad-universe results by 10-30pp, but is **not inferior** to the faithful RS-led tiebreak — it is marginally *better* on return-adjusted metrics. RS-magnitude-primary **picks the most extended (run-up) names** among ties → mildly taxes the fat tail / Calmar (lower Calmar all 3 cells, lower Sharpe 2/3, dominated in narrow). Confirms `edge_is_the_fat_tail`. `candidate_ranking` stays a default-off axis (no revert). See `project_screener_alphabetical_tiebreak`.

## Open / deferred (pick up here)
1. **Earliness-primary ranking experiment (the forward directive).** If revisiting candidate ranking, test an **earliness-PRIMARY** order (prefer FRESH breakouts over extended — the faithful "don't buy extended Stage-2" reading), not RS-primary. Same default-off axis (`candidate_ranking`), same grid harness — warehouses already built (`dev/data/snapshots/wfcv-top{500,1000,3000}-1998`, 2000-2026). Would need a small builder add (a new `Quality_earliness`-style mode) then re-run the grid. Open-but-low-conviction (entry-selection can't add return; this is do-no-harm hunting).
2. **#1782 scoring differentiation (live UX).** Live weekly picks remain alphabetical-within-grade (all grade-A/score-70, cap 20 → only A-tickers; AIT appeared 12/26 H1 weeks). Quality-ranking was rejected for *backtest* default, but a *live-display* de-dup/RS-led ordering still has standalone UX value (doesn't touch backtest selection). Lower priority.
3. **Sector data refresh** — `fetch_finviz_sectors.exe` (sectors.csv is ~5wk stale, manifest missing → "[sector-data] manifest missing" warning in every ops run). Marginal strategy impact (would spread grades a bit; within-grade order stays alphabetical). Deliberately deferred tonight.
4. **2026-H1 weekly series** (`dev/weekly-picks/3befbb36b/`, 26 weeks) is **on disk, uncommitted** — optional baseline record. Forward-trace eval already done (FINDINGS in the ops report / this session): pipeline sound, macro dynamic & faithful, but pick *quality* is unmeasurable until ranking differentiates.
5. **Weekly live-cycle cron (M6.6) still DEFERRED** — no auto-generation; backfill is by-hand in the container (`dev/status/weekly-snapshot.md`).

## Operational notes (watch these)
- **Container hygiene:** `trading-1-dev` accumulated **306 zombie processes** over ~6 days + a stuck `linter_magic_numbers.sh` (pipe_read hang) that made full `dune runtest` hang ~44 min. Restarted clean this session. Watch for recurrence; periodic restart may be warranted.
- **feat-agents committed in the PARENT workspace** (not their isolation worktree) **twice** tonight (#1783 original + the parallel rework). Recovered cleanly each time, but reinforce the `jj workspace add` first-step contract (`.claude/rules/worktree-isolation.md`).
- **QC scoped-runtest blind spot:** #1790's file-length + nesting linter failures passed scoped `dune runtest analysis/data/universe/` but failed CI (the devtools/checks linters only run in the full runtest). `feedback_qc_structural_misses_linters` — **CI is authoritative; always `gh pr checks` before trusting a QC lint claim.** Fixed by extraction (the GHA orchestrator landed it), not a limit bump.
- **Reusable WF-CV warehouses on disk** (gitignored `dev/data/snapshots/`): `weekly-review` (2024-06..2026-06, 5734 syms), `wfcv-top{500,1000,3000}-1998` (1998..2026-04). The snapshot-mode generator + walk_forward_runner `--snapshot-dir` make weekly screens / WF-CV fast now.
