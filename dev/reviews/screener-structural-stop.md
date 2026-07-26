# Structural QC review — screener-structural-stop (PR #2091)

Reviewed SHA: b8a11c5bacaf0d813de7664e9f9abe8abcde4951

## Initial review (SHA 4968f5253b4f7ffe0f0d1a9935f1065014b13182)

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Orchestrator pre-run, exit 0 |
| H2 | dune build | PASS | Orchestrator pre-run, exit 0 |
| H3 | dune runtest | PASS | Orchestrator pre-run, exit 0, zero `^FAIL:` lines |
| P1 | Functions <= 50 lines (linter) | PASS | Spot-checked new functions (report_renderer, stop_recompute) — all well under limit |
| P2 | No magic numbers (linter) | PASS | H3 green |
| P3 | Configurable thresholds in config record | PASS | `stops_config` / `initial_stop_buffer` threaded from `inputs.config`, no new hardcoded threshold |
| P4 | Public-symbol export hygiene (.mli coverage) | PASS | `stop_recompute.mli` fully documented; `weekly_snapshot.mli`/`report_renderer.mli` updated |
| P5 | Internal helpers prefixed per convention | PASS | All new private helpers underscore-prefixed; `Stop_recompute.for_candidate`/`for_held_long` correctly public/unprefixed |
| P6 | Tests conform to test-patterns.md | PASS | New tests use single `assert_that` + `all_of`/`field` composition. No P6 sub-rule violations in new/changed test lines. One pre-existing (untouched by this diff) `match Ok/Error -> assert_failure` setup helper at test_weekly_snapshot_generator.ml:96 matches the explicitly-approved "unwrap-or-fail builder" idiom, not a violation |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | PASS | None touched — all 19 files under weinstein/snapshot/**, one decision_audit test line, dev/plans, dev/status |
| A2 | analysis/ -> trading/trading/ import rule | PASS | Only dune diff adds `trading.base` and `weinstein_trading.stops` (both internal trading/trading libs) to gen/test/dune. No new analysis/ dependency introduced by this PR |
| A3 | No unnecessary modification of non-feature modules | PASS | PR file list (gh pr view --json files, 19 files) matches git diff --stat exactly — no ancestry contamination. Every file is either new, the field-owning module, a call site, the renderer, a literal-fixture site for the additive field, or docs |

### Verification highlights

- Confirmed the PR's claim that the pure screener library (`screener_scoring.ml`, `screener.ml`) and the core stop machine (`weinstein_stops.{ml,mli}`) are untouched — neither appears in the file list; both are only called from the new `stop_recompute.ml`.
- `Stop_recompute.for_held_long` is a genuinely verbatim relocation of the removed `_recommended_stop` — same computation, same empty-bars short-circuit, same values threaded at the call site. `weekly_snapshot_generator.ml` sits at 299 lines post-extraction (just under the stated 300-line limit); no limit bump, no `@large-module` marker added — correct instinct per code-health-discipline.md.
- Verified exactly 8 literal `Weekly_snapshot.candidate` construction sites now carry `stop_is_structural` (1 production site in `snapshot_display.ml` + 7 test-fixture files, with `test_round_trip.ml` contributing 2 literals) — matches the PR body's claim.
- `Support_floor.find_recent_level` call in `stop_recompute.ml` uses the correct label names (`~min_pullback_pct`, `~lookback_bars`) matching its actual `.mli` signature.
- `dev/status/_index.md` untouched; only the owning track file `dev/status/weekly-snapshot.md` was updated, per feat-agent-dispatch.md §4.
- Report renderer asterisk/footnote behavior is genuinely test-pinned (exact row-string + footnote-presence assertions), not just claimed.

### Quality Score

5 — Clean, well-scoped fix; every specific claim in the dispatch brief was verified against the actual diff and checked out; tests are well-composed; no hygiene shortcuts.

### Verdict

APPROVED

---

## Delta re-review — rework iteration 1 (4968f525 → b360baf8)

Trigger: qc-behavioral returned NEEDS_REWORK (2/5) at SHA 4968f525 with two
findings — `Stop_recompute.for_candidate ~side:Short` had zero test coverage,
and the documented "no resident daily bars → candidate unchanged" guard on
`for_candidate` (as opposed to its sibling `for_held_long`) was untested.

Feat-agent pushed commit `b360baf8` — `test(review): pin short-side stop
overlay + no-bars guard (QC rework iteration 1)`.

### Scope of the delta

```
git diff --stat 4968f525..b360baf8
 .../gen/test/test_weekly_snapshot_generator.ml     | 78 ++++++++++++++++++++++
 1 file changed, 78 insertions(+)
```

Genuinely **test-only**. Single file, additive only (no deletions, no
production `lib/` code touched). `git diff --name-only 4968f525..b360baf8`
confirms exactly one path. `git diff --stat origin/main...b360baf8` shows the
same 19-file shape as the original PR plus these 78 lines — no new files, no
scope creep.

### Delta Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Not re-run locally (dune gate forbidden per dispatch — see CI note). GitHub CI `build-and-test` completed/success at tip b360baf8, which includes fmt check. |
| H2 | dune build | PASS | GitHub CI `build-and-test` completed/success at b360baf8. |
| H3 | dune runtest | PASS | GitHub CI `build-and-test` completed/success at b360baf8; `perf-tier1-smoke` completed/success too. |
| P1 | Functions <= 50 lines | PASS | Both new test functions (`test_short_candidate_stop_recomputed_above_entry`, `test_candidate_without_bars_unchanged`) plus the two new helpers (`_mk_candidate`, `_stops_cfg`) are each well under 25 lines. |
| P2 | No magic numbers | PASS/NA | New literals (`85.0`, `100.0` default, `0.92`, `46.0`, `50.0`) are all in a test file; `linter_magic_numbers.sh` scope is explicitly "lib .ml files" only — test files are out of scope by design. |
| P3 | Configurable thresholds in config record | NA | No new tunable introduced; test-only. |
| P4 | .mli coverage | NA | Test files carry no `.mli`; no production signature changed. |
| P5 | Internal helpers prefixed per convention | PASS | `_mk_candidate`, `_stops_cfg` both underscore-prefixed per convention. |
| P6 | Tests conform to test-patterns.md | PASS | Both new tests use exactly one `assert_that` per value under test. `test_short_candidate_stop_recomputed_above_entry` uses `field` + `gt (module Float_ord)` (idiomatic per test-patterns.md item 6, not a manual `>` check). `test_candidate_without_bars_unchanged` composes two field checks via `all_of` — single `assert_that`, no nesting. Sub-rule 1 (`List.exists ... equal_to (true\|false)`): no hits. Sub-rule 2 (bare `let _ = ...on_market_close/.run` without assertion): no hits — both calls to `Stop_recompute.for_candidate` are bound to `c` and immediately asserted on. Sub-rule 3 (bare `match ... Error -> assert_failure` / unasserted `Ok`): no hits in the new lines. Clean. |
| A1 | Core module modifications | PASS | Delta touches only `trading/trading/weinstein/snapshot/gen/test/test_weekly_snapshot_generator.ml`; no Portfolio/Orders/Position/Strategy/Engine file in the delta. |
| A2 | analysis/ -> trading/trading/ import rule | NA | No dune file, no import changed in the delta. |
| A3 | No unnecessary modification of non-feature modules | PASS | Single file, same module the two QC findings were about; no unrelated-file drift. `dev/status/_index.md` confirmed NOT touched (absent from both the delta diff and the full `origin/main...b360baf8` diff). |

### Verification highlights

- `test_short_candidate_stop_recomputed_above_entry` closes CP1 (qc-behavioral finding 1): seeds a deliberately long-shaped stop (`entry *. 0.92`, i.e. below entry) on a `Short`-side candidate, then asserts the recomputed stop is `gt entry` — this would fail if the overlay ignored `side` and left/produced a below-entry stop, so the test has bite, not just an "unchanged" tautology.
- `test_candidate_without_bars_unchanged` closes CP4 (qc-behavioral finding 2): calls `for_candidate` (not the sibling `for_held_long`, which was the only function previously covered for this guard) with `Bar_reader.empty ()` and asserts both `stop` and `stop_is_structural` are byte-identical to the seeded input — pins the specific guard qc-behavioral flagged as untested.
- Both new tests wire through `_stops_cfg`, which reuses `Weinstein_strategy.default_config` — no new config-construction pattern introduced, consistent with existing tests in the same file.
- CI: `build-and-test` and `perf-tier1-smoke` both `completed`/`success` at tip `b360baf8c2d5c0fb0fe92f8243544b27ea1bba23` (checked via GitHub check-runs API, read-only, no local dune invocation per dispatch constraints).

### Quality Score

5 — The rework is a precisely-targeted, minimal, test-only patch that closes exactly the two gaps qc-behavioral named, with genuinely discriminating assertions (not tautological "didn't crash" checks). No scope creep, no new hygiene issues.

### Verdict

APPROVED

---

# Behavioral QC review — screener-structural-stop (PR #2091)

## Re-review — rework iteration 1 (4968f525 → b360baf8)

Reviewed SHA: b360baf8c2d5c0fb0fe92f8243544b27ea1bba23

Prior pass (SHA 4968f525) returned NEEDS_REWORK (2/5) with two findings:
1. `Stop_recompute.for_candidate ~side:Short` untested (CP1 / L1-short).
2. `for_candidate`'s "no resident daily bars → unchanged" guard untested (CP4).

Feat-agent pushed commit `b360baf8` — `test(review): pin short-side stop
overlay + no-bars guard (QC rework iteration 1)` — one file, 78 additive
lines in `test_weekly_snapshot_generator.ml`.

### Finding 1 — STILL OPEN

`test_short_candidate_stop_recomputed_above_entry` calls
`Stop_recompute.for_candidate` **directly** with `~side:Short`. It genuinely
pins the primitive (seeds a long-shaped stop, asserts the recomputed value is
`gt entry` — a side mixup inside `for_candidate` would fail this). But it
never invokes `generate`, so it does not exercise the actual new wiring the
finding was about:

```
weekly_snapshot_generator.ml:283-286
  let short_candidates =
    List.map result.short_candidates ~f:(fun c ->
        Snapshot_display.candidate_of_scored c
        |> _overlay_structural_stop ~inputs ~side:Trading_base.Types.Short)
```

The only `short_candidates` assertion anywhere in the suite is `size_is 0` on
an empty universe. Reverting the overlay call at that site (or swapping
`~side:Short` for `~side:Long` there) would not be caught by any test.
Additionally, the new test asserts only `stop > entry` (direction) — never
`stop_is_structural = true` nor an exact/correct value, weaker than the
original required fix ("qualifying counter-rally → `stop_is_structural =
true`, correct stop value"). The `is_structural = true` branch remains
untested for either side, before and after this rework.

Required fix: add a `generate`-level short-qualifying scenario test
(mirroring `test_breakout_stop_below_entry`) reading `snap.short_candidates`,
plus an explicit `stop_is_structural = true` assertion for at least one
qualifying-counter-move case.

### Finding 2 — CLOSED

`test_candidate_without_bars_unchanged` calls `for_candidate` (not the
sibling `for_held_long`) with `Bar_reader.empty ()`, asserting `stop = 46.0`
and `stop_is_structural = false` unchanged. `Bar_reader.empty ()`'s
`daily_bars_for` always returns `[]` (verified in `bar_reader.ml:107-115`).
Checked for vacuousness: with the guard removed, the fallback path would
compute `entry_price *. fallback_buffer = 50.0 *. 1.02 = 51.0`, then
`compute_initial_stop`'s `delta = min_correction_pct /. 2.0 = 0.04` →
`raw_stop = 51.0 *. 0.96 = 48.96` (before round-number nudge) — clearly
`<> 46.0`. The test would go red if the guard were deleted. Not vacuous.

### CP1–CP4 re-applied

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | New `.mli` docstring claims pinned by tests | FAIL | "No bars → unchanged" now PASS. "`stop_is_structural` true iff a qualifying counter-move found" — the `true` branch remains unpinned for either side; short-side "bars present" claim only indirectly touched (direction-only). |
| CP2 | PR body Test-plan claims match committed tests | PASS | Unchanged claims (fallback-differs-from-proxy, sizing-uses-overlaid-stop) still hold; no new PR-body claim introduced by this delta. |
| CP3 | Pass-through/identity tests pin identity, not size | PASS | `test_candidate_without_bars_unchanged` asserts exact field equality. |
| CP4 | Docstring-named guards have a discriminating test | PASS (no-bars guard) / FAIL (residual `is_structural=true` branch) | See Finding 1/2 detail above. |

### Domain checklist — L1 citation check

Opened `docs/design/weinstein-book-reference.md` §5.1 (lines 224-230)
directly: it documents ONLY the long-side rule. The short-side symmetric
rule ("Initial buy-stop: above prior rally peak") lives in §6.3 (lines
339-344), a different section. Opened `support_floor.mli` (pre-existing,
confirmed unmodified by this PR via `git show 96c4c5ff:...`): it attributes
BOTH long and short rules to "Ch. 6 §5.1" — a pre-existing misattribution not
introduced by PR #2091. Flagged as a non-blocking documentation follow-up,
out of this PR's scope. The PR body's own "Authority" section only quotes
§5.1 for the long-side wording and does not repeat the mis-citation. The
underlying short-side computation is book-faithful (§6.3); only the docstring
citation is wrong, and it predates this PR.

## Quality Score

2 — Finding 2 closed with genuine, hand-verified mutation sensitivity.
Finding 1 addressed at the wrong altitude: pins the primitive but not the
actual new `generate` wiring that motivated the finding, and drops the
`stop_is_structural`/exact-value requirement from the original fix.

## Verdict

NEEDS_REWORK

---

## Structural QC — delta re-review 2 (b360baf8 → b8a11c5b)

Reviewed SHA: b8a11c5bacaf0d813de7664e9f9abe8abcde4951

### PROCESS FLAG — PR #2091 already merged at the pre-rework tip

**Discovered during this review, not part of the requested delta scope but
too important to omit:** PR #2091 is `closed` / `merged: true` (squash commit
`2bcf5b33` on `main`, `merged_at: 2026-07-26T16:47:03Z`), and its recorded
`head.sha` is **`b360baf8`** — the tip qc-behavioral returned NEEDS_REWORK
against. In other words, **the PR merged carrying the open qc-behavioral
finding**, before rework iteration 2 (`b8a11c5b`, reviewed below) was pushed.

Verified via GitHub API (`pulls/2091`, `git/ref/heads/feat/screener-structural-stop`)
and by inspecting `main`'s history directly: `main`'s
`weekly_snapshot_generator.ml` (commit `2bcf5b33`, log entry "fix(picks):
compute structural stop for weekly-pick candidates (#2084 F2) (#2091)") does
carry the correct `_overlay_structural_stop ~side:Short` call site — so there
is **no production regression on `main`**. But the specific test-coverage gap
qc-behavioral flagged (the `generate`-seam short-side wiring was unpinned, so
reverting that call site would stay green) is **still live on `main` today**,
because rework iteration 2 — the commit that closes it — was pushed to the
branch *after* the PR had already closed, and is not part of any open PR.

`b8a11c5b` sits orphaned on `feat/screener-structural-stop` with zero
check-runs registered against it (`commits/.../check-runs` → `total_count: 0`)
and zero commit-status entries (`commits/.../status` → `"state": "pending"`,
empty `statuses`) — consistent with "no PR/CI is currently watching this
commit," not a CI failure.

**Orchestrator action needed:** open a fresh PR from `feat/screener-structural-stop`
(or cherry-pick this one test-only commit onto a new branch off current
`main`) to actually land the fix. Re-approving #2091 has no effect — GitHub
will not reopen a merged PR on a new push.

### Delta scope (b360baf8 → b8a11c5b)

```
 dev/status/weekly-snapshot.md                                       |  14 ++
 .../weinstein/snapshot/gen/test/test_weekly_snapshot_generator.ml   | 144 +++++++++++++++++++++
 2 files changed, 158 insertions(+)
```

Confirmed via `git diff --stat b360baf8..b8a11c5b` (read-only; working tree
untouched throughout — no `git checkout`/`reset` used). No `lib/` file, no
`.mli` file, and no `dune` file appears in the delta
(`git diff b360baf8..b8a11c5b -- '**/dune'` is empty) — the "production code
byte-identical" and "dune dep temporarily added then reverted, not committed"
claims both check out.

