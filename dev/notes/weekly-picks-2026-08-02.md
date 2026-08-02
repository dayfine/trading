# Weekly picks — as-of 2026-07-31 (run 2026-08-02)

First weekly run on the fully honest machinery: split-safe warehouse rebuild
(#2145/#2153 basis), generator self-validation (#2165), and the entry-cap
ticket alignment (#2171, size-on-cap per the 2026-07-29 user decision).

System version: `c028ee864`. Record: `dev/weekly-picks/c028ee864/2026-07-31.{sexp,md,html}`
+ `validation.txt` (v4 convention — validation is part of the record).

## Pipeline run

- **Fetch**: 12-batch parallel `fetch_symbols.exe`, 3,173/3,173 symbols
  (pinned 2026-06-26 universe 3,158 + 15 macro/context), **0 errors**; bars
  through Fri 2026-07-31.
- **Inventory**: 5,734 symbols.
- **Warehouse**: FULL non-incremental `build_snapshots.exe` rebuild of
  `dev/data/snapshots/weekly-review` (ops law post-#2108), windowed
  [2024-06-01, 2026-07-31], benchmark GSPC.INDX, `-emit-weekly-sidetable`
  (split-safe adjusted basis), superset Pinned universe
  (`universe-superset-2026-07-31.sexp`). **3,173/3,173 verified, 0 failures**
  (276s).
- **Generate**: `--as-of 2026-07-31`, live overrides
  (`live-config-overrides.sexp`), $100k template portfolio. The #2165
  self-validator fired its first live warn-first block (below).
- **Validate**: standalone `validate_weekly_snapshot.exe` with warehouse bars
  + $1,000 risk budget + armed thresholds (band 1.0 / max 15.0): **0 errors,
  1 warning** (matches the in-generator pass exactly).

## Validator finding (surfaced pre-publication)

- **WARN FBRX `split_in_window`** — raw/adjusted ratio step inside the bar
  window. FBRX is the rank-1 WATCH row (+112.9% EXTENDED past its $35.98
  entry, ticket suppressed — do not chase), so the basis-suspect flag touches
  **no actionable order**. Its resistance grade is split-safe (adjusted
  side-tables), but its structural floor is raw-basis until the split-safe
  floors decision item lands (`dev/status/support-floor-stops.md` follow-ups).

## Result

**Bullish** (1.00); 6 strong sectors; **20 long candidates** led by WTW
(A+ 90, Virgin_territory); 0 shorts; 0 held ($100k template — set real cash
in `portfolio.sexp` to size to your book). Classes: **2 EXTENDED**
(FBRX +112.9%, SAFT +26.2% — watch only) / **3 through-entry** (CZNC +4.7%,
KARO +5.6%, THC +2.5% — BUY LIMIT at ~close, capped) / **15 valid-stop**.

**First live #2171 tickets**: resting entries print
`BUY STOPLIMIT trigger $E limit $(E×1.15)` and through-entry rows print
`BUY LIMIT @ ~close, limit cap` — every ticket sized on the cap
(worst-case risk ≈ $1,000 budget; e.g. WTW 16sh, worst-case risk $969).
The do-not-chase ceiling is now mechanical in the order itself, closing the
intraday gap-chase hole between Fridays (#2158 Phase 1).

**Sparse-tail harvest**: SATS, BLD + others dropped (0 bars in last 15
trading days) — same #2083 rename/sparse-feed class as prior weeks; the
returns-basis rename arming (#15/#2083 remainder) is still the standing fix.

## Ops notes

- Run executed 2026-08-02 (the in-session Friday cron fired late — weekend
  data identical to Friday-evening run; as-of anchored to 2026-07-31).
- Fetch/build/generate all from the parent tree on main tip `c028ee864` with
  no concurrent jj ops or agent dispatches (single-writer window).
