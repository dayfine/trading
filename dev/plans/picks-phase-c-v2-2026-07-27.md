# Plan: Picks Phase C v2 — HTML report to the committed design reference

Date: 2026-07-27
Branch: `feat/picks-phase-c-v2`
Track: `dev/status/weekly-snapshot.md`

## 1. Context

PR #2105 landed the first native HTML weekly report: `Html_report_renderer`
(pure `Weekly_snapshot.t -> string`), `Svg_chart` (price/volume sparkline),
`Html_page` (escaping + inline stylesheet + document shell), `Report_shared`
(prose + `risk_pct` + the executable `instruction`, shared with the Markdown
renderer so the two cannot drift).

What landed is **a table report with per-row sparklines**. ~40 minutes after
that PR was dispatched the maintainer committed a hand-built design reference,
`dev/notes/weekly-report-design-reference-2026-07-27.html`, which is a
**card** report. Measured against it, #2105 is missing:

| Element | In #2105? |
|---|---|
| tag chips (score / volume / earliness / resistance / stop-kind / reconciliation) | no (one chip, on the reconciliation cell only) |
| card layout (`div.cand` > `cand-main` + `chart` + `ticket`) | no (a `<table>`) |
| 30-week MA line on the chart | no |
| ~2y **weekly** close line (chart is 90 **daily** bars) | no |
| last-close marker | no |
| collision-nudged right-hand level labels | no (levels carry `<title>` only) |
| TradingView link per symbol | no |
| order-ticket line per card | no (ticket text exists, but as a table cell) |
| shared chart legend | no |
| masthead / stat strip / sizing + data-hygiene notes | no |
| drop-reasons section | **yes** — the existing `Warnings` section already is this |

This plan closes that gap **additively**: `Svg_chart` stays pure geometry and
gains opt-in features; the card layout replaces the candidate/held tables in
the HTML renderer only.

### Hard constraints carried in from the brief

- Markdown renderer (`Report_renderer`) stays **byte-identical**. Anything
  shared goes through `Report_shared`.
- No `current_schema_version` bump, no new `Weekly_snapshot.t` field. Chart
  data keeps arriving through the existing
  `?bars_for:(symbol:string -> Types.Daily_price.t list)` lookup; the 30-week
  MA is **computed from those bars**, never stored.
- Self-contained page: inline CSS, inline SVG, no external asset, no JS. A
  TradingView `<a href>` is a link, not an asset — allowed.
- Graceful degradation: `< 2` chartable points → `no chart data` marker; no bar
  source at all → complete, readable page. Existing tests for the empty and
  mixed cases stay green.
- Architecture rule A2: the snapshot library may **not** gain an `analysis/`
  dependency. Weekly aggregation and the SMA are therefore ~25 lines of local
  arithmetic in `Svg_chart`, not a call into `analysis/technical/indicators`.
- `code-health-discipline`: 300 soft / 500 hard on `lib/*.ml`. Fix by
  extraction; never bump a limit, never add `@large-module`.
- Presentation only. No stage-classification, entry, stop, sizing, gating or
  volume-confirmation change. No new behavioural knob, therefore no
  `experiment-flag-discipline` flag.

## 2. Approach

### 2.1 Module split (decided up front, not in reaction to the linter)

`html_report_renderer.ml` is already 277 lines. The card layout is strictly
more markup than the table it replaces, so the work is split before it is
written:

