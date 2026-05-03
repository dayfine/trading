# M5.4 E3 — Stop-buffer sweep: hypothesis

## Date
2026-05-03

## Hypothesis

> Widening `initial_stop_buffer` from the current default of 1.02 (2%) to
> values in the 1.05–1.15 range improves risk-adjusted return (Sharpe,
> Calmar) on the sp500-2019-2023 full-cycle golden by reducing whipsaw
> exits.

Per `dev/plans/m5-experiments-roadmap-2026-05-02.md` §M5.4 E3.

The book (Weinstein Ch. 6) prescribes initial stops 5–15% below entry,
sited at the prior correction low. The current default of 1.02 (2%) is
materially tighter than the book's lower bound and produces frequent
sub-1-day stop-outs in baseline runs (74% whipsaw rate observed in the
prior recovery-2023 stop-buffer experiment, dev/experiments/stop-buffer/).

## Why re-run despite the prior `dev/experiments/stop-buffer/` study

The 2026-04-14 stop-buffer experiment ran a 5-cell sweep on a single
recovery-2023 window (2023-01-02 .. 2023-12-31). Its conclusion was
**hypothesis rejected on the 6-year golden** — single-regime tuning
favoured 1.15, but the multi-regime golden reversed that ordering and
the default stayed at 1.02.

Three things have changed since:

1. **Canonical baseline moved.** The sp500-2019-2023 golden was re-pinned
   on 2026-05-02 to 60.86% return / 86 trades / 0.55 Sharpe (vs the
   2026-04-30 baseline of -0.01% / 32 trades) after #744 (sizing fix),
   #745 (cash-deployment fix), #746 (long/short cap split), and #771
   (stop tuning). The behaviour space the prior study explored is no
   longer current.
2. **Wider grid.** This sweep adds 1.00 (no buffer; tightest possible),
   1.10 (canonical 10% rule of thumb), and 1.20 (out-of-band right-tail
   control) to the prior 1.02 / 1.05 / 1.08 / 1.12 / 1.15 set. 8 cells
   total, all run on the same multi-regime window.
3. **Single multi-regime window from the start.** sp500-2019-2023 covers
   late-cycle advance (2019), COVID crash (2020 H1), V-recovery (2020
   H2 – 2021), bear (2022), and rotation recovery (2023) — five regimes
   in one run. Avoids the prior study's single-regime-then-validate
   pitfall by collapsing the initial sweep onto the multi-regime view.

## Sweep grid

| Cell | `initial_stop_buffer` | Buffer meaning | Note |
|------|----------------------|----------------|------|
| 1.00 | 1.00 | exactly at suggested | left-tail control (no buffer at all) |
| 1.02 | 1.02 | 2% beyond suggested | current default; control / baseline within sweep |
| 1.05 | 1.05 | 5% beyond suggested | book lower bound |
| 1.08 | 1.08 | 8% beyond suggested | book lower-mid |
| 1.10 | 1.10 | 10% beyond suggested | "10% trailing stop" rule of thumb |
| 1.12 | 1.12 | 12% beyond suggested | book upper-mid; prior study's win-rate winner on recovery-2023 |
| 1.15 | 1.15 | 15% beyond suggested | book upper bound |
| 1.20 | 1.20 | 20% beyond suggested | out-of-band right-tail control |

8 cells, all on `goldens-sp500/sp500-2019-2023` (same universe, period,
and config; only `initial_stop_buffer` varies).

## Falsification criteria

The hypothesis is **not supported** if:

1. Sharpe and Calmar are flat (within ±10% of the 1.02 control) across
   the entire 1.05–1.15 band, indicating the prior study's signal was a
   single-regime artefact that doesn't replicate on the new baseline.
2. Total return degrades monotonically with wider buffers (1.00 best,
   1.20 worst), indicating the strategy genuinely cannot hold positions
   profitably beyond the tight default.
3. Variance between runs (start-date sensitivity, fuzz IQR) exceeds the
   signal between cells. The 2026-05-02 fuzz on the canonical baseline
   spans +37.92%–+60.86% — if a sweep cell falls inside that band, it
   isn't statistically distinguishable from the control.

## Expected qualitative shape

Naive prior:

- **Win rate:** monotonic up with buffer (less whipsaw); plateau or
  reverse past 1.15 as positions held too long give back gains.
- **Total trades:** monotonic down with buffer (fewer positions
  re-cycled).
- **Avg holding days:** monotonic up with buffer.
- **Max drawdown:** *not* monotonic. Tight buffers (1.00 / 1.02) stop
  out fast → small drawdowns from individual losses but high frequency.
  Wide buffers (1.15 / 1.20) absorb larger excursions per trade →
  fewer-but-larger drawdowns. Optimal is some interior point.
- **Sharpe / Calmar:** maximum at an interior cell (best guess: 1.05
  to 1.10), not at either extreme.

If the actual shape diverges meaningfully from the above (e.g. monotone
in either direction across the full grid), that itself is a useful
finding — the sub-1-day whipsaw mode may not be the dominant loss
driver on the multi-regime sp500 golden.

## What this experiment does NOT prove

1. **One window, even a 5-year one, is not a regime ensemble.** A 1.10
   winner here may not be the cross-regime winner. Norgate ingestion
   (M5.3) + the smoke catalog will let a follow-up triangulate this.
2. **`initial_stop_buffer` is one knob.** The trailing-stop-percent
   parameters in `stops_config` are unchanged — a wider initial buffer
   may interact non-trivially with those.
3. **Survivorship bias.** Universe is today's S&P 500. Norgate fix
   forthcoming (M5.3).