### Delta Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1/H2/H3 | dune build @fmt / build / runtest | PASS | Not re-run locally per dispatch constraint (no dune in this container). Feat-agent reported `GATES_EXIT=0` for the chained gate command at this tip. GitHub check-runs/status API shows nothing registered against `b8a11c5b` (orphaned branch, no PR wired to it post-merge — see PROCESS FLAG) — absence of CI here is explained by the process issue, not treated as a red flag. |
| P1 | Functions <= 50 lines | PASS | New helpers (`_reprice`, `_short_bars`, `_short_rally_high`, `_short_bar_reader`) and the new test function are all well under limit by inspection. |
| P2 | No magic numbers (lib) | NA | Delta is test + status docs only, no `lib/` touched. |
| P3 | Config completeness | NA | No new tunable introduced. Fixture-local constants (`_rally_bars = 9`, `_rally_daily_gain = 0.015`, `_breakdown_volume_bars = 15`, `_breakdown_volume_mult = 3`) are test-fixture parameters with inline rationale comments, not production thresholds. |
| P4 | .mli coverage | NA | No `.mli` in delta. |
| P5 | Internal helper naming convention | PASS | All new helpers/values underscore-prefixed (`_short_symbol`, `_short_start_date`, `_short_syn_config`, `_reprice`, `_rally_bars`, `_rally_daily_gain`, `_breakdown_volume_bars`, `_breakdown_volume_mult`, `_short_bars`, `_short_rally_high`, `_short_bar_reader`). |
| P6 | test-patterns.md conformance | PASS | `test_short_candidate_overlay_applied_at_generate_seam` uses exactly one `assert_that shrt (is_some_and (all_of [ field ...; field ... ]))` — single `assert_that`, composed via `all_of` + `field`, no nested `assert_that`. Sub-rule 1 (`List.exists .* equal_to (true\|false)`): no hits anywhere in the file. Sub-rule 2 (bare `let _ = ...on_market_close`/`.run`): no hits. Sub-rule 3 (bare `Error -> assert_failure` w/o asserting `Ok` branch): one hit at line 98, pre-existing, outside this delta (already reviewed/approved in the initial review as the "unwrap-or-fail builder" idiom). |
| A1 | Core module modifications | NA | None touched. |
| A2 | analysis/ → trading/trading/ import rule | PASS | No `dune` file changed in the delta — verified directly, so the agent's "temporarily added then reverted" analysis-deps claim is moot: nothing analysis-related is actually committed. Nothing to flag. |
| A3 | No unnecessary modification of non-feature modules | PASS | Only the test file that already owns this suite + the track's own status file changed. |
| — | `dev/status/_index.md` untouched | PASS | Confirmed empty diff for that path across the delta. |

