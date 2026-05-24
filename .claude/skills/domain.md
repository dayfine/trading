# Domain docs — layout + consumer rules

This repo is **single-context**: one domain (Weinstein-style stage-analysis trading system) for the whole codebase.

## File layout

| Doc | Location | Status |
|---|---|---|
| Canonical domain reference | `docs/design/weinstein-book-reference.md` | present — the load-bearing authority for stage definitions, buy/sell criteria, stop-loss rules. |
| System design (what we're building) | `docs/design/weinstein-trading-system-v2.md` | present. |
| Codebase assessment (mapping) | `docs/design/codebase-assessment.md` | present. |
| Engineering design docs | `docs/design/eng-design-{1,2,3,4}-*.md` | present (data layer, screener, portfolio/stops, simulation). |
| `CONTEXT.md` (single-context Matt-Pocock-skills marker) | repo root | not yet present — this repo's domain context is split across the design-doc family above. |
| `CONTEXT-MAP.md` (multi-context marker) | repo root | n/a (single-context). |
| Architecture decision records (ADRs) | `docs/adr/` | not yet present. New ADRs would land here as `NNNN-<slug>.md`. |

## Consumer rules

Skills that read domain docs (`improve-codebase-architecture`, `diagnose`, `tdd`, `qc-behavioral`) should:

1. **For Weinstein domain logic** — primary authority is `docs/design/weinstein-book-reference.md`. Trace every claim about stage classification, stop-loss rules, screener cascade, sector analysis to a section of that doc. The qc-behavioral agent already uses this contract; see `.claude/rules/qc-behavioral-authority.md` for the row-by-row checklist.
2. **For system architecture + component boundaries** — read `docs/design/weinstein-trading-system-v2.md` + `docs/design/codebase-assessment.md`.
3. **For per-subsystem behavior** — read the matching `eng-design-N-*.md` (1=data, 2=screener, 3=stops, 4=simulation).
4. **For "what changed and why"** — there are no formal ADRs yet. The closest equivalents are: `dev/plans/<feature>.md` (forward-looking plans), `dev/notes/<topic>.md` (post-hoc reasoning), and `dev/status/<track>.md` (current state per track). Treat plans as design intent, notes as decision narratives, status files as the live state.

## When this layout might change

If the system splits along axes that develop their own jargon (e.g. a separate execution-engine layer with its own state-machine semantics vs the strategy layer), `CONTEXT.md` + `CONTEXT-MAP.md` may become useful. Until then, the design-doc family above is the single source of truth and the skills should treat it as `CONTEXT.md`-equivalent.

## Where this is referenced

- `CLAUDE.md` §"Agent skills" → "Domain docs"
- Skills that need domain context look here for the doc layout before reading any specific file.
