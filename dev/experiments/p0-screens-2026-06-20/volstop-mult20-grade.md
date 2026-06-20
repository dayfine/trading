# Decision-grading report — cell-e-1998-volstop-mult20

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 735 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 246 | +14.5% | +227.2% | 39% | 22% | -227.2% | -1.97 |
| stage3_force_exit | 19 | -2.5% | +0.1% | 37% | 21% | -0.1% | -1.97 |
| stop_loss | 465 | -3.8% | +23.1% | 38% | 26% | -23.1% | -2.38 |
| unlabeled | 5 | -7.7% | -17.8% | 20% | 80% | +17.8% | -2.52 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 246 | -14.8% | +242.6% | -21.1% | +36.0% | 27% |
| stage3_force_exit | 19 | -22.1% | +25.1% | -35.0% | +22.0% | 37% |
| stop_loss | 465 | -19.2% | +218.4% | -27.9% | +41.6% | 34% |
| unlabeled | 5 | -32.6% | +19.6% | -38.7% | +10.9% | 100% |
