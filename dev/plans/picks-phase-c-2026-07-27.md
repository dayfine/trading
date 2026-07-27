# Picks Phase C — native HTML report + per-candidate SVG charts (2026-07-27)

**Track:** weekly-snapshot · **Branch:** `feat/picks-phase-c`
**Spec:** `dev/plans/weekly-picks-execution-protocol-2026-07-24.md` §Phase C
(first two bullets only) + `dev/notes/next-session-priorities-2026-07-26.md` §P1.

## 1. Context

Phases A and B shipped: the weekly snapshot now carries live held positions,
fixed-risk sized instructions, structural-vs-fallback stop labelling
(`stop_is_structural`), the spike-bar `data_suspect` flag, and a `warnings`
list holding every drop reason. All of it is rendered by one **Markdown**
renderer, `Weinstein_snapshot.Report_renderer`
(`trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}`, 270 lines).

Phase C's presentation half is a **native HTML report** with per-candidate
price/volume SVG sparklines, so the reader can see the base, the breakout
level, and the stop without leaving the page.

This is a **presentation-only** change. No selection, sizing, gating, or stop
computation is touched.

## 2. The one real design decision — where chart data comes from

`Weekly_snapshot.t` carries **no price history**. `candidate` and
`held_position` hold only scalars (`entry`, `stop`, `score`, `current_price`,
…). An SVG price chart needs bars from somewhere.

- **(a) Extend the snapshot schema with a per-candidate bar series.**
  Rejected. It forces a `current_schema_version` bump, multiplies the on-disk
  size of every weekly artifact by ~2 orders of magnitude, and — decisively —
  violates the module's own stated design principle
  (`weekly_snapshot.mli` §Design): *"Snapshot record types are independent of
  in-memory analysis types … a future refactor cannot silently change the
  snapshot format."* Coupling the frozen record to a rendering concern is
  exactly the coupling that principle forbids.

- **(b) The HTML renderer accepts bars as a separate explicit parameter.**
  **Chosen.** `render` gains `?bars_for:(symbol:string -> Types.Daily_price.t
  list)`, defaulting to `no_bars` (returns `[]` for every symbol). The snapshot
  schema is untouched; `render` stays a pure function of its arguments.
  `Types.Daily_price.t` is already reachable — the `weinstein_trading.snapshot`
  library already depends on `types`, so **no new library dependency** is added.

**Graceful degradation is a hard requirement.** A symbol with no bars (or
fewer than two) renders a chart-less cell carrying a short `no chart data`
marker. A snapshot rendered with the default `no_bars` produces a complete,
readable page with every section, table, marker, legend and warning intact —
only the chart cells degrade.

## 3. Approach — module split

HTML/SVG generation sprawls. Per `.claude/rules/code-health-discipline.md` the
split is planned up front so no file approaches the 300-line soft limit; no
limit is bumped and no `@large-module` marker is added.

All new modules live in the existing
`trading/trading/weinstein/snapshot/lib/` (library `weinstein_trading.snapshot`).

| Module | Role | Est. LOC |
|---|---|---|
| `report_notes.{ml,mli}` | **Shared** legend/note prose + the predicates that gate them, extracted from `report_renderer.ml` so Markdown and HTML cannot drift | ~70 |
| `svg_chart.{ml,mli}` | Pure SVG sparkline primitive: bars + horizontal levels + optional band → `string option`. Knows nothing about snapshots | ~150 |
| `report_style.{ml,mli}` | The inline CSS constant for the HTML page | ~70 |
| `html_report_renderer.{ml,mli}` | Page assembly: head, sections, tables, chart cells, legends | ~240 |

### `Report_notes` (extraction, byte-identical output)

`report_renderer.ml` currently owns `_stop_fallback_note`,
`_data_suspect_note`, `_any_fallback_stop`, `_any_data_suspect`,
`_truncation_note` (+ `_note_body` / `_cutoff_score` / `_count_tied`). The HTML
renderer needs all of them. Duplicating multi-sentence prose in two renderers
is a guaranteed drift bug, so it moves to `Report_notes` returning **unwrapped**
text; the Markdown renderer wraps in `_…_`, the HTML renderer wraps in
`<p class="note">`. The Markdown bytes are unchanged — pinned by the existing
`test_report_renderer.ml` substring assertions, which stay green untouched.

