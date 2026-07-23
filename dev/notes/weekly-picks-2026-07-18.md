# Weekly picks — as-of 2026-07-17 (weekend 2026-07-18/19)

First live run on the **resistance-v2 promoted config** (PR #2047,
`6a2d9b426`, merged 2026-07-23): `w_overhead_supply=Some 30`,
`virgin_crossing_readmission=true`, `overhead_supply=Some
Resistance_supply.default_config` (floors zeroed). Iteration 0.

System version: `7f24f2c8d`. Snapshot: `dev/weekly-picks/7f24f2c8d/2026-07-17.sexp`.
Rendered report: `dev/weekly-picks/7f24f2c8d/2026-07-17.md`.

## Pipeline run

- **Fetch**: parallel incremental fetch (12 batches, `fetch_symbols.exe`) of
  the 3,158-symbol picks universe (`dev/weekly-picks/universe-2026-06-26.sexp`)
  + 15 macro/context symbols (11 SPDR sector ETFs, GSPC.INDX, GDAXI.INDX,
  N225.INDX, ISF.LSE) = 3,173 symbols total. **3,173/3,173 fetched, 0
  errors.** Pre-fetch staleness check: essentially the entire universe was
  stale vs 2026-07-17 (2,630 symbols last-fetched 2026-07-10, 527 at
  2026-06-26, remainder scattered) — consistent with the known caveat that
  mega-caps and long-tail names alike go stale between weekly runs. Post-fetch
  spot check (AAPL/MSFT/NVDA/XLK/GSPC.INDX): all fresh to **2026-07-22**.
- **Inventory**: rebuilt via `build_inventory.exe` (5,734 symbols indexed).
- **Snapshot warehouse**: rebuilt incrementally via `build_snapshots.exe`
  against `dev/data/snapshots/weekly-review/` — windowed columns
  `[2024-06-01, 2026-07-17]`, benchmark `GSPC.INDX`, default
  `sketch-deep-days=3650` (~10y, feeds the resistance-v2 weekly side-table
  independent of the windowed start). **3,173/3,173 verified, 0 failures.**
  Build universe for this step was a superset Pinned sexp (picks + all 15
  context symbols; sector labels are placeholders and unused by the warehouse
  writer).
- **Generate**: `generate_weekly_snapshot.exe --as-of 2026-07-17 --universe
  dev/weekly-picks/universe-2026-06-26.sexp --bars-snapshot-dir
  dev/data/snapshots/weekly-review --config-overrides
  dev/weekly-picks/live-config-overrides.sexp --system-version 7f24f2c8d`.
  Config overrides armed on top of the (now-default) resistance-v2 bundle:
  `extension_stop (2.0, 0.25)`, `reject_declining_ma_long_entry=true`,
  `resistance_lookback_bars=520`.

## Macro

**Bullish** (score 1.00) — **GSPC.INDX Weinstein-stage vote only.** Per the
generator's known wiring (`Weekly_snapshot_generator.generate` calls
`Macro.analyze ~ad_bars:[] ~global_index_bars:[]`), the A-D breadth and global
(DAX/Nikkei/FTSE) indicators are NOT wired into the live macro read despite
those bars now being freshly cached — they degrade to Neutral and the
index-stage vote (weight 3.0) alone decides the regime. This is a pre-existing
generator gap (`M6.6` scope), not something this run changed.

**Strong sectors**: Consumer Staples, Financials, Health Care, Industrials,
Information Technology, Materials, Real Estate, Utilities (8/11).
**Weak sectors**: Communication Services.

## Sector-manifest status

`data/sectors.csv.manifest` (the `fetch_finviz_sectors.exe` manifest, per
`fetched_at`/`row_count`/`errors` schema) **does not exist** — it has never
been written by a run of that tool in this checkout. The only sector-freshness
signal on disk is `data/sectors.meta.sexp`, a hand-maintained metadata file
recording `fetched_date 2026-04-14` (~100 days stale as of this run).

**This did not skew this run's picks.** `generate_weekly_snapshot` builds its
per-ticker sector map (`Sector.analyze`'s `sector_map`) entirely from the
`--universe` file's embedded `(sector ...)` field plus the freshly-fetched
SPDR ETF bars — it never reads `data/sectors.csv` at runtime. The relevant
staleness is the **pinned universe snapshot's** build date (2026-06-26, ~3.5
weeks stale), which is membership-drift-acceptable per the 2026-07-12
precedent (`dev/notes/weekly-picks-sanity-2026-07-12.md`), not a "+10 spread"
tie-skew artifact. Sector labels used this run therefore reflect a ~3.5-week
snapshot of GICS assignments, not April data.

**Follow-up (not done this session, out of scope):**
`fetch_finviz_sectors.exe` scrapes ~10,472 Finviz quote pages at the
tool's 1 rps default rate limit — a ~3-hour job, too slow for this
report-generation session and orthogonal to this week's pick correctness.
Recommend a dedicated ops-data dispatch to run
`fetch_finviz_sectors.exe -data-dir /workspaces/trading-1/data -api-key
"$EODHD_API_KEY"` (no EODHD key actually required — this fetch scrapes Finviz,
not EODHD) and commit the refreshed `data/sectors.csv` + write the missing
manifest, independent of the weekly-picks cadence.

## Long candidates (20 — full screener output, no truncation this week)

