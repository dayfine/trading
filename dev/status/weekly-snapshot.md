# Status: weekly-snapshot

## Last updated: 2026-07-27

## Status
IN_PROGRESS

**2026-07-27 (Phase C item 4c.a — `record_fill` CLI, branch
`feat/record-fill-cli`, PR #2117):** `dev/weekly-picks/portfolio.sexp` was only
editable by hand: append a `position` record and remember to debit `cash`,
delete one and remember to credit it. The failure mode is silent — a portfolio
whose cash no longer matches its holdings still parses, still generates a
report, and sizes every subsequent pick against the wrong number.

Shipped as **three named operations, not one signed delta**: `record` (append,
debit), `close` (credit, remove — the only path that removes a holding), and
`adjust` (move the stop, and/or trim part of a position, never closing it).
Each carries an invariant the other two do not — must *not* already be held /
must be held / must stay open — so each is one named check with one named test
instead of three branches of a shared function. The book-keeping is a new pure
`Portfolio_edit`; the CLI is flag parsing plus the read/write at the edges.

**`record` rejects a duplicate symbol outright** rather than merging. That is
not a weighted-average scale-in: `Live_portfolio.position` is one row and one
`entry_price` per symbol, so a merge would invent portfolio behaviour nothing
else in the system shares. Re-running the CLI therefore cannot silently double
a position, and re-running `close` reports "not held" rather than crediting the
proceeds twice.

**`--as-of` is required on every subcommand**, never `Date.today` — the library
functions take the date, so they are reproducible; the CLI asks for it.
**`--dry-run` prints the exact bytes** a real write would produce
(`Live_portfolio.to_file_contents`, which `save` itself calls), so the two
cannot drift. `Live_portfolio` also gained `header`, re-emitted verbatim on
every rewrite: sexp parsing drops comments, so a naive write would have deleted
the file's own schema documentation.

**Validation asymmetry, deliberately:** `record` requires the stop below the
entry (book-reference §5.1); `adjust --stop-price` does not, because a trailing
stop legitimately rises past the entry once a position is in profit. Enforcing
the initial-stop rule on every adjustment would reject correct trailing-stop
updates. Item 4c.b (automating that trail across weeks) remains a separate PR —
this CLI only lets the user *set* the field.

28 tests; **10 mutations, 10 red**, each naming the test that caught it. Cash
arithmetic is pinned numerically on every happy path. The nesting linter failed
three functions on the first draft; fixed by extracting named `_check_*`
helpers, not by a marker or a limit bump.

**2026-07-27 (Picks Phase C v2 — HTML report to the committed design reference,
branch `feat/picks-phase-c-v2`):** #2105 shipped the presentation half of Phase
C as *a table report with per-row sparklines*. ~40 minutes after that PR was
dispatched the maintainer committed a hand-built design reference,
`dev/notes/weekly-report-design-reference-2026-07-27.html`, which is a **card**
report. This closes the gap between the two.

Implemented, measured element by element against the reference: per-candidate
**card layout** (`div.cand` > `cand-main` / `chart` / `ticket`) replacing the
candidate and held tables; **tag chips** (score, rationale clauses, resistance,
structural-vs-fallback stop, data-suspect, reconciliation class); a **30-week
moving average** on every chart; **weekly** closes rather than daily; a
**last-close marker**; **collision-nudged right-hand level labels**; a
**TradingView link** per symbol; a per-section **chart legend**; a masthead with
the macro-regime chip; a counts strip; and closing notes. The Warnings section
already was the reference's drop-reasons section and is unchanged.

**Chip text is snapshot text, never a re-labelling.** `candidate.rationale` is a
`"; "`-joined signal list (`"Early Stage2; Strong volume; RS positive; …"`);
each clause becomes one chip carrying that clause *verbatim*, and only the CSS
variant is derived from a small recognised vocabulary. The reference's
shorthand ("3x volume" for `Strong volume`) is deliberately NOT reproduced:
printing a measurement the snapshot does not contain would be a fabrication. An
unrecognised clause still renders, as a plain chip — pinned by a test.

**Module split decided up front, not in reaction to the linter** (plan
`dev/plans/picks-phase-c-v2-2026-07-27.md` §2.1): new `Chip`, `Report_card`,
`Candidate_card`, `Report_masthead`, plus two extractions taken when
`svg_chart.ml` crossed the 300-line soft limit — `Svg_labels` (label
collision-avoidance) during execution, and `Svg_series` (weekly aggregation +
the simple moving average, i.e. series preparation as distinct from geometry)
during review rework. No limit was bumped and no `@large-module` marker was
added. Every `lib/*.ml` is under 300 lines.

**Contracts preserved.** `Report_shared` is untouched, so the Markdown report is
byte-identical *by construction* — `test_report_renderer.ml` is unchanged and
green. No `current_schema_version` bump, no new `Weekly_snapshot.t` field: the
30-week average is computed from the bars the existing `?bars_for` lookup
already supplies. No new `analysis/` dependency (A2) — weekly aggregation and
the SMA are ~25 lines of local arithmetic in `Svg_chart`. All `Svg_chart`
additions are opt-in (`?ma_period`, `?annotate`), so every pre-existing pinned
coordinate in `test_svg_chart.ml` is unchanged.

**Assertion strategy changed, deliberately.** #2105's full-`<tr>` cell pins broke
twice in two days: #2107 added a cell, the rebase was textually clean, and only
CI caught it. Those are replaced by (a) **one body-only golden**
(`test/fixtures/html_report_body.golden` — body only, because ~90 of a
full-document golden's lines would be CSS and would be promoted blind), plus
(b) targeted semantic pins for what a golden cannot explain: arm separability,
the ticket being `Report_shared.instruction` *asserted by calling it*, risk
quoted against `expected_fill_price`, the chart being weekly with a 30-week
average, and every degradation path. **20 mutations, 20 red**, each naming the
test that caught it.

**Deliberately out of scope / disclosed:** the chart window is
`Svg_chart.max_bars` = 90 **weekly** marks, i.e. ~21 months rather than the
reference's "~2y" — bumping a public constant and re-pinning its tests for a 13%
visual difference was not worth it, and the docs say ~21 months rather than
overclaiming. The reference's per-run sizing/data-hygiene numbers (book size,
risk fraction, per-position cap) are NOT printed: they are configuration this
renderer is not handed, and plausible-looking values would be fabricated. The
bottom date axis on each chart is not drawn (the card's figures and the masthead
carry the dates). `forward_trace.ml:173` (F7 on #2107) is untouched.

`render_weekly_report` gains `-html-out PATH` — the deferred #2105 item — so one
invocation can produce the `.md` and the `.html` without shell redirection.

Plan: `dev/plans/picks-phase-c-v2-2026-07-27.md`.

**2026-07-27 (Picks Phase C — entry reconciliation, issue #2103, branch
`feat/picks-entry-reconciliation`, PR #2107, stacked on #2105):** The
correctness half of Phase C, and an instruction-level bug rather than a
cosmetic one. `candidate.entry` is the breakout level from the *transition*
week; the `<=4`-week early-Stage-2 window admits a name for weeks afterwards,
and nothing reconciled that level against the current price. On the 2026-07-24
report MBX printed `BUY STOP 651 sh @ $46.08 ... risk $784` while MBX traded
~$62 — a resting stop under the market *is* a market order, so the real fill
was ~$62, the notional 34% larger than sized, and the risk against the $44.88
stop ~$11k: **14x the displayed figure**. Three of that day's picks were >15%
past entry (CRNX +43.7%, MBX +34.5%, SAFT +26.0%), six were 1-15% past.

Two new modules plus a schema field:

- `Entry_reconciliation` (`snapshot/lib/`) — the pure classifier. A side-signed
  *overshoot* (`(close - entry)/entry` for longs, its mirror for shorts, so
  positive always means "already past the entry") against two thresholds:
  `Valid_stop` (today's resting ticket) / `Through_entry` (re-anchor to a
  MARKET fill at the close and **re-size on it**) / `Extended` (suppress the
  ticket with a do-not-chase reason, keep the row for watch) / `Not_reconciled`
  (the disarmed no-op).
- `Entry_reconcile` (`snapshot/gen/lib/`) — the bar-reader-backed pass, wired
  into `_build_candidates` for **both** the long and the short arm, between the
  structural-stop overlay and the sizing pass.
- `Weekly_snapshot.candidate.reconciliation` — additive,
  `[@sexp.default Not_reconciled]`, no schema bump, plus
  `Weekly_snapshot.expected_fill_price` as the **single source of truth** for
  what the order will fill at. `Trade_sizing` and both renderers call it, so
  the arithmetic and the printed price cannot drift — that disagreement *was*
  the bug.

**The invariant: sizing is always on the expected FILL price, never the
historical breakout level.** Everything else is presentation of that.

**Config + defaults (experiment-flag R1/R2).** `entry_through_band_pct` and
`entry_extension_max_pct` are real `Weinstein_strategy.config` fields, so they
resolve through `Overlay_validator` and are `Variant_matrix`-expressible.
`entry_extension_max_pct > 0.0` is the arming switch; at the `0.0` default the
pass is skipped entirely and output is bit-identical to before. Defaults were
kept no-op deliberately even though this is a bug fix — the fields are read
only by `Weekly_snapshot_generator.generate`, never by `on_market_close`, so a
default flip could not fix a backtest number; the four sibling report-hygiene
gates (#2083 F1/F2/F3, #2084 F1) all ship this way; and the danger is fixed
regardless because the same PR arms
`dev/weekly-picks/live-config-overrides.sexp` at the issue's own boundaries
(1.0 / 15.0 percentage points).

**Weinstein authority (W1).** Suppressing an over-extended entry follows
`weinstein-book-reference.md` §1 "Stage 2 detail (Ch. 2)", which locates the buy
at the breakout or on "at least one pullback close to the breakout point — this
is a second chance to buy". A name trading far above its breakout is at neither,
so there is no Weinstein buy point to write a ticket against. The section's
"Late Stage 2 warning" reads similarly but is deliberately **not** the citation:
it is conditioned on the stock sagging toward its MA, a different predicate from
distance past the breakout (narrowed in review round 1). No admission rule
changes and **no pullback-timing mechanic** is implemented; the
no-reversal-timing rule stands.

**Evidence.** Every production branch added is pinned by a test that dies when
it breaks — verified by mutation, **10/10 red**: dropping the short-arm
reconcile; flipping the short arm to `~side:Long` (sign-flips the overshoot);
sizing on `c.entry` instead of the fill; removing the `Extended` unsized arm;
removing the `Extended` suppression from the instruction; reverting the market
ticket to a resting stop; dropping the HTML chip cell; collapsing
`expected_fill_price`; and — added in review round 1 — reverting Risk % to the
stale entry level in *each* renderer independently. The re-sizing arithmetic is
pinned **numerically** against a hand computation (fill $107.30, stop $90.00,
$100k book, 1% risk → 57 sh / $6116.10 / risk $986.10, where the stale-entry
path would have given 100 sh / $10,000 / $1,000), because a label-only test
would not have caught the original bug.

**Review round 1 (qc-behavioral CP1 FAIL, PR #2107).** Both renderers computed
the Risk % column off `c.entry` rather than the expected fill, so a through-entry
row contradicted the ticket printed beside it — the Markdown fixture read
`10.0%` next to an instruction quoting `risk $986` on `$6116` (16.1%), and at
the armed 15.0 cap the column understates real risk **2.2×** (10.0% vs 21.7%).
That is issue #2103 again, one column over, and it falsified the
single-source-of-truth claim in `weekly_snapshot.mli`. Worse, the round-0 test
*pinned the wrong number* inside its row substring, so a correct implementation
would have failed the suite — a reminder that a strong assertion locks in
whatever the implementation emits, correct or not. Fixed by routing both
renderers (and `_market_order`'s quoted price) through
`Weekly_snapshot.expected_fill_price`, adding the missing HTML Risk %
assertion — reconciled rows had none, which is why the HTML side was invisible
to the round-0 mutations — and pinning the Risk % cell together with the
instruction so the two can no longer disagree.

**Known gaps, disclosed:** the structural stop is *not* re-derived at the new
fill price (correct for a real support floor, conservative for a fixed-buffer
fallback); short candidates remain unsized (short entries are default-off), so
a through-entry short's Instruction cell still renders `-` — shorts do get
classified, and an extended short does get the suppression text; the
zero-share `sizing_note` reason text is not pinned for a through-entry
candidate; the `_market_order` price now reads through `expected_fill_price`
rather than `l.close`, but that change is **not independently
mutation-testable** — the two are equal by construction for `Through_entry`, so
it buys structural honesty, not new behaviour coverage; and the 2026-07-24
artifact is not regenerated here (it needs a live data pull).

## Follow-up

- **F4 + F5 close together with one test.** The 07-24 specimen is not
  regenerated (F4) and "old snapshots without the field parse" is unpinned (F5).
  A single test that reads `dev/weekly-picks/2bcf5b335/2026-07-24.sexp` — which
  predates the `reconciliation` field — through `Snapshot_reader` would pin the
  `[@sexp.default]` round-trip against a real historical artifact *and* give the
  regeneration a reference point. Cheap, and it covers both gaps at once.
  (Raised by qc-behavioral on PR #2107; not done there to keep the rework
  scoped, and **still open** after `feat/picks-phase-c-v2` — that PR is a
  presentation change and taking the reader test would have widened it.)

Plan: `dev/plans/picks-entry-reconciliation-2026-07-27.md`.

**2026-07-27 (Picks Phase C — HTML report + SVG charts, branch
`feat/picks-phase-c`, PR #2105):** The presentation half of Phase C
(`dev/plans/weekly-picks-execution-protocol-2026-07-24.md` §Phase C bullets 1-2;
plan `dev/plans/picks-phase-c-2026-07-27.md`). Four new modules under
`trading/trading/weinstein/snapshot/lib/`:

- `Html_report_renderer` — pure `Weekly_snapshot.t -> string`, a self-contained
  HTML page (inline CSS, inline SVG, no external asset, no JS). Renders
  ALONGSIDE the Markdown renderer, same section order; neither replaces the
  other.
- `Svg_chart` — pure price/volume sparkline: shaded entry-to-stop band, volume
  strip, close polyline, dashed entry + stop level lines. Returns `None` below
  two bars.
- `Html_page` — escaping, the inline stylesheet, the document shell.
- `Report_shared` — the legend prose, the tie-honesty truncation note,
  `risk_pct` and the executable `instruction` sentence, shared by both
  renderers so the two formats cannot drift. Markdown output is byte-identical
  to before.

**Chart-data design decision.** `Weekly_snapshot.t` carries no bar series, by
design (`weekly_snapshot.mli` §Design: the on-disk schema stays decoupled from
analysis types). Rather than bloat the frozen record and bump
`current_schema_version`, `render` takes an explicit
`?bars_for:(symbol:string -> Types.Daily_price.t list)` lookup. The schema is
untouched, `render` stays pure, and a symbol with fewer than two bars degrades
to a `no chart data` marker — a snapshot rendered with no bar source at all
still produces a complete, readable page.

Every candidate row (long AND short) and every held-position row carries a
chart cell tagged `data-chart="<arm>:<symbol>"`, so the three rendering arms
are separately assertable; the test fixtures give each arm distinct symbols,
prices and bar series, and mutating either secondary arm's chart call to
`no_bars` turns a dedicated test red. `render_weekly_report` gains `-html` and
`-data-dir PATH` (bars from the CSV price store, read on demand); Markdown
remains the default so the existing invocation is unchanged.

Carried across from the Markdown contract: the structural-vs-fallback stop tag,
the `data_suspect` "(!)" marker, the drop-reasons Warnings section, and the
tie-honesty note on truncated tables.

**2026-07-26 (live rename tracking, issue #2083 Finding 2, branch
`feat/universe-rename-tracking`):** The last of the three 07-17 findings, and
the only one that attacks the ROOT cause rather than a symptom. F1
(`Sparse_tail_gate`, #2090) refuses a candidate whose recent tail is too sparse;
F3 (`Spike_bar_gate`, #2097) annotates one whose signal rests on a single bar.
Neither knows *why* the feed went bad. F2 detects the rename itself: Sensei
Biotherapeutics -> Faeth Therapeutics, SNSE -> FTH, 2026-06-16.

Issue #2083 proposes two mechanisms for F2 — the EODHD symbol-change feed, or
"the existing returns-basis twin matcher run live". **`EODHD_API_KEY` is not
available in the GHA container, so the vendor-feed half could not be built or
exercised even once and is explicitly OUT OF SCOPE here** (see §Follow-up). This
PR builds the second, which needs no vendor feed and is fully testable offline.

New pure module `Weinstein_snapshot_gen.Rename_detector`
(`trading/trading/weinstein/snapshot/gen/lib/rename_detector.{ml,mli}`): given
`symbol -> daily adjusted-close series` plus an `as_of`, it returns candidate
`(old_symbol, new_symbol)` pairs with the evidence that justified each —
changeover date, overlap length, returns-similarity score, per-side tail-bar
counts. Pure: no filesystem, no `Bar_reader`; the caller owns loading, exactly
as `Twin_detector` does. Its trading-day calendar is derived from the union of
the input's own dates.

**Reuse, not reimplementation.** The returns-similarity score comes from calling
`Twin_detector.detect` on the two-series pair with `basis = Returns` and
`min_overlap_days = 2` (which makes its anchor stride 1, so its prefilter is
exhaustive over a two-series input and cannot drop a genuine match); the
resulting `pair_match` supplies `overlap_days` / `match_fraction`. Not one line
of similarity arithmetic is duplicated. `Config.default` inherits
`Twin_detector`'s own calibrated `match_fraction = 0.95` / `ret_epsilon = 1e-3`
(its top-3000 audit: real rename twins score 0.95-0.99 on the returns basis,
different-company controls below 0.06).

**What is new over `Twin_detector` is SUCCESSION, not concurrency.**
`Twin_detector` answers "which series here are near-duplicates of each other,
concurrently?" and reports a dual listing the same way it reports a rename. A
rename additionally requires a handover: the predecessor goes sparse at the
right-hand edge (tail density <= `max_predecessor_tail_density`) while a younger
leg becomes dense (>= `min_successor_tail_density`), with matching returns over
whatever they share. Two fully-overlapping dense series are NOT reported.

New adapter `Weinstein_snapshot_gen.Rename_gate` (`series_for` / `partition`)
reads the series out of a `Bar_reader` and returns the same
`(eligible, warnings)` pair `Sparse_tail_gate.partition` does, so the two #2083
eligibility stages compose uniformly. Wired into
`Weekly_snapshot_generator.generate` **before** the sparse-tail gate, on the
full ticker list — the zombie tail that identifies a superseded ticker is
exactly what that gate removes, so running second would erase the evidence
(pinned by a test that arms both). A detected predecessor is dropped from
candidate consideration and a warning line naming the successor is appended to
`Weekly_snapshot.t.warnings`, so the pick disappears with an explanation and an
actionable alternative ticker rather than silently.

Default-off per `experiment-flag-discipline.md` R1/R2: two additive fields on
`Weinstein_strategy_config.config`, `rename_detect_min_overlap_days : int
[@sexp.default 0]` and `rename_detect_match_fraction : float [@sexp.default
0.0]` (the `sparse_tail_min_bars` / `sparse_tail_window_trading_days` pair is
the precedent). Either at its default disables detection, and
`Rename_gate.partition` returns before any series is read — an unarmed run is
bit-identical AND pays no extra load cost. Real config fields, so they resolve
through `Config_overrides_loader -> Overlay_validator.apply_overrides` and are
expressible as a `Variant_matrix` axis (R2; pinned by an overrides-loader test).
**Default NOT flipped and NOT armed in
`dev/weekly-picks/live-config-overrides.sexp`** — that needs a ledger ACCEPT
(R3) plus a false-positive dry run.

Engineering data-hygiene mechanism, **not** a Weinstein book rule: no
`weinstein-book-reference.md` section is cited because none supports it, and the
spine is untouched — no change to stage classification, the Stage-2-only buy
rule, volume confirmation, macro/sector gating, entry, stop or sizing.

Code health: the wiring first pushed `weekly_snapshot_generator.ml` to 303 lines
(limit 300) and tripped the nesting linter on three functions. Both fixed by
**extraction**, not a limit bump / `@large-module` marker / exception entry
(`code-health-discipline.md`): the adapter moved into its own `Rename_gate`
module (generator back to 276 lines) and three helper bodies were named
(`_rename_record`, `_warning_line`, `_report_for`).

Tests: `test_rename_detector.ml` (22 unit tests) + `test_rename_gate.ml` (7
adapter/seam tests) + 5 `generate`-seam tests + 1 overrides-loader test. Covers
the true positive (SNSE-shaped succession, right direction, right evidence), the
level-lookalike true negative (two companies within ~2% on price whose returns
differ — pins that the Returns basis does the work), the near-miss negative (a
*concurrent* twin that clears every other criterion and is rejected only by the
handover), the sparse-successor negative, default-off at every layer, and both
sides of the drop (predecessor removed AND successor/unrelated symbols kept,
asserted as exact lists). Full `dune build @fmt` + `dune build` + `dune runtest`
all exit 0.

**Production lines NOT pinned by a test** (stated rather than hidden): (a) the
`changeover > old.last` fast-path in `Rename_detector._succession` and (b) the
`if not config.enabled` short-circuit in `Rename_gate.partition` are both
*performance* guards — removing either yields identical output (the scoring path
rejects a zero-overlap pair; `Rename_detector.detect` returns an empty report on
a disabled config), so no test can distinguish them. (c) `prefilter_rel_tol =
Float.infinity` in `Rename_detector._returns_score` is a robustness choice;
`Twin_detector`'s default 2e-2 also passes on every current fixture, so the
fixtures do not force it. Every other new line was mutation-checked: 17
mutations run, each turning at least one test red (detector: stale/fresh density
filters, old/new direction swap, `min_predecessor_bars`, `min_overlap_days`,
`Returns`->`Levels`, loosened `ret_epsilon`, `enabled` guard, `Config.armed`
predicate, `_better` tie-break, tail-window width, `survivors`; gate:
`survivors` bypass, warnings suppression, `adjusted_close`->`close_price`;
generator: whole stage bypassed, survivors ignored, warnings dropped, stage
order flipped).

**QC (PR #2097, mirrored by the orchestrator — the QC agents were fenced
read-only on a shared working tree and could not write here):**
`structural_qc: APPROVED` (5/5) and `behavioral_qc: APPROVED` (4/5), both at
tip `5454d9f1`; `overall_qc: APPROVED`. One rework iteration: at base tip
`ad11fb7f` behavioral returned NEEDS_REWORK (3/5) on a CP4 gap — short-side
spike flagging at `weekly_snapshot_generator.ml:220` was claimed in the `.mli`,
the PR body and this file but pinned by nothing, and the mutation
`(shorts, [])` left the whole suite green. Closed by
`test_armed_spike_flags_short_candidate_and_warns` at the `generate` seam.
Merged `089116bc` with all three gates green. Full verdicts are PR review
comments on #2097; audit record `dev/audit/2026-07-26-weekly-snapshot.json`.
One non-blocking nit carried: the *flagged* candidate's own
rank/entry/stop/sizing invariance holds by construction
(`{ c with data_suspect = true }`) but is not pinned at the seam.

**2026-07-26 (spike-bar "data-suspect" flag, issue #2083 Finding 3, PR #2097
`feat/weekly-snapshot-spike-flag`):** Closes the last of the three 07-17
report-review findings. F1 (sparse-tail gate) and F2 (rename tracking, still
unbuilt) attack the data source; F3 is the **report-hygiene backstop**: even
when a spike bar is genuine and the ticker alive, a candidate whose signal
rests on a single outsized bar gets a visible caveat on the ticket. New module
`Weinstein_snapshot_gen.Spike_bar_gate`
(`trading/trading/weinstein/snapshot/gen/lib/spike_bar_gate.{ml,mli}`, mirrors
the sibling `Sparse_tail_gate` shape): `check` compares the last daily bar
at/before `as_of` against the prior **resident** bar's close (on a zombie feed
that is not the prior trading day — that is the point) and reports the
**absolute** percentage move; `>= threshold_pct` -> `Data_suspect { move_pct;
threshold_pct; bar_date }`.

**Flag, do not drop** (unlike F1): the candidate keeps its rank, entry, stop
and size. `Weekly_snapshot.candidate` gains an additive `data_suspect : bool
[@sexp.default false]` (the `stop_is_structural` precedent from #2091);
`Report_renderer` marks the Symbol cell `TEST (!)` plus an explanatory footnote
(same treatment as the fallback-stop asterisk); a warning line stating the
candidate was **kept** is appended to `Weekly_snapshot.t.warnings`. Wired into
`Weekly_snapshot_generator` beside the `_sparse_tail_*` helpers, applied to
long AND short candidates (`generate`'s candidate assembly was extracted into
`_build_candidates` to stay inside the function-length cap).

Default-off per `experiment-flag-discipline.md` R1/R2: one new field
`spike_bar_threshold_pct : float [@sexp.default 0.0]` on
`Weinstein_strategy_config.config`; `<= 0.0` disables (same convention as
`sparse_tail_window_trading_days = 0`), so an unarmed run is bit-identical.
Real config field -> resolves through `Overlay_validator.apply_overrides` and
is expressible as a `Variant_matrix` axis. **Default NOT flipped and NOT armed
in `live-config-overrides.sexp`** — that needs a ledger ACCEPT (R3).
Engineering data-hygiene flag, **not** a Weinstein book rule: no
`weinstein-book-reference.md` section is cited (none supports it) and the spine
is untouched — no change to stage classification, the Stage-2-only buy rule,
volume confirmation, entry, stop or sizing.

Code health (same PR, second commit): the new wiring pushed
`weekly_snapshot_generator.ml` past the 300-line file-length limit. Fixed by
**extraction**, not a limit bump or an `@large-module` marker
(`.claude/rules/code-health-discipline.md`): each #2083 gate module now owns
both halves of its own semantics — `Spike_bar_gate.flag_candidates` (flag a
candidate list) and `Sparse_tail_gate.partition` (split tickers into eligible +
warnings, a pure code move) — and the held-book enrichment moved verbatim into
a new `Held_position_row` module (`enrich` / `long_market_value`; it concerns
the held book, not the screener cascade). Generator 299 -> 261 lines, so the
file has real headroom again. No behaviour change in either move; all
dune-wired linters green (file-length, nesting, fn-length, mli-coverage,
magic-numbers, fmt).

Tests: `test_spike_bar_gate.ml` (12 unit tests — disabled/negative no-op, +58%
SNSE-shaped spike, quiet bar, downward spike reporting the absolute move,
inclusive threshold boundary, gapped series comparing the prior *resident* bar,
<2 bars, no bars, zero prior close, both `warning` branches); 6 new
generator-level tests pinned at the **`generate` seam** (default-config
disabled; disabled run bit-identical on a spiked fixture; armed+spike flags AND
keeps the candidate + warns; armed on a quiet dense fixture stays clean; the
**short**-side flag+keep+warn on a spiked `SHRT` fixture; and a two-candidate
list where only one spikes, pinning same-length/same-order plus the non-spiking
row byte-identical to its disabled-run self); 2 renderer tests (marker +
footnote present / absent); `test_round_trip` pins the additive-field
back-compat default. Six mutations run, each turning **exactly one** new test
red: (A) long call site bypassed, (B) `~threshold_pct:0.0`, (C) drop instead of
flag, (D) `_symbol_cell` marker removed, (E) footnote legend removed, (F) the
SHORT call site bypassed (`let shorts, short_warnings = (shorts, [])`) — (F)
fails only the new short-side seam test (QC rework 1). `dune build @fmt` + `dune build` exit 0. Full `dune runtest` exits 1
ONLY on the pre-existing `Tuner.Bayesian_opt` LAPACKE GP-Cholesky failures
(`Failure("LAPACKE: 9")` in `bayesian_opt_cholesky.ml`; maintainer-owned fix PR
#2009, stalled since 07-19) — unrelated to this diff, which touches no tuner
code. Every weinstein/snapshot test and every dune-wired linter is green.

**2026-07-26 (structural stop for weekly-pick candidates, issue #2084 Finding
2, PR `feat/screener-structural-stop`):** Fixes the second finding from the
same 07-17 report review: the displayed AND live-instructed stop for a
candidate pick (e.g. rank-1 FTH, `$33.98`) was `entry * (1 - 8%)` — a flat
percentage divorced from chart structure, unlike the backtest's actual entry
stop (which already derives a real support floor via
`Weinstein_stops.compute_initial_stop_with_floor`). Since PR #2078 wired the
sized instruction line ("on fill place SELL STOP @ $<stop>"), this was also a
live/sim divergence: the same symbol's backtest entry installs a structural
stop while the live instruction told the trader to place the naive one; sizing
was also wrong (always assumed an 8% stop distance).

New module `Weinstein_snapshot_gen.Stop_recompute`
(`trading/trading/weinstein/snapshot/gen/lib/stop_recompute.{ml,mli}`)
consolidates two call sites that both wrap `compute_initial_stop_with_floor`:
`for_candidate` (new — overlays the real structural stop onto a screener
candidate before sizing/display) and `for_held_long` (moved out of
`weekly_snapshot_generator.ml` verbatim — pre-existing held-position
"recommended stop" logic, unchanged behavior). `Weekly_snapshot.candidate`
gains an additive `stop_is_structural : bool [@sexp.default false]` field;
`Report_renderer` marks a fallback (non-structural) stop with a trailing `*`
plus an explanatory footnote so a reader can tell the two apart without
cross-referencing the chart.

Deliberately does **not** touch `Screener.scored_candidate.suggested_stop`,
`screener_scoring.ml`, or `screener.ml` — the pure cascade library has no
daily-bar access, and its `suggested_stop` value still feeds
`trading/backtest/optimal/lib/stage_transition_scanner.ml` (the
optimal-strategy counterfactual tool) unchanged; that tool's own tests
(`test_stage_transition_scanner.ml`, pinning `suggested_stop = 92.46` under
the flat-8% formula) still pass untouched, confirming no backtest/golden path
was moved. Per `.claude/rules/experiment-flag-discipline.md`, this landed
**on by default** (no new config field) — see
`dev/plans/screener-structural-stop-2026-07-26.md` for the empirical
default-branch check (grepped every `suggested_stop` / candidate-stop
consumer; ran full `dune runtest` before/after). This is a
display/instruction-path correctness fix restoring
`.claude/rules/weinstein-faithful-core.md` spine item 5 to the live path, not
a new strategy mechanism.

Tests: `test_weekly_snapshot_generator` (fallback stop differs from the
screener's raw flat-8% proxy — proves the overlay ran; sizing keys off the
post-overlay stop distance — proves overlay-before-sizing ordering) and
`test_report_renderer` (fallback stop renders `*` + footnote; structural stop
renders neither). Every new assertion mutation-tested (overlay call removed,
overlay/sizing pipe order swapped, `is_structural` forced `true`, stop-cell /
footnote logic stubbed) and confirmed to go red.

QC rework iteration 2 added the missing **short-side `generate`-seam** pin:
`test_short_candidate_overlay_applied_at_generate_seam` builds a synthetic
early-Stage-4 breakdown fixture (`SHRT`, a decline whose 30-week MA has just
turned down, with volume expansion on the breakdown leg and a ~13%
counter-rally spliced onto its final bars) so a real short candidate flows
through `Screener.screen` into `result.short_candidates`. It asserts
`stop_is_structural = true` (the first such assertion on either side — the
prior tests only covered the fallback branch) and that the stop sits in
`[rally_high, rally_high * 1.10]`, i.e. just above the prior counter-rally
high per §6.3. Mutation-verified: reverting the short overlay to a bare
`List.map … candidate_of_scored` → red; flipping `~side:Short` to `~side:Long`
at the same call site → red (stop lands at `63.875`, the long-side correction
low, outside the band).

**2026-07-26 (sparse-tail eligibility gate, issue #2083 fix 1, PR
`feat/weekly-snapshot-sparse-tail`):** Closes the data-hygiene hole behind the
2026-07-17 report's rank-1 "SNSE" pick, a ticker that did not exist at the
broker (Sensei Biotherapeutics had renamed to Faeth Therapeutics, SNSE->FTH,
on 2026-06-16). The feed kept serving occasional stale bars under the dead
symbol (6 bars across ~15 trading days, one anomalous spike near the right
edge) and the existing "too few bars" check never fired because the series
read current at `as_of` and was merely sparse in the middle. New module
`Weinstein_snapshot_gen.Sparse_tail_gate` (`trading/trading/weinstein/snapshot/gen/lib/sparse_tail_gate.{ml,mli}`):
`check` counts bars actually present in the trailing `window_trading_days`
**trading days** (via `Bar_reader.daily_view_for`'s calendar-walk, so weekends
never count as "missing") ending at `as_of`; fewer than `min_bars` ->
`Sparse_tail`. Two new flat fields on `Weinstein_strategy.config`
(`sparse_tail_min_bars`, `sparse_tail_window_trading_days`, both
`[@sexp.default 0]` — default disabled, exact no-op) resolve through the real
`Config_overrides_loader` -> `Overlay_validator.apply_overrides` path (same
mechanism as `resistance_lookback_bars` / `candidate_ranking`), so they are
consumed **only** by `Weekly_snapshot_generator.generate` — the backtest/live
strategy path never reads them, so arming cannot move a backtest number.
Wired into `generate`: a dropped ticker is excluded from candidate
consideration and a warning line is emitted (not a silent drop). Schema:
`Weekly_snapshot.t` gains an additive `warnings : string list [@sexp.default
[]]` field (no version bump; pinned that the actual committed
`dev/weekly-picks/7f24f2c8d/2026-07-17.sexp` — the file at the center of the
incident — still parses). `Report_renderer` gains a `## Warnings` section
(bulleted, `(none)` when empty). Armed in
`dev/weekly-picks/live-config-overrides.sexp` at the issue's own suggested
threshold (`min_bars=10`, `window_trading_days=15`). Out of scope (per issue
#2083): fix 2 (rename tracking on fetch) and fix 3 (spike-bar "data-suspect"
flag) — separate, larger changes. Tests: `Sparse_tail_gate` unit tests
(disabled/armed/dense/sparse/no-bars/warning-text, incl. an explicit
"~6 bars in ~15 trading days with a spike near the edge" SNSE-shaped
regression fixture) + generator-level tests (default-config carries the gate
disabled; disabled run is bit-identical on a fixture that would be dropped if
armed; armed+sparse drops + warns; armed+dense retains) + an overrides-loader
test proving the arming path resolves through the genuine loader/validator.
Every new assertion was mutation-tested (break the implementation, confirm
red, restore) — see PR body for the per-test mutation log. `dune build @fmt`
+ `dune build` + full `dune runtest` all green (a nesting-linter violation in
the first draft of `Sparse_tail_gate` was fixed by splitting the disabled/
armed branches and the message-formatting body into named helpers).

**2026-07-24 (live execution protocol — Phase A+B, PR `feat/picks-protocol`):**
Weekly picks are now executable end-to-end and held positions thread week to
week. **Phase A (portfolio state):** new `Weinstein_snapshot_gen.Live_portfolio`
module — a human-editable sexp file (`cash`, `as_of`, `positions` of
`{symbol; shares; entry_price; entry_date; stop_price}`); template committed at
`dev/weekly-picks/portfolio.sexp` (user must set real `cash`). The generator
gains `--portfolio PATH`: it prices each held position via the same `Bar_reader`
(current close as-of the run date), computes unrealized %, and recomputes the
Weinstein support-floor stop (`Weinstein_stops.compute_initial_stop_with_floor`,
shown beside the current stop with the delta — no new stop logic; full trailing
state machine deferred to Phase C). Held tickers are excluded from candidate
output. **Phase B (sized instructions):** each long candidate is sized via the
existing `Portfolio_risk.compute_position_size` (fixed-risk sizing, MIRRORING the
backtest — risk-normalized, NOT equal-sized; a tighter stop earns more shares).
The report gains an `Instruction` column (`BUY STOP <n> sh @ $<entry> … place
SELL STOP @ $<stop>, GTC …`); 0-share results render their reason; without
`--portfolio` candidates size against a $100k template and are stamped `UNSIZED`.
New `Trade_sizing` helper module. Schema: `candidate` + `held_position` gained
additive `[@sexp.default]` fields (no version bump) — old snapshots still load
(pinned test + verified on committed `7f24f2c8d/2026-07-17.sexp`). Plan:
`dev/plans/weekly-picks-execution-protocol-2026-07-24.md`. All weinstein tests +
full build green, `@fmt` clean.

**2026-07-24 (report rendering fixes, P1 #2050 follow-up):** Two display-only
fixes to the weekly report (PR `feat/picks-render-fixes`). (1)
`Report_renderer.render` now renders each candidate's `resistance_grade` in a
new Markdown `Resistance` column (long + short candidate tables); it was
sexp-only before. `None` renders as `-`. (2) `weekly_snapshot_generator` strips
the module-qualified `Weinstein_types.` prefix that `[@@deriving show]` emits —
grade strings are now the bare quality label (e.g. `Heavy_resistance (0.82)`)
via a small explicit `_overhead_quality_label` (mirrors `_regime_label`; the
`[@@deriving show]` on the type is untouched). No scoring/analysis/default
changes. Tests: new renderer + generator assertions pin the clean unprefixed
string and the `None -> "-"` cell; `dune runtest trading/weinstein/snapshot`
passes, `@fmt` clean.

**2026-06-28 (snapshot-warehouse fast input path):** `generate_weekly_snapshot`
now has a fast bar-source path so a weekly screen runs in seconds instead of the
prior ~2h20m (the CSV path loads ALL bars into memory via
`Bar_reader.of_in_memory_bars` every run — unusable for a 26-week sweep). PR
`feat/weekly-snapshot-mode`. New lib module
`Weinstein_snapshot_gen.Snapshot_warehouse_reader` opens a pre-built snapshot
warehouse (`manifest.sexp` + per-symbol `.snap`), builds a real trading-day
calendar, and returns a `Bar_reader.of_snapshot_views ~calendar` reader — the
same on-demand LRU-streamed reader the backtest runners use. The bin gains a
`--bars-snapshot-dir DIR` input flag, mutually exclusive with the existing
`--bars` CSV path (errors clearly if both/neither given); the CSV path is
unchanged (back-compat). **TDD parity pin:** a new test builds a tiny warehouse
end-to-end with the real `build_snapshots` build path (`Build_runner.build`)
over fixture synthetic bars in a temp CSV store, reads it via
`Snapshot_warehouse_reader`, and asserts the generated `Weekly_snapshot.t` is
**identical** to the in-memory-CSV-path snapshot — proving the build→read
pipeline before we build a large warehouse. 9 tests pass (7 existing + 2 new).
No screener/strategy logic changed; no core-module changes.

(Owner: feat-weinstein per #778 scope expansion.)

**2026-06-14 (M6.6 generator):** `generate_weekly_snapshot` bin SHIPPED via
PR (`feat/weekly-snapshot-generator`). The missing producer is built: a new
`weinstein_trading.snapshot_gen` lib (`Weekly_snapshot_generator.generate`)
runs the existing screener cascade (`Macro.analyze` → `Sector.analyze` →
`Stock_analysis.analyze` → `Screener.screen`) on cached bars for one as-of date
and assembles a `Weekly_snapshot.t`; the CLI bin loads a Pinned universe + CSV
bars, builds a `Bar_reader`, and `Snapshot_writer.write_to_file`s it to
`dev/weekly-picks/<system-version>/<date>.sexp`. No strategy logic
reimplemented — pure wiring of existing public primitives; no core-module
changes. Remaining M6.6 (live DATA_SOURCE / cron / alerts / trading-state) stays
deferred.

**2026-06-14 rework (PR #1588):** CI `build-and-test` tripped the repo nesting
linter (a full-runtest target the scoped `dune runtest` skipped) on three
helpers in `weekly_snapshot_generator.ml`. Fixed by extracting the innermost
nested blocks into named private `_helper`s (`_set_sector_ctx_for_etf`,
`_analyze_ticker`, `_etf_rating` + `_sector_name_if_rated`) — pure structural
refactor, no behavior change; full `dune runtest` now passes including the
nesting linter.

**2026-06-14 test follow-up (PR #1596, `feat/weekly-snapshot-generator`):**
test-only follow-up to #1588 closing two gaps vs the M6.6 brief: (a) added the
**C2 macro-gate pin** — `test_bearish_macro_blocks_longs` uses a `Declining`
synthetic index so the macro gate reads `Bearish` and asserts zero long
candidates (the merged suite had no bearish fixture); (b) fixed three P6
`equal_to true` matchers wrapping boolean predicates (entry>0, stop<entry,
regime-known) to use real matchers (`gt`, an `(entry - stop)` projection,
`matching` over the closed label set). 7 tests pass; no lib/bin change.

Track created 2026-05-02 to absorb M6.1–M6.5 (verification harness via incremental processing). Plan: `dev/plans/m6-weekly-snapshot-verification-2026-05-02.md`. Authority: `docs/design/weinstein-trading-system-v2.md` §7 sub-milestones M6.1–M6.5 (added 2026-05-02).

**2026-06-14 reconcile (orchestrator):** M6.1–M6.5 are SHIPPED on main —
`trading/trading/weinstein/snapshot/lib/{weekly_snapshot,snapshot_writer,snapshot_reader,forward_trace,pick_diff,report_renderer,round_trip_verifier}.{ml,mli}`
plus bins `trace_picks`, `diff_picks`, `render_weekly_report`,
`verify_corporate_actions`. The remaining gap is **M6.6**: there is no
*generator* that runs the screener+strategy on cached data, builds a
`Weekly_snapshot.t`, and writes it to `dev/weekly-picks/<version>/<date>.sexp`
(the dir does not yet exist). The consumers (trace/diff/render) all read an
existing pick file; nothing produces one. The concrete next step is a small
`generate_weekly_snapshot` bin (`--as-of/--universe/--bars/--snapshot-dir`).
See `dev/notes/next-session-priorities-2026-06-14.md` §3. **M6.6 is DEFERRED
pending a human scope green-light** (the live-cycle scheduling decision is an
open Question to the maintainer — carried in the daily summary).

## Interface stable
NO

M6.1–M6.5 interfaces (`Weekly_snapshot.t`, writer/reader, forward-trace,
pick-diff, report-renderer) are merged and stable; the remaining M6.6
`generate_weekly_snapshot` generator interface is not yet built, so the
track interface is not fully stable.

The reframe: **weekly picks are first-class durable artifacts before they're inputs to live trading.** This subsystem is a verification harness first; the M6.6 live cycle is wiring on top.

## Blocked on
- None. Prior M5.1 blocker (`split_day_stop_exit:1:post_split_exit_no_orphan_equity`) was RESOLVED by PR #752. Track is owner-pending: feat-weinstein not currently dispatched on M6.x items.

## Scope

### M6.1 — Weekly snapshot generator

`trading/trading/weinstein/snapshot/lib/{weekly_snapshot,snapshot_writer,snapshot_reader}.{ml,mli}` (new). Format: `dev/weekly-picks/<system-version>/<date>.sexp` containing macro context, sector strength, ranked candidates with score/grade/entry/stop/rationale, held positions. Schema-versioned. Round-trip stable.

Wired into `Simulator.step` via gated `--write-snapshots <dir>` flag.

### M6.2 — Forward-trace renderer

`trading/trading/weinstein/snapshot/lib/forward_trace.{ml,mli}` (new). Pure function `(picks, bars, horizon_days) → per-pick outcome`. Reports max favorable, max adverse, final price, stop-trigger, winner/loser. Uses adjusted_close.

CLI: `trace_picks <pick-file> <bars-dir> --horizon 20`.

### M6.3 — Cross-version pick diff

`trading/trading/weinstein/snapshot/lib/pick_diff.{ml,mli}` (new). Set/map operations on parsed snapshots. Reports `added_in_v2`, `removed_in_v2`, score deltas, rank changes, macro_change.

CLI: `diff_picks <v1.sexp> <v2.sexp>`.

### M6.4 — Split/dividend verification harness

EODHD `/splits` + `/div` endpoints (new wiring; data already in plan). Replay 5 known scenarios:

| Symbol | Date | Action |
|---|---|---|
| AAPL | 2020-08-31 | 4:1 forward split |
| TSLA | 2020-08-31 | 5:1 forward split |
| GOOG | 2022-07-18 | 20:1 forward split |
| NVDA | 2024-06-10 | 10:1 forward split |
| KO | 2024 | quarterly cash dividend |

Assertions: adjusted_close round-trip, position quantity post-split, total cost basis preserved, no phantom pick churn, stop-loss adjusted, dividend cash injected for KO.

Wired into `dune runtest` so CI catches G14-class regressions automatically.

### M6.5 — Weekly report renderer

`trading/trading/weinstein/snapshot/lib/report_renderer.{ml,mli}`. Pure `Weekly_snapshot.t → string` (markdown). Same shape as eventual M6.6 live report. Display limits are configurable (`render ?long_limit ?short_limit`, default long 7 / short 5); a truncated table appends a tie-honesty note stating how many hidden names tie the cutoff score (#1826). Display-only — the `.sexp` retains the screener's full capped list.

CLI: `render_weekly_report <pick-file> [-long-limit N] [-short-limit N]` → stdout.

### M6.6 — DEFERRED

Live `DATA_SOURCE` impl, cron wrapper, alert dispatch, trading-state durability. ~5 sessions once verification phase is solid.

## In Progress
- None.

## Next Steps

M6.1–M6.5 are SHIPPED (see the 2026-06-14 reconcile above). M6.6's generator is
now also SHIPPED (`generate_weekly_snapshot` bin +
`weinstein_trading.snapshot_gen` lib, PR `feat/weekly-snapshot-generator`). The
remaining queue:

1. **[M6.6, DONE]** ~~`generate_weekly_snapshot` bin~~ — SHIPPED 2026-06-14.
   Runs the existing screener cascade on cached data, assembles
   `Weekly_snapshot.t`, and `Snapshot_writer.write_to_file`s it to
   `dev/weekly-picks/<version>/<date>.sexp`.
1b. **[snapshot-mode, DONE]** ~~`--bars-snapshot-dir` fast input path~~ — SHIPPED
   2026-06-28 (`feat/weekly-snapshot-mode`). Next: build a large warehouse over
   the live universe with `build_snapshots` and run a real multi-week sweep
   (the parity test already proved the build→read pipeline on a tiny fixture).
2. **[M6.6, optional]** generate + commit a first baseline pick record to diff
   future weeks against (the stretch item; deferred — needs a committed
   universe + cached bars to run against, not done in the generator PR).
3. **[M6.6, deferred]** live `DATA_SOURCE` impl, cron wrapper, alert dispatch,
   trading-state durability (see §Out of scope).
4. **[#2083 F2, detection SHIPPED; application OPEN]** rename tracking. The
   returns-basis detector + its default-off pipeline wiring landed on
   `feat/universe-rename-tracking` (see the 2026-07-26 entry above). What
   remains, in priority order:
   a. **EODHD symbol-change feed** — the other half of the issue's proposal.
      Needs `EODHD_API_KEY`, which the GHA container does not have; a
      maintainer-local or ops-data task. It is the only mechanism that catches
      a clean cut-over with zero overlap between the two legs.
   b. **Bar-store-wide scan + universe re-pin** — the detector only sees the
      symbols it is handed, and in the actual incident FTH was absent from the
      bar store entirely, so a run over the 07-17 pinned universe would NOT
      have caught SNSE -> FTH. Closing that needs a scan of the whole store and
      a re-pin, which is maintainer judgement over real data.
   c. **Carry history under the new ticker** (merge/rename the on-disk series) —
      deliberately untouched; the detector emits the mapping, applying it is a
      separate, destructive operation.
   d. **Arm it** — pick `rename_detect_min_overlap_days` /
      `rename_detect_match_fraction` from one live dry run over the real
      universe (false-positive check against spin-offs and dual listings),
      record a ledger ACCEPT, then add them to
      `dev/weekly-picks/live-config-overrides.sexp` (R3).

4b. **[decision item, for review]** `Rename_detector` scores a pair by calling
   `Twin_detector.detect` on it. Cleaner long-term would be to extract
   `Twin_detector`'s `_returns_match_fraction` into a shared scoring module both
   detectors call. Not done unilaterally (CLAUDE.md: propose, don't execute,
   refactors of existing working modules). The only change made to
   `snapshot_warehouse` was giving `twin_detector` a `public_name` so a public
   library may depend on it — packaging only, no code change.
4c. **[Phase C, remaining]** the two Phase C bullets NOT in PR #2105, each its
   own PR because each is a behavioural change rather than presentation:
   a. **[DONE]** ~~`record_fill` CLI that edits
      `dev/weekly-picks/portfolio.sexp`~~ — PR #2117 (`feat/record-fill-cli`),
      plan `dev/plans/record-fill-cli-2026-07-27.md`. Three subcommands
      (`record` / `close` / `adjust`) over a new pure `Portfolio_edit` module,
      plus `Live_portfolio.save` / `to_file_contents` / `header`. Cash moves
      with the position list in every operation, so the two cannot drift apart.
   b. Full trailing-stop state machine threaded across weeks (persist
      `stop_state` per held position) rather than the recomputed-floor
      side-by-side Phase A uses (plan §Phase C bullet 4). This is the one that
      changes what the report *says*, not how it looks.
   Also deferred from #2105: writing the HTML report to disk alongside the
   `.md` in the weekly pipeline (today `-html` prints to stdout, so the caller
   redirects), and a `sectors_weak` section (Markdown has none either — parity
   was kept deliberately).
5. **[#2083 F3 follow-up]** decide an arming threshold for
   `spike_bar_threshold_pct` and arm it in
   `dev/weekly-picks/live-config-overrides.sexp` (the flag ships default-off;
   the incident bar was +58%, a 25-30% threshold is the obvious first
   candidate). Requires one live-report dry run to check the false-positive
   rate on genuine gap-up breakouts before arming.

## Parallelism
M6 work runs in parallel with `experiments` track M5.2 — no shared source files.

## Out of scope

- Live data wiring (M6.6).
- Cron / alert dispatch / webhook delivery (M6.6).
- Trading-state persistence across process restart (M6.6).
- Mid-week stop monitor (M6.6).
- Real-time intraday updates — we trade weekly.

**2026-07-27 (Next-Steps for orchestrator):**
- [non-blocking] Issue #2103 entry reconciliation (valid-stop /
  through-entry / EXTENDED classes; re-size on expected fill; suppress
  extended tickets) — correctness half of Phase C; spec + specimens in the
  issue. Do FIRST.
- Phase C: CLAIMED by GHA (branch feat/picks-phase-c, 2026-07-27 02:13Z) —
  design reference committed at
  `dev/notes/weekly-report-design-reference-2026-07-27.html`; include #2103
  reconciliation (see issue comment).
  — design reference committed at
  `dev/notes/weekly-report-design-reference-2026-07-27.html`; plan §Phase C
- Fence: if a local session claims either item it will mark this file per
  the takeover protocol.
