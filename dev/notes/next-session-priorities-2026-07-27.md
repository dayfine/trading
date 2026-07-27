# Next-session priorities — 2026-07-27

**Supersedes** `next-session-priorities-2026-07-26.md`. Since that doc: the
leverage-dawn surface COMPLETED and was adjudicated — **REJECT all 6 cells**
(ledger `2026-07-26-leverage-dawn-surface`, memo
`leverage-dawn-surface-results-2026-07-26.md`, PR #2102): Sharpe monotone
.766→.51 in dawn aggressiveness, the 2024 falsifier fired as predicted, even
fold-010 loses risk-adjusted. **The P1b regime program is CLOSED — no
surviving payload; regime-conditioned deployment intensity joins the reject
family.** Also: user chart-review of the 07-24 picks surfaced a THIRD
report defect (issue #2103, below) and the report artifact was upgraded to
the full Phase-C design spec (charts + reconciliation flags).

## P0 — picks Phase C: HTML report + entry reconciliation (#2103), one build

Combine into a single feat-weinstein program (they share the generator seam):

1. **Entry reconciliation (#2103) — the correctness half, do FIRST.**
   Classify each candidate close-vs-entry with config thresholds
   (`entry_through_band_pct`, `entry_extension_max_pct`): valid-stop
   (resting BUY STOP, as today) / through-entry (re-anchor ticket to market
   fill at current close, RE-SIZE on close-vs-structural-stop — mirrors the
   sim's `Entry_walk` fill) / EXTENDED (suppress ticket with do-not-chase
   reason, keep row for watch). Sizing ALWAYS on expected fill price. On
   the 07-24 list: 3 extended (CRNX +43.7%, MBX +34.5%, SAFT +26.0%), 6
   through-entry, 11 valid — the extended tickets mis-size real risk by up
   to 14×.
2. **Native HTML renderer with charts.** The committed design reference is
   `dev/notes/weekly-report-design-reference-2026-07-27.html` (the
   hand-built artifact page — replicate its structure): per-candidate SVG
   (~2y weekly closes ink line, 30-week MA blue, entry green dashed = the
   resistance/breakout line, stop rust dashed, last-close marker, collision-
   nudged right labels), card layout with tag chips (score / volume /
   earliness / resistance / structural-vs-fallback stop / reconciliation
   class), order-ticket line, drop-reasons section, TradingView link per
   symbol, shared legend, sizing + data-hygiene notes. OCaml exe (no-python)
   emitting a self-contained page beside the .md.

## P1

- **Baseline-drift integrity check** (from the leverage-dawn ledger): this
  run's baseline (.766/34.6/17.7) vs the M4 surface's (.827/36.2/14.1) on
  the same spec+warehouse; code 7ef57ed2→96c4c5f. Suspects: #2085
  (exit-visibility), #2081 (ADV aggregation). Bisect before any cached
  baseline is reused; if a merged "no-op" moved the record path, that is a
  parity break worth its own issue.
- ~~#2083-F2 rename tracking~~ **MERGED overnight** (#2100, returns-basis
  succession, default-off) — remaining: arm it in live overrides + universe
  re-pin (small follow-up).
- **User action carried:** real cash into `dev/weekly-picks/portfolio.sexp`.

## P2 — carried

Tax Phase 2 (parked); trader-preset audit; floor-quality P1b step 3;
decision_audit Phase-2.

## GHA watch
**Phase C is IN FLIGHT on GHA right now** (branch `feat/picks-phase-c`,
plan committed 2026-07-27 02:13Z, orchestrator run 30231043807) — do NOT
dispatch locally; watch for its PR, review against the design reference,
and verify #2103 reconciliation is included (comment posted on #2103).
If untouched by next session +1 cron slot, reclaim per takeover protocol.

The weekly-snapshot track file carries the P0 as `[non-blocking]`
Next-Steps — the orchestrator may land #2103 + Phase C before the next
local session (it shipped the whole prior bug queue overnight twice).
Check `gh pr list` + the track file before dispatching locally
(takeover protocol per gha-local-coordination).
