---
name: project-true-dollar-gate-chain-w
description: "Chain-w 11-12 (#3605): true_dollar_volume gate moves ~1 % of decisions, own P&L ~0, no list rebuild needed (#3136); td-full shadows 650 bar files (fix before any flag-on run)"
metadata:
  node_type: memory
  type: project
  originSessionId: 249246cf-fc3d-457f-8536-5d3b905a45a5
  modified: 2026-11-14T07:23:18.661Z
---

Chain-w (pre-reg #3571, results #3584, read #3605), cloud, W0 vs Wtd (`true_dollar_volume` off/on), 26y top-3000
pit-v12 seed 0. T1 V6 exit 0; T3 PASS: first differing id is CVM 2000-02-04 (divisor 1/7,500, stored ADV fails $1M,
true passes). Gate-level changes: 6 blocked→admitted (all reverse-splitters near $1M: CVM, SVRA, HAFC, VHI, VHC,
MAXN), 1 admitted→blocked (AVD 2005), 1 hold exit (PENN 2000, the only liquidity_exit) = ~1 % of placed decisions,
vs the 10-19 note's 2.5 % of member-weeks. Gate's own trades net −0.03 % NAV (removing any one of CVM, VHC, MAXN or HAFC flips the sign).
Level −0.055 log (0.25 band SD) is displacement, 84 % one trade (OPSW 2007 takeover, W0 only). **Decision recorded:
no list or warehouse rebuild for the gate basis (#3136).** Default flip is a separate correctness PR, not a returns
case; K=5 not worth ~22 h/arm.

**Defect D1 (must fix before any flag-on run or V7/V13 comparison):** chain td-full step 2 copies the 650 committed
`trading/test_data` short `data.csv` files (2009+) over the full store, so the divisor misses splits for 300 symbols
(AAPL F 28 vs 112) and the validator's V13 39 / V7 36 vs record 24 / 21 are artifacts. A standard run tree has no
full `data.csv` at all, so the flag is inert for ~11,200 symbols there.

#3183 M1–M4: symbol-class filter drops 0–15 names per vintage (21 distinct: warrants, units, 4 curated non-USD), none
in 2022-25; rk-k0 traded none of them. Non-curated foreign names (VNTR, RICO, CMIG3…) still outrank AAPL/AMZN in some
lists. #3109 did not run (PREREQ_MISSING). W0 ≠ record (#3475 dedupe + #3483 fill order), V6-equal.

Related: [[project_26y_path_noise_floor]], [[project_record_kseed_band]], [[project_edge_is_the_fat_tail]].
