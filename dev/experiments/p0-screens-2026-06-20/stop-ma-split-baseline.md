File ".", line 1, characters 0-0:
File ".", line 1, characters 0-0:
stop_ma_split: graded 746 stop_loss exits
# Stop MA-structure split — /workspaces/trading-1/dev/backtest/scenarios-2026-06-18-232354/cell-e-top3000-1998-deep

30-week SMA at exit; 26w post-exit horizon. For a long, +continuation = price kept rising after we sold (gave up upside / whipsaw); -adverse = drop dodged. Per-decision value-add ~ realized - continuation (more negative = worse exit).

## By MA slope at exit

| MA slope | n | mean continuation | mean favorable | mean adverse | mean realized |
|---|---|---|---|---|---|
| rising | 445 | +4.4% | +27.0% | -18.3% | +0.7% |
| falling | 294 | +8.9% | +34.1% | -21.1% | -3.9% |

## By price vs MA at exit (Stage-2 structure intact = close above MA)

| price vs MA | n | mean continuation | mean favorable | mean adverse | mean realized |
|---|---|---|---|---|---|
| above MA (whipsaw?) | 521 | +6.6% | +30.1% | -18.8% | +0.0% |
| below MA (breakdown?) | 218 | +5.2% | +29.1% | -20.8% | -3.9% |
| insufficient bars | 7 | +7.6% | +42.0% | -34.1% | -9.0% |

