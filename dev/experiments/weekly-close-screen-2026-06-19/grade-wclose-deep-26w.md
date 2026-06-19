# Decision-grading report — cell-e-top3000-1998-deep-wclose

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 831 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 307 | +18.3% | +3.2% | 33% | 24% | -3.2% | -0.40 |
| stage3_force_exit | 24 | -1.8% | +27.5% | 46% | 25% | -27.5% | -1.72 |
| stop_loss | 496 | -2.7% | +7.3% | 37% | 32% | -7.3% | -3.49 |
| unlabeled | 4 | +0.3% | +4.0% | 25% | 25% | -4.0% | -3.03 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 307 | -15.8% | +19.6% | -22.9% | +28.1% | 27% |
| stage3_force_exit | 24 | -22.4% | +210.0% | -17.6% | +23.7% | 42% |
| stop_loss | 496 | -19.5% | +32.8% | -26.9% | +46.1% | 38% |
| unlabeled | 4 | -21.1% | +38.1% | -38.4% | +69.6% | 50% |
