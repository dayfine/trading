# Decision-grading report — cell-e-1998-volstop-mult15

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 813 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 269 | +16.8% | +4.1% | 36% | 24% | -4.1% | -3.27 |
| stage3_force_exit | 13 | -1.8% | +3.1% | 38% | 23% | -3.1% | -1.58 |
| stop_loss | 527 | -2.5% | +7.6% | 37% | 31% | -7.6% | -2.94 |
| unlabeled | 4 | -6.0% | +20.7% | 50% | 50% | -20.7% | -0.83 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 269 | -15.6% | +21.3% | -22.5% | +30.5% | 25% |
| stage3_force_exit | 13 | -19.4% | +19.6% | -14.4% | +22.0% | 38% |
| stop_loss | 527 | -20.5% | +183.2% | -30.4% | +44.0% | 39% |
| unlabeled | 4 | -18.5% | +41.9% | -29.6% | +97.7% | 25% |