| Module | Responsibility | Est. `.ml` |
|---|---|---|
| `Chip` (new) | One presentation primitive: `{ text; modifier }` → `<span class="tag tag-<mod>">`. Knows nothing about snapshots. Also renders the masthead/sector chips. | ~40 |
| `Report_card` (new) | The generic card scaffold — `render ~modifier ~rank ~symbol ~chips ~nums ~chart ~footer` → `div.cand`. Owns the TradingView anchor and the `<i>label</i>value` numeric stack. Snapshot-independent. | ~75 |
| `Candidate_card` (new) | `Weekly_snapshot.candidate` → chips + nums + ticket → `Report_card`. The only module that knows how a candidate becomes chips. | ~140 |
| `Report_masthead` (new) | Masthead (title, as-of, system version, regime chip), the stat strip, the chart legend, the sizing + data-hygiene footer notes. | ~110 |
| `Html_report_renderer` (edit) | Composes the above + the held-position cards + Warnings. Table primitives deleted. | ~170 |
| `Svg_chart` (edit) | `?ma_period`, `?annotate` (right labels + last-close marker). | 171 → 260 |
| `Svg_labels` (new) | **Added during execution.** The label collision-avoidance rule. `Svg_chart` landed at 321 lines — over the 300 soft limit — so the label layout was extracted rather than the limit bumped, exactly as §4 anticipated. | 32 |
| `Svg_series` (new) | **Added during review rework.** Weekly aggregation + the simple moving average. The `?ma_period` fix pushed `svg_chart.ml` to 305, over the limit again; rather than trim a comment to squeak under, the *series-preparation* half was split from the *geometry* half — which is what `Svg_chart`'s own docstring has always claimed it is. `Svg_chart.weekly_bars` moved here; the one call site and its four tests moved with it. | 43 |
| `Html_page` (edit) | Card / chip / masthead / strip / legend / footer CSS; chart classes for MA + marker + labels. | 144 → ~215 |

Rejected alternative: keep one growing `html_report_renderer.ml` and add an
`@large-module` marker. Explicitly forbidden by `code-health-discipline.md`.

Rejected alternative: rebuild the renderer from scratch against the reference
HTML. The maintainer has an open question about exactly that; until it is
answered, extending keeps the work useful under either answer, and `Svg_chart`
is snapshot-independent pure geometry that a rewrite would keep anyway.

### 2.2 Cards replace the candidate + held tables

The reference has no table. `div.cand` carries three stacked strips:

```
div.cand[.cand-extended]
  div.cand-main   -> span.rank | a.sym (TradingView) | span.tags | span.nums
  div.chart       -> inline <svg> (or the no-chart marker)
  div.ticket[.ticket-extended] -> the order line
```

The `data-chart="<arm>:<symbol>"` hook that makes the three rendering arms
separately assertable is **kept**, moved onto `div.chart`. Held positions use
the same scaffold: no rank, held-specific chips (status, structural-vs-current
stop delta), and a position line instead of an order ticket.

### 2.3 Chips — derived from the snapshot, never invented

The reference's chip labels ("3× volume", "Fresh breakout") are the
maintainer's shorthand for clauses that live verbatim in
`candidate.rationale`, a `"; "`-joined signal list — real 07-24 data:

```
"Early Stage2; Strong volume; RS positive; Overhead supply (continuous); Strong sector"
```

Inventing "3×" from "Strong volume" would print a measurement the snapshot does
not contain. So: **the chip text is the rationale clause verbatim**; only the
CSS modifier is derived, by matching a small recognised vocabulary
(`Strong volume` → `vol-strong`, `Stage1→Stage2 breakout` → `breakout`,
`Early Stage2` → `early`). An unrecognised clause still renders, with no
modifier — new screener vocabulary degrades to a plain chip rather than
disappearing.

Chip set per candidate, in order:

1. `score` — `"<grade> <score:%.2f>"`, modifier `score`. (The plan floated a
   `score-top` variant keyed on grade `A+`; dropped on execution — `grade` is a
   free-form snapshot string and hard-coding one of its values to drive styling
   is exactly the kind of derived-from-untrusted-text class name §2.3 rules out
   elsewhere. The number itself carries the distinction.)