Screener cap is 20; all 20 slots filled this week with no tie-cutoff overflow
(cf. 2026-07-10's report, which had 4 more names tying the rank-7 cutoff).

| Rank | Symbol | Sector | Score | Grade | Entry | Stop | Risk % | v2 resistance grade | RS vs SPY |
|---|---|---|---|---|---|---|---|---|---|
| 1 | ACAD | Health Care | 100 | A+ | $28.49 | $26.21 | 8.0% | Virgin_territory (0.00) | 1.00 |
| 2 | COGT | Health Care | 100 | A+ | $43.95 | $40.43 | 8.0% | Virgin_territory (0.00) | 1.22 |
| 3 | ENTA | Health Care | 100 | A+ | $17.24 | $15.86 | 8.0% | Clean (0.00) | 1.03 |
| 4 | HIPO | Financials | 100 | A+ | $39.17 | $36.04 | 8.0% | Virgin_territory (0.00) | 0.90 |
| 5 | NBBK | Financials | 100 | A+ | $22.97 | $21.13 | 8.0% | Virgin_territory (0.00) | 0.99 |
| 6 | PESI | Industrials | 100 | A+ | $16.58 | $15.25 | 8.0% | Clean (0.00) | 1.30 |
| 7 | SNDX | Health Care | 100 | A+ | $25.72 | $23.66 | 8.0% | Virgin_territory (0.00) | 1.10 |
| 8 | SNSE | Health Care | 100 | A+ | $36.94 | $33.98 | 8.0% | Clean (0.00) | 1.47 |
| 9 | STC | Financials | 100 | A+ | $79.00 | $72.68 | 8.0% | Virgin_territory (0.00) | 0.98 |
| 10 | AII | Financials | 90 | A+ | $26.49 | $24.37 | 8.0% | Virgin_territory (0.00) | 0.90 |
| 11 | BALL | Materials | 90 | A+ | $68.63 | $63.14 | 8.0% | Clean (0.00) | 1.04 |
| 12 | CALM | (see sexp) | 90 | A+ | $118.04 | $108.60 | 8.0% | Clean (0.00) | — |
| 13 | CNA | (see sexp) | 90 | A+ | $50.97 | $46.89 | 8.0% | Clean (0.00) | — |
| 14 | ESNT | (see sexp) | 90 | A+ | $67.43 | $62.04 | 8.0% | Clean (0.00) | — |
| 15 | FBK | (see sexp) | 90 | A+ | $62.68 | $57.67 | 8.0% | Virgin_territory (0.00) | — |
| 16 | HRTG | (see sexp) | 90 | A+ | $32.14 | $29.57 | 8.0% | Virgin_territory (0.00) | — |
| 17 | MBI | (see sexp) | 90 | A+ | $8.30 | $7.64 | 8.0% | Virgin_territory (0.00) | — |
| 18 | MEDP | (see sexp) | 90 | A+ | $632.06 | $581.50 | 8.0% | Virgin_territory (0.00) | — |
| 19 | NMIH | (see sexp) | 90 | A+ | $42.49 | $39.09 | 8.0% | Clean (0.00) | — |
| 20 | NNI | (see sexp) | 90 | A+ | $145.10 | $133.49 | 8.0% | Virgin_territory (0.00) | — |

Rationale (all 20, verbatim, ranks 1-9): "Stage1→Stage2 breakout; Strong
volume; RS positive; Overhead supply (continuous); Strong sector". Ranks
10-20: same with "Adequate volume" in place of "Strong volume" (score 90 vs
100 — the volume-confirmation tier is the only differentiator this week).

## Short candidates

(none)

## Held positions

(none — no live portfolio/trading-state is wired into this generator; M6.6's
trading-state persistence remains deferred per `dev/status/weekly-snapshot.md`)

## Caveats / things that smelled wrong

1. **v2 grade display gap in the rendered `.md`.** `render_weekly_report.exe`
   / `Report_renderer.render` does not print the `resistance_grade` field at
   all — the continuous v2 score (`"<quality> (0.NN)"`) is only visible by
   reading the raw `.sexp` (as done above), not in
   `dev/weekly-picks/7f24f2c8d/2026-07-17.md`. This is a pre-existing display
   gap (not introduced by this run) worth a follow-up ticket if the v2 score
   is meant to be human-reviewable weekly.
2. **All 20 picks this week graded `Virgin_territory` or `Clean`, both at
   `0.00`.** That's semantically correct (no overhead-supply score to display
   when there's no supply), but it means this first live run under the
   promoted config did **not** exercise the continuous nonzero-score path
   (e.g. `Bounce_under_overhead (0.4x)`) — the sample this week happens to be
   all fresh-breakout / virgin-territory names. Not a red flag, just a note
   that the "sanity-check the v2 numbers" ask couldn't be exercised against a
   nonzero example this week.
3. **Cosmetic**: the grade string carries a stray module prefix —
   `"Weinstein_types.Virgin_territory (0.00)"` instead of
   `"Virgin_territory (0.00)"`. Pre-existing (from `[@@deriving show]` on the
   variant type), not introduced by this run; cosmetic only.
4. **Universe membership is ~3.5 weeks stale** (`universe-2026-06-26.sexp`).
   Acceptable per the 2026-07-12 precedent; flagging per the standing caveat
   that a fresher composition snapshot would be more representative of
   current market-cap / listing changes.
5. **A-D breadth and global-index inputs remain unwired** in the live macro
   read (see Macro section) — this is a standing M6.6 gap, not new this run.

## Verdict

Pipeline mechanics: **HEALTHY** — fetch/inventory/warehouse/generate all
completed cleanly with zero errors across 3,173 symbols. First live exercise
of the resistance-v2 promoted default: the v2 grade field populates correctly
in the raw snapshot (confirmed non-crash, correct format), but this week's
candidate set didn't include a nonzero-score example to visually confirm the
continuous scoring's discriminative behavior — worth eyeballing again next
week or picking an off-cycle date where a `Bounce_under_overhead`-class name
clears the screener.
