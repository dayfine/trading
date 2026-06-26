Reviewed SHA: aac9c28337260cf09a301aefef1f975c1348f7c7

# QC Review — PR #1753 (feat/concentration-0.30-goldens)

PR: #1753 — feat(goldens): promote concentration 0.14 → 0.30 (long-only goldens)
Author: dayfine (maintainer-opened, ready-for-review)
Reviewed by: lead-orchestrator QC pipeline (GHA run 28212309813), 2026-06-26.
overall_qc: APPROVED

## Structural QC (qc-structural — APPROVED, quality 5)

Hard gates (via dev/lib/run-in-env.sh, in isolated worktree):
- H1 `dune build @fmt` → exit 0
- H2 `dune build` → exit 0
- H3 `dune runtest` → exit 0 (303 OK checks)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt (format check) | PASS | All .ml/.mli correctly formatted. |
| H2 | dune build | PASS | Full project build succeeds. |
| H3 | dune runtest | PASS | 303 OK checks; all goldens re-pinned correctly vs their stores. |
| P1 | Functions ≤ 50 lines | NA | No .ml/.mli modified; data (.sexp) + doc (.md) only. |
| P2 | No magic numbers | NA | No .ml/.mli modified; .sexp numeric bands are expected-value ranges. |
| P3 | Configurable thresholds in config record | NA | No .ml/.mli modified. |
| P4 | Public-symbol export hygiene | NA | No .ml/.mli modified. |
| P5 | Internal helpers prefixed | NA | No .ml/.mli modified. |
| P6 | Tests conform to test-patterns.md | NA | No test files modified; golden regression data + docs only. |
| A1 | Core module modifications (FLAG) | PASS | No core modules touched. |
| A2 | No new analysis/ imports outside allow-list | PASS | No dune files modified. |
| A3 | No unnecessary modifications to existing modules | PASS | Scope verified: 9 files (1 doc, 8 goldens), all intentional re-pins; no unrelated drift. |

Quality Score: 5 — Pure data re-pin backed by ledger ACCEPT + broad WF-CV; gates green, scope tight.
Verdict: APPROVED
GitHub review id: 4576274463

## Behavioral QC (qc-behavioral — APPROVED, quality 5)

Production-default finding: `max_position_pct_long` default = 0.30, confirmed at
`trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml:45`
(`let default_max_position_pct_long = 0.30`; `[@sexp.default ...]` on the config
field at line 56). The re-pin moves goldens UP from a 0.14 override toward
production — not a live-behavior change. Author claim #1 confirmed.

Verification scope:
- Independently verified: production default; all 8 golden diffs (config 0.14→0.30
  present in every file); band-vs-documented-table internal consistency for all 8
  (each band wraps its documented 0.30 actual within stated tolerance); pure-data
  change (8 .sexp + 1 .md, no code); none of the 8 in the PR-CI scenario smoke
  catalog (author claim #4 holds — green PR CI does not itself validate the values).
- 3 sp500 goldens: validators NOT re-run in-GHA (expensive — sp500-2010-2026 band
  300–3600s); verified by diff/band consistency; committed test_data CSV store present.
- 5 broad goldens: flagged author-verified / warehouse-gated, NOT independently
  reproducible in GHA (EODHD delisting-complete warehouse via --snapshot-dir absent).
  Honest NA-with-note.
- Ledger ACCEPT (2026-06-25-capacity-concentration-broad): cited, not re-derived
  (out of scope — verifying the re-pin reflects the authorized default, not re-running WF-CV).

Contract Pinning Checklist:
- CP1/CP3/CP4: NA (no code/.mli, no pass-through, no guard claims).
- CP2: PASS — all four author claims pinned/verifiable.
- Weinstein S*/L*/C*/T* block: all NA — regression-data re-pin, no
  stage/stop/screener/strategy code; spine untouched.

Quality Score: 5 — Clean pure-data re-pin; the docs note honestly documents the
regime-dependent per-window picture (incl. the two windows where 0.30 HURTS:
bull-crash 38→10%, six-year 19→4%) plus the store-resolution landmine.
Verdict: APPROVED
GitHub review id: 4576281891

Non-blocking follow-up: `goldens-small/*` smoke variants remain at 0.14 (PR note
§Scope, "lower priority"); a consistency follow-up could align them. Out of this
PR's long-only scope.