2. rationale clauses, verbatim, one chip each.
3. resistance grade, when `Some` (modifier `virgin` when it starts `Virgin_territory`).
4. stop kind — `structural stop` / `fallback stop` from `stop_is_structural`.
5. `data-suspect` when `data_suspect` (keeps the `(!)` semantics of #2083 F3).
6. reconciliation class from `Entry_reconciliation.label`, when `Some`.

### 2.4 `Svg_chart` additions (all opt-in — existing geometry tests untouched)

- `val weekly_bars : Types.Daily_price.t list -> Types.Daily_price.t list` —
  buckets dailies by ISO Monday; `open` = first, `high` = max, `low` = min,
  `close` = last, `volume` = sum, `date` = **last** daily date in the bucket, so
  the right edge of the chart is the snapshot's own Friday. Pure, exposed,
  tested.
- `?ma_period:int` — a second polyline (`polyline.ma`) of the simple moving
  average of `close` over the **whole** supplied series, drawn only where
  defined and only inside the drawn window. Computing over the whole series
  (not the window) means a caller who supplies 5y of history gets an MA across
  the full window instead of one that starts 30 points in. Omitted → no MA
  line, byte-identical to today.
- `?annotate:bool` (default `false`) — reserves a right-hand gutter and emits
  (a) one `<text>` per level, baseline `level_y + label_offset`, sorted and
  **nudged down to a minimum gap** so an entry and a stop a few cents apart do
  not overprint; (b) a `<circle class="last">` last-close marker with a
  `<title>` naming the close and its date. Default `false` keeps every pinned
  coordinate in `test_svg_chart.ml` exactly as it is.
- `max_bars` (90) stays the window cap; the renderer passes weekly bars, so
  90 weekly bars ≈ 21 months ≈ the reference's "~2y".

The renderer calls `Svg_chart.render ~width:860 ~height:150 ~ma_period:30
~annotate:true ~bars:(weekly_bars daily) …`. 30 is the Weinstein weekly MA
period; it is named as a constant in the renderer, not a bare literal.

### 2.5 Test-assertion strategy (the row-shape-churn problem)

The failure this must not repeat: #2105 pinned full `<tr>` rows cell-by-cell in
order; #2107 added a cell; the rebase was textually clean and semantically
broken, and only CI caught it. Hand-maintained whole-row pins must be edited by
every PR that changes row shape — and this PR changes it drastically.

Two layers, replacing the whole-row pins:

1. **One body-only golden** (`test/fixtures/html_report_body.golden`). The test
   renders the full fixture snapshot with bars, slices out `<body>…</body>`,
   and compares. Body-only because ~90 of 110 lines of a full-document golden
   would be CSS — regenerated on every palette tweak and therefore promoted
   blind (the reviewer's own objection on #2105, and the reason the full golden
   was withdrawn). The body carries element order, nesting, chip order, card
   composition, ticket text and every SVG coordinate: exactly the surface that
   the per-cell pins were trying and failing to hold.
   Regeneration is a documented one-liner (`-html` + slice), and the diff a
   reviewer sees is the semantic diff.
2. **Targeted semantic pins that a golden cannot express** — kept small and
   each one mutation-verified:
   - the three arms chart independently (count == 3, one per `data-chart` arm);
   - each new chip kind appears with its modifier, on a fixture that only one
     arm can satisfy;
   - the ticket line is character-identical to `Report_shared.instruction c`
     (asserted by *calling* it, so drift is impossible to introduce);
   - the TradingView href is built from the symbol and is escaped;
   - degradation arms (no bar source / one bar / partial coverage);
   - determinism (render twice → equal).

A golden alone would be promoted blind; targeted pins alone rot on shape churn.
Together, a shape change costs one regeneration + a semantic read, and a
*behaviour* change still turns a named test red.

### 2.6 `-html-out PATH` (cheap deferred item from #2105)

`render_weekly_report` gains `-html-out PATH`: write the HTML to `PATH`
instead of stdout, so a caller can produce `.md` and `.html` in one run without
shell redirection. Default behaviour unchanged.

## 3. Files to change

**New (lib):**
- `trading/trading/weinstein/snapshot/lib/chip.{ml,mli}`
- `trading/trading/weinstein/snapshot/lib/report_card.{ml,mli}`
- `trading/trading/weinstein/snapshot/lib/candidate_card.{ml,mli}`
- `trading/trading/weinstein/snapshot/lib/report_masthead.{ml,mli}`

**Edited (lib):**
- `svg_chart.{ml,mli}` — `weekly_bars`, `?ma_period`, `?annotate`.
- `html_page.{ml,mli}` — card / chip / masthead / legend / footer CSS + new chart classes.
- `html_report_renderer.{ml,mli}` — table primitives out, card composition in.
- `report_shared.{ml,mli}` — **not changed after all.** The plan put the two
  closing notes here; on execution they went to `Report_masthead` instead,
  because the Markdown report has no masthead and therefore nothing for them to
  drift against. `Report_shared` is for prose BOTH formats print; putting
  HTML-only prose there would have misrepresented the invariant. Net effect:
  `Report_shared` is untouched, so the Markdown output is byte-identical by
  construction rather than by inspection.

**Edited (bin):** `render_weekly_report.ml` — `-html-out PATH`.

**Tests:**
- `test/test_svg_chart.ml` — weekly aggregation, MA, labels + nudging, marker.
- `test/test_html_report_renderer.ml` — rewritten assertions per §2.5.
- `test/fixtures/html_report_body.golden` — new.
- `test/test_report_renderer.ml` — **untouched**, and that is the proof the
  Markdown side did not move.

**Docs:** `dev/status/weekly-snapshot.md`, this plan.

## 4. Risks / unknowns

- **Golden churn.** A body golden is regenerated on any intentional markup
  change. Mitigated by body-only scope + the semantic pins in §2.5.2, which
  fail independently of the golden.
- **Chip vocabulary drift.** If the screener changes a rationale clause the
  modifier silently degrades to a plain chip. That is the *designed* failure
  mode (degrade, don't drop); pinned by a test with an unrecognised clause.
- **Weekly bucketing at year boundaries.** Bucketing by "Monday of this date's
  week" via `Date.add_days d (-(iso_weekday - 1))` has no year-boundary
  discontinuity, unlike `(year, week_number)`. Pinned by a test that straddles
  a New Year.
- **Chart width.** 860×150 per card × 7 long + 5 short cards is a larger
  document than the table version. Acceptable — it is the reference's own size,
  and the page is still one self-contained file.
- **`Svg_chart` file length.** Estimated ~265 lines, under the 300 soft limit.
  If it overshoots, the label-layout block extracts to `Svg_labels`.

## 5. Acceptance criteria

- [ ] Every element in the §1 table is either implemented or has a written
      reason in the PR body.
- [ ] The chart window is described honestly. `Svg_chart.max_bars` stays at 90,
      so the weekly chart spans ~21 months, not the reference's "~2y". Bumping a
      public constant (and re-pinning its tests) for a 13% visual difference was
      not worth it; the docs say ~21 months rather than overclaiming.
- [ ] `Report_renderer` (Markdown) output byte-identical: `test_report_renderer.ml`
      unchanged and green.
- [ ] No `current_schema_version` bump; no new `Weekly_snapshot.t` field;
      no new `analysis/` dependency in the snapshot library's `dune`.
- [ ] Degradation arms green: no bar source, single bar, partial coverage.
- [ ] Each new rendering arm mutation-verified — mutate, name the test that
      goes red, revert; log in the PR body.
- [ ] No `lib/*.ml` over 300 lines; no limit bumped; no `@large-module` added.
- [ ] `dune build @fmt`, `dune build`, `dune runtest trading/weinstein/snapshot/`
      all exit 0 (exit code read, not grepped).

## 6. Out of scope

- `record_fill` CLI and the full trailing-stop state machine (deferred by the brief).
- `forward_trace.ml:173` stale-anchor FLAG (F7 on #2107) — do not fix, do not regress.
- Regenerating the 2026-07-24 specimen (needs a live data pull).
- F4/F5 "old snapshot parses without `reconciliation`" test — optional, taken
  only if it falls out naturally.
- Any strategy behaviour: stage rules, entry, stop, sizing, gating.
- `dev/status/_index.md` — reconciled by the orchestrator, not by this PR.
