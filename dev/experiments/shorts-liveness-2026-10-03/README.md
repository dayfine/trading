# Shorts liveness on the investor preset, 5d (2026-10-03)

## Why

User decision 2026-10-03: run the next-session item 4(d) first — one liveness pair, not a programme
(`dev/notes/next-session-priorities-2026-10-03.md` §4(d)). The investor preset runs with
`enable_short_side false`. Weinstein shorts Stage 4 breakdowns in a bear tape (book reference §Short-Selling
Rules); the question here is only whether the short leg **fires at all** on the broad PIT universe once the
faithful gates and the margin model are on.

Prior record, and why this is not evidence for or against shorts as a lever:
- `project_p0_levers_no_build_2026_06_20`: a reserved short sleeve lost at every fraction on broad deep; short
  supply was gated by Stage-4 signal count and `short_min_price 17`, not by cash.
- `project_p1a_deep_short_screens`: hedge value appeared only ungated, on sp500 — not a broad measurement
  (`universe-discipline.md`).
- `project_short_realism_p0`: margin model, short stop fixes and short round-trips in `trades.csv` are on main.

## Arms

| arm | spec | difference |
|---|---|---|
| `sh0` | `specs/sh0-5d.sexp` | byte-copy of `entry-anchor-recovery-2026-10-02/specs/ia0-5d.sexp` (investor preset, shorts off) |
| `shB` | `specs/shB-5d.sexp` | `sh0` + `enable_short_side true`, `neutral_blocks_shorts true` (already the default), `enable_slow_grind_short_gate true`, `short_min_price 17.0`, `short_borrow_min_dollar_adv 1e6`, margin model on (maintenance 0.30, FINRA-shaped borrow-rate and maintenance tiers below $5 / $17 — the block from `staging-margin-m4-stress/*`, without `short_buyin_stress_mode`) |

The margin model is on in `shB` only. With `initial_long_margin_req 1.0` nothing on the long side is borrowed,
so it should not touch long P&L (the 06-26 acceptance measured margin off vs on at < 0.06 pp); rule 2 checks it.

## Window, salt

5d = 2007-06-01 → 2012-06-29, PIT top-3000 schedule (2006–2011 lists), warehouse `_v11pit` (9,364 entries).
Salt 0 only. Two cells, ~25 min each (`perf-long-cells.csv`: ia0-5d 1,405–1,457 s). Pinned worktree at
`origin/main`, specs read from this pre-registration commit (`results/launch.sh`).

## Reading rule (pre-registered 2026-10-03, before any cell runs)

1. **Gate.** `validator_diff -check V6` exit 0 for the pair. A mismatch → "no reading" for any P&L delta;
   the liveness counts in rule 3 are still reported.
2. **Long leg unchanged.** Report the long trades shared between arms on (`position_id`-independent) entry
   date + symbol, and those unshared. Shorts compete for cash, so some divergence is expected; report its
   size, do not interpret it.
3. **Liveness (the question).** From `shB` `trades.csv` (`side = SHORT`) and the trade audit:
   - number of short entries filled, by year, and how many fall in 2007-10 → 2009-03;
   - short P&L total, win count, median holding days, exit-reason split (stop / cover / force-cover);
   - number of margin force-covers (`force_liquidations.sexp`).
   - **Live** = ≥ 1 short entry filled. **Sparse** = 1–9. **Active** = ≥ 10.
   - If 0: report what blocked it — weeks the macro read Bearish, weeks the slow-grind gate admitted shorts,
     Stage-4 short candidates screened and their rejection reasons — so the record says *which gate*.
4. **Portfolio read (descriptive only).** Return, max DD, Calmar, and NAV at 2009-03-31 for both arms, and the
   SPY-regime split (`backtest-result-review.md` RV2) of the NAV gap. One salt and one pair: no verdict on the
   lever from these numbers.
5. **Review pack.** Build, render and look at the `shB` pack (`backtest-result-review.md` steps 1–4); record
   what the look found.
6. **Verdict calibration.** This pair can say "live / sparse / active / dead under the faithful gates" and
   name the binding gate. It cannot accept or reject shorts. No default changes, no ledger entry. What comes
   next (a surface over the gates, more salts, or nothing) is a user decision.

**Expected, stated in advance.** Sparse shorts (`short_min_price 17` plus the grind gate), concentrated in
2008; possibly a few force-covers in the March–May 2009 rebound. A higher max DD in `shB` is plausible if
shorts are caught in the 2009 rebound.

## Result (2026-10-03, build 29e81f888, salt 0)

**Dead under the faithful gates: 0 short entries filled in five years, 2007-06 → 2012-06.** The run did place 2 short
tickets; neither filled. Both arms are identical apart from `position_id` numbering.

### Rule 1 — gate

`validator_diff -check V6` exit 0 (`results/chain-S.log`, `v6diff:sh0-5d:exit=0`).

### Null tripwire

