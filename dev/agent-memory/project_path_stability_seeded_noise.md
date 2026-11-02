---
name: project_path_stability_seeded_noise
description: 10-24 path-stability (#3404, PR #3419): seeded tie order = 12.6× alphabetical path noise (SD ln 0.21 on 6y top-3000); SR/SC fail as stabilisers; Seeded default APPROVED by user 10-25 (flip PR pending)
metadata:
  type: project
---

Chain 2019–2024 top-3000 pit-v12, record N, 4 arms × K=6 (seeds + one minor-name deletion), build 3db869d32, all V6-clean.
- spread SD ln(1+R): A (alphabetical) 0.017, S (Seeded) 0.211, SR (resize 0.5) 0.209, SC (cap 0.07) 0.121. Medians A 0.976, S 1.031, SR 0.976, SC 0.626.
- Yardstick verdict: alphabetical FREEZES one draw (doesn't shift level; A-p0 inside S's range). Seeded default = correctness fix, APPROVED by user 2026-10-25; flipped (#3425); 26y K-seed band measured 10-28 ([[project-record-kseed-band]]): SD 0.225.
- SR does not stabilise; SC fails do-no-harm (tails pay ~half, names don't double).
- **Why:** window return = 3 tail trades (ADMA, APPS, GLNG) + open MMYT. Gate 1: top-20 cut lands inside a score tie group (binds every week; 91 % of slots then No_structural_stop). Gate 2: cash at placement.
- Defects found: V12/stop_fill_distance split-basis mix; V13 counts delisting exits; cash_rejection `available` = gross cash.

**How to apply:** measure lever noise with K≥5 seeds, paired by seed (paired SD 0.11–0.15). A single cell is one draw. Contradicts [[project_screener_alphabetical_tiebreak]]; refines [[project_26y_path_noise_floor]]. Follow-up arm: [[project_floor_and_refresh_screens]] (floor-nearest #3418 running 10-25).
