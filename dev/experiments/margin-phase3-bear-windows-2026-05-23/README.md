# Margin Phase 3 — bear-window validation

**Filed:** 2026-05-23. Owner: `feat-weinstein`.
**Issue:** [#859](https://github.com/dayfine/trading/issues/859).
**Plan authority:** [`dev/plans/short-side-margin-2026-05-13.md`](../../plans/short-side-margin-2026-05-13.md)
§Stage A.

## Purpose

Margin Phase 1 (Reg-T collateral + borrow fee, PR #1113/#1115) and
Phase 2 (simulator wiring — daily borrow accrual + maintenance
force-cover, PR #1119) shipped 2026-05-16. Both phases gate behind
`margin_config.enabled = false`, so existing baselines stay bit-equal
until a scenario opts in.

This experiment is the validation gate: re-run the strategy across
historical bear windows with `margin_config.enabled = true` and
compare bottom-line metrics against the same scenario with the flag
off. The hypothesis (plan §0): realistic margin friction (50% Reg-T
initial collateral lock + 50bps daily borrow fee + 25% maintenance
threshold) does not make the Stage-4 short edge profitable; it only
stops the simulator from flattering it.

## Scenario inventory

Eight scenarios — four bear windows × two configs (margin off baseline
vs margin on under the Phase 1+2 wiring).

| Window | Date range | Universe | Margin on/off |
|---|---|---|---|
| 2000-2002 dot-com | 2000-03-01 .. 2002-10-31 | `broad-1000-30y` | one each |
| 2008 GFC | 2007-10-01 .. 2009-03-31 | `broad-1000-30y` | one each |
| 2020-Q1 COVID | 2020-01-02 .. 2020-06-30 | `sp500-2010-01-01` | one each |
| 2022 bear | 2022-01-01 .. 2022-10-31 | `sp500-2010-01-01` | one each |

All eight scenarios share the same Cell E sizing / portfolio config
(`max_position_pct_long=0.14`, `max_long_exposure_pct=0.70`,
`min_cash_pct=0.30`, stage3 force-exit h=1, laggard rotation h=2) so
the only varied parameter across each pair is `margin_config.enabled`.

## Universe coverage caveat

The 2000-2002 and 2008 windows pre-date the `sp500-2010-01-01.sexp`
universe (510 symbols pinned at 2010-01-01). Per plan §5.2 these
windows use `broad-1000-30y` instead — 1000 symbols with bar history
back to ≤1996-01-01. Every symbol in that universe is a 30y+ survivor
(survivorship bias), but the bias is in the conservative direction
for short-side measurement: shorting survivors yields fewer winning
shorts, not more, so the bias under-states (not over-states) shorts'
profit potential.

The 2020-Q1 + 2022 windows use the `sp500-2010-01-01.sexp` universe
to share the modern-liquidity profile of the 16y long-short golden
(PR #1066).

## Data coverage

The 2000-2002 and 2008 scenarios require bar history pre-2009 and
will only run against the production data dir
(`/workspaces/trading-1/data` in container; `~/Projects/trading-1/data`
on host). The committed test data under `trading/test_data/` only
covers 2009+ so these two scenarios are excluded from CI / nightly
runs by design — they are explicitly experiment-only scenarios and
not perf-catalog members.

The 2020-Q1 and 2022 scenarios run against either the production data
dir or the committed test data.

## Acceptance gate (plan §2.2)

Per-window, report Sharpe, MaxDD, total return, total trades, win
rate, avg holding days, force-liquidations count, and (where Phase 2
emits it) `margin_call`-labelled exits and accrued borrow fee.

**PASS** if Sharpe(margin-on) > 0 in ≥2 of the 4 windows AND
MaxDD(margin-on) ≤ MaxDD(margin-off) + 5pp in each window. The
≤5pp tolerance allows for the realistic-friction effect (slightly
worse cumulative return, slightly higher drawdown from fewer winning
shorts) without flagging it as "shorts broke."

**FAIL** otherwise. The constructive interpretation of FAIL per plan
§5.3: the Stage-4 short-entry rule is honest about being unprofitable
under realistic friction; flipping the default `enable_short_side`
off is the right outcome, not a fix-the-code outcome.

## How to run

From the repo root (or this agent's worktree):

```bash
./dev/lib/run-in-env.sh dune build trading/backtest/scenarios/scenario_runner.exe

./dev/lib/run-in-env.sh \
  trading/_build/default/trading/backtest/scenarios/scenario_runner.exe \
  --dir /workspaces/trading-1/.claude/worktrees/<agent>/dev/experiments/margin-phase3-bear-windows-2026-05-23/scenarios \
  --parallel 2 \
  --no-emit-all-eligible
```

The runner forks each scenario into a child process and writes
per-scenario output under `dev/backtest/scenarios-<timestamp>/<name>/`.
Read `actual.sexp` for the pinned-metric snapshot.

`--parallel 2` is conservative — 16y/8-year-bear scenarios are
RAM-heavy (~6 GB each). Bump to 4 if running on a host with ≥32 GB
free.

## Report

The interpretation + go/no-go verdict lives at:

  `dev/notes/margin-phase3-bear-windows-2026-05-23.md`

That report drives whether to (a) keep `margin_config.enabled = true`
as a default candidate in Phase 5 (long-short re-pin), or (b) close
issue #859 with `enable_short_side = false` flip.

## Out of scope

- Changing `margin_config` defaults in code based on this result — that
  decision is a follow-up PR after the report is reviewed (plan §4
  Phase 5).
- Modifying margin logic in `trading/trading/weinstein/portfolio_risk/`
  or `trading/trading/strategy/lib/position.ml`. Phase 1+2 wiring is
  frozen for this validation.
- Adding per-symbol hard-to-borrow flagging (plan §5.4 #3 — deferred).
