# QC Review History: portfolio-stops

## Current status: IN_PROGRESS — no valid QC review

order_gen has not yet been correctly implemented. Two prior implementations were closed:
- PR #203 (2026-04-06): order_gen in `analysis/weinstein/`, took screener candidates + did sizing — wrong
- PR #214 (2026-04-07): same mistake repeated — closed

See `dev/decisions.md` §"order_gen — correct design" for the spec.
See `dev/status/portfolio-stops.md` for next steps.

---

## Prior review records (superseded)

### 2026-04-05 — NEEDS_REWORK (branch: portfolio-stops/trading-state-sexp)

Reviewed a stale/wrong branch. That branch's work has since been merged to main. Review no longer applicable.

### 2026-04-07 — APPROVED (branch: feat/portfolio-stops-order-gen, PR #214) — VOID

Both structural and behavioral QC returned APPROVED, but the implementation was subsequently
identified as repeating the same design mistake as PR #203: order_gen was in `analysis/weinstein/`
(wrong location), took screener candidates (wrong input), and made sizing decisions (wrong
responsibility). PR #214 was closed. This APPROVED verdict is void.
