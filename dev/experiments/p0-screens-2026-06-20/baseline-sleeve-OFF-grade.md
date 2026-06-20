# Decision-grading report — cell-e-top3000-1998-longshort

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 1164 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 312 | +16.2% | +5.2% | 38% | 22% | -5.2% | -1.03 |
| stage3_force_exit | 19 | -1.1% | -3.7% | 21% | 32% | +3.7% | -1.33 |
| stop_loss | 828 | -1.2% | +13.1% | 35% | 32% | -13.1% | -2.78 |
| unlabeled | 5 | +45.4% | +2.2% | 40% | 20% | -2.2% | 0.49 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 312 | -15.7% | +20.8% | -22.9% | +28.8% | 27% |
| stage3_force_exit | 19 | -22.7% | +19.0% | -17.6% | +11.3% | 53% |
| stop_loss | 828 | -20.0% | +38.4% | -30.7% | +42.2% | 38% |
| unlabeled | 5 | -16.1% | +23.0% | -17.3% | +22.5% | 20% |
