---
name: split-safe-resistance-basis
description: Split-blind resistance grades fixed hash-gated (#2145); blast-radius grid COMPLETE (broad path/folds + sp500 cell); migrator #2153; open = user R3 record re-pin + bundle-vs-alts margin + split-safe floors A2 decision
metadata: 
  node_type: memory
  type: project
  originSessionId: 3f2dbf6c-5e5e-4297-9d15-8571a3c1ccb4
---

Resistance supply machinery measured RAW prices while warehouses store raw
OHLC + separate Adjusted_close — splits inside the 520w lookback mis-scaled
overhead. Fix #2145 (hash-gated: new adjusted hash `128e4c1e…`, old kept as
`format_hash_raw_basis`, reader anchors per-hash). Live picks regraded 07-24 v4
(CLMB out, PH in).

**Blast radius MEASURED (2026-07-28, ledger `split-basis-blast-radius`):**
record-convention 26.5y on v5thin, raw control vs split-safe clone, pinned
worktree @9f50de9. Control reproduced the record (+8,689%/30.3 DD/1,172 tr).
Honest: **+8,367% / MaxDD 37.1 / 1,122 tr** → return flattering mild (−3.7%
rel), **MaxDD flattered 6.8pp**. Entry churn broad (~190/~140 symbol swap at
cap-20 boundary); AXTI monster intact ($64.1M). Memo
`dev/notes/split-basis-blast-radius-2026-07-28.md`.

**Tool:** `rebuild_weekly_sidetables.exe` (PR #2153) — clones any warehouse
split-safe in ~4 min. Two traps it solves: (1) `.snap` lacks the 3650d deep
prefix (re-read from CSV store); (2) CSV adjusted basis drifts off the
warehouse basis on every refetch (EODHD whole-history rebase; re-pin by median
snap/CSV ratio, tol 1e-3 over 4dp rounding noise). 14/2908 symbols =
revision-class raw restatements (HON etc.) → snap-only fallback; LH/ONTO
skeleton drift.

**Fold-level re-cert DONE (2026-07-29, ledger `split-basis-fold-recert`):**
honest 13×2y broad baseline = **.765/28.49/15.93** (vs split-blind
.827/36.17/14.05); no-op variant bit-identical 13/13. **Fold baseline of
record is now .765 on the adjusted clone — never compare new experiments
to .827.** (Honest .765 ≈ contaminated 07-26 .766 = pure coincidence.)

**sp500 cell (07-29, ledger `split-basis-sp500-cell`):** raw +1,477/DD 30.5
vs honest +1,290/DD 28.8 — return flattering LARGER rel (−12.6%) but DD
IMPROVES: DD-flattering = broad marginal-cohort effect, not universal. Grid
complete.

**Still open:** (1) record-of-record re-pin = user R3 (path + fold + sp500
cell inputs in); (2) bundle-vs-ALTERNATIVES honest margin never measured
(pre-bundle/w15/floors arms on adjusted clone, ~7-8h grid, only if R3 wants
it); (3) older v2/v4 warehouses still raw-basis (migrate on demand); (4)
split-safe floors A2 decision (feed corrected lows from caller vs shared-lib
move — wick-vs-close knob itself SHIPPED #2167 default-Wick; before Close
ever defaults on, fix stop_recompute's Wick-only `stop_is_structural`, see
support-floor-stops.md follow-ups); (5) ~30 historical picks basis-suspect
(`split_in_window`); (6) #2158 entry order-type three-layer alignment
(Phase 1 holds on user size-on-cap decision).

07-29 session also shipped: #2165 Snapshot_validator wired into
generate_weekly_snapshot (warn-first, `-validate-strict`) — Friday runs
self-check (#2122 slice a).

Ops law: weekly warehouse rebuild = full non-incremental `build_snapshots.exe`
with Pinned superset universe (picks + 15 context syms), grammar
`(Pinned ( ((symbol X) (sector "S")) ... ))`. [[leverage-dawn-drift-root-cause]]
