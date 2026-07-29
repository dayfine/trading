# Next-session priorities — 2026-07-29

**Supersedes** `next-session-priorities-2026-07-28.md`. That doc's P0 (#2133
backtest blast radius, task #12) SHIPPED end-to-end this session:

- **Tool**: #2153 `rebuild_weekly_sidetables.exe` — clones any warehouse with
  split-safe side-tables (CSV deep-prefix re-feed + median-ratio basis
  re-pin). Both v5thin warehouses cloned (broad 2,894/2,908 clean, sp500
  516/521; refusals = genuine raw restatements, in `migration_report.sexp`).
- **Path-level blast radius** (ledger `2026-07-28-split-basis-blast-radius`,
  memo `split-basis-blast-radius-2026-07-28.md`, merged #2156): control
  reproduced the record exactly; honest = **+8,367% / MaxDD 37.1** vs
  +8,689 / 30.3 — return flattering mild, **risk number flattered 6.8pp**.
- **Fold-level re-cert** (ledger `2026-07-29-split-basis-fold-recert`):
  honest 13×2y broad baseline = **.765 / 28.49 / 15.93** vs split-blind
  .827 / 36.17 / 14.05. No-op variant bit-identical 13/13 (adjusted path
  deterministic). **This is the fold baseline of record now** — new
  experiments compare against .765 on the adjusted clone, never .827.
- DEEP_RESULTS carries the split-basis caveat on the record row. Issue #2158
  filed (entry order-type three-layer divergence). Overnight: sp500
  raw-vs-adj blast-radius arms running (`/tmp/sweeps/basis-sp500-*.log`).

## P0 — two user decisions + Friday run

1. **R3: record-of-record re-pin.** Inputs are in: honest path
   +8,367/37.1, honest folds .765/28.49/15.93, sp500 cell overnight.
   Options: (a) re-pin the record row + `deep_headline_records.sexp` to the
   honest numbers (README renders from it); (b) keep the raw row with the
   caveat until the bundle-vs-alternatives honest margin is measured. Note:
   the bundle's *relative* promotion margin was never re-run adjusted — if
   that margin matters for (a), it is a further comparison grid (pre-bundle /
   w15 / floors arms on the adjusted clone, ~7-8h).
2. **Friday live run (07-31)** — first weekly picks on fully honest
   machinery. Recipe pinned in `project_split_safe_resistance_basis` memory +
   07-28 priorities doc: fetch → full non-incremental weekly-review rebuild
   (Pinned superset universe = picks + 15 context syms) → generate with live
   overrides → `validate_weekly_snapshot.exe` → render; validation is part of
   the record (v4 convention).

## P1

- **#13 floor anchoring (wick vs close)** — `support_floor` anchors stops on
  intraday capitulation wicks (CLMB's $14.64 = Apr-30 wick −4% → 42.5% stop
  distance). Domain-rule change: book authority + default-off knob. Also make
  `support_floor` split-safe (raw lows) via the same `Adjusted_basis` helper.
- **#2122 slice (a)**: wire the validator into `generate_weekly_snapshot`
  warn-first so Friday runs self-check.
- **#2158 Phase 1** (live + report order alignment: `StopLimit(E, cap)`,
  `Through_entry` → limit @ close, cap line on charts, size-on-cap decision).
  Phase 2 (simulator fill model) is a gated experiment — never bundle.

## P2 — carried

- #15 / #2083 remainder: arm returns-basis rename detection in live config +
  universe re-pin.
- #2122 slices (b) instruction identity, (c) reproducibility golden, (d)
  "N eligible beyond cap" visibility.
- Older warehouses (v2/v4 dirs) still raw-basis — migrate on demand with the
  #2153 tool before any resistance-sensitive re-measure.
- Tax Phase 2; trader-preset audit; decision_audit Phase-2 (unchanged).

## Ops notes (this session)

- **Dune wedge recurred twice** (0%-CPU futex_wait, unreaped zombie
  ocamlopts; container had 806 zombies, PID 1 = `tail` never reaps).
  `docker restart trading-1-dev` cleared it — add to the wedge playbook:
  if pkill+rm-lock doesn't revive, restart the container (bind-mounts and
  /tmp warehouses survive restart; only recreation wipes them).
- `jj new main@origin` for a docs commit REMOVES feature-branch files from
  the shared working tree — anything (dune exec) depending on those sources
  breaks until the branch merges or you jj edit back. Sequence docs commits
  after feature-tree work, or run from a pinned worktree.
- Pinned-worktree runs: `.claude/worktrees/sweep-basis-blast` (@ 9f50de924)
  still holds the basis-recert spec + built runner; sp500 chain runs from
  it overnight. Clean up (`git worktree remove --force`) after the sp500
  results are archived.
- The migrator's first live run caught its own tolerance bug (82 false
  unstable flags at 1e-6 — EODHD 4dp rounding noise; fixed to median ratio
  @ 1e-3, regression-pinned by the `rounded rebase still stable` test).
