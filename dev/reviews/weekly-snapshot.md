Reviewed SHA: b36b4f9c

# QC review — weekly-snapshot track

## PR #2105 — `feat/picks-phase-c` (Picks Phase C: HTML report + SVG charts)

Native HTML weekly report alongside the Markdown one, with per-candidate and
per-held-position SVG sparklines.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1 (of a cap of 2).

Full verdicts are PR review comments on #2105. Written here by the
**orchestrator**, not the QC agents: both were fenced read-only because the GHA
container shares a single git working tree. The `*_qc:` lines above sit at
column 0 with no list marker or backticks, and the `## Quality Score` heading
at the bottom is followed by a bare integer — `record_qc_audit.sh` greps
`^structural_qc: (APPROVED|NEEDS_REWORK)` and reads the first non-blank line
after a `## Quality Score` heading.

Process note: qc-structural and qc-behavioral were run **concurrently** rather
than gating behavioral on structural APPROVED (Step 5 Stage 2). Declared
deviation, for wall-clock. It paid off — behavioral found every real defect.

### Round 1 — base tip `f7916665`

- structural: **APPROVED**, quality 5/5. H1–H3 PASS by delegated measurement.
  P6 clean on both new test files. A1 NA (no core module touched). A2 PASS.
  A3 PASS (file list taken from the PR API, not a git-log ancestry walk).
  Code health verified mechanically: largest new file 248 lines, no limit
  bumped, no `@large-module` / `@large-function` marker, no
  `linter_exceptions.conf` entry — despite two linters tripping mid-development.
- behavioral: **NEEDS_REWORK**, quality 3/5. Scope confirmed **presentation-only**
  by reading the full diff (the 103-line loss from `report_renderer.ml` is a
  verbatim move into `Report_shared`; nothing touches stops, sizing, ranking,
  filtering or gating), so the S*/L*/C*/T* domain rows are NA and CP1–CP4 was
  the whole review. Two FAILs, one class — **loose-substring assertions that
  stay green while the document is wrong**:
  - **CP1** — document termination unpinned (`html_page.ml:126-145`). Two `.mli`
    docstrings claim a complete, newline-terminated document; no test greps
    `</html>`, `</body>` or `is_suffix`. *Falsifier:* truncate `document`'s
    format string after `%s` → all 32 tests pass, CLI emits unterminated markup.
  - **CP3** — candidate-row cell **order** unpinned (`html_report_renderer.ml:112-128`).
    The M21 fix pinned the `<thead>`, but the same weakness survived one level
    down. *Falsifier:* swap `_num_td entry` and `_stop_td c` → page renders
    Entry $90.00 / Stop $100.00 under headers saying the opposite, suite green.
    Both values remain present somewhere; `$55.00*` remains because `_stop_td`
    merely changed column; chart `<title>` assertions read `_sparkline`'s
    arguments, not the cells.
- Author claims the reviewer **verified independently**: disclosed gap (a) was
  over-stated (both sides of the CSS/SVG class contract *are* pinned to literals);
  "Markdown byte-identical" holds, with the two moved legends diffed
  character-by-character against main; degradation, anti-vacuity, determinism
  and all three arms genuinely pinned; the mixed-store case is covered.

### Round 2 — rework tip `b36b4f9c`

- structural: **APPROVED**, quality 5/5 (delta re-review). **Test-only claim
  confirmed** from `--stat`: 1 file changed, 47 insertions / 13 deletions,
  `test_html_report_renderer.ml` only, no production `.ml`/`.mli` in the delta,
  **no mutation probe left behind**. New `_starts_with` / `_ends_with` matchers
  use the `matching` combinator and compose under `assert_that` — P6 clean.
- behavioral: **APPROVED**, quality 4/5. Both FAILs **CLOSED**, each verified by
  reconstructing the rows cell-by-cell from `_candidate_row` rather than on the
  author's word. Both pins are `<tr>`-anchored through `</tr>`, so *every*
  two-cell permutation dies, not only the two originally named. The entry↔stop
  swap **does** kill the short arm (`_candidate_row` is shared), which matters
  because an unpinned short arm has been this track's recurring defect.
  Non-vacuity holds: every cell in each row renders a distinct string.
