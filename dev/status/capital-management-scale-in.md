# capital-management-scale-in

Explore/exploit scale-in — the **reallocation** capital-management lever (P1
capacity/concentration frontier). Design: `dev/plans/capital-management-scale-in-2026-07-02.md`
(#1829). A 4-PR build; PRs 1–3 merged, PR 4 (runner + wiring) pending.

## Status
IN_PROGRESS

## Last updated: 2026-07-03

## Interface stable
NO

## Ownership
dayfine (maintainer, LOCAL sessions). Orchestrator QCs + merges the PRs as they land.

## Completed
- PR 1 (#1830) — `Fill_router` extraction (side-aware fill routing). MERGED.
- PR 2 (#1831) — `Stops_runner` advances the shared per-ticker Weinstein stop
  state machine **once per tick** via a per-`update` memo/replay
  (`Stop_transitions`), so scale-in siblings on one ticker don't double-advance.
  Bit-identical today (one position per ticker). QC APPROVED (structural + behavioral 4/5),
  3-gate auto-merged this run.
- PR 3 (#1832) — pure `Scale_in_detector` (pullback-hold / early-new-high / extension-gate
  predicates) + **default-off** config (`enable_scale_in=false`, `initial_entry_fraction=1.0`).
  No-behavior-change land; nothing consumes the flag yet. Faithful Weinstein ½+½
  "Trader's Way" dial (W1/W2 PASS). experiment-flag-discipline R1/R2 PASS. QC APPROVED
  (structural + behavioral 4/5), 3-gate auto-merged this run.

## Next Steps
- PR 4 — the scale-in runner: wire `enable_scale_in` + `Scale_in_detector` into
  `on_market_close` (grow a held position via the missing `Holding → larger Holding`
  transition), consuming PRs 1–3. Then it becomes a searchable axis; promotion needs a
  ledger ACCEPT + confirmation grid (default stays off until then).
- Non-blocking QC notes carried for PR 4: (a) plan §5 lists `max_adds` no-op default `0` but
  the impl defaults `1` (behaviorally inert while default-off) — reconcile when wiring;
  (b) `early_new_high`'s ≥2-bar / above-entry clauses are pinned only transitively.

## Blocked on
None between tracks. PR 4 is maintainer-LOCAL work (in-flight build).
