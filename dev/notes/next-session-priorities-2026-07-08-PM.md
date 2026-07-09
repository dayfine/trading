# Next-session priorities — 2026-07-08 PM

**Supersedes** `next-session-priorities-2026-07-08.md` (its P0 — warmup
210→364 — is DONE and merged). Main green on d82f1b35 with all postsubmits.

## What 2026-07-08 (this session) shipped

- **#1890 (merged, 3 gates + all postsubmits green)** — warmup 210→364 for
  Weinstein/Spy_only runners: the RS-honest basis. `rs_value` present from the
  FIRST screen of every window (was `None` for all symbols in the first 22
  weeks ≈ 21% of every WF-CV fold). Hardcoded 210s in `all_eligible_runner` +
  `optimal_strategy_runner` now reference `Backtest.Runner.warmup_days_for`.
  Full record: `dev/notes/warmup-364-repin-2026-07-08.md`; ledger
  `2026-07-08-warmup-364-basis-change`.
- **13 tight goldens re-pinned** (each vs its own validator store), 12
  sanity-wide goldens verified PASS, 3 BAH unaffected.
- **Deep warehouse rebuilt for 364**: `/tmp/snap_top3000_1998_2026`, window
  [1999-01-02, 2026-04-30], 2999 snaps verified. Old 210-window copy at
  `/tmp/snap_top3000_1998_2026.bak-210`. ⚠ Container `/tmp` is ephemeral —
  rebuild command in the repin note if lost.
- In-flight at handoff: comment-only warning header on the
  `sp500-1998-2026.sexp` scaffolding scenario (its direct-run ~227% number is
  a placeholder-universe + survivor-store artifact; almost got quoted as a
  real deep baseline this session).

## Findings that steer the next work

1. **GME-squeeze Portfolio_floor sterilization (P1b input, the big one).**
   On the honest basis, sp500-2010-2026 long-only rides GME Sept-2020
   (+$7.8M realized). The squeeze's $28.9M MTM peak poisons the MONOTONIC
   `Force_liquidation.Peak_tracker` (floor = NAV < 0.4×peak, halt until macro
   flips): NAV never re-clears the floor → brake fires 2021-02-02 and the run
   is dead for its remaining 5 years (32 floor liqs, zero 2023-24 entries,
   ends all-cash; 1013% return but DD 65.8%). Longshort twin same window:
   healthy (362%, DD 21.3). **Any P1b circuit-breaker design must handle
   squeeze-shaped MTM spikes** — decaying or realized-basis peak, floor reset
   semantics, per-position vs portfolio separation.
2. **RS-honest basis shifts windows asymmetrically.** Broad short windows
   LIFT with lower DD (six-year 4→22%, bull-crash 10→41%, covid-broad
   53→134%): the "concentration 0.30 hurts short windows" caveat from
   2026-06-25 mostly evaporates. sp500-2019-2023 long-only DROPS 41→16%
   (unhedged COVID ride) — dispersion, not pathology. Absolute numbers from
   before 2026-07-08 are on the old basis; relative verdicts stay valid.
3. **Scaffolding-golden trap**: `sp500-1998-2026.sexp` direct runs are
   artifacts (static top-3000-1998 placeholder universe + survivor-subset
   test_data store silently skipping most names). Honest deep numbers =
   warehouse-backed runs only.

## P1 — the floor-quality program (unchanged from AM doc, now unblocked+informed)

**P1a — deep re-screen of the faithful short gates (first, cheap, read-only).**
#1696 (`neutral_blocks_shorts` Bearish-only + slow-grind gate) + #1708
(`fast_v_arm_on_rate_alone`) screened NEEDS-DEEP-DATA on 2010-26. The deep
warehouse is now rebuilt on the 364 basis — run the screens on the deep window
(2000-02 + 2008 is where the benefit case lives). Note: any comparison
baselines must be re-run on the new basis (do NOT reuse pre-07-08 absolute
numbers).

**P1b — fast circuit-breaker SPY sleeve (design + default-off build + screen).**
Ingredients validated: decline-character classifier (#1692), catastrophic stop
(#1695), A-D-live breadth, factor-lens edge~forward-DD r=−0.79. Success bar:
match TOTAL-RETURN SPY, cut the left tail — not Calmar. **New requirement from
finding 1: the breaker's peak/floor semantics must survive squeeze MTM spikes
(the GME case is the concrete regression scenario — sp500-2010-2026 long-only
on the current floor is the worked example of what NOT to do).**

**P1c — blending only after P1b produces a floor worth blending.** Barbell
gates stay PARKED.

## Decision items (human)

1. **check_limits wire-or-delete** (carried; DELETE now natural).
2. (New, small) `Portfolio_floor` semantics: is the monotonic-peak halt
   *intended* behavior for research runs, or should the fix land ahead of
   P1b? Currently documented-not-fixed; the golden pins the pathological
   behavior loudly.

## Carried / small

- `data/breadth/nyse_advn.csv` truncated (791 rows, 2017-2020) by the 07-07
  recovery → 2 local-only test failures (`ad_bars_unicorn:7`,
  `ad_bars_compose:8`). CI unaffected (no data/ on runners). Cheap re-fetch
  fixes; or leave.
- `feature_screen` constant-feature failwith nit (carried).
- all_eligible runner hardcodes macro=Neutral per Friday (BY DESIGN; carried).
- P4 continuous-RS display (live-picks UX only; carried).
- Faithful per-week universes (M6.6, deferred).
- `write_ledger_entry.exe` doesn't regen `index.sexp` (carried; index edited
  by hand this session).
- goldens-small remain at 0.14 concentration override (unchanged since 06-25;
  re-pinned on the 364 basis this session at 0.14).

## Standing constraints (unchanged)

Entry-selection CLOSED (powered null); scale-in closed; reallocation
exhausted; envelope closed; stop-tuning closed. Weinstein spine fixed. Open
frontier: **floor quality (fast circuit breaker + effective shorts) → then
blending; plus capacity/breadth economics.** Scoreboard = absolute return +
start-date robustness with tail control; comparators TOTAL-RETURN always.
NEW: all absolute backtest numbers quoted from before 2026-07-08 are on the
210 basis — re-measure before citing against post-07-08 runs.
