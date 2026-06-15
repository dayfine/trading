# Next-session priorities — 2026-06-15 (morning handoff)

**Supersedes** `next-session-priorities-2026-06-14.md`. Written end of the long
2026-06-14 PM session. Check main CI green first (`session-rampup`).

---

## ✅ The live recommendation pipeline is now OPERATIONAL

This session built and ran the end-to-end weekly-recommendation pipeline. **The
first live baseline is committed** (`dev/weekly-picks/58ff1e79/2026-06-12.{sexp,md}`,
PR #1598).

**How to regenerate weekly (the runbook):**
1. **Refresh data** (ops-data): `fetch_symbols` (current US listings) → `fetch_prices`
   to latest → `build_inventory`. Bars currently through **2026-06-12**.
2. **Build eligible universe** (#1594 builder):
   `build_eligible_universe_runner -inventory-path /workspaces/trading-1/data/inventory.sexp
   -csv-data-dir /workspaces/trading-1/data -date <Fri> -min-price 5.0 -min-adv 1000000.0
   -output-path /tmp/eligible-<Fri>.sexp` → **3,149 eligible** on 2026-06-12.
   Eligibility spec (locked, hygiene-not-alpha per `project_trade_realism_liquidity`):
   price ≥ $5, last-30d avg dollar-volume ≥ $1M, ≥30wk history, common+ADR,
   REIT/preferred/junk excluded, **no top-N cap**.
3. **Generate snapshot** (#1588 M6.6 bin, double-dash flags):
   `generate_weekly_snapshot --as-of <Fri> --universe /tmp/eligible-<Fri>.sexp
   --bars /workspaces/trading-1/data --snapshot-dir dev/weekly-picks
   --system-version <git-sha>`. Long-only Cell-E via `default_config`; the snapshot
   still RECORDS short candidates (Stage-4) for the record. `Universe_file.load`
   auto-projects the eligible `Snapshot.t` → Pinned, no converter needed.
4. Commit `dev/weekly-picks/<sha>/<Fri>.{sexp,md}`; diff vs prior week with `diff_picks`.

**The 2026-06-12 baseline:** macro **Bearish** → longs correctly empty (C2 gate);
10 Stage-4 short candidates (ABG/ABR/ADMA/…); strong sectors Industrials/IT/
Materials/Real-Estate.

### Pipeline follow-ups (flagged, not blockers)
- **Macro `score 0`** — coherent Bearish (not starved — surfaced shorts + sectors)
  but score 0 warrants verifying breadth/global-index data completeness through the
  as-of date.
- **Short candidates uniform `score 50 / grade C`** — short-side ranking is
  under-differentiated vs the long cascade. Worth a scoring look IF shorts become
  actionable (gated on Initiative B margin).
- **Sector manifest 59 days old** (2026-04-16) — refresh `fetch_finviz_sectors`
  before relying on sector labels.
- **Snapshot-mode macro gotcha** (cost 2 dead backtest runs this session): a
  `build_snapshots` warehouse omits the 15 macro/index/sector-ETF context symbols
  unless the build universe includes them → macro gate starves → 0 trades. See
  `project_deep_1998_2026_contiguous`.

---

## Locked priority order (user, 2026-06-14 grill)

`[0 DONE] recs baseline` → **[1] policy universe** → **[2] factor-lens 5b** →
**[3] WF-CV the 28y** → **[4] margin / long-short**.

1. **Policy universe** — emit `apply_composition_policy` artifact. Low value per the
   no-bull-edge finding; the ADR $-volume floor is ADR-only hygiene. (User hasn't
   supplied a threshold; the live-universe eligibility builder largely subsumes this.)
2. **Factor-lens 5b** — screener-based factors (macro stage at start, sector-RS
   dispersion, Stage-2 candidate count) on top of #1586's realized-edge columns.
   NOTE: this is also the place to *close* (low prior) the "is there ANY entry
   feature separating winners from losers" question — see
   `project_accuracy_is_unreachable_diversify_instead`.
3. **WF-CV the 28y** — turn this session's single-path +1552% existence proof into a
   promotion-grade fold estimate.
4. **Margin / long-short (Initiative B)** — Phase 1 margin accounting
   (`dev/plans/short-side-margin-2026-05-13.md`). The actual profit lever; touches
   core Portfolio (qc A1 flag), default-off keeps goldens bit-equal. This is route-2
   of the "smoother outcome" family (offsetting leg), NOT an accuracy tweak.

---

## Key findings this session (all in memory)

- **28y contiguous deep run** (`project_deep_1998_2026_contiguous`): realized **+1552%**
  vs SPX-price +599% (~+3.3pp/yr), MaxDD 35.9%, only 13% MTM-inflated. Confirms the
  multi-regime edge (`project_index_beating_structural_bar`) — bull-only 2011-26 was
  NEGATIVE; the full window with dotcom+GFC beats. Trade-by-trade: top-5 = 84.6% of
  PnL (fat tail), laggard_rotation +$31.9M (profit engine) vs stops −$16.6M (premium),
  winners held 4.3× longer, every regime net-positive, 100% Stage2. Writeup
  `dev/experiments/deep-1998-2026-2026-06-14/ANALYSIS.md` (#1593).
- **Accuracy is unreachable, diversify instead** (`project_accuracy_is_unreachable_diversify_instead`):
  winners≈losers at ENTRY (vol-ratio 3.57 vs 3.51, score 75.6 vs 76.1, flat win across
  vol buckets); cascade-reweight WF-CV-rejected. "Trade less / pick better" is a dead
  end — the routes to a smoother outcome are diversifying LAYERS (barbell, regime-gating,
  long-short), never entry-selection tuning.

## Merged this session
#1589 (volume enrichment + track inventory) · #1593 (28y deep analysis) · #1595 (live
data refresh to 2026-06-12) · #1594 (eligibility universe builder) · #1598 (first live
weekly-picks baseline) · #1586 (factor-lens cheap pass, realized-edge columns) · #1596
(generator C2 test + P6 fixes).

---

## 🌙 Night-2 continuation (2026-06-15 PM) — kept the queue moving

Per the new rule [[feedback_work_through_the_night]] (don't wrap early when the queue
has work), continued after the morning wrap. Additional merges:

- **#1605 — deep 28y WF-CV baseline robustness.** Cell-E as 28 independent annual
  folds 1998-2025 (PIT top-3000-1998, snapshot mode). **Sharpe 0.64 ± 0.86,
  23/28 folds positive**, down-years shallow (2008 GFC −4.6% vs SPX ~−37%); mean
  fold-Sharpe ≈ single-run 28y Sharpe 0.59 → the +1552% is NOT a lucky path.
  Writeup `dev/experiments/deep-1998-2026-2026-06-14/wfcv/`. **Caveat:** worst fold
  2024 (−21.9%) is a **PIT-1998 membership-decay artifact** → the WF-CV follow-up
  is **per-fold rolling membership** (re-snapshot top-3000 as-of each fold start).
- **#1606 — margin sizing-cash seam.** ⚠ **REFRAME: margin Phase 1/2 was ALREADY
  BUILT on main** (collateral lock, available-cash check, maintenance force-cover,
  borrow fee — #1113/#1115/#1119/#1274, fully tested in `test_margin_accounting.ml`).
  The priorities premise ("margin is a no-op") was STALE (same as the M6.6 generator).
  #1606 closed the one real gap: `~sizing_cash` threaded into
  `compute_position_size` (default-off/bit-equal, goldens unchanged).
- **#1607 — factor-lens 5b.** 4 screener factors on the rolling-start matrix (macro
  stage / Macro_composite / Stage-2 count / sector-RS dispersion), from precomputed
  warehouse fields. Universe-scan factors emit None for Full_sector_map (documented).

### The real next step on Initiative B (PROFIT lever) — needs YOUR oversight
The margin foundation is built + the sizing seam is in. The remaining step is
**Phase 5: wire `Portfolio.available_cash` / `sizing_cash` into the strategy entry
path** (`entry_audit_capture` / `weinstein_strategy`) so backtests size shorts on
*trustworthy* (collateral-locked) cash. **This RE-PINS the with-shorts goldens
(behavior-changing)** → it's the oversight boundary; I did NOT land it autonomously.
Once wired (with margin on + `enable_short_side` on), **Phase 3/4 Stage-A short-only
validation answers the profit question** ("does shorting Stage-4 help?") on a
trustworthy model — that's the high-value next move.

### 🔁 Window switched 2011→2000-2026 (user steer, 2026-06-15 ~18:00 PDT)
The 2011-2026 matrix is **bull-only — the least-informative regime for the lens**
(no corrections for H1 to dodge; prior analysis: "the window contains no real bear,
the strategy's designed payoff"). Switched to the **2000-2026 (26y) multi-regime
window** — covers dot-com bust + GFC, where the strategy earns its keep. Data was
ready in-container: warehouse `snap_top3000_2000` (1.9G, 3015 snaps) + scenario
`cell-e-top3000-2000-26y.sexp` (2000-01-03→2026-04-30). (1998 warehouse not in /tmp;
2000-26 captures both crashes, so it's the right practical window.) Killed the 2011
run, relaunched 2000-26 at cache=1024. Log: `/tmp/rolling-factor-matrix-2000.log`;
out: `/tmp/rolling-factor-matrix/matrix-t3k-2000-26.md`.
- **Heavier + slower:** ~48 starts, first = 26y window (heaviest child yet). At
  cache=1024 the 15y run projected ~26h; 26y windows × more starts → likely **40-50h+**.
  User chose to let it ride. WATCH the 26y child's memory — per-start mem must be FLAT
  (a 26y plateau that OOMs the container = the eager-allocation bug, not scaling).

### ⚠️ (superseded) 2011 matrix re-run DIED on OOM, relaunched at cache=1024 (2026-06-15 ~22:40 PDT)
The overnight `rolling_start_eval` re-run (launched 14:52) **crashed — Fork_pool
child sigkilled (OOM)** before producing any output. Root cause: the **first start
= the 15y full window (2011→2026) is the heaviest child**; at `SNAPSHOT_CACHE_MB=4096`
(and even 2048) the child's backtest heap + the snapshot cache exceed the **7.8GB
container** (confirmed: container free dropped to 44MB, swap fully exhausted, OOM-kill).
WF-CV #1605 fit only because its folds are 1-year windows; rolling-start's first
window is 15y.
- **FIX (relaunched):** `SNAPSHOT_CACHE_MB=1024` (+ `setsid nohup`, `--parallel 1`).
  Verified past the OOM cliff with ~3.7GB free headroom (vs 44MB at cache=2048).
  Trade-off: smaller cache → more disk re-reads → slower load; full 33-start run
  likely **longer than the original ~10h ETA**. Output (markdown) is written **only
  at the very end** to `/tmp/rolling-factor-matrix/matrix-t3k-2011.md` (+ sexp on
  stderr in `/tmp/rolling-factor-matrix.log`); container `/tmp` is **NOT bind-mounted
  → copy to `dev/experiments/` immediately on completion** before any container restart.
- **GOTCHA (cost ~1h this session):** Linux `comm` truncates to 15 chars, so the
  process shows as `rolling_start_e` — `pgrep -x rolling_start_eval.exe` / `ps -C
  rolling_start_eval.exe` **never match** and falsely report "dead". Use
  `pgrep -f rolling_start_eval.exe` for liveness, and container **free-available MB
  + swap** (not summed RSS, which double-counts COW-shared cache) as the true OOM signal.
- **CONTAINER IS LOCKED for the duration:** the job holds ~5.5GB; do **NOT** dispatch
  feat/qc agents or run container `dune` while it runs (sweep-hygiene) — they fight for
  the 7.8GB and will re-trigger OOM. Host-side doc/analysis only until it completes.

### Open analytical step (data-gated on the relaunched matrix above)
factor-lens **causal analysis** — correlate the #1607 factor columns with
`realized_edge_pct` to test H1/H2/H3 (the deploy-when guidance). **Gated** on the
cache=1024 re-run completing (above). NOTE the low prior on entry-feature
separation per [[project_accuracy_is_unreachable_diversify_instead]] — the lens's
value is regime/deploy-when guidance, not entry accuracy.
- **Partial H1/H2 read already possible from the EXISTING 2026-06-11 matrix** (it has
  per-start benchmark-CAGR + edge + realized). Directional finding (host-side, this
  session): edge is weakly negative only at benchmark-CAGR **extremes** — the two
  highest-CAGR starts (2023-04 17.95%→−16.7pp; 2023-10 20.2%→−28.1pp) lag most
  (consistent with **H2 melt-up tax**), and the lowest (9.65%) is +6.5pp. BUT the
  dominant negative-edge structure — the **2013-2017 cluster** — sits at *moderate*
  CAGR (~11-13%) and is **orthogonal** to benchmark CAGR. That mid-2010s gap is the
  real target the #1607 regime/supply factors (Stage-2 count, sector-RS dispersion)
  exist to explain; H1 (forward-index-DD) is the strongest untested hypothesis and is
  **only in the new matrix**, justifying the re-run despite the low prior.

### Deprioritized
**policy universe ([1])** — subsumed by the live-universe eligibility builder (#1594);
the ADR $-volume floor is ADR-only hygiene. Skip unless a specific need arises.
