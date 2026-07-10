---
name: project_honest_tradeable_baseline
description: "Honest-tradeable deep baseline 2026-07-10 (overlay 1e6/5e5 + stale-exit 5d armed): +6889.6% MTM / realized ≈+1600% (~11.4%/yr) — FIRST deep path where realized beats TR-SPY (8.15%); Sharpe .806, DD 40.6, Ulcer 15; overlay = QUALITY filter, gradual sign-stable 3.2× vs un-armed"
metadata: 
  node_type: memory
  type: project
  originSessionId: dbeb7536-3c56-4212-a532-4c2daa8dfc4b
---

`dev/notes/honest-tradeable-baseline-2026-07-10.md` + DEEP_RESULTS ⭐ row.
top3000-2000-2026-catstop (0.14/catstop-0.10, 364 basis, merged main incl.
#1906 pairing fix + #1910 floor-off) with realism dials ARMED:
`liquidity_config (min_entry 1e6 / min_hold 5e5)` + `stale_exit_after_days 5`.

- **+6889.6% MTM / realized ≈ $17.0M ≈ +1600% (~11.4%/yr) vs SPY-TR 8.15%/yr
  — realized beats the index for the first time on a deep path.** Sharpe
  0.417→0.806, MaxDD 40.6 (real), Ulcer 26.5→15.0.
- **WHY (decomposed, not luck):** armed/un-armed year-end ratio grows
  GRADUALLY and sign-stable (1.0→1.2→2.15 by 2008→3.2 by 2026; one
  convergence year). Overlay = QUALITY filter: fake wins gated (APPB), zombie
  capital recycled (IN1 $143k dead 20y), corrupt-bar names excluded; freed
  capital compounds in liquid names where ALL real fat-tail winners live
  (re-derives [[project_trade_realism_liquidity]] from a new angle).
- **Caveats:** single path (fold-proof next step = WF-CV/rolling-start with
  `liquidity_config.min_entry_dollar_adv {0,1e6}` axis); terminal MTM still
  AXTI ($51.7M of $66.8M OPV); overlay+stale-exit stay default-off — arming
  is a MEASUREMENT convention for record runs (like TOTAL-RETURN
  comparators), not a promoted default.
- Supersedes the un-armed topline in [[project_deep_topline_364]] as the
  number of record.