### Quality Score

5 — The delta itself is exactly what was promised: a single well-documented
test closing the `generate`-seam gap qc-behavioral flagged, no production or
dune changes, clean test-pattern conformance. The only reason this isn't
simply "shipped" is the external process issue (PR merged before this landed)
detailed above — not a defect in this diff.

### Verdict

APPROVED

(Applies to the delta's structural quality only. Per the PROCESS FLAG above,
this verdict cannot be effectuated on PR #2091 itself since it is already
closed/merged — a new PR/cherry-pick is required to land the fix on `main`.)

---

## Behavioral QC — re-review 2 (b360baf8 → b8a11c5b)

Reviewed SHA: b8a11c5bacaf0d813de7664e9f9abe8abcde4951

### PROCESS FLAG — read this first (confirms qc-structural's independent finding)

PR #2091 is already `closed`/`merged: true` (squash commit `2bcf5b33` on
`main`, `merged_at: 2026-07-26T16:47:03Z`). Its recorded `head.sha` is
`b360baf8` — the iteration-1 tip I returned NEEDS_REWORK against, with
Finding 1 explicitly STILL OPEN. Verified independently: `git diff 2bcf5b33
b360baf8 --stat` is empty — the tree merged into `main` is byte-identical to
`b360baf8`. `b8a11c5b` (this review's assigned SHA) is not an ancestor of
`origin/main` and sits orphaned on `feat/screener-structural-stop` with zero
registered check-runs and an empty commit-status. **Main shipped with
Finding 1's test-coverage gap unresolved** (no production regression — the
merged code does call `_overlay_structural_stop ~side:Short` correctly — but
the regression *guard* against re-breaking it is absent from `main`).
Re-approving #2091 has no effect; a follow-up PR or cherry-pick of the
`b8a11c5b` test-only delta onto current `main` is required.

