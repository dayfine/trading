# Decision-grading report — cell-e-1998-sleeve030

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 904 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 240 | +17.8% | +4.6% | 36% | 21% | -4.6% | -0.73 |
| stage3_force_exit | 10 | -1.0% | -4.3% | 20% | 40% | +4.3% | -0.93 |
| stop_loss | 652 | -1.9% | +15.8% | 36% | 31% | -15.8% | -2.17 |
| unlabeled | 2 | -6.6% | -0.2% | 50% | 50% | +0.2% | -3.34 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 240 | -16.1% | +20.1% | -22.0% | +29.4% | 28% |
| stage3_force_exit | 10 | -20.2% | +18.7% | -17.6% | +13.8% | 50% |
| stop_loss | 652 | -20.4% | +43.5% | -30.3% | +41.3% | 38% |
| unlabeled | 2 | -16.8% | +16.3% | -21.1% | +20.6% | 50% |
