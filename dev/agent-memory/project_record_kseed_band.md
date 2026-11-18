---
name: project-record-kseed-band
description: K=5 Seeded band #3467 (median 2.78, SD 0.225) carried the #3664 basis-mix look-ahead; one-basis band (vsb-1) median 2.48, SD 0.20 becomes the record at the flip; 26y verdicts need K>=5 paired per seed
metadata:
  type: project
---
`dev/experiments/record-kseed-2026-10-27/` (run tree fc78391dd, top-3000 PIT v12, 2000-01 → 2026-06, seeds k0-k4,
V6 = 0 everywhere). Supersedes N (`breadth-fix-rb1`) as the record.
- Per seed total return: k0 +1,313 % (default config), k1 +2,219, k2 +1,515, k3 +1,193, k4 +1,649. Median ln 2.7819
  (CAGR 11.07 %), SD 0.2254; median max DD 26.1 %, Sharpe 0.63. SPY TR +706 % (ln 2.087).
- 26y SD ≈ 6y SD (0.21): spread comes from a few large tie-cut tails (ADMA 2023-08-18 in k1/k2/k4 = 0.30 of entry NAV;
  GLNG cut by seed 2; CVNA only k0), not window length. Same gate-1 draws recur at the same seeds as in the 6y chain.
- Exposure is identical across seeds (56-57 %); the spread is which names ride.
- Old N (2.25) below every seed = the build change #3266 measured (Alphabetical M = 2.786, mid-band), not Seeded.
- Run lists are #3391's (CMN dropped), not N's; the chain comment claiming "same lists" is wrong and its md5 is unchecked.

**Why:** gate 1 (tie cut at the binding top-20) + gate 2 (cash at placement) re-draw the tails
([[project_path_stability_seeded_noise]], [[project_edge_is_the_fat_tail]]).
**How to apply:** every 26y lever read on the record config runs k0-k4, read paired per seed (~22 h per arm). Single
cell floor ≈ 0.45 log (2 SD), refining [[project-26y-path-noise-floor]]. #3388 twin dedupe measured 2026-10-31 (PR #3489, K=3 seeds k0-k2): mean d -0.022 log = 0.10 band SD, inside noise; deduped lists are the record universe; re-measure the band on them at the next re-baseline (dd k3,k4 only if the tree has not moved the record path). Any run after 11-01 differs from rk-k* for two reasons, not td-full (chain-w #3584 parity trace 11-13): #3475 dedupe (universe 9,222 to 9,185, first change PRMB 2004-05-28) and #3483 same-day fill order (insertion order; DWSN1 vs BRC 2006-05-30). k0 at current main is +1,472.6-1,472.8 %, 576 trades, ln 2.756. The price-band S arms (11-13, 1034b458e, k0-k4) are the first K=5 band on the deduped lists.
Pack defects to fix: stage replay only for first run; missed-winners "rode"; seeds labelled arms.

**Superseded at the #3664 flip (vsb-1, 11-17, PR #3671).** The 2.78 band carried the virgin/supply basis-mix look-ahead. vsb-1 (One_basis, 96cacbe20, k0-k4) ln 2.546, 2.531, 2.332, 2.070, 2.481: median 2.481, SD 0.20, median maxDD 31.9 % (S at that HEAD: 2.755, 2.878, 2.664, 2.580, 2.856, maxDD 25.6 %). USER 11-17 chose flip-on-correctness: vsb-1's cells are the record band from the flip HEAD on; pre-flip observatory rows stay mixed-basis reads.
