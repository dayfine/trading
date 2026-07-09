# Portfolio_floor off — the GME-window ablation (2026-07-09)

User-directed experiment ("what if we get rid of it — would it make things more
stable?"): re-run the floor pathology window with the brake disabled. No code
change — `min_portfolio_value_fraction_of_peak` is config;
`((portfolio_config ((force_liquidation ((min_portfolio_value_fraction_of_peak 0.0))))))`
disables the portfolio-floor trigger (per-position force-liq stays active).

**Arms:** `goldens-sp500-historical/sp500-2010-2026.sexp` (long-only, 0.30
concentration, 364 basis, test_data store) as-is (floor 0.4 = default) vs
floor-off. Same-session paired run; floor-on reproduced its golden pins
exactly (1013.8% / DD 65.8 / 32 floor liqs / OPV 0).

## Result — floor-off dominates every metric that matters

| metric | floor ON | floor OFF | read |
|---|---|---|---|
| total return | 1013.8% | **2223.3%** | +1210pp |
| Sharpe | 0.538 | **0.610** | |
| Sortino | 0.813 | **0.865** | |
| Calmar | 0.242 | **0.271** | better even though MaxDD is worse — return more than compensates |
| Ulcer (time-underwater) | 33.9 | **23.6** | floor-off recovers; floor-on flatlines 5y |
| MaxDD | **65.8%** | 78.3% | the one floor "win" — but see below |
| trades | 410 | 588 | floor-on missed ~178 trades (2021-2025 sterilized) |
| portfolio-floor liqs | 32 | 0 | |
| end state | $11.1M all-cash, halted | $23.2M ($6.5M unrealized) | floor-off end is MTM-top-heavy; realized-basis ≈ $16.7M still ≫ $11.1M |

**The MaxDD "win" is hollow.** Both drawdowns are measured from the same
$28.9M GME-squeeze MTM peak (never realizable). The floor's 65.8% includes
the damage the floor itself caused — it force-sold the entire book at the
squeeze collapse (near the local bottom) and then re-liquidated 31 more times,
locking the loss in. Floor-off rides the same collapse deeper on paper
(78.3%) but keeps the book, keeps trading, and its time-underwater profile
(Ulcer 23.6 vs 33.9) is far better. A brake whose fire = sell-everything-at-
the-bottom + halt does not reduce risk; it converts a paper drawdown into a
realized one and then forecloses the recovery.

## Scope honesty

- Single window, single path, and the window was chosen BECAUSE the floor
  misfires here — this quantifies the harm on the worked example; it is not a
  universe/period-robust promotion test.
- The floor's intended value case (a true, non-recovering death spiral) does
  not occur in any tested config: the deep top-3000 2000-2026 run fires it 0
  times, sp500 deep arms ~1 per-position event, and the only portfolio-floor
  fires we have ever observed are these 32 pathological ones. There is no
  observed window where the portfolio floor helped.

## Options (decision item — user)

1. **Fix semantics, keep the brake** (recommended path, already in motion):
   the P1b breaker lib's index-referenced trailing-WINDOW peak + self-
   contained re-entry is the squeeze-immune design; port it to
   `Force_liquidation.Peak_tracker` once the lib lands. The brake then can't
   be poisoned by one position's MTM spike and can't sterilize a run.
2. **Default the portfolio-floor trigger off now** (set
   `min_portfolio_value_fraction_of_peak` default 0.4 → 0.0): defensible on
   the evidence (never helps, catastrophically hurts once), but it is a
   default change on a RISK-CONTROL — per experiment-flag-discipline R3 +
   promotion-confirmation this wants more than one pathological window; and
   it re-pins the sp500-2010-2026 golden (this experiment IS the re-pin
   measurement if chosen).
3. Leave as-is, documented (status quo; the golden pins the pathology loudly).

Artifacts: `floor-{on,off}-actual.sexp` here; raw runs under the gitignored
`trading/dev/backtest/scenarios-2026-07-09-160512/`; log
`/tmp/sweeps/floor-exp-v1.log`.
