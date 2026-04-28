# sp500-2019-2023 short-side refresh — current main vs PR-#639 baseline

Re-runs the `sp500-2019-2023` golden against current main and compares
against the published baseline in
`dev/notes/goldens-performance-baselines-2026-04-28.md`.

The brief expected the comparison to isolate the short-side cascade
plumbing fix (#623) + full short cascade (#630) + Ch.11 spot-check
(#631). All three landed before commit 565365fb, which is the build
SHA the baseline note (PR #639) declares it ran on. The only
strategy-touching delta on `origin/main` since 565365fb is PR #642
(trade-audit capture sites + strategy refactor, 6f9a66d9). The result
table below puts the short-cascade hypothesis aside and reports what
actually changed.

## Setup

- Build: `origin/main` at 6f9a66d9 (post-#642).
- Initial cash: $1M, no `config_overrides`.
- Container: `trading-1-dev`, `eval $(opam env)`.
- Command: `_build/default/trading/backtest/scenarios/scenario_runner.exe --dir trading/test_data/backtest_scenarios/goldens-sp500`.
- Run dir (re-runnable, not committed): `dev/backtest/scenarios-2026-04-28-053202/sp500-2019-2023/`.
- Universe: 491 symbols (`universes/sp500.sexp`), 506 incl. index + sector ETFs.
- No `OCAMLRUNPARAM` override (default GC).

## Headline

**The short cascade did fire — 4 short entries in `trade_audit.sexp` —
but only in the first 2 weeks of Jan 2019 (residual late-2018 bearish
macro). All 4 short positions are absent from `trades.csv`.** Far
larger, unrelated changes dominate the result: total trades
134 → 30, return +70.8% → +4.16%, MaxDD 97.7% → 5.05%. The
delta is not attributable to the short-side cascade work.

## Side-by-side — baseline vs current main

| Metric | 2026-04-28 baseline (PR #639, build 565365fb) | Current main (6f9a66d9) | Δ |
|---|---:|---:|---:|
| Total trades (trades.csv) | 134 | 30 | −104 |
| Win rate | 38.1% | 46.7% | +8.6 pp |
| Total return | +70.8% | +4.16% | −66.6 pp |
| Sharpe | 0.39 | 0.28 | −0.11 |
| MaxDD | 97.7% (split-anomaly contaminated) | 5.05% | −92.6 pp |
| CAGR | ~11% | 0.74% | −10 pp |
| Avg hold (days) | 72.6 | 40.4 | −32 |
| Trade frequency (per mo) | 5.03 | 1.06 | −3.97 |
| Realized PnL | +$198K | −$13.7K | −$212K |
| Unrealized PnL | $1,675K | $408K | −$1,267K |
| Open positions at end | 10 | 3 | −7 |
| Profit factor | 1.29 | 0.66 | −0.63 |
| Calmar ratio | n/r | 0.15 | n/a |

Win-rate up + losing money + MaxDD collapsed to 5% = the strategy is
barely trading. The 30 trades involve only 7 unique symbols (JNJ ×10,
HD ×6, KO ×4, JPM ×3, CVX ×3, AAPL ×3, MSFT ×1) — out of a
491-symbol universe. The previous 134-trade run cycled through far
more names.

## Per-year breakdown (current run)

| Entry year | Trips | Wins | Realized PnL ($) | Avg hold (d) |
|---|---:|---:|---:|---:|
| 2019 | 11 | 7 | +296 | 27 |
| 2020 | 6 | 2 | −6,883 | 18 |
| 2021 | 2 | 1 | +1,110 | 187 |
| 2022 | 5 | 2 | +2,884 | 95 |
| 2023 | 6 | 2 | −11,122 | 41 |

2022 (the bear year B&H lost ~−18% on) was net +$2.9K realized
— statistically thin (5 trades). 2023 was the worst year (−$11K on 6
trades). The sample is too small to claim the strategy "closed the
2022 bear gap"; the strategy's −5% MaxDD floor just means it sat in
cash through nearly all of 2022.

## Short trades — audit vs CSV

`trade_audit.sexp` (the new artifact from PR #642) records 4
`Short`-side entries:

| Symbol | Entry date | Side | Entry | Stop installed | Stop > entry? |
|---|---|---|---:|---:|---|
| AAPL | 2019-01-04 | Short | 234.64 | 239.24 | yes (correct for short) |
| MSFT | 2019-01-04 | Short | 116.76 | (suggested 126.10) | n/a |
| CVX | 2019-01-04 | Short | 129.19 | **116.15** | **NO — inverted** |
| JNJ | 2019-01-11 | Short | 149.49 | **152.63** | borderline (1.02× entry) |

For shorts, the stop is the upside ceiling (above entry). AAPL has a
correctly-placed stop ($239.24 > $234.64). CVX has the stop INVERTED
($116.15 below entry) — that's a long-side stop placement applied to a
short position. JNJ has a stop barely above entry but inconsistent
with the suggested $161.45 from the cascade. This suggests the
`Weinstein_stops` install path doesn't reliably mirror the side, and
the AAPL short just got lucky.

**None of these 4 trade_audit entries appear in `trades.csv`.**
trades.csv has 30 rows; trade_audit.sexp has 37 entries (33 long
+ 4 short). The 4 short entries are exactly the gap. The
`Result_writer` likely filters by `Side = Long` when emitting
trades.csv; this is also a separate bug.

## Where macro was Bearish

The cascade only emits Short candidates when `Macro.result.trend =
Bearish`. Across the full 2019-01..2023-12 window, macro was Bearish
on a handful of weekly bars only. Audit-entry breakdown by macro
trend at entry:

| Macro trend | Audit entries | Side |
|---|---:|---|
| Bullish (confidence 1.0) | 26 | all Long |
| Neutral (confidence 0.47) | 6 | all Long |
| Neutral (confidence 0.65) | 1 | Long |
| **Bearish (confidence 0.235)** | **4** | **all Short** |

All 4 Bearish-macro entries fall on Jan 4 / Jan 11 2019 — the very
end of the late-2018 SPX Stage-4 episode. Both the COVID crash
(Mar–Apr 2020) and the 2022 bear (Q1–Q3 2022) registered as
**Neutral**, not Bearish, in the macro classifier. This is why no
shorts appeared in either of those windows.

That's a finding about macro-classifier sensitivity, not the short
cascade itself: the cascade plumbing (#623) and screener (#630)
*will* generate short candidates when given Bearish macro, but
Bearish macro is a much narrower regime than the layperson reading
of "the SPX was in a bear market." Per the QC behavioral rule C2,
the macro gate is unconditional — but its threshold for declaring
Bearish is high enough that it never fires in 2020 or 2022 on this
data.

## Did adding shorts change the long-trade count?

No — the wrong frame for the observed data. The long-trade count went
134 → 30, but shorts (when they appeared) only ran for 2 weeks in
Jan 2019 and the 4 positions did not run concurrently long enough to
drain cash from competing longs. The ~104-trade collapse is dominated
by something else, plausibly the strategy refactor in PR #642
(capture-site insertion, weinstein_strategy.ml 209-line net diff per
the merge commit). The audit sites are supposed to be passive
observers; they aren't, in this run, behaviourally passive.

## Did the 2022 bear become more / less profitable?

Roughly unchanged in direction (small positive realized) but on too
few trades (5) to read meaningfully. The previous run had ~25 trades
over 2022 (extrapolating 134 / 5 yrs); this run has 5. So "more
profitable per trade, fewer trades" — net effect on equity is
essentially flat for 2022.

The strategy did **not** capture the bear via shorts. The 2022 bear
gap vs B&H persists — but for a different reason than the baseline
note speculated: shorts aren't suppressed by sizing competition;
they're suppressed by the macro classifier never declaring Bearish.

## Honest take

1. **The short cascade is wired and the screener is generating
   candidates.** trade_audit shows 4 textbook bearish-macro short
   entries (Stage 4 stocks, breakdown volume, virgin support below).
   That's the #623 + #630 work landing.

2. **The macro classifier is too restrictive to surface shorts at the
   moments that matter** (2020 COVID, 2022 bear). 4 out of 37 audit
   entries (11%) were Bearish-macro, and all 4 in the same 2-week
   window. Candidate for a separate macro-tuning experiment, not
   blamed on the short-side track.

3. **The big regression in this run is unrelated to short-side work
   and is almost certainly PR #642's strategy refactor.** Trade
   count, return, drawdown, frequency — all collapse together.
   Without #642 the baseline 134 trades / +70.8% / 97.7% MaxDD
   numbers would still hold.

4. **trades.csv silently drops short-side round trips.** Logging bug
   in `Result_writer`, not a strategy bug. If trades.csv is to remain
   the system-of-record for trade counts post short-side, this needs
   a follow-up.

5. **Short stops appear inverted on at least 2 of 4 entries** (CVX,
   JNJ). Either the audit-recorder is reading the wrong field or the
   stop state machine has a sign bug for shorts. Cannot tell from the
   audit alone; needs a unit-test pass on `Weinstein_stops` for the
   Short branch.

## What this note does NOT do

- Re-pin `expected` ranges in `sp500-2019-2023.sexp`. Ranges in the
  scenario file currently fail in 6 of 7 dimensions on the current
  run. Re-pinning is premature until the #642 refactor regression is
  understood (or reverted) and short stops are debugged.
- Investigate the #642 refactor. The brief explicitly scoped this to
  documentation-only.
- Re-run the small or broad goldens. Out of scope per the brief.

## Follow-ups (in priority order)

1. Diagnose the trade-count collapse since #642. Likely candidates:
   - Sizing or alternatives-considered routing changed in
     `entry_audit_capture.ml` / `weinstein_strategy.ml`.
   - The new `Audit_recorder` callback bundle is changing position-id
     allocation order, displacing entries.
2. Fix `Result_writer` to emit short-side round trips into trades.csv.
3. Audit the short-side `Weinstein_stops` sign convention against the
   CVX 2019-01-04 / JNJ 2019-01-11 audit entries.
4. Once 1-3 land: re-run this golden, then re-pin
   `sp500-2019-2023.sexp`'s `expected` block.

## References

- Baseline note: `dev/notes/goldens-performance-baselines-2026-04-28.md`
- Scenario: `trading/test_data/backtest_scenarios/goldens-sp500/sp500-2019-2023.sexp`
- Cascade fixes: PR #623 (Macro plumbing), #630 (full short screener),
  #631 (Ch.11 spot-check)
- Suspected regression source: PR #642 (trade-audit capture sites)
- Status: `dev/status/short-side-strategy.md`
