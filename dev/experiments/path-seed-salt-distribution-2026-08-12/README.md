# First per-cell distribution — path-seed salt, 2026-08-12

The armed-StopLimit golden config (sp500, 2019-2023, CI's committed bars) run
five times under `TRADING_PATH_SEED_SALT=0..4` on post-#2279 main.

| salt | total_return_pct | total_trades |
|---|---|---|
| 0 (unset) | 112.28323995525771 | 240 |
| 1 | 112.50079295906956 | 240 |
| 2 | 113.26940843547713 | 240 |
| 3 | 110.95984916423684 | 240 |
| 4 | 113.48537554308106 | 240 |

mean ≈ **112.50**, range **2.53pp** (110.96 → 113.49) = **~2.2% relative**.
Trade count identical at 240 across all five.

## Why this matters

Determinism (#2279) makes a run *repeatable*. It does not make it
*representative*: the strategy's return is concentrated in a handful of trades
and the cash queue is saturated, so which path the simulator walks through each
bar decides which candidates get funded. A single run is one draw from that
lottery.

This is the first measurement of the draw-to-draw spread with the binary held
fixed — which is what a comparison between two configs has to clear.

## The scaling is the finding

| scale | path-realisation spread | relative |
|---|---|---|
| sp500 / 5y (here, n=5 salts) | 2.53pp on ~112.5 | **~2.2%** |
| top-3000 / 26y (ladder-v4 cells 07/08, n=1 pair) | 278pp on ~587 | **~47%** |

Same mechanism, >20× the relative spread. The 26y figure is a single observed
pair (`dev/notes/ladder-v4-read-2026-08-12.md` §1), so treat it as an existence
proof rather than an estimate — but the direction is not in doubt, and it is
exactly where the ladder program does its comparisons.

## How to use it

Run any cell across K salts and compare *distributions*, not points:

```sh
for s in 0 1 2 3 4; do
  TRADING_PATH_SEED_SALT=$s TRADING_DATA_DIR=<repo>/trading/test_data \
    scenario_runner.exe --dir <cell-dir> --fixtures-root <fixtures> --parallel 1
done
```

Unset (or `0`) is bit-identical to the pre-salt build — verified: the golden
returns `112.28323995525771` / 240 either way — so every pinned number and every
golden is untouched.

**Do not read a 26y single-run ladder ranking as a ranking.** At ~47% relative
spread, no knob tested so far produces an effect that clears one draw.
