# Delisting data fix — end series at the last real print, at the data layer (2026-09-06)

**User direction (2026-09-06):** "can we actually fix the data correctly and ignore the
administrative stub prints? Like in real trade we won't be dealing with these phantom
data." — yes: move the fix from a runtime guard (#2686 guard 3, `stub_print_max_ratio`)
to ingestion / warehouse build, so the backtest never sees a post-delisting stub bar.

## What we know (measured 2026-09-05/06)

- `Daily_price.active_through` / `Snapshot_manifest.file_metadata.active_through` /
  `Daily_panels.active_through_for` are plumbed end to end but populated on NO
  warehouse: the EODHD bar parser leaves it `None` and no enrichment pass exists
  (`memory/project_delisting_guards_2672`).
- EODHD's delisted roster (`/api/exchange-symbol-list/US?delisted=1`, 59,927 rows) has
  NO date field (`Code, Name, Country, Exchange, Currency, Type, Isin`), and it shows
  ticker reuse directly: its "DTV" is DTE Energy, its "ICT" is an unrelated container
  company. The fundamentals endpoint (`General::DelistedDate`) is **403 on our tier**.
  Alpha Vantage `LISTING_STATUS&state=delisted` carries `delistingDate` but needs a
  real (free) key — the demo key returns `{}`; coverage before ~2010 unverified.
- Two defect classes in the warehouse: (i) **terminal stub run** (STMP: real to
  2021-10-04 at $329.61, then $0.045/$0.04/$0.03 to the end); (ii) **interleaved /
  mis-scaled series** (CLE, ICT, ABK, MEL, MVL, AGR; 66 symbols with ≥20 flagged bars
  in `arc-rerun-2026-09-01/results/splice-scan.csv`) — ticker reuse merged into one
  series; no terminal rule can repair these.
