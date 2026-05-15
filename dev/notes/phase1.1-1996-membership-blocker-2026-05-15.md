## SUPERSEDED 2026-05-16

This note is preserved for historical context. The Norgate-blocked
diagnosis below has been replaced by a vendor pivot: Norgate is
retired (Windows-only NDU client incompatible with our Mac/Linux
Docker toolchain), and the new SP500 PI path is EODHD Fundamentals
API (`HistoricalTickerComponents` on `GSPC.INDX`) for 2000-present,
with optional `fja05680/sp500` static seed for the 1996-1999 tail.
Russell 3000 history is now sourced via DIY iShares IWV scrape
(2006-present), tracked separately as Phase 1.4.

Full vendor comparison and reasoning:
**`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`**.

Updated track status:
**`dev/status/data-foundations.md`** §"Blocking Refactors" + §"Notes".

---

Phase 1.1 — sp500-1996-01-01.sexp membership blocker (2026-05-15)
==================================================================

**Status:** BLOCKED on Norgate vendor signup.
**Dispatched task:** Build `sp500-1996-01-01.sexp` membership data with
per-symbol `active_through` columns by extending PR #1076's pattern back
to 1996.
**Verdict:** Not buildable from Wikipedia changes alone. The
Wikipedia "Selected changes to the list of S&P 500 components" table
documents ~25 events for the entire 1976–2006 window vs. ~360 events for
2010–2026 alone — the pre-2007 data is editorial/selective, not a full
historical log. Wait for Norgate signup before retrying.

## 1. What the data shows

Year-by-year event counts in the pinned 2026-05-03 Wikipedia HTML
snapshot
(`trading/analysis/data/sources/wiki_sp500/test/data/changes_table_2026-05-03.html`,
3273 lines, ~395 events total per the existing module docstrings):

| Year | Unique event dates | Total event rows |
|------|---:|---:|
| 1976 | 1  | 2 |
| 1994 | 1  | 1 |
| 1997 | 1  | 1 |
| 1998 | 1  | 3 |
| 1999 | 3  | 3 |
| 2000 | 4  | 7 |
| 2003 | 1  | 1 |
| 2005 | 2  | 2 |
| 2006 | 1  | 1 |
| **1976–2006 total** | **15** | **21** |
| 2007 | 11 | 11 |
| 2008 | 6  | 8 |
| 2009 | 8  | 13 |
| **2007–2009 total** | **25** | **32** |
| 2010 | 8  | 11 |
| 2011 | 17 | 19 |
| 2012 | 16 | 18 |
| 2013 | 16 | 19 |
| 2014 | 14 | 16 |
| 2015 | 22 | 29 |
| 2016 | 26 | 30 |
| 2017 | 18 | 28 |
| 2018 | 18 | 23 |
| 2019 | 19 | 24 |
| 2020 | 13 | 20 |
| 2021 | 13 | 20 |
| 2022 | 15 | 21 |
| 2023 | 12 | 17 |
| 2024 | 11 | 19 |
| 2025 | 14 | 21 |
| 2026 | 3  | 6  |
| **2010–2026 total** | **255** | **361** |

Counted via:

```bash
grep -oE '(January|...|December)[[:space:]]+[0-9]{1,2},?[[:space:]]+[0-9]{4}' \
  trading/analysis/data/sources/wiki_sp500/test/data/changes_table_2026-05-03.html \
  | grep -oE '[0-9]{4}$' | sort | uniq -c
```

## 2. Why this means the 1996 universe is not reconstructible

Replay direction is reverse-time (newest-first), via
`Membership_replay.replay_back` per
`trading/analysis/data/sources/wiki_sp500/lib/membership_replay.mli` line
51. Starting from 2026-05-03's 503 constituents, we'd need to undo every
change event with `effective_date > 1996-01-01` to land on the
1996-01-01 universe.

The S&P 500 turns over **~25 names per year** during normal periods (and
more during regime breaks like 2000–2002 and 2008–2009). Over the 30
years from 1996-01-01 → 2026-05-03 that is ~750 expected events. The
pinned table contains 376 events post-1996, of which **354 are
2010-or-later** and only **22 cover 1996–2009**.

The shortfall:
- Required: ~750 events for full 1996 → 2026 replay.
- Available: 376 events.
- Missing: ~370 events — and the gap is concentrated in 1996–2009
  exactly where we need them.

