## Segmentation vs MaSlope walk-forward A/B (2026-05-11)

### Background

The 2026-05-10 overnight Segmentation vs MaSlope A/B on a single 15y window (2010-2024) showed a +11pp return delta and a Sharpe +0.02 difference — not enough signal on one window to promote Segmentation as the default stage classifier. This note repeats the comparison across **7 rolling 5y windows** on the new 0.14/exp0.70 Cell E default, to determine whether Segmentation's edge is durable or window-specific.

### Method

7 scenarios mirror the post-sweep rolling 5y winner (`dev/experiments/rolling-5y-cell-e-0.14-exp0.70-2026-05-11/scenarios/cell-e-5y-*.sexp`) with one override added:

```
((stage_config ((stage_method Segmentation))))
```

Stage3 force-exit (h=1), laggard rotation (h=2), and position sizing (0.14/0.70/0.30) are identical to the MaSlope baseline. Both runs use the 510-symbol SP500 historical universe.

Source: `dev/experiments/rolling-5y-segmentation-ab-2026-05-11/`. Wall: 1,475s (24 min) for 7 windows.

### Results

| Window | MaSlope Ret | Seg Ret | Δ Ret | MaSlope Sharpe | Seg Sharpe | Δ Sharpe | MaSlope DD | Seg DD |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2011-01 |  52.7% |  88.2% | **+35.5** | 0.71 | 0.97 | +0.26 | 16.3% | 24.0% |
| 2012-07 | 110.4% | 119.5% |  +9.1 | 1.23 | 1.28 | +0.05 | 14.5% | 16.9% |
| 2014-01 |  63.9% |  62.3% |  -1.6 | 0.81 | 0.69 | -0.12 | 13.0% | 22.6% |
| 2015-07 |  81.1% |  41.0% | **-40.1** | 0.93 | 0.50 | -0.43 | 21.7% | 17.4% |
| 2017-01 |  72.2% | 112.2% | **+40.0** | 1.09 | 0.99 | -0.10 |  8.5% | 14.1% |
| 2018-07 |  12.3% |  25.0% | +12.7 | 0.25 | 0.34 | +0.09 | 20.6% | 25.0% |
| 2020-01 |  12.5% |   4.7% |  -7.8 | 0.23 | 0.14 | -0.09 | 24.9% | 35.7% |

### Summary stats

| Metric | MaSlope | Segmentation | Δ |
|---|---:|---:|---:|
| Geom-mean 5y return | 41.7% | 49.4% | **+18% relative** |
| Avg Sharpe | 0.75 | 0.70 | **-7% relative** |
| Avg WR | 37.4% | 34.8% | -2.6pp |
| Avg MaxDD | 17.1% | 22.2% | +5.1pp |
| Avg trades | 256 | 256 | ≈0 |
| Wins on return | — | 4 of 7 | mixed |
| Wins on Sharpe | — | 3 of 7 | MaSlope edge |

### Verdict — DO NOT promote Segmentation

Segmentation delivers higher geom-mean return (+18% relative) but at a worse risk-adjusted profile across the panel:
- **Sharpe regresses** in 4 of 7 windows; geom-mean Sharpe drops -7%
- **DD is worse** in 5 of 7 windows; avg DD widens 5.1pp
- **WR is worse** in 5 of 7 windows
- **Two windows show large return swings**: 2015-07 (-40pp Seg loss) and 2017-01 (+40pp Seg win) — Segmentation amplifies regime-dependence rather than smoothing it

The single 15y headline (Seg +11pp vs MaSlope) was driven by a small number of windows (notably 2011-01 +35pp, 2017-01 +40pp). The averaging effect of the full 15y run masks the regime-dependent volatility that the rolling 5y panel exposes.

### Implications

1. **Keep MaSlope as the default stage classifier.** Segmentation's higher mean return is offset by worse Sharpe, DD, and WR. Promotion would trade a known regime-robust classifier for a higher-variance one, with no improvement in risk-adjusted terms.
2. **Segmentation is interesting in specific regimes.** Wins concentrated in 2011-01 (post-GFC recovery) and 2017-01 (steady bull) — i.e. clean trending regimes. Losses concentrated in 2015-07 and 2020-01 — choppy/whipsaw regimes. A *regime-conditional* classifier choice (Segmentation in clear trends, MaSlope in chop) could be worth exploring as a Cell-F feature, but is out of scope here.
3. **Headline-window selection bias is real.** The 2010-2024 15y window happened to capture more of Segmentation's winning regimes than losing ones. Future classifier-promotion decisions should require the rolling 5y panel evidence, not single-window headlines.

### Numbers to retire

- The overnight note's recommendation "If A/B Segmentation completes overnight, compare against the MaSlope baseline" is now closed: comparison done, Segmentation does not earn promotion.
- The previous summary on 2026-05-10 ("Segmentation is marginally better but not a differentiator") is **partially superseded** — it understated the return delta on the 15y window but correctly identified Segmentation as not durable enough to default to.
