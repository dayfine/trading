Reviewed SHA: 39893ec4843d4363f0c7332bec497c2dd895f57b

## Structural QC — fix/stop-ratchet-freeze-2486

### Build & Test Gates

| Check | Status | Notes |
|-------|--------|-------|
| H1: dune build @fmt | PASS | CI green at this SHA |
| H2: dune build | PASS | CI green at this SHA |
| H3: dune runtest | PASS | Scoped `trading/weinstein/stops`: 172 tests total, all passed (11+41+4+7+6+9+10+7+77), exit 0 |

### Code Patterns & Architecture

| Check | Status | Notes |
|-------|--------|-------|
| P1: Functions ≤ 50 lines | PASS | Linter gates (fn_length_linter) included in dune build; H3 passes |
| P2: No magic numbers | PASS | magic_numbers linter included in dune build; H3 passes |
| P3: Config completeness | PASS | New flag `reset_anchor_on_stalled_cycle` is in `stop_types.mli` config record, line 293 |
| P4: Public-symbol export hygiene | PASS | Linter gates (mli_coverage) included in dune build; H3 passes |
| P5: Internal helpers prefixed | PASS | All new helpers follow `_*` convention (e.g., `_stalled_trailing` line 331) |
| P6: Test patterns | PASS | Both new test files conform: `test_stop_ratchet_freeze.ml` (7 tests), `test_variant_matrix.ml` (+39). All use single `assert_that` per value with proper matcher composition (`elements_are`, `field`, `pair`, `matching`). No sub-rule violations: no `List.exists…equal_to(true|false)`, no `let _ = …run\b`, no bare match patterns with improper error handling |
| A1: Core module modifications | FLAG | `trading/trading/weinstein/stops/` is core domain code (peer to portfolio/orders/position). Modified files: `stop_types.{ml,mli}`, `weinstein_stops.ml` (extraction), new `stop_geometry.{ml,mli}`. Flagged for qc-behavioral to verify generalizability. Not a FAIL — domain-specific stop-state-machine changes that do not leak into strategy/portfolio/engine/position boundaries |
| A2: Dependency direction | PASS | No new `analysis/` → `trading/trading/` imports outside allowlisted backtest paths. Dune grep: none found |
| A3: Unnecessary modifications | PASS | File list matches scope (10 files total: 1 config, 5 stops-lib, 2 test, 1 dune, 1 status-doc). No cross-feature drift |

### Experiment Flag Discipline

**Requirement: experiment-flag-discipline.md R1/R2/R3**

| Rule | Status | Verification |
|------|--------|---|
| R1 (default-off) | PASS | `reset_anchor_on_stalled_cycle : bool; [@sexp.default false]` in stop_types.mli line 293. The only new branch is guarded by this flag at weinstein_stops.ml line 379: `\| Stalled when config.reset_anchor_on_stalled_cycle ->`. When false (the default), pattern matching falls through to the old path (discard cycle). No existing code path changed behaviour when the flag is false |
| R2 (searchable axis) | PASS | Real config field in sexp. Test proves searchability: `test_variant_matrix.ml` line 756-784 (`test_reset_anchor_on_stalled_cycle_nested_axis_expands`). The nested path `stops_config.reset_anchor_on_stalled_cycle` expands to valid override sexps for both `false` and `true`, and validates with Overlay_validator (exact mirror of `split_safe_floors` precedent, line 741) |
| R3 (promotion gate) | NA | No existing default changed. This is a NEW field starting at default-off; no promotion logic applies until a ledger ACCEPT is recorded |

### Config-Default Blast Radius

**Requirement: config-default-blast-radius.md B1/B2/B3**

| Rule | Status | Verification |
|------|--------|---|
| B1 (paired golden check) | PASS | NEW config field, not a default change to an existing field. Per the rule: "A PR is a config-default change if it touches a `[@sexp.default ...]` value". This PR ADDS a field with default-off; it does NOT CHANGE an existing default. Paired golden run not required. Commit message confirms: "all 41 pre-existing `test_weinstein_stops` cases plus the rest of the stops suite pass unchanged" |
| B2 (paired table presence) | NA | New field only; no paired table needed |
| B3 (goldens-affected job) | PASS | CI workflow `goldens-affected` is green at this SHA (per dispatch notes); no affected goldens flagged |

### File-Length & Linter Compliance

