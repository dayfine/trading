---
name: project-axis-observatory-gate-funnel
description: Axis observatory plan (#3622, user 11-14): continuous paired runs read as D(t) curves; P1 = one 26y gate-funnel cell (pre-reg #3628) on the new candidate-log fields (#3625/#3626)
metadata:
  type: project
  modified: 2026-11-15T06:03:21.601Z
---
User 11-14: "keep running some axis combinations… to track the effects and discover where the opportunity is / analyze the effects of multiple layers of gates"; on noise: "the main thing is to have a continuous run and observe the trend over time". Plan `dev/plans/axis-observatory-2026-11-14.md` (#3622): read each arm as D(t) = ln(NAV_A/NAV_S) per seed over 2000–26 (slope = mechanism, step = lottery traced to trades, sign by regime); mechanical reader → public `surface.tsv` (aggregates) + private curves; analyst only on a pre-set flag (median D_end ≥ 0.20, yearly sign ≥ 60 % in ≥ 4/5 seeds, largest step < half); streams: baseline drift over commits, dial queue (main effects first, pairs only where both slope), forward weeks.

**P1 gate funnel (pre-reg #3628, `dev/experiments/gate-funnel-2026-11-15/`):** one S k0 26y cell with `--emit-candidates`. Built for it: #3625 (63a608151, pure `Entry_stop_check.evaluate` + walk report) and #3626 (917341665): rows carry `rank`, `walk`, `shadow` (Buyable/No_structural_stop/Stop_too_wide/Already_held; an UPPER bound, ignores entry-assembly gates); weeks carry `tickets_placed`, `long_cash_left_pct`, `long_resting_reserved_pct`. Free cash (G3 off) = left − reserved, floored 0 (same-Friday cancels still counted). Prior: CLOSE (09-22 top-N 40: slots/cash bind, not supply; [[project-top-n-capacity-verdict]]). Also re-tests score vs outcome after the #2380 RS fix (every earlier selection test had a constant RS term).

**Why:** endpoint verdicts reduce to which monster landed ([[project-26y-path-noise-floor]]).
**How to apply:** launch the cell from cloud routine `trig_01EGdsscqsgyTNNLHwbG7h5T` (disabled placeholder with both repos as sources) once #3628 merges; GF_SHA = that merge commit. Friday demo (#3623): `dune exec trading/weinstein/strategy/friday_demo/bin/friday_demo_main.exe` — synthetic one-Friday trace, prose built from config. Related: [[project-trait-y-low-price]], [[project-eodhd-terms-private-bucket]].