- Runtime guard 3 fixes (i) but perturbs the universe on 97% of screens (it ends every
  dying symbol's series a few bars early) and cannot tell a stub tail from a genuine
  terminal collapse; the 26y guards-on run is a path lottery, not a measurement
  (`dev/experiments/delisting-guards-rerun-2026-09-06/`).

## Design

1. **Series end = delisting evidence.** At warehouse build, every symbol whose last bar
   predates the build's end date gets `active_through = last real bar date` in the
   manifest (and the CSV store's 8th column, already parsed). No external date needed
   for the common case — the vendor stops the series.
2. **Terminal-stub truncation at build, with a review report.** The build applies the
   same pure rule as `Snapshot_runtime.Stub_tail.cutoff_date` (terminal run of closes
   below `ratio ×` the last real close; default ratio a build flag, e.g. 0.05), drops
   those bars from the `.snap`, sets `active_through` to the last real bar, and writes
   `stub_tails.csv` beside `splices.csv` (symbol, cutoff, n_dropped, ratio, last real
   close, first stub close). A human reads the list once per vintage; anything that looks
   like a genuine collapse (e.g. a multi-week decline through the ratio) is whitelisted
   in a small committed exceptions file and NOT truncated.
3. **Optional external dates.** If an Alpha Vantage key is provided, an enrichment
   script fills `active_through` from `delistingDate` where present and reports
   disagreements with rule 1 (series end vs published date); published dates win.
   Keep it optional — the build must work without it.
4. **Interleaved series (class ii)** are handled by the splice detector at build: a
   symbol with a splice finding is split at the splice or dropped per a committed
   exceptions file; this is a separate PR (`#2649` made the detector report-only).
5. **Runtime.** Guards 1 and 2 stay (a stale price is still a stale price; a zombie is
   still a zombie). Guard 3 becomes redundant on rebuilt warehouses and retires under
   `experiment-flag-discipline.md` Rule 4 once every live warehouse is rebuilt.
6. **Rebuild** the three vintage warehouses in Pinned shape (never `-incremental`, #2669),
   then re-run the record with salts — the rebuild perturbs the 26y path exactly like
   guard 3 did, but now with the true universe.

## Sequence (queued 2026-09-06 — the executable queue is `dev/experiments/warehouse-rebuild-2026-09-06/README.md`)

- PR-A — **MERGED as #2691 (squash cccd06813, 2026-09-06 16:06 PT)** (`feat/delisting-data-fix-a`, `Snapshot_pipeline.Series_tail`,
  flags `-stub-ratio 0.05 -stub-max-bars 60 -stub-max-price 1.0 -no-stub-truncation
  -no-stray-drop -tail-exceptions`, report `terminal_runs.csv`, exceptions file
  `trading/test_data/warehouse_exceptions.sexp`): build-time `active_through` from series end + stub-tail
  truncation + `stub_tails.csv` report + exceptions file + tests (STMP shape, CLE shape
  untouched, genuine-collapse whitelist path, manifest field populated, `Daily_panels`
  read-through). No golden moves: the committed test warehouses have no stub tails —
  verify with the report.
- Review the report for the 2000 vintage (the scan `tail_scan_2000.txt` sizes it).
- Rebuild 2000 / 2009 / 2019 warehouses (hours each; container-exclusive).
- PR-B: splice-class handling at build (class ii).
- Record re-base with salts on the rebuilt 2000 warehouse; retire guard 3.

## Not doing

- No runtime inference of delisting from price shape beyond the build-time report.
- No sp500 measurement anywhere in this program (`universe-discipline.md`).

## Sizing (2000-vintage warehouse `snap_top3000_dedup_v5thin_adj`, scanned 2026-09-06)

Full-series scan of all 2,908 symbols (`dump_snap`; per-symbol lists in
`dev/experiments/delisting-guards-rerun-2026-09-06/scan/`):

| class | count | rule | disposition |
|---|---:|---|---|
| series ended before 2026-06 (delisted by vendor evidence) | **1,964** of 2,908 | last bar date < build end | `active_through = last bar` — no external date needed |
| **terminal stub tail** | **13** | terminal run of closes < 0.05 × last real close, run ≤ 60 bars, stub close < $1 | truncate at the last real bar; review list once per vintage. Six are cash-takeover shapes (STMP 18 stubs, WDR 29 at $0.27 after a $25 deal, HIBB 7, PFSW 9, BULL_old 4, TVSFF 1); six are already-sub-cent micro-caps (RDRTQ, UPSL, AWEB, IMBI, SDNA, LMSC — a reviewer may whitelist; they are untradeable under the liquidity floor either way); NCF is a single stray bar 12 years later |
| prefix mis-scale (last "real" close ≥ 1,000; the later, lower-priced bars are the true series) | 10 | AGR, SGY, SBER, DRL, TEK_old, GEG_old, SWD, LAN, HPC, MEL | **NOT a tail** — a bare ratio walk-back would delete thousands of real bars; route to the splice/rescale PR (class ii) |
| long low tail (> 60 bars at pennies: ticker reuse or a genuine multi-month collapse) | 23 | SHU, UPR, KRB, TND, DME, AVE, ARJ, VRI, FPC, PAS, C-WS-A, UCM, VLY-WS, MRVT, TNO, MEH, OV, MVL, COX, HRVEQ, SRR, CEC, IISX | review; reuse cases split at the splice (class ii), genuine collapses kept |
| stray late bar(s) ≥ 2 years after the penultimate bar | 14 | e.g. ANCR 2000-08-01 → 2016-01-27 | drop the stray bars; `active_through` = the real end |

At ratio 0.20 the terminal-run count is 116 and at 0.50 it is 109 on 40-bar tails — the
ratio is not the lever; the run-length cap and the absolute-price floor are what separate
the stub class from the others. **Design consequence:** the build-time rule is
`ratio ≤ 0.05 AND n_stub ≤ 60 AND stub close < $1`, everything else goes to the review
report untouched. This also retires the single-ratio semantics of runtime guard 3, which
would have truncated AGR's 4,653 real bars at 0.05.

## Principle (user, 2026-09-06): fallbacks are quality flags, not mechanisms

"Stale exit is a fallback mechanism, like force_liquidation; they should ideally never
happen, and any instance we spot should lead to a data fix or a quality flag that requires
double-checking in analysis."

Applied to the record's own 7 stale force-exits (all blank `exit_trigger`, #2687):

| symbol | entry → exit | exit close | what it was |
|---|---|---:|---|
| WLL1 | 2002-01-22 → 03-19 | 55.50 | Willamette → Weyerhaeuser cash deal |
| RBAK | 2006-12-23 → 2007-01-30 | 25.02 | Redback → Ericsson cash deal |
| PCYC | 2015-01-21 → 05-27 | 261.25 | Pharmacyclics → AbbVie ($261.25 cash+stock) |
| CY ×2 | 2020-04-18 → 04-20, 04-25 → 04-27 | 23.82 | Cypress → Infineon ($23.85) — **entered twice AFTER the series ended 2020-04-15** (a stale-bar entry, guard 1's class, twice) |
| CHS | 2023-10-21 → 2024-01-09 | 7.59 | Chico's → Sycamore ($7.60) |
| AZPN | 2025-01-30 → 03-17 | 264.33 | Aspen Tech → Emerson ($265) |

Every one is a cash-deal delisting that the safety net priced correctly by accident (the
last close ≈ the deal price), and CY shows the net also hiding a real defect (two entries
on a dead symbol). So:

- **PR-C — make delisting a first-class exit and every fallback a flag** (**PR #2692**, `feat/fallback-exits-quality-flags`, closes #2687; adds V17 stale-entry-bar check and
  `Forced_exit_step`).
  1. When a held symbol's `active_through` (now populated by PR-A) is reached, exit at the
     last real close with reason `delisted` (a `Strategy_signal { label = "delisted" }` or
     a new `Stop_log.exit_trigger` variant) — an EXPECTED event, not a fallback.
  2. `stale_force_exit` then only fires for a symbol that stops producing bars WITHOUT an
     `active_through` — a data defect by definition. Same status for `force_liquidation`,
     `margin_call`, `maintenance_reduce`, `buyin_stress`: safety nets.
  3. Post-run validator check **V16 "fallback exits"** (report-only, like V15): list every
     fallback-tagged round trip (symbol, dates, prices, reason), count them in
     `summary.sexp`, and print `QUALITY-FLAG: n fallback exits — see V16` in the run log.
     Zero is the target; non-zero routes to a data fix or an explicit whitelist entry.
  4. V16 also flags any ENTRY whose fill bar is older than N days than the decision date
     (the CY shape) — with PR-A's `active_through` that becomes impossible by
     construction, so a non-zero count is a build/warehouse defect.
  5. #2687 is a prerequisite: the label has to reach `trades.csv` for any of this to be
     visible in the artifacts.
- The 26y record therefore carries 7 events to re-label (`delisted`) and 2 defects (CY)
  that PR-A's `active_through` removes; the stub-print class (STMP) is a third shape the
  same principle catches: a `delisted` exit at $329.61 instead of a `stop_loss` at $0.04.
