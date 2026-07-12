# Fresh weekly picks + sanity pass — as-of 2026-07-10 (2026-07-12)

First execution of pre-deployment checklist item 1 (deployment-readiness doc):
generate the current week's recommendations and sanity-check them.

## Pipeline run

- Bars: ops-data incremental fetch of the 2,702-symbol picks universe + 16
  macro/context symbols through 2026-07-10 (2,693/2,718 = 99.1% coverage;
  2 delisted + 23 EODHD-source-lag stragglers; 0 fetch errors). NOTE the
  fetch mechanism re-pulls FULL history and re-merges — any symbol with a
  split/dividend since last fetch had its whole adjusted_close column
  rebased (inherent to fetch_symbols; matters for adjustment-vintage-keyed
  consumers).
- Warehouse: weekly-review rebuilt incrementally to [2024-06-01, 2026-07-10],
  5,734/5,734 verified.
- Snapshots: `generate_weekly_snapshot` for as-of 2026-07-02 (short holiday
  week) and 2026-07-10, system-version 7f24f2c8d, universe
  `universe-2026-06-26.sexp` (2 weeks stale — membership drift acceptable,
  noted). Reports rendered to `dev/weekly-picks/7f24f2c8d/2026-07-{02,10}.md`.

## Report summary (2026-07-10)

Macro **Bullish (1.00)**, 7 strong sectors, 20 long candidates (all A+/85,
tie-order disclaimer correctly printed), 0 shorts, 0 held.

## Per-pick sanity (top 7, chart-read + mechanical checks)

Freshness: all 7 have bars to 2026-07-10 ✓. ADV(20d): all ≥ $1M gate
(FTHY marginal at $1.1M) ✓. Macro inputs non-degenerate ✓ (A-D/NH-NL/global
all populated — no broken-breadth artifact).

| pick | verdict | note |
|---|---|---|
| FSS | CLEAN | new-high breakout from 8-month flat consolidation; "Clean overhead" accurate |
| AVAH | acceptable | fast bounce but breaking THROUGH to new highs |
| DGICA | acceptable | entry trigger above prior all-time high |
| CWST | **Class-A bounce-under-overhead** | $89-97 under a year of $100-118 tops; report claims "Virgin territory" |
| FG | **Class-A** | bounce off 46→20 two-year collapse; entry under massive 30-46 supply |
| FRSH | **Class-A (worst)** | $10 bounce in monotone 24→9 downtrend; BF-B twin |
| FTHY | **universe hygiene** | bond CEF (yield-grind chart); stage analysis meaningless; marginal ADV |

## Findings

1. **CWST/FG/FRSH are V-bounce recovery entries — the strategy's STANDARD
   ticket, not defects** (initial chart-read alarm corrected by the
   base-gate screen, same session: the V-bounce-after-Stage4 shape is
   64-84% of ALL record-run entries; its feature-twins include FARM/SKYW.
   Gating it is net-negative at every threshold — no-build). What IS wrong:
   their "Virgin territory" labels are data-starved (weekly-review
   warehouse starts 2024-06 ≈ 110 weekly bars vs the mapper's 520-bar
   virgin_lookback spec) — a label-correctness fix (extend the live
   warehouse window or degrade the label when the window is short), NOT a
   gate. Expect ~35% win rate and defined −8%-stop risk on these tickets;
   that is the premium schedule, not a pipeline error.
2. **Universe contains non-equity instruments** (FTHY = bond CEF; likely
   others). Add an asset-type filter to universe construction
   (asset_type_enrichment exists) — new hygiene follow-up.
3. Tie-order disclaimer now printed (the #1782 UX fix works); tied-at-85
   cohort is A-F alphabet-skewed as expected until quality display-ranking
   lands.
4. The 07-02 short week (July-3 holiday) generated cleanly.

## Verdict for the deployment checklist

Pipeline mechanics: HEALTHY (macro, sectors, freshness, staleness guard,
holiday-short week both generated cleanly). Pick quality: consistent with
the record run's entry distribution — 3/7 top picks are standard
V-bounce-recovery tickets (defined stop risk, the premium schedule), 2-3
are near-high breakouts, 1 (FTHY) is a universe-hygiene leak (bond CEF —
exclude; asset-type fix queued). Two label-correctness issues to fix
(resistance window; CEF filter); no gating changes warranted (two gate
hypotheses screened and killed this session). The weekly human chart pass
stays mandated — it caught FTHY and the label bug in one week.
