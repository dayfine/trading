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
weekly-picks baseline) · #1586 (factor-lens cheap pass, realized-edge columns). #1596
(generator C2 test + P6 fixes) auto-merging.
