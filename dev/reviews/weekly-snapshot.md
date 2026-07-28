Reviewed SHA: 77e5b57b12a9a934bc18440649650b659f0f44c5

# QC review — weekly-snapshot track

## PR #2145 — `feat/sketch-adjusted-basis` (split-safe sketch basis, #2133 defect 2)

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1 (of a cap of 2). **MERGED `790d23a0`** on 2026-07-28 run 2.

Full verdicts are PR review comments on #2145 — structural `4799919475`,
behavioral `4799994353`, both at `77e5b57b`. Written here by the **orchestrator**,
not the QC agents: this run's dispatch briefs explicitly told both agents not to
write `dev/reviews/*`, anticipating PR-D'c
(`dev/status/orchestrator-automation.md` §Open work), which proposes dropping the
dual-write entirely. Until PR-D'c lands, the `Reviewed SHA:` line is still parsed
by Step 1.5 and Step 0.5 Condition 1, so leaving it stale would silently corrupt
the next run's dispatch guard — hence this entry.

### Round 2 (this run) — tip `77e5b57b` = rework `eaba3891` + clean merge of main

- **structural: APPROVED, quality 4.** Scoped *delta* re-review, and says so in
  its own body. The orchestrator established byte-level that the rework's
  production delta is doc-comment-only, so the round-1 APPROVED at `ae52b3f1`
  covers the production code; the uncovered surface was ~296 lines of new test
  code. No P6 violations. Confirmed the new `test_adjusted_basis` is genuinely
  attached to the `runtest` alias (the failure mode #2143 shipped with). H1–H3
  PASS on **completed** CI for the exact tip (run 30367458897), stated as
  verified, not predicted.
- **behavioral: APPROVED, quality 4.** Seven mutations re-run independently;
  6 killed, 1 surviving (N5, `Bar_reader` `Raw` default — FLAG only: both
  production consumers resolve the basis from the manifest hash and pass it
  explicitly, so the default is never consulted). Round-1's two survivors, M3
  (corrupt-close guard) and M4 (`sidetable_basis` threading), are both dead.
  N1/N2 show each guard disjunct is independently pinned; N3 (1e-15 relative
  drift) proves the R1 bit-identity assertion is genuinely bitwise rather than
  epsilon-tolerant.
- **The reviewer retracted two of its own round-1 prescriptions.** Its required
  fix for M4 ("add a test calling `stock_analysis_callbacks_of_weekly_views`
  … that kills M4") does **not** kill M4 — under M4, 14 of 15 tests passed,
  including the pre-existing test in exactly that shape. The implementer had
  disputed it and was right. Its finding 3 also mis-scoped a third wording site
  in `weekly_sidetable_builder.ml` that never carried the claim. Recorded as
  review defects rather than quietly absorbed.

### Round 1 — tip `ae52b3f1` (2026-07-28 run 1)

- structural: APPROVED q4 (review `4795521335`) — could not complete H2/H3 under
  container contention; approved on H1 + inspection.
- behavioral: **NEEDS_REWORK** q2 (review `4795688051`) — 8 mutations, 6 caught,
  2 survived.

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

---

## PR #2114 — `feat/picks-phase-c-v2` (2026-07-27 run 2)

**Format note:** `record_qc_audit.sh` matches the `*_qc:` fields at column 0 and
takes the **last** occurrence, plus the bare integer under the last
`## Quality Score`. Keep them unadorned.

Closes the remaining half of **P0**: the gap between the merged HTML weekly
report (#2105, a table with sparklines) and the design reference the maintainer
committed ~40 minutes after #2105 was dispatched
(`dev/notes/weekly-report-design-reference-2026-07-27.html`, a **card** report).

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1.

### What landed

21 files, +2338/−609 on the base tip. New modules `chip`, `report_card`,
`candidate_card`, `report_masthead`, `svg_labels` (and `svg_series` in the
rework); `html_report_renderer` 277 → **199**; `svg_chart` 171 → 260;
`html_page` 144 → 227. Card layout replacing both the candidate and held tables,
tag chips, a 30-week MA computed from the supplied bars (**no schema change** —
the `?bars_for` lookup pattern was kept), collision-nudged right labels,
per-symbol TradingView links, an order-ticket line, masthead + counts strip, and
`render_weekly_report -html-out PATH` (the deferred #2105 item).

Caveats the author volunteered rather than hid: the chart window is 90 weekly
marks ≈ **21 months, not the ~24 the reference implies** (documented as 21
instead of overclaimed); entry/stop dashes keep #2105's CVD-validated blue/red
rather than the reference's unvalidated green/rust; sizing/data-hygiene
**numbers** are deliberately not printed because the renderer is not handed that
config and plausible-looking values would be fabricated; no bottom date axis.

### The displayed-number contracts — the highest-risk surface, verified clean

This renderer prints broker-facing order instructions and risk figures, and on
this track a display path silently disagreed with the sizing arithmetic **twice**
this week (#2103, then its recurrence in the Risk % column, caught by QC).
qc-behavioral verified from source, not from the PR body:

- `candidate_card.ml`'s `_footer` **calls** `Report_shared.instruction c`
  (escaped) — `report_shared.ml` is not in the diff, so Markdown output stays
  byte-identical. `ticket_is_the_shared_instruction` builds its expected
  substring by calling the same function, so a drifting lookalike goes red.
- `_risk_value` uses `Report_shared.risk_pct ~entry:(Weekly_snapshot.expected_fill_price c)`
  — the *same expression* as `report_renderer.ml:60-63`. **`c.entry` is never the
  risk denominator.** Pinned positively and negatively (16.1% present, 10.0%
  absent). `Extended` correctly stays entry-based (there is no fill to price),
  with card + ticket-strip marking pinned on the opposite arm.

### The one real finding, and its rework

**CP1 FAIL (base tip):** `svg_chart.mli` promised that a **non-positive**
`?ma_period` is "no overlay, and the output is byte-identical to the
pre-`?ma_period` renderer". The *omitted* half held; the *non-positive* half did
not. `_sma` correctly yielded all-`None`, but `_aria_label` matched the option as
a plain `Some p` and emitted `"; %d-period moving average"` — so `~ma_period:0`
rendered `aria-label="… ; 0-period moving average"`, announcing an average that
is not drawn. Untested. It mattered beyond the letter because that byte-identical
guarantee is the author's own justification for leaving every pre-existing
coordinate assertion in `test_svg_chart.ml` un-re-pinned.

**Closed by making the code match the doc** (the stronger of the two options
offered): `render` normalises with `Option.filter ~f:(fun period -> period > 0)`
as its first statement, so the leak is closed at the single point
`_ma_over_window` and `_aria_label` share, not patched at one of them. The new
test asserts **whole-render equality** (`render ~ma_period:0 () = render ()`, and
again for `-5`) — the right instrument precisely because the leak satisfied every
negative substring one would think to write. Mutation-verified: reverting to
`Fn.id` reddens only that test.

**Consequential extraction, handled correctly.** The fix pushed `svg_chart.ml` to
305 lines, over the 300 soft limit. Per `code-health-discipline.md` the author
**extracted** rather than trimming a comment to squeak under: series preparation
(weekly aggregation + the SMA) moved to a new **`Svg_series`** (43 lines),
leaving `Svg_chart` as the pure geometry its docstring always claimed, at **260**.
The four `weekly_bars` tests moved **verbatim** — qc-behavioral compared fixtures
and assertions against their base-tip versions and confirmed nothing was
loosened. The move also **newly pins the `sma` alignment contract** (same length
as input, `None` until `period` values are behind a position), which the
coordinate tests had been assuming implicitly.

### The golden — the #2105 argument, finally synthesised

#2105's full-`<tr>` pins broke twice in two days (most sharply when a rebase that
was textually clean met an added 12th cell). The #2105 reviewer had proposed a
**body-only** golden after the author objected that a full-document golden would
be ~90/110 lines of CSS and get promoted blind. This PR builds exactly that: 17
lines, `<header>`→`</footer>`, no `<style>`/DOCTYPE, wired via
`(deps (glob_files_rec fixtures/*))`, with the regeneration path documented in
both the test docstring and the failure message.

It earns its place: **M15 (dropping the legend) is caught by the golden and
nothing else** — qc-behavioral confirmed by grep that the four legend-adjacent
assertions in `test_html_report_renderer.ml` are all negative assertions about
*notes*, and `section_order` omits the legend entirely. When the rework added the
held-section legend, the regenerated golden diff was **exactly one added line,
zero deletions, zero modifications**, byte-identical to the two legends already
present — inspected before promotion.

Known limitation, recorded rather than papered over: the golden renders with an
empty bar source, so all three chart slots are `no chart data`. It does **not**
protect chart composition; `test_svg_chart.ml`'s exact-coordinate pins do.

### Evidence

20 mutations, 20 red, each naming the specific test that reddens (qc-behavioral
verified all 20 name tests that exist and would go red). Arm separability
preserved — `data-chart="<arm>:<symbol>"` moved from the row onto `div.chart`, so
long / short / held remain separately assertable; this is the F4 defect shape
from #2105, handled. Degradation paths (unknown regime, unrecognised clauses,
missing bar data, the mixed-store case) all still pinned. Both Weinstein
citations verify verbatim against `weinstein-book-reference.md` §1 and §5.2, and
`_held_stop_line` never suggests lowering a stop — the L2 spine property holds.

### An orchestrator correction, recorded because it must not recur

qc-structural's **base-tip** verdict was NEEDS_REWORK (3/5) on a single blocker:
that the author had modified `dev/status/_index.md` and must revert the row.
**That was false.** I verified three ways — the REST file list (21 files, no
`_index.md`), `git diff --stat` on that path (empty), and a byte comparison of
the file at `origin/main` versus the branch (**identical**). I posted a public
correction on the PR rejecting the finding, and instructed the author explicitly
not to act on it.

This is the **A3 ancestry-walk false positive** that
`.claude/rules/qc-structural-authority.md` documents by name (PR #687), and the
review's dispatch prompt restated the rule in its own words. Second recorded
instance; filed as an escalation. The delta re-review, re-briefed with the
authoritative file list, returned **APPROVED (4/5)** and did not re-raise it.

## Quality Score

5

## Verdict

APPROVED

---

## PR #2117 — `feat/record-fill-cli` (item 4c.a)

Reviewed at `25e1965b`. Orchestrator run 30262098532 (2026-07-27 run 3).

**Provenance:** dispatched by orchestrator run 30250031315 (08:28Z), which pushed the plan
commit and then died without writing a summary, leaving a plan-only draft PR. Run 3 adopted
the orphan and implemented it.

A CLI to edit `dev/weekly-picks/portfolio.sexp` programmatically **so `cash` cannot drift out
of sync with the position list** — that invariant is the whole justification for the feature.
Three subcommands (`record` / `close` / `adjust`) over a new pure `Portfolio_edit` module,
with `save` / `to_file_contents` added to `Live_portfolio`. 28 tests.

structural_qc: NEEDS_REWORK
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK

Rework iterations: 1 (dispatched this run).

### Structural — NEEDS_REWORK (3/5)

Design and layering praised. `Portfolio_edit` confirmed **pure**, all I/O at the CLI edge; no
wall-clock reads (`--as-of` is explicit); `save` and `to_file_contents` correctly layered so
`--dry-run` shares the exact write-path formatting. All **six** author-declared plan
deviations verified sound, including that the nesting-linter failures were fixed by
**extracting `_check_*` helpers rather than adding a marker or bumping a limit** — the
behaviour `.claude/rules/code-health-discipline.md` asks for.

**Blocking (P6):** `test_live_portfolio.ml` ~:72 and ~:80 discard a `Result` via
`let _ = Live_portfolio.save …`. `.claude/rules/test-patterns.md` sub-rule 2 requires it be
asserted. The tests would still fail *indirectly* (a later read fails), but the failure must
be explicit.

### Behavioral — NEEDS_REWORK (3/5)

**Verified genuinely pinned** (invariant → test, with values):

| operation | cash movement | pinning test | value |
|---|---|---|---|
| `record` | `-= shares * entry_price` | `record_appends_and_debits` | 100@180 → 82,000 |
| `close` | `+= shares_held * exit_price` | `close_credits_and_removes` | 100@200 → 120,000 |
| `adjust --stop-price` | none | `adjust_stop_only` | 100,000 unchanged |
| `adjust --trim` | `+= trim.shares * trim.price` | `adjust_trim_credits_and_reduces` | 40@200 → 108,000, 60 held |
| both | credit + stop | `adjust_trim_and_stop` | 108,000, 60 held, stop 175 |

Also confirmed end-to-end against a copy of the committed `portfolio.sexp`
(100,000 → 82,000 → 90,000 → 102,000, exactly conserved), and with `dune runtest --force`
(not cached).

- **`>=` trim boundary — correct and genuinely pinned.** Called "the strongest part of the PR":
  relaxing `<` to `<=` turns `adjust_rejects_full_trim` RED, and the test sits exactly on the
  equality point (100 of 100). Verified by mutation, not by eye.
- **Round-trip and `--dry-run` pinned.** `load (save t) = Ok t` on the whole value;
  `--dry-run` fidelity is **structural** (`save` is literally
  `write_all ~data:(to_file_contents t)`, so one formatting function exists), confirmed by
  diffing a live `--dry-run` against the committed file.
- **The author's three mutation re-runs hold up.** Spot-checked all three; each builds and goes
  red on the assertion rather than the compiler (M2 → 2 RED, M5 → 1 RED, M9 → 3 RED). The
  author's own correction of its false-red mutants was sound.
- **`--entry-date` concern closed** — it does not mis-date back-dated fills; the flag is
  honoured whenever supplied and documented in `~doc` and plan §6.4.

**Blocking — three mutations SURVIVED with 20/20 green.** The implementations are correct; the
regression fences are missing (~15 lines):

1. `record` blank symbol — would append an empty-ticker ghost position *and* debit cash.
2. **`trim.shares` positivity — `--trim-shares -10 --trim-price 200` would mint 10 shares and
   move 2,000 of cash.** Flagged as the **#2059 phantom-position class**, in the one operation
   this feature exists to make safe. #2059 cost five runs to find.
3. `trim.price` positivity.

Plus `adjust`'s symbol normalization is unpinned — mutation M8 mutates the *shared* helper, so
the `adjust` call site merely *reads* as covered.

**Non-blocking:** `adjust --stop-price` accepts a *lowered* stop with no documented decision
(4c.b trailing-stop territory — note it, don't implement a ratchet); `Live_portfolio.header`
can silently drift from the schema it documents (currently byte-identical,
`harness_gap: LINTER_CANDIDATE`).

### Rework iteration 1 — `25e1965b..a007d550` — both gates APPROVED; MERGED `72e593e2`

**structural APPROVED (4/5)** — P6 CLOSED at both sites (`save` Results now bound and asserted via
an `_outcome` helper, so a failed write reports its own error text instead of surfacing as a
downstream read failure). The 18 new tests are themselves pattern-clean against all three
`test-patterns.md` sub-rules. No marker or limit bumps; `dev/status/_index.md` untouched.

**behavioral APPROVED (4/5)** — F2.1–F2.4 all CLOSED. The reviewer **re-ran 3 of the 5 mutations
itself** rather than accepting the author's table:

- Dropped `String.strip` from `_normalize_symbol` → 1 red, `record_rejects_blank_symbol`, sole
  red. Confirms the whitespace-only ticker choice is genuinely stronger, and that this test is the
  **only** pin on the strip anywhere in the suite.
- Deleted `_check_positive_int ~name:"trim-shares"` → 1 red; then instrumented the assertion to
  inspect the `Ok` value under mutation: the operation **succeeds**, cash goes to 98,000 (**a
  2,000 debit from a sell**) with **110 shares from a 100-share holding**. The mint hazard and the
  "`_check_trim_fits` does not catch it" claim are both verified empirically.
- Deleted the `_normalize_symbol` binding from `adjust` only → 1 red, still compiles,
  `record`/`close` stay green. Call-site-specific — exactly the discrimination the original M8
  lacked.

**No implementation logic changed** — `git diff 25e1965b..a007d550 -- portfolio_edit.ml
live_portfolio.ml` is **empty**. The delta is tests, one `.mli` paragraph, and two status files.
The reviewer called this "the strongest single signal in the rework": a real test gap, not logic
bent to fit mutations.

**Both orchestrator questions answered:**
- Plain `""` **is** fenced — `_check_symbol` runs *post*-normalization and `_normalize_symbol "" = ""`,
  so `""` and `"   "` reduce to one identical predicate. Whitespace subsumes it and adds a strip pin.
- Negative trim price **is** fenced by the same `> 0.0` predicate; `0.0` is the *better* test value
  because it pins the `>` vs `>=` boundary, which a negative would not.

**Two non-blocking flags:**
- **FLAG-A** — the new `.mli` "lowering is permitted" claim is unpinned: all three stop tests use
  raises (195/175/175 against a held 168), so adding a ratchet would survive the whole suite. Not
  treated as a CP1 FAIL because the sentence disclaims its own permanence and names 4c.b as owner.
- **FLAG-B** — the PR body was stale (28 tests / 10 mutations vs the actual 32 / 15). It
  *undercounted*, so no CP2 failure, but the body is the durable evidence record on the merge.
  **Corrected before merging.**

**Domain note (L2).** "Trailing stop rises, never lowered" is the one Weinstein authority row this
delta genuinely touches. The reviewer **passed** it, reasoning that a manual data-entry CLI must
let a trader fix a typo'd stop and that the ratchet invariant belongs to the 4c.b state machine —
but flagged it as a judgement call, now documented in the `.mli` with a named owner rather than
left implicit. Worth the human's eye when 4c.b lands.

### Merge note

Final commit `574a8da8` merges `origin/main` to resolve a `dev/status/cleanup.md` §Backlog
conflict — this PR added the `schema_drift` entry while #2113 and #2121 flipped others on main.
Resolved by keeping this PR's new entry and taking main's **resolved** `[x] citation_gap` (dropping
this branch's stale `[ ]` copy). All **seven** reviewed code files verified byte-identical to the
QC-approved tip `a007d550` through that merge, so both verdicts carried without re-review.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1.

## Quality Score

4

## Verdict

APPROVED

---

## PR #2125 — `feat/trailing-stop-state-machine` (item 4c.b)

Reviewed at `629c523b`. Orchestrator run 30273061906 (2026-07-27 run 4).

structural_qc: APPROVED
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK (behavioral)

### The design decision, and why both reviewers endorsed it

The brief asked for "the full trailing-stop state machine". **The author did not write one**, and
that was the right call: `Weinstein_stops` already *is* the Weinstein machine
(`Initial → Trailing → Tightened`) and is what live and backtest run, so a second one built for
the report would fork the domain logic — the exact divergence `Stop_recompute` exists to close.
4c.b instead adds *continuity* around it: `Stop_track` (persisted state), `Stop_thread` (pure
`seed`/`advance`), and a ratchet policy on manual edits.

**qc-behavioral verified this claim rather than accepting it.** It traced the fold and confirmed
`_step` takes `Weinstein_stops.update`'s returned `stop_state` **verbatim**; the only additions
are a report-only `raises` counter (never fed back) and the `trigger_on_weekly_close = true`
override. `_walk`/`_week`/`_continue` decide only *which* weeks to replay and *when* to stop; no
stop level, arm, or correction bookkeeping is computed outside `Weinstein_stops`. **W1 spine
intact.**

It also confirmed **L3 is load-bearing rather than inherited**: `Weinstein_stops.update` genuinely
reads `config.trigger_on_weekly_close` (`weinstein_stops.ml:246,475` → `check_stop_hit ~on_close`),
so the override matters, and flipping it turns two tests red. This is a real correctness point —
the config default is `false` (kept for golden stability) and the bars are *weekly*, so without
the override the stop would fire on an intra-week wick.

### Structural — APPROVED (5/5)

Build/fmt/tests re-run and verified **non-vacuously**: 144 tests executed in the subtree, with
`test_stop_track` (10), `test_stop_thread` (14), `test_live_portfolio` (11, 4 new),
`test_portfolio_edit` (30) and `test_weekly_snapshot_generator` (39, 3 new) all confirmed as
actually executing rather than cache-served. P6 clean across ~800 lines of new test code. The
three nesting-linter fixes were verified as **genuine extractions** (`_with_level`'s inline-record
update; `_step`/`_week`/`_continue` split out of `_walk`) — no `@large-module` marker, no limit
bump, no `linter_exceptions.conf` entry. REST-derived file list quoted per the A3 provenance rule.

### Behavioral — NEEDS_REWORK (3/5) — two findings

**F1 (T3) — nothing pins that the trailing stop level actually RISES.** The reviewer mutated
`_step` to **freeze the stop level** while letting arms, events and `raises` advance normally —
**the entire suite stayed GREEN**. The report would then print `Trailing (2 raises, …)` above a
stop that never moved: exactly the failure 4c.b exists to eliminate, and a direct miss on **L2**,
the invariant the whole item is for. Root cause is fixture shape — no fixture runs more than one
correction cycle, while the book's §5.2 worked example is three (points E, G, I). Per **T3**,
stop tests must verify trailing across *multiple* advances.

**F2 (CP1) — four texts assert things that are not true.** `Stop_thread.seed` has **no production
caller** (only the test file), yet: the `portfolio.sexp` `header` block *shipped to the trader*
says of `stop_state` "OMIT IT: the tooling writes and updates it"; `live_portfolio.mli` says to
"let `Stop_thread.seed` derive it"; `stop_thread.mli`'s `seed` doc says the same; and
`stop_track.mli` claims "exactly one monotonicity check to test and exactly one to break" —
contradicted by **the author's own mutation table**, where #1 breaks `ratchet` and #2 breaks the
independent `_check_stop_not_lowered`. Worse, `test_header_documents_stop_state` now **pins the
false statement in place**. No behaviour change is required; the texts must be made true.

### What the reviewer checked that the author's own mutation table could not

The author reported 11 mutations, 11 red. The reviewer ran **five of its own, three of them not on
the author's list**:

| Mutation | Author-listed? | Result |
|---|---|---|
| A: `ratchet` `<` → `<=` (reject equality) | no | RED |
| B: `_check_stop_not_lowered` ignores `allow_lower` | no | RED |
| **C: freeze the stop level, arms/events advance** | **no** | **GREEN — the finding** |
| D: `Entered_tightening` bumps `raises` | disclosed unpinned | GREEN (disclosure accurate) |
| E: `_weekly_close_config` → `false` | yes (#4) | RED (2 tests) |

The author's disclosure of two deliberately-unpinned lines was confirmed accurate by D. The
lesson from C is that a mutation table is only as good as the mutations chosen — 11 red says
nothing about the axis nobody mutated.

### Orchestrator note — my own verification was weaker than the reviewer's

Before dispatching QC I spot-checked the headline claims and reported "single ratchet
implementation confirmed" on the strength of `grep -c ratchet` across the three consumers. That
grep **cannot see a differently-named check**, and `Portfolio_edit._check_stop_not_lowered`
(`portfolio_edit.ml:108`, its own `Float.(new_stop >= current)`) is exactly that. The reviewer
caught what I missed; I re-verified both halves of F2 directly afterwards and both hold. Recorded
because the orchestrator spot-check should not be mistaken for a review.

### Disclosure quality — assessed and passed

The write-back is deferred to 4c.c, so `advance` runs read-only and a track is created only by
hand-editing `portfolio.sexp`. The reviewer judged the PR body, plan §8/§9.3 and status file to
state this **plainly**, and specifically credited §9.3 for correcting an earlier inaccurate
version of itself. It also established the deferral costs **correctness nothing** — the replay
recomputes from `prior.updated` every run, so this is persistence, not semantics. The problem is
confined to the `.mli` and `header` texts, which is why it is CP1 and not a disclosure failure.

Flagged for the operator: while `seed` is unwired, `--allow-lower-stop` is a **one-way trapdoor**
— it clears the track and nothing can recreate one without a hand edit.

## Quality Score

3

## Verdict

NEEDS_REWORK

### Rework iteration 1 — `629c523b..68916668` — APPROVED (both gates)

Reviewed SHA `68916668`, carried to `2360b39f` after a branch update (all **17** reviewed code and
test files verified byte-identical; the update brought only main's commits). **MERGED `e5726315`.**

structural_qc: APPROVED (5/5)
behavioral_qc: APPROVED (4/5)
overall_qc: APPROVED

**F1 CLOSED.** The reviewer **re-ran mutation C itself** rather than accept the author's report,
"since I am the one who found it green": frozen level → **RED** on
`advance_raises_the_stop_level_on_every_cycle` (`Cases: 16 … Failures: 1`); reverted → **GREEN**.
The diagnostic detail it drew out is the finding restated as a passing artifact — under the
mutation the sibling `advance_records_one_raise_per_cycle` **still passed**, which is exactly the
bookkeeping that masked a frozen stop.

It then instrumented the fixture rather than trusting its shape (debug removed, tree verified
clean): 40 bars, 31 base weeks + 3×3-week cycles; peaks `160 → 166.4 → 173.056 → 179.978` each
strictly higher; dips of 10%/12% against `min_correction_pct = 0.08`; levels
`137.998 → 143.375 → 149.259`; all three outcomes `Holding`. The assertion is on `Stop_track.level`
with strict `Float.( > )` and three rises required, so a stop that raises once and sticks scores 1
and fails. It also confirmed the author's `_replay_from` anchoring comment is accurate —
`weinstein_stops.ml:221` does seed `last_trend_extreme` from the first replayed bar's close.

**F2 CLOSED.** Every claim traced to code: `seed`'s only non-doc reference is
`test_stop_thread.ml:91`; `generate_weekly_snapshot.ml:140` calls `load` only (the sole `save`
caller is `record_fill.ml:43`); `enrich` falls back to `Stop_recompute.for_held_long` on `None`.
The misleading "OMIT IT: the tooling writes and updates it" is gone, and the correction is pinned
in `header` itself — **the bytes the trader reads** — not only in a doc-comment.

**The author corrected the reviewer on one detail, and was right.**
`test_header_documents_stop_state` did not literally assert the false sentence; it checked the
substrings `"stop_state"` and `"--allow-lower-stop"`, both still true. The real problem was the
*absence* of any test on the false claim — so it added
`header_does_not_promise_an_unwired_write_back` rather than editing the old test.

**Document-don't-merge judged real, not a rationalisation.** Two genuinely different fields on
different types: `ratchet` guards `Stop_track.t.state.stop_level`; `_check_stop_not_lowered` guards
`Live_portfolio.position.stop_price`. They demonstrably diverge (`_ratchet_track` handles the
machine-sits-higher case, and `seed` exists to reconcile the two), and an `option`-returning
ratchet can neither name offending values in a CLI error nor express `--allow-lower-stop`. Each is
pinned by its own named test (`test_stop_track.ml:85`, `test_portfolio_edit.ml:353`).

**Why the author chose docs over wiring** — better than "smaller diff": wiring `seed` would give it
a caller whose result nothing persists, so a seeded track would be rebuilt every run with `raises`
permanently zero. The report would *look* threaded while carrying no continuity — worse than no
caller. Persisting is 4c.c; the two belong in one increment.

**New-defect sweep: none.** The two touched `.ml` files contain **zero executable change** —
`live_portfolio.ml` (+13) is entirely string literals in `_header_lines`, `portfolio_edit.ml` (+5)
entirely inside one comment. I verified this independently before merging, along with
`stop_thread.ml` being byte-identical (the F1 mutation fully reverted). The risk flagged in the
brief did not materialise.

**Non-blocking follow-up (filed):** "writes" is used where "creates" is meant in four places —
`record_fill adjust --stop-price <higher>` *does* persist a ratcheted `stop_state`, so "nothing
writes this field yet" is over-broad standalone. Not a FAIL: every conclusion drawn from it is true
and verified, `live_portfolio.mli` discloses the exception in the same paragraph, and the
imprecision **under-promises** the tooling, which is the safe direction.

## Quality Score

4

## Verdict

APPROVED