### `Svg_chart`

```ocaml
type level_kind = Entry | Stop | Reference
type level = { label : string; price : float; kind : level_kind }

val render :
  ?width:int -> ?height:int -> ?band:float * float ->
  bars:Types.Daily_price.t list -> levels:level list -> unit -> string option
```

- Returns `None` when fewer than 2 bars — the degradation seam.
- Uses only the last `max_bars` (90) bars.
- Price domain spans bar highs/lows **∪ every level price ∪ the band bounds**,
  so the entry and stop lines are always inside the viewBox even when they sit
  outside the visible price range. Degenerate (flat) ranges are padded so no
  coordinate is `nan`/`inf`.
- Emits: optional band `<rect>`, volume `<rect>`s in a bottom strip, a
  `<polyline>` of closes, and one `<line>` + `<text>` per level with a
  kind-derived CSS class (`lvl-entry` / `lvl-stop` / `lvl-ref`).
- Deterministic: fixed-precision `%.1f` coordinate formatting, no time, no hashing.

### `Html_report_renderer`

```ocaml
type bar_source = symbol:string -> Types.Daily_price.t list
val no_bars : bar_source
val render :
  ?long_limit:int -> ?short_limit:int -> ?bars_for:bar_source ->
  Weekly_snapshot.t -> string
```

Self-contained single page: `<!DOCTYPE html>`, `<meta charset>`, inline
`<style>`, no external assets, no JS required to read it. Section order mirrors
the Markdown renderer exactly (title, system version, Macro, Strong sectors,
Long candidates, Short candidates, Held positions, Warnings) so the two reports
are cross-readable.

Carried across from the Markdown contract:
- structural-vs-fallback stop tag (`stop_is_structural = false` → `*` marker on
  the Stop cell + the fallback legend below the table),
- `data_suspect` → `(!)` marker on the Symbol cell + the data-suspect legend,
- the drop-reasons / **Warnings** section (`(none)` when empty),
- the tie-honesty note on a truncated table,
- the executable instruction cell (order / 0-share reason / `UNSIZED` prefix).

New in HTML: a **Chart** column. Every chart cell is wrapped as
`<td class="chart" data-chart="<arm>:<symbol>">` with `arm ∈ {long, short,
held}` — this makes each of the three arms independently assertable in tests
(see §6) and is genuinely useful for anyone scripting over the page.

Charts per arm:
- long / short candidate: levels = entry + stop, band = (entry, stop),
- held position: levels = entry price + current stop, band = (entry, stop).

**Escaping.** Every snapshot-sourced string (symbol, grade, sector, rationale,
sizing note, warning line, chart labels) goes through one `_escape` helper
(`& < > " '`). Snapshot text is externally-sourced (ticker feeds, config), so
this is a correctness requirement, not a nicety.

### CLI

`bin/render_weekly_report.ml` gains `-html` (render HTML instead of Markdown;
Markdown stays the default, so the existing invocation is unchanged) and
`-data-dir PATH` (read bars for each symbol from the CSV price store via
`Csv_storage.create ~data_dir` + `get`, so the charts are populated in real
runs). Without `-data-dir`, HTML renders with `no_bars` — chart-less but
complete. `bin/dune` already lists `csv` and `types`; it gains `fpath` only
(needed for `Fpath.v` on the data dir).

## 4. Files to change

New:
- `trading/trading/weinstein/snapshot/lib/report_notes.{ml,mli}`
- `trading/trading/weinstein/snapshot/lib/svg_chart.{ml,mli}`
- `trading/trading/weinstein/snapshot/lib/report_style.{ml,mli}`
- `trading/trading/weinstein/snapshot/lib/html_report_renderer.{ml,mli}`
- `trading/trading/weinstein/snapshot/test/test_svg_chart.ml`
- `trading/trading/weinstein/snapshot/test/test_html_report_renderer.ml`

