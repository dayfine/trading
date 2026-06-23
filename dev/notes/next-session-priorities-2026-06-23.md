# Next-session priorities — 2026-06-23 (handoff)

**Supersedes** `next-session-priorities-2026-06-22-EOD.md`. Continues the
decline-character / Build-0 work. Main green; this session merged **14 PRs**
(#1707-1720) + the Build-0 A-D work. The headline carry-forward is the
**A-D-default flip**, decided but deliberately left to execute next session, with
a **perf fix to do first**.

## P0 — the A-D-default flip (decided; execute this session, in two steps)

Build 0 made A-D breadth live (synthetic ADL 1998-2026 into gitignored
`data/breadth/`, 0.92-0.93 corr vs official NYSE). Full-window 1999-2026 evidence
(`dev/backtest/ad-default-fullwindow-2026-06-22/FINDINGS.md`) shows A-D-live is
**clearly better risk-adjusted in the real long-short config** (Sharpe
0.884→0.933, Sortino 1.481→1.583, Calmar 0.509→0.528, MaxDD 27.3→25.6%) at a ~10%
raw-return cost — and it is the **doctrinally faithful** default. **User confirmed
the direction: flip it.** (Note: the 2000-2010 "+92pp long-only lift" was a
bear-window artifact; full-window it's a return-for-risk trade, meaningful only
*with shorts*.)

### P0a (do FIRST) — fix the A-D macro O(n²) perf
A-D-live is 3-5× slower because the macro **rebuilds the cumulative-A-D array from
the full breadth history every weekly tick** (`macro.ml:_build_cumulative_ad_array`
+ `_compute_momentum_ma_scalar` fold the whole `ad_bars` list; `callbacks_from_bars`
rebuilds per call; the MA path is cached via `ma_cache` but the A-D path is not).
**Fix:** precompute the cumulative-A-D prefix-sum + momentum-MA series ONCE
(an `ad_cache` mirroring `ma_cache`, or hoist the build out of the per-tick path).
Pure perf change → **bit-identical output, no golden re-pin** → verify with a
before/after diff. This makes every A-D-live run (incl. the P0b re-pin runs) cheap,
so it de-risks the whole flip. Proper TDD + a perf-tier check.

### P0b — make A-D-live the default basis + re-pin goldens (ETA ~2-4h, less after P0a)
1. **Resolve the gating unknown (~20 min):** which data dir do committed goldens
   read in CI — `data/` (A-D-inert today) or `test_data/` (Unicorn breadth present
   1965-2020, no synthetic tail → maybe already partly A-D-live)? Sets blast radius
   (~4 vs ~30 goldens). `default_data_dir` = `/workspaces/trading-1/data`.
2. Generate synthetic ADL into **committed** `test_data/breadth/` + commit
   `synthetic_advn/decln.csv` (test_data/breadth has only Unicorn nyse_* today).
3. **Re-pin affected goldens** (the dominant cost): ~30 golden scenarios across
   `goldens-sp500-historical` (~4 core), `goldens-broad` (7), `goldens-small` (3),
   `goldens-sp500` (4), `panel_goldens` (2), etc. Re-run → update expected bands.
4. Verify full golden suite in-container; behavior-change PR → full CI + QC.

Evidence scenarios committed: `experiments/adlive-{longonly,longshort}-fullwindow-2026-06-22/`.

## P1 — decline-character mechanisms: re-run A-D-inert WF-CVs on the A-D-live basis
Every WF-CV this session was A-D-inert (the old degraded basis). With A-D live:
- `slow_grind_gate`: A-D-live WF-CV already done (#1720) → still **NO promote**
  (regime-mixed; single-window best-Calmar was a cumulative artifact). Stays axis.
- `neutral_blocks_shorts`: re-run cell-1/grid A-D-live (likely holds — still inert,
  all shorts Bearish-tape even live). The **faithfulness/asymmetry default-on flip**
  (user's "sideline-in-Neutral is OK") is still on the table — decide post-A-D.
- `fast_v_arm_on_rate_alone` (#1708) + `fast_v_min_rate_pct` (#1716): re-run the
  arming WF-CV + threshold surface A-D-live — the A-D-lead may finally separate the
  2020 catch from the 2010/2011 whipsaw (the rate signal alone couldn't;
  `fast-v-min-rate-surface` proved it). This is the arming-speed unlock.

## P2 — barbell weight cert (unchanged) — needs your weight mandate.

## Session ledger (this session, on main)
4 ledger entries (`2026-06-22-{neutral-blocks-shorts-wfcv,neutral-blocks-shorts-grid,
arming-speed-wfcv,fast-v-min-rate-surface,slow-grind-adlive-wfcv}`). Meta-pattern:
the short/crash gates are **faithful tail-tools with regime-specific niches, not
robust standalone alpha**; WF-CV corrected the single-window screen **three times**
(arming-speed, neutral-grid, slow-grind). The durable wins are the **deep-data
infra (1998-2026)** + **A-D breadth as a real risk-adjusted lever**.

## Local data state (IMPORTANT)
- Runner reads gitignored repo-root `data/` (`default_data_dir`; `TRADING_DATA_DIR`
  override). This session fetched the union sp500-2000/2010/2015/2020 PIT universes
  + ETFs + ^GSPC, **1998-2026 (731 names)**, AND generated synthetic+unicorn breadth
  into `data/breadth/`. Both gitignored — a fresh checkout / cleaned `data/` must
  re-fetch + re-generate breadth (`compute_synthetic_adl.exe -data-dir data`).

## State
Main green. 0 feature PRs open. Code on main: #1708 (`fast_v_arm_on_rate_alone`) +
#1716 (`fast_v_min_rate_pct`) — both default-off no-op axes. No behavior change
landed; the A-D-default flip (P0) is the first behavior change, queued for next
session.