- **Golden-document vs targeted pins — the reviewer withdrew its own proposal.**
  It had recommended a whole-document golden to retire the loose-substring
  *class*. The author declined and argued it: `Html_page.css` is ~90 of ~110
  shell lines, so a golden would be dominated by style bytes, regenerated on
  every palette tweak, and promoted blind — trading one non-load-bearing
  assertion for another. The reviewer accepted this as correct, and proposed the
  synthesis for a later PR: golden the **body only**, eliding the `<style>` span.

### FLAGs — accepted, non-blocking

- **F4 (new, found during round 2)** — the held row's pin (`:459-464`) is the one
  row pin **not** `<tr>`-anchored: it covers cells 1–9 and leaves cell 10 (Chart)
  unconstrained in position. *Mutation:* move `_held_chart_td` from last to first
  in `_held_row` (`html_report_renderer.ml:172-184`) → Chart renders first under
  a `<thead>` saying it is last, suite stays green. One-line fix. Judged FLAG not
  FAIL because the held arm's *content* is fully pinned, so this is not the
  unpinned-secondary-arm defect — only the chart cell's position is loose, which
  is cosmetic beside the Entry/Stop transposition that justified round one.
  **Filed to `dev/status/cleanup.md` §Backlog.**
- F1 legend prose asserted prefix-only (pre-existing on main).
- F2 dark-mode appearance unverified (needs a browser, not OUnit).
- F3 the CLI's `-html` / `-data-dir` and the `_bars_from_store` fail-soft guard
  are smoke-tested only — a bin with no library seam, mirroring the on-main
  `_load_bars` precedent. Seam-extraction follow-up recorded.
- Out of scope, noted: `risk_pct` renders `-10.0%` for shorts — pre-existing on
  main, carried over deliberately.

### Known delta against the committed design reference

`dev/notes/weekly-report-design-reference-2026-07-27.html` was committed (#2104)
~40 minutes **after** this work was dispatched, so #2105 implements the older
`weekly-picks-execution-protocol-2026-07-24.md` §Phase C. Absent versus the
reference: tag chips, card layout, 30-week MA line, TradingView links, ticket
line. Present: per-row sparklines with entry/stop levels, drop-reasons (via the
Warnings section), structural-vs-fallback stop tag, spike `(!)` marker.
`Svg_chart` is pure geometry and snapshot-independent, so the delta is additive.

## PR #2107 — `feat/picks-entry-reconciliation` (issue #2103) — OPEN, NOT MERGED

Stacked on `feat/picks-phase-c`. Reviewed at `60d745bc`.

- structural: **APPROVED**, quality 4/5. P3 PASS — both new config fields carry
  `[@sexp.default 0.0]` and route through `Overlay_validator` (R1/R2). A1 **FLAG**
  (additive field on the Strategy config record). A2/A3/P6/code-health PASS;
  the nesting-refactor claim verified.
- behavioral: **NEEDS_REWORK**, quality 2/5. **CP1 FAIL** — `expected_fill_price`
  is called by `Trade_sizing` but by **neither renderer**, so the Risk % column
  still computes from the stale breakout level
  (`report_renderer.ml:53`, `html_report_renderer.ml:131-133`). On the author's
  own fixture the row self-contradicts: `Risk % = 10.0%` beside an instruction
  implying **16.1%**; at the armed `15.0` cap, displayed 10.0% vs real 21.7%
  (**2.2× understatement**) — a narrower recurrence of #2103 itself. **The test
  pins the bug**, so a corrected implementation fails the suite. This also
  falsifies the `.mli` claim at `weekly_snapshot.mli:162-173`.
- Verified good, no action: **the live-override arming is R3-safe** — exactly one
  production read of either config field, at `weekly_snapshot_generator.ml:214-215`
  inside `_reconcile_entry`, reachable only from `generate`, never
  `on_market_close`, so arming cannot move a backtest number. The numeric sizing
  pin is genuine (all four values recomputed independently). The Weinstein
  citation is verbatim. The short arm is correct and non-vacuous. W1 PASS.
- Six non-blocking FLAGs: stop not re-derived at the new fill; through-entry short
  renders `-`; zero-share note lacks market-order context; 07-24 specimen not
  regenerated; "old snapshots parse" unpinned; SVG band spans entry→stop.

Rework iteration 1 of 2 dispatched in-run. **#2107 must not merge until the
Risk % finding is closed** — arming a report whose Risk % column understates by
2.2× would be worse than leaving the mechanism unarmed.

## Quality Score

4

## Verdict

APPROVED
