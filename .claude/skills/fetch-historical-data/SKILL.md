---
name: fetch-historical-data
description: Audit market-data coverage and fetch/extend historical bars (EODHD) for a symbol list or point-in-time universe snapshot. Two phases — (1) availability check (de-risk, also runnable standalone to audit coverage), (2) bulk fetch + validate into the CSV store. Use when extending the backtest data floor (e.g. pre-2009 deep history), building a historical universe, adding symbols, or before any multi-symbol fetch. Triggers: "fetch data", "extend history", "check data coverage", "do we have bars for...", "build a deep/historical universe", "test a longer window".
---

# Fetch / extend historical market data

Two phases. **Never skip Phase 1** — a multi-hour fetch on unverified coverage is
how you build a *survivorship-biased* dataset (the thing that silently invalidates
every backtest on it). Phase 1 is cheap (~10 curls) and also stands alone as a
coverage audit.

Pairs with: `project_gspc_index_golden_2017_floor` (a data floor silently
truncated every experiment), `reference_deep_history_data_sources`,
`project_phase1_1996_membership_norgate`,
`dev/notes/vendor-comparison-historical-universe-2026-05-16.md`.

## Phase 1 — availability check (the de-risk; runnable standalone)

Before committing to a fetch, probe the vendor for a **representative sample that
includes the failure modes**:

- A few large survivors (AAPL, GE) — confirms the date floor.
- **At least 2-3 names that DIED in the target window** (delisted / bankrupt):
  e.g. `LEH` (Lehman, Sep 2008), `ENRNQ`/`ENE` (Enron), `BS` (Bethlehem Steel,
  2004), `WCOM` (WorldCom). **This is the load-bearing check** — if the vendor
  doesn't retain delisted bars through their death, your "deep" universe is
  survivorship-biased and the fetch is not worth doing. EODHD *does* retain major
  delistings to their last trade date (verified 2026-05-31: LEH→2008-09-17,
  BS→2004-01-05, YHOO→2017-06-16); small-caps are spottier.

```bash
TOKEN="${EODHD_API_KEY:-$(tr -d '[:space:]' < trading/analysis/data/sources/eodhd/secrets)}"
for sym in AAPL GE LEH ENRNQ BS WCOM; do
  r=$(curl -s -m 20 "https://eodhd.com/api/eod/${sym}.US?api_token=${TOKEN}&fmt=csv&from=<START>&to=<END>&period=d")
  rows=$(echo "$r" | grep -cE '^[12][0-9]{3}-')
  echo "$sym rows=$rows first=$(echo "$r"|grep -E '^[12][0-9]{3}-'|head -1|cut -d, -f1) last=$(echo "$r"|grep -E '^[12][0-9]{3}-'|tail -1|cut -d, -f1)"
done
```

Decision: proceed only if survivors cover the window AND delistings land at their
real death dates. EODHD EOD US history starts ~1999 in practice (claims 2000).

## Phase 2 — fetch + validate into the CSV store

### Get the symbol list
- Universe snapshot: `build_universe.exe -as-of YYYY-MM-DD -output <snapshot.sexp>`
  (point-in-time membership via Wikipedia changes replay; reliable 1994+). Extract:
  `grep -oE '\(symbol [A-Z.]+\)' snap.sexp | sed 's/(symbol //;s/)//' | sort -u`.
- Or an explicit list.

### Gotchas (all cost real time the first time)
- **Token:** the EODHD secret lives at `trading/analysis/data/sources/eodhd/secrets`
  (gitignored — absent in fresh worktrees) OR host env `EODHD_API_KEY`. The
  container env does NOT have it; run curls on the host or pass it in.
- **Ticker format:** EODHD uses `<SYM>.US`. Dotted tickers map differently:
  `BRK.B` → `BRK-B.US` (not `BRK.B.US`). Bare-dot tickers 404 — handle/skip.
- **CSV store path layout:** `<data_dir>/<sym[0]>/<sym[-1]>/<SYM>/data.csv`
  (first char / **last** char / symbol). E.g. `AAPL`→`A/L/AAPL`, `GSPC.INDX`→
  `G/X/GSPC.INDX`. Get this wrong and the backtest silently won't find the bars.
- **CSV header:** the store uses lowercase `date,open,high,low,close,adjusted_close,volume`;
  EODHD returns `Date,Open,...` — lowercase the header line.
- **`fetch_prices` bin samples the universe — it does NOT take a symbol list.**
  For a targeted list use `build_universe.exe -fetch-prices -token-file <f> -cache-dir <data_dir>`
  (but it only fetches **missing** CSVs — it will NOT extend an existing CSV back
  in time). To deepen existing symbols you must overwrite: delete-then-refetch, or
  a direct curl loop writing the full range (the reliable path for a one-off).
- **Index + macro data too:** the macro gate needs the index golden (`GSPC.INDX`)
  to span the window — extend it the same way (prepend the earlier rows; keep the
  later bytes). A/D breadth is non-binding (the index is the gate).
- **Manifest:** raw curl writes skip `manifest.sexp`; the backtest reads `data.csv`
  directly so it works, but provenance is lost — fine for an experiment input, not
  for a committed golden.

### Bulk fetch (curl loop, ~P8, the proven one-off path)
Loop the symbol list; for each, curl the range, require >200 rows, write the
lowercased CSV to the computed path. Log `OK <sym> <rows> <first>` / `MISS <sym>`.
~500 symbols at P8 ≈ 15-20 min. (See the 2026-05-31 deep-history build for a
working script shape.)

### Validate (mandatory)
- Coverage: count OK vs MISS; a 95%+ hit rate is good. List the misses.
- **Re-confirm delistings landed** with their real death dates (the survivorship
  proof) — not just that survivors fetched.
- Spot-check the store path resolves: `ls <data_dir>/<f>/<l>/<SYM>/data.csv`.

## Where the data lands vs. what to commit

- Fetch into the data dir the backtest reads (`TRADING_DATA_DIR`, default repo
  `trading/test_data`). For an experiment, an uncommitted worktree `test_data` is
  fine — **do NOT commit hundreds of deep-history bar CSVs** (huge); they're an
  experiment input. **Do** commit the universe snapshot + the scenario + the
  result/ledger/notes.
- A backtest reads bars via the data dir, the index golden, and the universe
  snapshot's `universe_path`; a new scenario just needs `universe_path` +
  `period` pointed at the deep universe/window.

## What "good" looks like
Phase 1 green (survivors + delistings covered) → Phase 2 fetch 95%+ with
delistings at real death dates → a backtest on the deep window produces non-zero
trades in the previously-empty early folds (the end-to-end proof, mirroring the
GSPC-floor fix verification).
