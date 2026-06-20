# Decision-grading report — cell-e-top3000-1998-deep

Period: 1998-01-01 .. 2026-04-30 | round-trips graded: 1061 | grade horizon: 26w

Net value-add = realized − counterfactual-if-held (positive = the exits helped). % premature = gave up a winner; % good exit = dodged a drop.

### Exit value vs hold-counterfactual

| exit_reason | n | mean realized | mean post-exit cont. | % premature | % good exit | mean net value-add | mean capture |
|---|---|---|---|---|---|---|---|
| laggard_rotation | 296 | +16.9% | +4.7% | 36% | 27% | -4.7% | -0.68 |
| stage3_force_exit | 16 | +0.1% | -2.2% | 12% | 19% | +2.2% | -4.48 |
| stop_loss | 746 | -1.2% | +6.2% | 36% | 30% | -6.2% | -3.64 |
| unlabeled | 3 | -3.9% | +5.0% | 33% | 33% | -5.0% | -15.87 |

### Disaster-avoidance vs upside-foregone (the insurance decomposition)

| exit_reason | n | mean disaster dodged | mean upside foregone | cont p10 | cont p90 | disaster-dodge rate |
|---|---|---|---|---|---|---|
| laggard_rotation | 296 | -15.9% | +21.6% | -26.9% | +36.0% | 29% |
| stage3_force_exit | 16 | -22.0% | +14.0% | -15.0% | +11.3% | 38% |
| stop_loss | 746 | -19.5% | +29.9% | -29.5% | +41.4% | 36% |
| unlabeled | 3 | -11.2% | +19.7% | -14.0% | +28.2% | 0% |
