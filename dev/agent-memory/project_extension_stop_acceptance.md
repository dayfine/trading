---
name: extension-stop-acceptance
description: "extension_stop (2.0x/25%) armed-vs-off record pair — banks all 8 parabolic tops incl AXTI +5196%/$59M; Sharpe .68→.82, MaxDD 40.9→32.3; combo with MA-gate additive"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7df7c106-7818-4bd3-9908-c008f4c7d09e
---

**2026-07-13 armed-run matrix on the dedup-v2 warehouse** (base = deduped 28y
honest-tradeable, `dev/notes/dedup-record-rerun-2026-07-13.md`):

| run | MTM | realized | Sharpe | CAGR | MaxDD |
|---|---|---|---|---|---|
| baseline (off) | +3,407% | $10.4M | 0.68 | 14.4% | 40.9% |
| A: extension_stop 2.0×/25% | +7,455% | $66.8M | 0.82 | 17.7% | 32.3% |
| B: reject_declining_ma | +3,621% | $11.0M | 0.69 | 14.6% | 40.9% |
| D: both | +7,914% | $70.9M | 0.83 | 18.0% | 32.3% |

**extension_stop (#1934, insurance dial):** fired 8×/26y, EVERY firing banked a
parabolic top (+89% to +5,196%): AXTI 2026-05-30 $59.0M (vs riding $140→$70 to
a $24M mark), DDD Feb-2021 (its actual peak), BFX Nov-2020, dot-com era names
Mar-Apr 2000. Zero premature on-ramp kills observed (trigger 2.0×WMA30 only
arms parabolics; 25% trail survives shakeouts — screen-pinned values held).
Realized composition flips from mark-heavy ($10M realized/$25M mark) to banked
($67M realized/$9.5M mark). Left tail: MaxDD 40.9→32.3. CAVEAT: single-path,
AXTI = ~88% of the realized delta — but the insurance acceptance basis
(left-tail/event-level, NOT fold Sharpe; ~1% event rate) is exactly what this
was sanctioned under, and it passes every cell.

**declining-MA gate (#1775):** small consistent positive on this basis
(+213pp MTM, +$0.7M realized, DD unchanged, 3 entries removed incl. the AIR
2020 COVID-waterfall −33.5%); validator V8 goes 4→PASS when armed —
mechanism/validator cross-confirm. Effects of the two dials are ADDITIVE (D ≈
A + B deltas).

**ARMED 2026-07-14 (PR #1960)** — ledger insurance-ACCEPT
`2026-07-14-extension-stop-insurance-accept`; record-convention staged scenario
`staging-record-convention/top3000-2000-2026-record-convention.sexp` (Run-D
config) + live weekly-review arming via new `generate_weekly_snapshot
--config-overrides dev/weekly-picks/live-config-overrides.sexp`. Code defaults
stay no-op (R1). **sp500 robustness cell**: armed-vs-off on sp500-PIT-2000
2000-2026 = BIT-IDENTICAL (0 firings in 26y; Sharpe 0.685 both) — mechanism
engages only in the broad parabolic tail, do-no-harm elsewhere; not a
top-3000-specific harm artifact.
[[project_extension_stop_screen_no_build]] [[project_honest_tradeable_baseline]]
[[rename-twin-dedup-returns-basis]]