`sh0` reproduces `../entry-anchor-recovery-2026-10-02/results/ia0-5d-s0-v11-*` on a newer HEAD (29e81f888 vs 4b90a8cc7): `actual.sexp` metrics identical, and `trades.csv` identical on every shared column except the stop-report columns of 3 rows (MMSI, BCH, AAON: `exit_stop` / `max_stop` / `n_stop_raises`), which #3100 corrected (reporting only; dates, prices and P&L unchanged). The new file adds `entry_anchor`.

### Rule 2 — long leg

All 72 long trades are shared, identical in every column except `position_id`: the two short tickets took two ids
(`RMD-wein-73`, `GFI-wein-192`), shifting later ids. Equity curve, open positions and force liquidations are
byte-identical (force liquidations after stripping ids; the one event is a long, CCME 2011-02-03, in both arms).
No short ever filled, so nothing competed for cash, and the margin model had nothing to borrow.

### Rule 3 — liveness: 0 (dead), and which gate

Weekly funnel from the `shB` trade audit (`results/s0-shB-short-funnel.csv`, 255 weeks):

| macro | weeks | weeks with Stage-4 short candidates graded | weeks the slow-grind gate let any through (`short_top_n_admitted > 0`) |
|---|---:|---:|---:|
| Bearish | 138 | 138 | **21** |
| Neutral | 25 | 25 | 0 (`neutral_blocks_shorts`) |
| Bullish | 92 | 0 | 0 |

1. **The slow-grind gate is the main block.** In 117 of 138 Bearish weeks, 7–590 graded short candidates (median 163, p25 59, p75 286)
   reached the last cascade stage, and `short_top_n_admitted` was 0. With the macro admitting shorts, that stage
   returns nothing only when `decline_is_slow_grind` is false (`screener.ml`, `slow_grind_admits`). The 21 open
   weeks were 2008-02-22 → 04-11 (5), 2008-08-08 → 09-19 (6), 2008-12-12 → 2009-01-16 (6), 2011-09-23 → 10-14 (4).
   It was closed through the Sep–Nov 2008 crash (a fast decline, by design).
2. **The entry step admits almost nothing.** Those 21 weeks admitted 174 candidates; 2 became tickets. The
   audit lists skip reasons only for weeks with an entry: in those two weeks 17 other candidates were skipped,
   12 `No_structural_stop` (`require_structural_stop true`: no structural level in range for the short stop,
   so the fallback stop would apply and the candidate is skipped) and 5 `Sized_to_zero`. The other 19 weeks have no audit row, so their reasons are not recorded.
3. **The two tickets rested above the market and never filled.** Entry is a stop-limit (`enable_sim_entry_stoplimit`,
   2 % band). RMD (2008-02-22): ticket 54.85 vs close 41.07 (+34 %); highest high before the 53-week TTL
   cancel 50.58. GFI (2011-10-14): ticket 18.79 vs close 15.59 (+21 %); highest high to the window end 18.39,
   2 cents under the band floor (18.41). The ticket is the breakdown level from the transition week; by the
   decision the price was already well below it. This is the short-side mirror of the long-side "far anchor"
   in `project_recovery_reentry_gap`.

Short P&L, win count, hold and exit split: none (no fills). Margin force-covers: 0.

### Rule 4 — portfolio (descriptive)

Both arms: return +18.47 %, max DD 14.42 %, Calmar 0.235, 72 trades, NAV at 2009-03-31 $967,054.29. The NAV gap is
zero, so there is no regime split to make.

### Rule 5 — review-pack look

`shB` pack built with `--no-container` (the trade-audit cards read n/a, not 0), rendered and read, all 7 images. Published: https://claude.ai/artifact/BoYPmkotZjNQZbCMWRWKv7
KPIs match `actual.sexp`; charts span 2007-06 → 2012-06; no mojibake or empty data panels; validator panel V6
PASS. **Found:** the pack has no short-side read, so a shorts-enabled run with zero fills looks exactly like the
null. A detector (short leg enabled in params → tickets placed / filled / the binding gate) is filed as a
follow-up issue.

### Rule 6 — verdict

**Dead under the faithful gates on the 5d window.** The binding gate is the slow-grind gate (117 of 138 Bearish
weeks), then the structural-stop requirement at entry, then the stop-limit band on tickets placed at a
breakdown level the price had already left. This cannot accept or reject shorts: it says that with these gates the
short leg does not trade, so its value cannot be measured. No default change, no ledger entry. What next (a
liveness pair with the grind gate off, more windows, or nothing) is a user decision.

**Why, and what it implies:** the expectation (sparse shorts concentrated in 2008) was wrong because the gates
compound. The grind gate closes in fast declines, which is when Stage-4 breakdowns cluster. When it is open, the
structural-stop and stop-limit rules, written for long breakouts, rarely find a short that is both near its
breakdown and has a structural stop in range. A short-side test needs the gates opened one at a time, starting
with the grind gate, or it measures nothing.

## Files

- `specs/` — the two arms.
- `results/chain-shorts.sh`, `results/launch.sh` — the chain (copy of the anchor chain, paths moved) and launcher.
- `results/` — per-arm artifacts and the chain log, committed with the results.

## Log

- 2026-10-03 — pre-registered.
- 2026-10-03 — chain ran 22:01–23:36 PT (sh0 2,692 s, shB 2,358 s); result above.