The `replay_back` function silently no-ops un-doable drops (per
`membership_replay.mli` line 75 — *"if event.added.symbol is not present
in the current working set when its event fires, the drop is silently
skipped"*) so we wouldn't get a hard error: we'd get a "1996" universe
that is actually closer to 2007's constituent set plus 22 random
adjustments. That's invalid data, not a blocker.

## 3. What would be reproducible from Wikipedia alone

Reasonable cutoffs given the pinned data:

| As-of date | Reconstruction confidence | Notes |
|---|---|---|
| 2010-01-01 | High (already pinned: `universes/sp500-historical/sp500-2010-01-01.sexp`, 510 syms) | The current production universe. |
| 2007-01-01 | Medium — limited by 2007 being the first "dense" Wikipedia year. ~50 missed events from late 2007 alone (the 11 dated rows likely under-count). | Useful for a 19y window 2007 → 2026 if needed. |
| 2000-01-01 | Low — 4 unique dates and 7 events cover all of 2000. Industry mid-cycle saw ~30 changes/year. | Universe would mostly equal the 2007 reconstruction +/- 7 ad-hoc adjustments. |
| 1996-01-01 | **None.** No viable reconstruction. Need vendor source. | Reject. |

## 4. What Norgate would buy us

Per `dev/status/data-foundations.md` §"Track 1 — Norgate Data
ingestion":

- US 1990-present per-day point-in-time SP500 / Russell 1000 / Russell
  2000 membership snapshots.
- Delisted symbols included with per-symbol delisting date — this is
  exactly the `active_through` field PR #1076 added to
  `Types.Daily_price.t`.
- Licensed redistribution-restricted (cache under `dev/data/norgate/`,
  gitignored).

Effort estimate from
`dev/notes/historical-universe-status-2026-05-13.md` §4:

- Norgate ingest itself: M effort (`analysis/data/sources/norgate/`
  client + index_membership module + fetch_universe CLI). User-confirmed
  budget OK ($32–66/mo). Vendor signup pending.

Total cost to reach 1996 universe once Norgate access is live:

1. `analysis/data/sources/norgate/` library + CLI — M (200–400 LOC, 1
   PR).
2. `build_universe.exe --as-of 1996-01-01` over Norgate substrate — S
   (~100 LOC adapter, 1 PR).
3. `sp500-1996-01-01.sexp` golden — XS (data + perf-tier header).
4. Per-symbol bar history 1990–2026 via EODHD with Norgate-sourced
   `active_through` — M+ (existing infra, but ~750 net-new historical
   delisted-symbol fetches; need to verify quota and EODHD
   ticker-resolution against Norgate symbols).

Estimated 3–5 stacked PRs after vendor signup completes.

## 5. Recommended next action

Per `memory/project_phase1_1996_membership_norgate.md` and the next
priorities doc, three options:

| Option | Verdict |
|---|---|
| (a) Wait for Norgate signup, then build sp500-1996-01-01 properly. | **Recommended for honest 1996 data.** Single-source-of-truth from a licensed vendor; carries `active_through` natively. |
| (b) Narrow scope: build sp500-2007-01-01.sexp as the "broader baseline" instead. | **Useful interim.** 19y window (2007→2026) covers the 2008 GFC + post-GFC + 2020 COVID regimes; still gives the survivorship-aware re-baseline the strategic-pivot doc wants. Wikipedia data density at 2007-01-01 is borderline (~32 documented changes 2007–2009 vs. ~75 expected; might be 50% complete) — qualitatively closer to "honest" than 1996 but not vendor-grade. |
| (c) Pivot to Phase 1.2 (`broad-3000-2010-01-01.sexp` cohort). | **Higher-ROI next step per the memory caveat.** Builds entirely on Wikipedia + EODHD data we have; expands universe breadth (current 510 syms → ~3000); 2010-2026 window is the period for which our membership data is dense and trustworthy. Does not need Norgate. |

The user should pick one before re-dispatching feat-data.

## 6. Files inspected (none modified)

- `dev/notes/next-session-priorities-2026-05-15.md` (Phase 1 §1)
- `dev/notes/historical-universe-status-2026-05-13.md` (sparse pre-2007
  caveat)
- `dev/status/data-foundations.md` (Norgate block confirmed)
- `memory/project_phase1_1996_membership_norgate.md` (caveat verbatim)
- `trading/analysis/data/sources/wiki_sp500/lib/changes_parser.{ml,mli}`
- `trading/analysis/data/sources/wiki_sp500/lib/membership_replay.{ml,mli}`
- `trading/analysis/data/sources/wiki_sp500/bin/build_universe.ml`
- `trading/analysis/data/sources/wiki_sp500/test/data/changes_table_2026-05-03.html`
- `trading/test_data/backtest_scenarios/universes/sp500-historical/sp500-2010-01-01.sexp`
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-2026.sexp`
- Git history of PR #1076 (`3a776411`) confirming the `active_through`
  pattern.

No code was changed. No data was invented.