The fix (commit 1c212d64) pushed `weinstein_stops.ml` to **522 lines** (>500 hard limit). Per `.claude/rules/code-health-discipline.md` the correct response is extraction, not a limit bump.

**Refactoring commit (39893ec4, current):**

| File | Lines | Status |
|------|-------|--------|
| weinstein_stops.ml | 474 | PASS — under 500 limit |
| stop_geometry.ml (NEW) | 47 | PASS — well under limits |
| stop_geometry.mli (NEW) | 62 | PASS |

**Limit & Exception Audit:**
- No `@large-module` markers added (existing marker at `weinstein_stops.ml` line 1 is pre-existing, not new)
- No limits bumped in `trading/devtools/linter_exceptions.conf` (verified via diff)
- **Nesting linter compliance:** The extraction also split `_cycle_outcome` at its nested-else (line 343 in current file) into `_completed_outcome`, clearing the nesting-linter violation that was present in the pre-extraction version

### Dev Governance

| Item | Status | Notes |
|------|--------|-------|
| dev/status/_index.md | PASS | Not modified — index reconcile happens post-merge per feat-agent-dispatch.md §4 |
| dev/status/support-floor-stops.md | PASS | Updated (+166 lines) with full derivation of the freeze invariant, exact precondition, artifact-vs-intended reasoning, queued BOOK-CHECK-NEEDED item, and three new follow-ups. Appropriate for track-status scope |

### Summary

**All structural gates pass.** The one finding is A1 (FLAG, not FAIL): core domain modification to the stop state machine. This is expected for a fix to issue #2486 and does not violate architecture constraints — the stops module is self-contained and its public interface is unchanged (re-exported helpers from Stop_geometry, new flag parameter in config).

**Key structural integrity claims verified:**
1. Default-off experiment flag with bit-identical default path ✓
2. New flag is a real searchable config axis (proven by R2 test) ✓
3. File extraction restored compliance with 500-line limit ✓
4. Test suite confirms no behaviour change in default path ✓
5. New tests follow pattern rules (P6) ✓
6. Architecture boundaries respected (A2/A3) ✓

## Quality Score

5 — Exemplary structural integrity. Default-off claimed and proven; extraction cleaned up file-length violation; tests are comprehensive and pattern-compliant; experimental flag is properly wired and searchable. Ready for behavioral review.

## Verdict

APPROVED


---

## Behavioral QC — fix/stop-ratchet-freeze-2486

Behavioral reviewed SHA: 39893ec4843d4363f0c7332bec497c2dd895f57b (same pin as the structural section above)

