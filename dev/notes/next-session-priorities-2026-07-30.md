# Next-session priorities — 2026-07-30

**Supersedes** `next-session-priorities-2026-07-29.md`. That doc's P0 decisions
were made by the user 2026-07-29 evening and executed same-session:

- **R3 record re-pin: option (a) EXECUTED (#2170).** Record-of-record is now
  the split-safe basis: **+8,366.8% / MaxDD 37.1 / 1,122 tr / 37.7% win**;
  split-blind row kept as superseded. README deep-headline regenerated from
  the sexp. Grid evidence: broad path + broad folds (.765) + sp500 cell
  (ledgers `2026-07-28-split-basis-blast-radius`, `-fold-recert`,
  `-sp500-cell`). NOT re-certified: the bundle's *relative* promotion margin
  on the honest basis (noted in DEEP_RESULTS).
- **#2158 Phase 1 MERGED (#2171), size-on-cap per user decision.** One
  do-not-chase cap `E × (1 ± entry_extension_max_pct/100)` across live
  order-gen (`StopLimit(E, cap)`, default 0.0 = legacy byte-identical),
  report tickets (STOPLIMIT both prices; Through_entry → LIMIT at ~close),
  chart cap line, sizing on the cap. Phase 2 (simulator fill model) remains a
  gated experiment — never bundle.
- Also shipped 07-29: **#2165** validator wired into the generator
  (warn-first + `-validate-strict`), **#2167** support-floor `Wick|Close`
  anchoring knob (default Wick), **#2168** follow-ups doc, **#2172
  orchestrator cron cut 8 → 2 slots/day** (user quota directive — watch for
  drift: `dev/daily/<date>-runN.md` with N>2 means it crept back), remote
  branch sweep (192 deleted; 199 → ~5).

## P0 — Friday live run (07-31)

First weekly picks on fully honest machinery + the new entry-cap tickets.
Recipe pinned in `project_split_safe_resistance_basis` memory: fetch → full
non-incremental weekly-review rebuild (Pinned superset universe = picks + 15
context syms) → generate with live overrides (generator now self-validates
warn-first per #2165 — read the validator block; consider `-validate-strict`)
→ `validate_weekly_snapshot.exe` (validation is part of the record, v4
convention) → render. NEW this week: tickets print STOPLIMIT trigger+limit and
size on the cap; arm `entry_extension_max_pct` in live overrides for the cap
to be non-degenerate.

## P1

- **Bundle-vs-alternatives honest margin** (~7-8h grid: pre-bundle / w15 /
  floors arms on the adjusted clone) — the one open caveat on the re-pinned
  record. User call whether to spend it.
- **stop_recompute Wick-only `stop_is_structural`** (qc-behavioral on #2167)
  — must fix before `Close` anchoring is ever promoted default-on. Tracked in
  `dev/status/support-floor-stops.md` follow-ups.
- **Split-safe floors A2 decision** — feed corrected lows from caller vs move
  `Adjusted_basis` to a shared lib (same follow-ups section).
- **`entry_reconciliation.mli` stale "market order" prose** (qc-behavioral on
  #2171, non-blocking) — one-line cleanup on next touch.
- Two orchestrator PRs open at handoff: #2166 (adjusted-basis rescale sync
  pin), #2169 (atomic write_audit.sh) — its 2-slot loop owns them
  [non-blocking].

## P2 — carried (unchanged)

- #15 / #2083 remainder: arm returns-basis rename detection in live config +
  universe re-pin.
- #2122 slices (b) instruction identity, (c) reproducibility golden, (d)
  "N eligible beyond cap" visibility.
- Older v2/v4 warehouses raw-basis — migrate on demand with #2153 before any
  resistance-sensitive re-measure.
- Tax Phase 2; trader-preset audit; decision_audit Phase-2.

## Ops notes (this session)

- **CI has a separate `dune fmt (check only)` step** that is STRICTER than
  `devtools/checks/fmt_check.sh` (which passed while the fmt step failed on
  #2171). When fixing lint on a PR branch: run `dune fmt` in-container and
  commit ALL resulting churn — do not minimal-diff revert it.
- Nesting linter tripped on 2 of 3 feature PRs (#2165, #2171) — feat-agent
  briefs should require `dune runtest devtools/checks` (or at least the
  nesting linter) before push.
- Local/GHA double-dispatch collision observed: orchestrator picked up #2122
  slice (a) the same morning it was dispatched locally (#2161 closed as dup of
  #2165). Fence local in-flight work in the track file per
  `gha-local-coordination.md`.