### Finding 1 — CLOSED on the code at b8a11c5b (not yet true of `main`)

`test_short_candidate_overlay_applied_at_generate_seam` now drives through
`_generate` (the real seam), not `Stop_recompute.for_candidate` directly.
Confirmed non-vacuous: the assertion is `assert_that shrt (is_some_and
(all_of [...]))` where `shrt = List.find snap.short_candidates
~f:(symbol = "SHRT")` — an empty/missing candidate makes `is_some_and` fail
outright, so the test cannot pass on a vacuous fixture.

Traced the fixture against the actual admission code (not taken on faith):
early-Stage-4 `weeks_declining <= 4` scoring signal
(`screener_scoring.ml:214`) gated by `Stock_analysis.is_breakdown_candidate`
(`screener.ml:206`, `screener_admission.ml:131`); `min_correction_pct = 0.08`,
`support_floor_lookback_bars = 90` (`stop_types.ml:56,61`) match the fixture's
own comments; `Support_floor.find_recent_level ~side:Short` anchors on the
trough and searches forward for the rally peak (confirmed by reading
`_anchor_reader`/`_counter_reader`/`_anchor_offset` in `support_floor.ml`
directly) — a ~13% counter-rally clears the 8% pullback gate with room to
spare.

Mutation reasoning (reasoned from source, not executed — no `dune` in this
container):
1. Revert to bare `List.map ... candidate_of_scored`: `stop_is_structural`
   hardcodes to `false` in `snapshot_display.ml:67` — first matcher fails
   unconditionally, no arithmetic dependency.
