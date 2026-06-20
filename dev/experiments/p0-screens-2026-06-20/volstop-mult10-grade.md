# Decision-grading report — cell-e-1998-volstop-mult10

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 951 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 289 | +19.3% | +6.4% | 40% | 23% | -6.4% | -0.63 |
| stage3_force_exit | 13 | -1.5% | +42.9% | 31% | 23% | -42.9% | -4.29 |
| stop_loss | 643 | -2.7% | +16.2% | 37% | 32% | -16.2% | -2.57 |
| unlabeled | 6 | -0.6% | +3.7% | 17% | 0% | -3.7% | -0.17 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 289 | -15.9% | +23.2% | -24.4% | +35.0% | 25% |
| stage3_force_exit | 13 | -26.1% | +363.1% | -15.3% | +34.1% | 62% |
| stop_loss | 643 | -19.9% | +268.3% | -29.4% | +41.3% | 37% |
| unlabeled | 6 | -13.0% | +14.7% | -3.7% | +28.2% | 17% |
