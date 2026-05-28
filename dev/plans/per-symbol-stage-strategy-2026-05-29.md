# Per-symbol Weinstein stage strategy diagnostic — 2026-05-29

Diagnostic experiment: test whether the **Weinstein stage classifier on its
own** delivers alpha on SPY + the 11 SPDR sector ETFs, completely stripped of
all portfolio-level mechanics.

## Context

Per the dispatch brief: "do the stage analysis for SPY and work with just
that — buy when transiting into Stage 2, sell when transiting into Stage 3
(long-only); also sell short in Stage 4 (long-short). Repeat for each sector
ETF and see what the high-level return should look like."

This is the cleanest possible test of stage analysis as an alpha source. If
the minimal stage strategy beats BAH on a symbol, then stage analysis HAS
predictive power and the existing Weinstein system's portfolio mechanics
(laggard rotation, sizing, sector caps, screener cascade, screener scoring)
are the source of the alpha bleed.

Coordinating with a parallel mechanism-ablation agent
(`experiment/mechanism-ablation`) which tests disabling specific mechanisms
in the existing strategy. The two are complementary.

## Approach

**Standalone executable**, NOT a new strategy plugged into
`Strategy_choice`. Reasons:

- Diagnostic, not feature — the user explicitly asked for a probe, not a
  shipping strategy.
- 1-symbol portfolio is too simple to need the panel/snapshot/engine
  machinery (no sector data, no AD bars, no screener, no sizing).
- Direct loop is ~250 LOC; plumbing through `Strategy_choice` would be
  ~600 LOC for the same answer.
- Reuses existing `Stage.classify` so the stage definitions are the same
  ones the production system uses (no risk of a parallel
  implementation drifting).

### Strategy spec (variant: Long-only)

For each symbol:

1. Load daily OHLCV bars (Csv_storage).
2. Convert to weekly bars
   (`Time_period.Conversion.daily_to_weekly ~include_partial_week:false`).
3. Walk weeks chronologically. At each week `t`:
   - Call `Stage.classify ~config:Stage.default_config
      ~bars:<weeks 0..t>
      ~prior_stage:<stage at t-1>` to get current stage.
4. **Position state** (only one position at a time):
   - On `Stage1 -> Stage2` transition: buy 100% of cash at next week's open
     close (assumed equal to current week's adjusted close, with cost
     adjustment).
   - On `Stage2 -> Stage3` transition: exit to cash at current week's close.
   - Hold otherwise.
5. Compute per-period returns from the equity curve.

### Strategy spec (variant: Long-short)

Same as Long-only PLUS:
- On `Stage3 -> Stage4` transition: short 100% of cash.
- On `Stage4 -> Stage1` transition: cover short.

Net state: cash | long | cash | short.

### Cost model

Per the brief: 0.5 bps bid-ask + $0 commission.
- Buy fill: `price * (1 + 0.00005)`.
- Sell fill: `price * (1 - 0.00005)`.
- Applied at the close price of the transition bar (no next-week-open lookup
  — the strategy is on weekly bars and entry timing is "first close after
  signal").

### Metrics

Per the brief:
- Strategy CAGR (annualised compound return over the run window)
- BAH CAGR (buy on first available bar, hold to end)
- MaxDD (peak-to-trough on the equity curve)
- Sharpe (weekly returns annualised, scaled by sqrt(52))
- # Stage-2 entries (count of Stage1→Stage2 transitions that result in a buy)
- Avg holding days (calendar days per long hold, averaged across all
  completed round-trips)
- % time long (sum of long-position weeks / total weeks)
- For long-short: # short entries, % time short

## Test matrix

12 symbols × 2 variants = 24 backtests:

- SPY (1998-01-01 → 2025-12-31; data starts 1993-01)
- XLK, XLF, XLI, XLV, XLE, XLP, XLY, XLU, XLB (1998-12-22 → 2025-12-31)
- XLRE (2015-10-08 → 2025-12-31) — short history
- XLC (2018-06-19 → 2025-12-31) — short history

All symbols have data through 2026-04-14 (ETFs) or 2026-05-01 (SPY); we
truncate at 2025-12-31 to match the brief.

## Files to add

```
trading/analysis/scripts/per_symbol_stage_strategy/
├── dune                      (executable target)
├── per_symbol_stage_strategy.ml  (CLI + report rendering)
└── lib/
    ├── dune                  (library target)
    ├── single_symbol_backtest.ml   (the per-symbol loop)
    ├── single_symbol_backtest.mli  (entry-point signature)
    ├── stage_signal.ml         (stage transitions → trade actions)
    └── stage_signal.mli
```

Plus:

```
dev/notes/per-symbol-stage-strategy-2026-05-29.md  (report)
```

## Reused, not modified

- `Csv_storage.get` (load daily bars)
- `Time_period.Conversion.daily_to_weekly` (weekly aggregation)
- `Stage.classify` (the stage classifier — same one production uses)
- `Stage.default_config` (default ma_period=30, Wma, etc.)

## Risks / unknowns

1. **Stage classifier requires `prior_stage` to disambiguate flat MA.**
   Need to thread `prior_stage` through the walk. First week starts with
   `prior_stage = None` (which falls back to a long-term MA trend heuristic).

2. **`include_partial_week`.** Using `false` to avoid mid-week partial
   classifications. Means the last week of run may be dropped — acceptable
   for a 27y diagnostic.

3. **No survivorship issue.** The 11 SPDR ETFs all still exist; SPY too.
   No delisting / membership timing issues.

4. **Short-side mechanics.** When short, we accrue the **negative** of the
   price return. No borrow cost included (simplification per brief — "no
   portfolio mechanics").

5. **Stage classifier slow on long windows.** `Stage.classify` recomputes
   the full MA from all bars on every call. For 27y × 52 weeks ≈ 1400 calls
   × O(n) = ~1M operations per symbol. Acceptable (< 1 sec).

6. **First-position sizing.** "100% of cash" — for a single-position
   portfolio with 0.5bps slippage this is the integer share count that
   uses up to all cash. Use float shares for simplicity (no whole-share
   rounding) since this is a diagnostic, not a real-money strategy.

## Acceptance criteria

- [x] 12 symbols × 2 variants = 24 backtests run via the new exe.
- [x] Strategy module + per-symbol backtest committed under
  `analysis/scripts/per_symbol_stage_strategy/`.
- [x] Report `dev/notes/per-symbol-stage-strategy-2026-05-29.md` written
  with Section 1 (long-only matrix), Section 2 (long-short matrix),
  Section 3 (aggregate verdicts), Section 4 (per-symbol equity-curve
  samples), Section 5 (strategic interpretation).
- [x] `dune build` passes inside docker. Run-time of full 24-backtest
  matrix < 30 sec.
- [x] No modifications to existing modules (Stage, Csv_storage,
  Conversion, Weinstein_strategy, etc.).

## Out of scope

- Implementing as a `Strategy_choice` variant. The diagnostic is direct;
  any future productionised "minimal-stage strategy" can copy the loop
  into a STRATEGY module.
- Sector rotation across multiple ETFs. The brief is per-symbol — one
  ETF at a time, not a basket.
- Walk-forward / parameter tuning. The diagnostic uses
  `Stage.default_config`.
- Borrow cost on shorts. Acknowledged as a simplification.
- Sharpe/Sortino/Calmar beyond what the metric brief asks for.