2. Flip `~side:Short` -> `~side:Long`: with `Long`, the primitive returns the
   correction low (below the trough, since `compute_initial_stop` places the
   long stop at `reference_level * (1 - delta)`), which is always `<
   trough < rally_high` by construction — the long-mutation stop is
   structurally guaranteed to fall outside `[rally_high, rally_high*1.10]`
   independent of exact fixture numbers. The agent's reported value (63.875
   vs. band [77.77, 85.55]) is consistent with, not merely asserted by, this
   argument.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | `.mli` claims -> tests | PASS | `stop_recompute.mli`'s three-way claim ("`stop_is_structural` true iff qualifying counter-move found, false otherwise") now has all three legs pinned: long/primitive-direct (iteration 0), short/generate-seam (this iteration, closes the prior gap), no-bars-guard (iteration 1). |
| CP2 | PR body Test Plan -> tests | PASS | PR body predates this rework and claims nothing about a short-side generate-seam test; nothing new to falsify. Originally-claimed items unchanged and still satisfied. |
| CP3 | Pass-through/invariant identity tests | NA | No pass-through/identity semantics in this feature. |
| CP4 | Guard claims -> tests | PASS | "No resident daily bars -> unchanged" guard pinned by `test_candidate_without_bars_unchanged`, verified non-vacuous last iteration (hand-computed guard-removed value ~48.96 vs seeded 46.0). Unchanged this delta. |

### Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core module mod strategy-agnostic | NA | `Stop_recompute` is not a core module (Portfolio/Orders/Position/Strategy/Engine); qc-structural did not flag A1. |
| S1-S6 | Stage/buy-criteria definitions | NA | Out of scope — this PR only recomputes the stop for already-produced candidates. |
| L1 | Initial stop at correct structural level | PASS | Opened §6.3 ("Short Stop (Buy-Stop) Rules"): "Initial buy-stop: above prior rally peak" — matches `compute_initial_stop`'s short branch (`reference_level *. (1 + delta)` off the rally high). Flagging a citation defect: the new test's docstring and `dev/status/weekly-snapshot.md`'s new entry both cite "§5.1" for this short-side rule, but §5.1 is the *long*-side section — correct citation is §6.3. Behavior is book-faithful; only the in-repo citation is wrong. Minor, doc-only, non-blocking. |
| L2-L4, C1-C3, T1-T3 | Trailing/state-machine/cascade/macro/stage tests | NA | Not touched by this PR. |
| T4 | Tests assert domain outcomes | PASS | Asserts `stop_is_structural = true` and a tight numeric band, not just absence of error. |

### Quality Score

4 — Non-vacuous, seam-correct fix that closes the CP1 gap cleanly; mutation
reasoning holds under direct code inspection. Docked one point for the
persisting §5.1/§6.3 citation error and because this fix never actually
reached `main` (see PROCESS FLAG).

### Verdict

APPROVED

(Applies to the code at `b8a11c5b` — Finding 1 is CLOSED on its merits. Has
no effect on PR #2091, already closed/merged at the earlier `b360baf8` tip.
A follow-up PR/cherry-pick of `b8a11c5b`'s test-only diff onto current `main`
is required before Finding 1's fix takes effect on `main`.)