Environment: GHA runner. `docker` absent — the container-cwd mandate in
`.claude/rules/qc-behavioral-authority.md` is overridden for this dispatch per the
orchestrator brief (issue #2386). `dune` run natively against this worktree
(`/__w/trading/wt-qc2492`), gated on exit codes.

### Gates run in this worktree

| what | result |
|---|---|
| `dune build @trading/weinstein/stops/test/runtest --force` | exit 0 — 9 executables, 172 tests (4+11+7+41+77+6+9+7+10), all `OK` |
| `wc -l weinstein_stops.ml` | 474 (under the 500 hard limit; PR body's claim confirmed) |
| goldens moved | none — `git diff --stat <merge-base> HEAD` touches no `test_data/` path |

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | New `.mli` surface = `stop_geometry.mli` + the `reset_anchor_on_stalled_cycle` field doc in `stop_types.mli`. Pairs: `is_better_stop` never-lower → `test_weinstein_stops:stop_never_lowered_for_long` (mutation-confirmed, M4); `nudge_round_number` widens-only → `initial_stop_nudge_whole` / `initial_stop_nudge_half`; `bar_extreme` Long=low/Short=high → the short-side cases in `regression_test`; `is_correction` 8-10% gate + `is_recovery` → `regression_test` cycle cases; flag "resets extremes to bar close, increments `correction_count`, leaves `stop_level` exactly where it was" → `flag_unfreezes_the_ratchet` (periods 1-4 pinned at 97.92, period 5 raises to 103.95, which is only reachable if `last_trend_extreme` moved to the period-3 close) + `flag_counts_the_cycles` (count=2); "phantom-cycle guard still applies" → `stale_anchor_still_blocked_under_flag` (mutation-confirmed, M2); "default `false` is an exact no-op" → see the differential under A1/R1 below. One sub-claim is only indirectly pinned (`correction_observed_since_reset` returning to `false` in `_stalled_trailing` — the period-5 raise would fire under either value); non-blocking. |
| CP2 | Each claim in PR body "What shipped" / test-coverage sections has a corresponding test in the committed test file | PASS | All 7 named cases exist in `test_stop_ratchet_freeze.ml` with exactly those names. `reset_anchor_on_stalled_cycle_nested_axis_expands` exists in `test_variant_matrix.ml:756`. "close 101→140 while the stop stays pinned at 97.92 across all six periods" — verified literally (tape closes 101→140; `elements_are` asserts six 97.92s). "All 41 pre-existing `test_weinstein_stops` cases pass unchanged" — observed `Ran: 41 tests … OK`. "no golden moved" — verified. "extracting `Stop_geometry` → 474 lines" — verified. "the prior fix pinned at `test_weinstein_stops.ml:568`" — that is `test_no_phantom_cycle_on_continuous_advance`; citation accurate. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | `fallback_stop_never_ratchets`, `flag_unfreezes_the_ratchet`, `structural_stop_ratchets_on_the_same_tape` all use `elements_are [float_equal …]` over the full 6-element level sequence — whole-value identity, no `size_is`. `stale_anchor_still_blocked_under_flag` pins the exact `(last_correction_extreme, correction_count)` pair *and* the event, for both configs. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | PASS | Two guards claimed. "Never-lower rule (L2) untouched — the flag moves only bookkeeping" → `flag_unfreezes_the_ratchet` periods 1-4; mutation M3 (make `_stalled_trailing` install `stop_level *. 0.98`) turns it RED. "Phantom-cycle guard untouched" → `stale_anchor_still_blocked_under_flag`; mutation M2 (`anchor_is_fresh = true`) turns it RED. |

### Behavioral Checklist (Weinstein domain)

| # | Check | Status | Notes (authority) |
|---|-------|--------|-------------------|
| A1 | Core module modification is strategy-agnostic | PASS | See "A1 generalizability" below. |
| S1 | Stage 1 definition matches book | NA | No stage-classification code in the diff. |
| S2 | Stage 2 definition matches book | NA | Same. |
| S3 | Stage 3 definition matches book | NA | Same. The stops module *consumes* `stage` for the tighten trigger (`_should_tighten_long`), unchanged by this PR. |
| S4 | Stage 4 definition matches book | NA | Same. |
| S5 | Buy criteria: Stage-2 breakout + volume | NA | The stops module emits no buy signals. |
| S6 | No buy signals in Stage 1/3/4 | NA | Same. |
| L1 | Initial stop placed below the base (Stage 1 low) | PASS | Unchanged by this PR. `compute_initial_stop_with_floor` still prefers the prior correction low (§5.1 "below the significant support floor"); the buffer fallback fires only when the support scan finds nothing, which §5.3 licenses ("Use 4-6% initial stop if no nearby prior peak"). The PR deliberately declines to touch `initial_stop_buffer` (open 1.02→1.0 decision) — correct scoping. `floor_stop.ml`'s only change is a dedup, verified behaviour-preserving. |
| L2 | Trailing stop rises as price advances (never lowered) | PASS | The strongest row in this review, and the one the PR is most at risk of breaking. `Stop_geometry.is_better_stop` is character-identical to the deleted local definition (strict `>` long / `<` short). The new `Stalled` branch carries `stop_level` through verbatim; `_stalled_trailing` provably cannot move it (no candidate is even in scope). External writers respect it too: `Stop_track.ratchet` returns `None` on a lowering. Empirically: mutation M3 (lower the stop in the stalled branch) → `flag_unfreezes_the_ratchet` RED; mutation M4 (replace the never-lower test with `<>`) → pre-existing `stop_never_lowered_for_long` RED. Book §5.2. |
| L3 | Stop triggers on weekly close, not intraday | PASS | Unchanged. `_trigger_price` is gated by `config.trigger_on_weekly_close`; the mechanism is present and configurable per §5.2. Not in this PR's scope. |
| L4 | Stop state-machine transitions are correct (INITIAL → TRAILING → TRIGGERED) | PASS | I traced the full reachable transition graph at this SHA: `Initial → {stop-hit, Tightened, Trailing}`; `Trailing → {Trailing, Tightened, stop-hit}`; `Tightened` is terminal. The PR's new branch is strictly `Trailing → Trailing` and changes only bookkeeping. Note the *defect being fixed is itself an L4 defect*: `correction_count` provably pinned at 0 through a multi-cycle advance means the TRAILING state never advances its cycle, which §5.2's "repeat for each correction cycle" requires. eng-design-3-portfolio-stops.md. |
| C1 | Screener cascade order | NA | No screener code. |
| C2 | Bearish macro blocks all buys | NA | Same. |
| C3 | Sector RS vs market | NA | Same. |
| T1 | Tests cover all 4 stage transitions | NA | Stage classification untouched. (For what it is worth, my differential harness exercised all four stage constructors × three MA directions against the machine.) |
| T2 | Bearish-macro → zero-buy-candidates test | NA | No macro code. |
| T3 | Stop-loss tests verify trailing behavior over multiple price advances | PASS | `structural_stop_ratchets_on_the_same_tape` walks two full cycles (86.4 → 97.375 → 103.95) across a 101→140 advance; `flag_unfreezes_the_ratchet` walks the fallback arm of the same tape (97.92 → 103.95). Plus the 11 pre-existing `regression_test` cycle cases. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every new case asserts exact stop levels, exact `correction_count`, or the exact `(anchor, count)` + event pair. No `is_ok`-only assertions. |

### The deadlock proof — verified, with one scoping caveat

**Sound as stated for the `Trailing` state.** I re-derived it rather than adopting it:

- `_advance_tracking` moves `last_correction_extreme` only by `Float.min` (long) — monotone non-increasing from the `A0` seeded in `_to_trailing`.
- `_cycle_stop_candidate` = `stop_candidate(min(correction_extreme, ma))`, and `stop_candidate` is monotone non-decreasing in its argument while `nudge_round_number` only ever moves a long's level *down*. Hence `candidate ≤ A0 × (1 − trailing_stop_buffer_pct)` unconditionally. **A rising MA genuinely cannot help** — it enters through a `min` already dominated by `A0`. Confirmed.
- The only writer that moves the anchor back up is `_raised_trailing`, reachable only from the `Raised` arm. Confirmed by reading every constructor of `Trailing` in the lib.

Escape paths I checked and ruled out: `last_trend_extreme` (affects only *whether* a cycle completes, never the candidate level); re-entry to `Initial` (no transition returns to `Initial`); external level writes (`Stop_track.ratchet` raises only, and never resets the anchor — a raise makes the precondition *more* binding, not less); exit-and-re-entry (a new position, so outside "the life of the position").

Arithmetic re-derived independently: `S0 = entry × 1.02 × (1 − 0.08/2) = 0.9792 × entry`; freeze ⟺ `A0 × 0.99 ≤ 0.9792 × entry` ⟺ `A0 ≤ 0.989091 × entry`, i.e. entry-bar low more than **1.0909%** below entry. The PR's "~1.09%" is correct.

**The one caveat (non-blocking).** The proof is about the `Trailing` ratchet, but the `.mli` and test-file prose generalise to "the trailing stop is frozen at its initial level for the life of the position." Strictly, a transition into `Tightened` can raise the *installed* level exactly once, because `_ratchet_tightened` uses the tighter `tightened_stop_buffer_pct` (0.005 vs 0.01). That fires only in the band `S0/A0 ∈ [0.99, 0.995)` — with the shipped numbers, entry-bar low between 1.09% and 1.59% below entry — and lifts the stop by at most 0.5% of `A0`, still below entry. So the claim is materially true and the proof stands; the sentence is a shade stronger than what is proved. The author already documents this exact mechanism in the H1 follow-up, so it is a prose-precision nit rather than an unnoticed gap. Notably `dev/status/support-floor-stops.md` states it correctly ("There is no escape inside `Trailing`") — the tighter wording belongs in the `.mli` too.

### §5.2 citation — checked against the reference, and it does support "artifact, not faithful"

`docs/design/weinstein-book-reference.md` §5.2, `STATE: TRAILING`, verbatim: *"(repeat for each correction cycle) / AFTER each correction (8-10%+) + recovery back near prior peak: new_stop = below(min(correction_low, MA)) … 'Continue moving the sell-stop up as the MA advances (points E, G, I)' — each successive ratchet uses the current (risen) MA, so stops trend upward across correction cycles."*

Two things in that block carry the argument. First, the explicit "repeat for each correction cycle" plus "stops trend upward across correction cycles" — a machine whose `correction_count` is provably 0 through a multi-cycle advance is not implementing it. Second, and less obvious: `correction_low` in the book's formulation is *this cycle's* low, measured from the *current* peak — the reference resets per cycle by construction. The implementation's carried-forward `last_correction_extreme` has no counterpart in the book's state machine. The citation supports the classification. PASS on the row it backs (L4), not merely "plausible".

### BOOK-CHECK-NEEDED

The author's queued item is **the right question**, and it is correctly scoped: tier 1 settles that stops must trend upward across cycles (which is what makes the freeze a defect and licenses the fix), and is genuinely silent on whether a completed-but-non-improving cycle advances the reference point (which is what sizes the flag's effect). Marking that sub-question `PLAUSIBLE-pending-book` rather than PASS/FAIL is exactly the environment-aware protocol in `.claude/rules/book-as-authority.md`. I carry it forward unchanged and add no new items:

```
BOOK-CHECK-NEEDED: When a correction cycle completes (>= 8-10% pullback, then a
rally back through the prior peak) but the resulting stop would be BELOW the
stop already resting, does Weinstein treat the cycle as having happened — i.e.
does the next cycle measure its pullback from the NEW peak and place its stop
under the NEW correction low — or does the reference point stay pinned to the
older, deeper low until a raise actually occurs?
```

### A1 generalizability (routed from structural)

**PASS.** `trading/trading/weinstein/stops/` is Weinstein-owned domain code, not one of the strategy-agnostic core modules on the A1 watch-list (`portfolio/`, `orders/`, `position/`, `strategy/`, `engine/`) — nothing in this diff reaches those. The relevant generalizability question is whether the stop machine's contract to its callers changed: it did not. `update`'s signature, `stop_state`'s shape, and `stop_event` are all byte-identical; no caller needs to change; every strategy driving this machine gets identical default-off behaviour.

`Stop_geometry` **is** a coherent boundary, not a linter-shaped cut. Its six exports share one concept — pure, side-parameterized geometry over a bar and a config, with `Long`/`Short` as exact mirrors — and the `.mli` states that property explicitly. Two observations: (a) the cut is coherent but not *maximal* — `_is_correction_touch` and `_cycle_stop_candidate` are the same shape and stayed behind in `weinstein_stops.ml`, which is where a line-count-driven extraction tends to stop; (b) the `.mli` is honest about the extraction motive. Neither is a finding. The `floor_stop.ml` dedup is behaviour-preserving: `Stop_geometry.nudge_round_number`'s body is character-identical to the local definition it replaces, and the differential below includes 500 fallback-initial-stop constructions with byte-identical output.

### Default-off verified behaviourally, not just structurally

I did not take the flag's `[@sexp.default false]` as proof. Three independent lines:

1. **Exhaustive arm mapping.** The old code's `option` and the new `cycle_outcome` form an exact partition: `No_cycle | Stalled` (flag off) each evaluate the identical `(no_change, No_change)` expression the old `None` arm did, and `Raised c` evaluates the identical construction the old `Some c` arm did — `_completed_outcome` computes the same candidate via the same `_cycle_stop_candidate` and the same `_is_better_stop` test. No third path exists.

2. **A 1000-tape differential against the merge-base library.** I wrote a throwaway harness against the *public* API only (never naming the new field), seeded deterministically, covering both sides, both initial-stop flavours (fallback and structural), all four stage constructors and all three MA directions, 20 bars each — 20 000 `update` calls exercising 568 `Stop_raised`, 724 `Entered_tightening` and 11 403 `Stop_hit` events. I then checked out the merge-base `weinstein_stops.ml` / `stop_types.{ml,mli}` / `floor_stop.ml`, removed `stop_geometry.*`, rebuilt, and re-ran. **`cmp` reports the two 51 618-line traces byte-identical.** The harness and the `dune` edit were removed afterwards; `git status` is clean apart from this untracked review file.

3. **Mutation M1** (delete the `| Stalled when config.reset_anchor_on_stalled_cycle` arm) leaves all 165 other tests green and reddens only the two flag tests — corroborating that the new branch is unreachable on the default path.

`no golden moved` also verified directly from the diff. R1 satisfied; R2 satisfied by `test_variant_matrix.ml` (a real nested `stops_config` key path, not a hardcoded constant). R3 correctly not invoked — no default flipped.

### Mutation results

| # | mutation | expected | observed |
|---|---|---|---|
| M1 | remove the `Stalled when …` fix branch | `flag_unfreezes_the_ratchet` + `flag_counts_the_cycles` RED | exactly those two RED; all other 165 tests green |
| M2 | `anchor_is_fresh = true` (neuter the phantom-cycle guard) | `stale_anchor_still_blocked_under_flag` RED | RED, plus pre-existing `regression_test` cases 7 and 9 |
| M3 | `_stalled_trailing` installs `stop_level *. 0.98` (violate never-lower) | some L2 test RED | `flag_unfreezes_the_ratchet` RED |
| M4 | replace the never-lower test with `candidate <> stop_level` | the defect-documenting tests RED | `fallback_stop_never_ratchets`, `no_correction_cycle_is_ever_counted`, `flag_unfreezes_the_ratchet` RED, plus pre-existing `stop_never_lowered_for_long` |

No new test survives deletion of the thing it tests. M4 additionally establishes that the two *defect-documenting* cases are non-vacuous — the flat 97.92 sequence is a real property of the machine, not an inert fixture.

`structural_stop_ratchets_on_the_same_tape` **is** a genuine control: identical `tape`, identical `replay`, identical entry-bar anchor, with only `compute_initial_stop ~reference_level:90.0` (→ 86.4) substituted for the fallback (→ 97.92) — and it produces a *different, moving* level sequence (86.4 → 97.375 → 103.95). That isolates the fallback stop as the cause rather than the fixture, which is precisely what the row claims.

### Deferring the `_ratchet_tightened` twin defect — correct call

I verified the defect is real: `_ratchet_tightened` recomputes `new_extreme = min(last_correction_extreme, bar_extreme)` and writes it back on *both* branches, so for a long the candidate is monotone non-increasing and its maximum is on the first `Tightened` bar. If it does not beat the incoming stop there, it never will; if it does, the single raise consumes the headroom. So the function raises **at most once, on the first `Tightened` bar** — its docstring's "as new extremes are set" is wrong. H1 is accurate.

Deferring is right, and shipping the partial fix does **not** leave the machine incoherent:

- The states are disjoint and sequential (`Trailing → Tightened`, one-way, `Tightened` terminal). The flag's only branch lives in `_raise_after_cycle`, which `Tightened` never reaches — the two mechanisms cannot interact.
- The direction of any interaction is safe: under the flag more `Trailing` raises occur, so the stop *entering* `Tightened` is higher, which can only make `Tightened`'s single raise less likely to fire. Never-lower holds independently in both states, so the installed stop is monotone non-decreasing either way — with the flag on or off, fixed or unfixed.
- Bundling would put two mechanisms under one PR (and either one flag governing two behaviours, or two flags in one commit), against `.claude/rules/experiment-flag-discipline.md`'s one-mechanism-per-commit norm, and would double the blast radius of a core stop-machine change.
- H1 also raises a genuine prior question the fix depends on — whether `Tightened` is *meant* to trail at all, given §5.2 STAGE3_TIGHTENING reads as a one-shot tighten ("pull stop tighter — below correction_low even if ABOVE MA"). That is a book question, not a code question, and answering it on a runner where the book is unreachable would be exactly the guess `book-as-authority.md` forbids. Filing beats bundling.

H1/H2/H3 are all recorded in `dev/status/support-floor-stops.md` under Follow-ups, so nothing is dropped.

### Scope items correctly excluded

Real-data verification (H2) needs a container backtest and is fenced to the concurrent local session sharing the 26y instrumented run with #2489/#2490 — not a finding. No default flipped, no golden re-pinned; `config-default-blast-radius.md` B1/B2 do not fire (a *new* default-off field cannot move a golden that never names it, and the diff touches no `weinstein_strategy_config` default value).

## Quality Score

5 — Exemplary. The defect is proved rather than asserted, the fix is a minimal decoupling behind a default-off flag whose no-op I confirmed byte-identical against the merge-base over 20 000 machine steps, every new test survives mutation, and the record is unusually honest about what it did not do (H1/H2/H3, the scope fence, the queued book question). The only findings are a prose-precision nit on "life of the position" and a non-maximal extraction boundary — neither is blocking.

## Verdict

APPROVED
