# Decision-grading report — cell-e-1998-sleeve020

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 1053 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 295 | +15.5% | +4.1% | 35% | 24% | -4.1% | -0.31 |
| stage3_force_exit | 17 | +1.6% | +33.0% | 24% | 24% | -33.0% | -1.31 |
| stop_loss | 739 | -1.1% | +6.9% | 34% | 32% | -6.9% | -2.68 |
| unlabeled | 2 | +26.3% | -13.8% | 50% | 50% | +13.8% | 0.54 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 295 | -16.7% | +20.6% | -23.8% | +33.3% | 31% |
| stage3_force_exit | 17 | -21.2% | +285.7% | -15.0% | +35.9% | 59% |
| stop_loss | 739 | -19.6% | +33.6% | -29.4% | +40.2% | 37% |
| unlabeled | 2 | -32.6% | +13.6% | -42.6% | +15.1% | 50% |
