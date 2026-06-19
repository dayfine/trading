# Decision-grading report — cell-e-top3000-2011-wclose

Period: 2011-01-01 .. 2026-04-30 | round-trips graded: 566 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 212 | +12.4% | +1.3% | 27% | 25% | -1.3% | -0.15 |
| stage3_force_exit | 16 | -0.2% | +2.0% | 31% | 25% | -2.0% | -1.39 |
| stop_loss | 334 | -5.3% | +11.9% | 40% | 28% | -11.9% | -8.40 |
| unlabeled | 4 | -6.3% | +14.8% | 50% | 25% | -14.8% | -3.24 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 212 | -16.7% | +17.5% | -23.5% | +21.9% | 29% |
| stage3_force_exit | 16 | -19.6% | +13.2% | -15.0% | +18.1% | 50% |
| stop_loss | 334 | -12.8% | +37.0% | -23.8% | +36.8% | 36% |
| unlabeled | 4 | -17.0% | +42.1% | -39.8% | +61.6% | 25% |
