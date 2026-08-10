# Ladder v3 — faithful StopLimit scenario specs (2026-08-09)

Scenario specs for the ladder-v3 faithful-ticket A/B run. Committed for
reproducibility per `dev/plans/entry-ticket-async-v2-2026-08-10.md` (PR-6 row).

- Results + trade dissection: `dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md`
- Verdict memory: `project_faithful_ticket_structural_exclusion`
- Comparators: record-nextopen +7,321%; book-honest +310%; faithful w4 +318% /
  w13 +262% (top-3000, 26y window).

| spec | anchor window | run status |
|---|---|---|
| `...faithful-w4.sexp` | 4-week local range top | ran (+318%) |
| `...faithful-w8.sexp` | 8-week local range top | killed mid-run by user decision (no marginal info over w4/w13) |
| `...faithful-w13.sexp` | 13-week local range top | ran (+262%) |

Run artifacts (trades/audit/faithfulness reports) are NOT committed — they live
in `.sweep-output/ladder-v3-artifacts/` (ephemeral, host-local).