Modified:
- `trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}` — delegate
  note prose to `Report_notes` (output bytes unchanged)
- `trading/trading/weinstein/snapshot/bin/render_weekly_report.ml` — `-html` /
  `-data-dir`
- `trading/trading/weinstein/snapshot/bin/dune` — add `fpath`
- `trading/trading/weinstein/snapshot/test/dune` — register the two new tests
- `dev/status/weekly-snapshot.md`
- this plan file

Explicitly untouched: `weekly_snapshot.{ml,mli}` (no schema change),
`weekly_snapshot_generator.ml`, every gate / sizing / stop module.

## 5. Risks / unknowns

1. **Prose drift between the two renderers.** Mitigated by `Report_notes` —
   there is exactly one copy of each legend string.
2. **Markdown regression during the extraction.** Mitigated: the existing
   `test_report_renderer.ml` pins the exact truncation sentence and the legend
   substrings; it is not modified, so any byte change fails it.
3. **Degenerate chart geometry** (flat series, zero range, single bar, levels
   far outside the price range) producing `nan` coordinates. Mitigated by an
   explicit domain-padding branch plus a test asserting no `nan`/`inf` token
   appears in output.
4. **Unpinned secondary arms** — the failure mode that rejected the last four
   PRs on this track. Mitigated by the per-arm `data-chart="<arm>:<symbol>"`
   attribute plus the §6 evidence method, with **distinguishable** fixture
   values so no branch is vacuous.
5. **CSV bar read cost in the CLI** for a large candidate list — bounded, one
   read per shown symbol, and only when `-data-dir` is passed.

## 6. Evidence standard (how §5.4 is discharged)

For every production branch added, name the test that goes **RED** when that
branch is broken. The direction is *production lines lacking a test*, not
*mutations tried*. The full table goes in the PR body. Non-negotiable items:

- Mutating the **short-candidate** `bars_for` call to `no_bars` must turn a test
  red → `test_short_candidate_chart_rendered` asserts
  `data-chart="short:SHRTB"><svg`.
- Mutating the **held-position** `bars_for` call to `no_bars` must turn a test
  red → `test_held_chart_rendered` asserts `data-chart="held:GOOG"><svg`.
- Fixtures give longs, shorts and held **distinct symbols and distinct bar
  series**, so no branch is satisfied vacuously by another arm's output.
- Determinism: render twice → byte-identical (mirrors the Markdown property).

## 7. Acceptance criteria

- [ ] `Html_report_renderer.render` produces a self-contained HTML page: inline
      CSS, no external assets, no JS required to read it.
- [ ] Per-candidate (long **and** short) price/volume SVG sparkline showing the
      base band, the breakout/entry level, and the stop.
- [ ] Held-position mini-charts with the current stop line.
- [ ] Structural-vs-fallback stop tag, `data_suspect` `(!)` marker,
      drop-reasons/Warnings section, and tie-honesty note all carried across.
- [ ] Missing bars degrade gracefully to a chart-less but complete page.
- [ ] Markdown renderer output is byte-identical to before.
- [ ] Every new module has an `.mli`; no file over the 300-line soft limit; no
      limit bumped, no `@large-module` marker, no linter exception added.
- [ ] `dune build @fmt && dune build && dune runtest` exit 0.
- [ ] Per-production-branch mutation evidence table in the PR body, including
      the short and held arms; any deliberately-unpinned line disclosed.

## 8. Out of scope

- The `record_fill` CLI (plan §Phase C bullet 3).
- The full trailing-stop state machine threaded across weeks (§Phase C bullet
  4) — a *behavioral* change; Phase C as scoped is *presentation*.
- Any change to `weekly_snapshot_generator.ml` selection / sizing / gating /
  stop logic, or to the snapshot schema.
- Arming any config flag.
- `#2083-F2` rename-tracking follow-ups (a–d) — maintainer-local, data-gated.
- `dev/status/_index.md` — reconciled by the orchestrator, not this PR.
