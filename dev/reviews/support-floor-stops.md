Reviewed SHA: 94490854e109c10a9e3a9c8119665019e691fd54

# QC Structural Review: support-floor-stops — rework iteration 1 (delta pass)

**PR**: #2220 — `feat/split-safe-fallback-telemetry`
**Tip**: `94490854` (2 new commits over `7e3b2586`, which I APPROVED 5/5)
**Reviewer**: qc-structural
**Date**: 2026-08-06

Delta pass. Rows the delta can plausibly move (H1–H3, P1/P4/P6, A2, A3) were
re-derived from scratch; the rest are carried forward with justification.

## Raw gate exit codes (re-run at `94490854`)

| Gate | Exit code |
|---|---|
| `dune build @fmt` | **0** |
| `dune build` | **0** |
| full-repo `dune runtest` (foreground) | **0** |

## Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | `dune build @fmt` | PASS | Re-run: exit 0 |
| H2 | `dune build` | PASS | Re-run: exit 0 |
| H3 | `dune runtest` | PASS | Re-run: exit 0, full repo, foreground. Counts re-measured: `test_support_floor` 60→**63**, `test_entry_audit_capture` 43→**45**, `test_trade_audit_recorder` **3** (new module), `test_panel_callbacks` **24** and `test_trade_audit` **28** unchanged. |
| P1 | Functions ≤ 50 lines | PASS | Re-run via H3. `_scan_basis` grew to 5 lines. |
| P2 | No magic numbers | CARRIED | Linter green via H3; delta adds a `n_days = 0` structural comparison, not a tunable literal. |
| P3 | Config completeness | CARRIED | `Empty_window` is a fourth *derived* state of the same existing `split_safe_floors` field. Still no new knob. |
| P4 | `.mli` coverage | PASS | Re-run via H3. New constructor documented in all four `.mli` sites; new test module needs no `.mli`. |
| P5 | Helper prefixes | CARRIED | No new helpers; `_split_safe_basis_of_event` / `_scan_basis` unchanged in naming. Test-local helpers in the new module (`_recorded_entry`) are correctly underscore-prefixed. |
| P6 | Test-pattern conformance | PASS | Re-derived across all four touched test files **plus** the new module. Sub-rule 1: 0 hits. Sub-rule 2: 0 hits. Sub-rule 3: one added `assert_failure` at `test_entry_audit_capture.ml:291` — the same **test-setup value extraction** sanctioned by `test-patterns.md` and already established in this file. New module uses `Matchers` idiomatically (`elements_are` over the constructor list, one `assert_that` per value). |
| A1 | Core module modifications | CARRIED | Delta touches no new paths; still zero files under `trading/trading/{portfolio,orders,strategy,engine}/`. No FLAG. |
| A2 | No new `analysis/` → `trading/trading/` edges | **PASS (re-derived, premise changed)** | My previous PASS rested on "zero dune files changed" — **that premise no longer holds** and was not carried forward. Mechanical re-derivation: the complete set of added dune lines in the entire delta is exactly one — `+  test_trade_audit_recorder` — inside the `(names ...)` list of `trading/trading/backtest/test/dune`. That is a **test executable name, not a library dependency**; the `(libraries ...)` block is byte-unchanged. Zero dependency edges added anywhere. Separately: that dune file's pre-existing `(libraries)` already carries `weinstein.{data_source,snapshot_pipeline,snapshot_runtime,types,screener,resistance}` and `weinstein_trading.stops`, all of which sit under the allow-listed `trading/trading/backtest/**` exception surface and none of which this PR touches. |
| A3 | No unnecessary modifications | PASS | Delta file list re-derived via `git diff --name-only 7e3b2586..94490854`: 16 files, all in scope for B1–B4 + docs. No cross-feature drift. |

## Item 1 — `Empty_window` audit (the highest-risk item)

**Is the compile-time pin still intact?** Yes — and this delta is empirical proof it
works. All six declarations carry all four constructors, including the two
**type-equation-with-constructor-re-export** sites (`weinstein_stops.ml`,
`audit_recorder.ml`/`.mli`). Adding `Empty_window` upstream *forced* every one of them
to update or fail to compile. The property I endorsed last pass as stronger than a sync
test held under exactly the stress it was meant to absorb.

**Did anything get a wildcard?** No. `_split_safe_basis_of_event` in
`trade_audit_recorder.ml` is the only match on the type anywhere in the tree, and it is
fully exhaustive across all four constructors with no `_ ->` fallthrough. I grepped every
non-test occurrence of `Raw_fallback`/`Empty_window` in `trading/trading/` to confirm no
second match site exists.

**Is the value channel preserved?** Yes, and I verified the load-bearing premise rather
than trusting the comment. `_window_is_adjustable` ends `cbs.n_days > 0 && loop 0`, so it
returns **false** for an empty window — meaning the pre-delta code did fall through to
`(callbacks, Raw_fallback)`, exactly as B3 describes. The new branch returns
`(callbacks, Empty_window)` — the **same `callbacks` binding, untouched**. So the fix is
**tag-only; the value channel is bit-identical**, and the docstring's
"behaviour-preserving" claim is accurate. Branch order is correct: flag check →
empty check → adjustability check, so the empty case is caught before it can be
misread as a fallback.

**Is the sexp story still sound?** Yes. `[@sexp.default Flag_off]` is unchanged, so
`trade_audit.sexp` rows predating the field still parse. Adding a constructor to a
`[@@deriving sexp]` variant does not affect parsing of sexps containing only the prior
three, so **existing artifacts remain readable**. (The converse — a *new* artifact
carrying `Empty_window` read by an older binary — is forward- not backward-compatibility
and is out of scope.) The round-trip test in `test_trade_audit.ml` enumerates all four
constructors, and `test_trade_audit_recorder.ml:132` drives all four through the sink hop.

## Item 4 — MT4 re-run independently

Applied MT4 myself (deleted the `Empty_window` branch from `_scan_basis`):

| suite | claimed | **observed** |
|---|---|---|
| `stops/test_support_floor` | 1 | **1** |
| `strategy/test_entry_audit_capture` | 0 | **0** |
| `backtest/test_trade_audit_recorder` | 0 | **0** |

Exactly `support_floor:52:split_safe_basis_empty_window_is_not_fallback` reddens. Table is
honest. Mutation reverted; `git diff` on `floor_stop.ml` confirmed empty.

## On B2 (retraction) — structural note

Resolving B2 by **retracting the overstated single-sourcing claim** rather than
manufacturing a test to justify it is the correct call, and matches
`.claude/rules/mechanism-validation-rigor.md` §"Verdict calibration". The restated
property — drift is *unrepresentable* because one branch emits both outputs — is a
compile-time/structural claim that a runtime mutation genuinely cannot exhibit, so the
absence of an MT2 red is expected rather than a coverage hole. The tests correctly now
pin only the weaker observable ("tag tracks the branch"), which is what MT1 reddens.

## Previous non-blocking nit — resolved

My `trade_audit.mli` A2-justification nit was folded in correctly. It now states the
upstream type *is* reachable via `backtest/lib/dune`'s `weinstein_trading.strategy`
declaration and reframes the re-declaration as a **deliberate schema boundary** (the
on-disk sexp schema should evolve independently of a strategy-layer type). That is
more precise than my original note.

## New non-blocking nit (does not block approval)

`test_trade_audit_recorder.ml` says "three" in three places — the function name
`test_split_safe_basis_projects_all_three_states` (line 130), its docstring "Driving all
three constructors" (line 128), and the OUnit label `"split_safe_basis projects all three
states"` (line 189) — but the test drives **four** (`Flag_off; Adjusted; Raw_fallback;
Empty_window`, line 132). The assertion itself is exhaustive and correct; only the naming
undercounts, presumably left over from before `Empty_window` was added in the second
commit. Line 189 is the label printed in failure output, so a future reader debugging a
red here is told "three states" for a four-constructor check. Worth a one-line fix on the
next touch; it is a legibility defect in a PR whose subject is telemetry legibility, but
it is cosmetic and pins nothing incorrectly.

## Quality Score

4 — Good: all gates green at the new tip, both blocking findings properly closed (B2 by honest retraction rather than a manufactured test), the compile-time pin demonstrably survived a constructor addition, and MT4 reproduced exactly — held off 5 only by the stale "three states" naming carried in three places in the new test module.

## Verdict

APPROVED

No FAIL items. A2 re-derived from scratch against the changed dune premise and still passes. Cleared for qc-behavioral re-review.

---

# QC Behavioral Review: split-safe fallback telemetry (F5) — PR #2220, rework iteration 1 (delta pass)

Reviewed SHA: 94490854e109c10a9e3a9c8119665019e691fd54

Exit codes observed:

| run | exit |
|---|---|
| `dune build` at `94490854` | **0** |
| `dune runtest` (full repo) at `94490854` | **0** (2 `FAIL:` grep hits are `sete_diagnostics_check` self-check echoes) |
| iteration-0 sink mutation (both hops → `Flag_off`), backtest+strategy | **1** — now RED (was 0) |
| MT-F + MT-G (`Empty_window` collapsed at projection / branch deleted at classifier), backtest+stops | **1** — both RED |
| `dune build` + targeted runtest after reverting all mutations | **0** (tree restored byte-identical) |

## Verification of the four prior findings

**B1 — CLOSED, measured.** I re-applied the *identical* iteration-0 mutation (hardcode
`Flag_off` at `entry_audit_capture.ml:411` and `trade_audit_recorder.ml:105`). At
`7e3b2586` the **full repo** stayed at exit 0; at `94490854` it is RED at both hops:
`entry_audit_capture:15:B1 hop 1: build_entry_event propagates the basis` and
`Trade_audit_recorder:0:split_safe_basis projects all three states`. Driving the
projection through the real `of_collector` bundle rather than the private
`_entry_decision_of_event` is the right call — it covers the bundle wiring too.

**B2 — CLOSED, and closed the right way.** Retraction verified in the status file
("**MT2 retracted in rework iteration 1 — see below. Do not cite it.**"). Declining to
manufacture a test for a property no test can express, and instead re-scoping the claim
from behavioural to structural, is the correct response; I want to say so explicitly
because the tempting move was to invent a test that appeared to pin it.

**B3 — CLOSED, and better than I asked for.** I proposed a docstring sentence; the writer
added a fourth constructor and defined the metric on the type. Both mutations are caught
(MT-G: deleting the `n_days = 0` branch → `support_floor:52:split_safe_basis_empty_window_is_not_fallback`;
MT-F: collapsing `Empty_window → Raw_fallback` at the projection →
`Trade_audit_recorder:0:...`). Behaviour-preserving: `test_split_safe_empty_window_stop_matches_flag_off`
pins the stop against the flag-off stop.

**B4 — CLOSED.** `test_entry_meta_split_safe_basis_survives_reanchor` asserts
`stop_floor_kind = Buffer_fallback` **and** `split_safe_basis = Adjusted` on the same
`entry_meta` — requiring the two tags to *disagree* is a stronger pin than asserting the
basis alone, since it would also catch a re-anchor that reset both.

## Answers to the four questions posed

**Q1 — is the chain pinned end to end, or only at the two points I probed?** *End to end.*
I enumerated every value-carrying site for `split_safe_basis` in non-test library code
(exhaustive grep; all other hits are type declarations, aliases or docstrings). There are
exactly **six**, and each is pinned:

| # | site | pinned by |
|---|---|---|
| 1 | `floor_stop.ml:151` `split_safe_basis_of_callbacks` = `snd (_scan_basis …)` | stops telemetry tests (MT1 / MT-C / MT-G measured) |
| 2 | `entry_audit_helpers.ml:144,158` reads it, returns 3rd component | MT3 (2 F in `test_entry_audit_capture`) |
| 3 | `entry_audit_capture.ml:152` packs into `stop_tags` | the three `entry_meta` basis tests |
| 4 | `entry_audit_capture.ml:102` `entry_meta.split_safe_basis` | same |
| 5 | `entry_audit_capture.ml:411` `build_entry_event` | **new** `test_build_entry_event_propagates_split_safe_basis` (all 4 constructors) |
| 6 | `trade_audit_recorder.ml:105` `_entry_decision_of_event` | **new** `test_trade_audit_recorder.ml` (all 4, via `of_collector`) |

Downstream of (6) there is **no seventh site**: `Trade_audit.record_entry`
(`trade_audit.ml:179`) stores the whole `entry_decision` with no field projection, and
`Result_writer._write_trade_audit` (`result_writer.ml:182-192`) wraps the record list in
`audit_blob` and calls derived `sexp_of_audit_blob` — no hand-written serializer that
could omit a field, and the four-constructor sexp round-trip is pinned in
`test_trade_audit.ml`. `Audit_recorder.t.record_entry` is a plain
`entry_event -> unit` callback (`audit_recorder.ml:65`), not a rebuild.

On the root-cause pattern ("a module with no tests at all"): I re-checked every module in
the chain. `Trade_audit_recorder` was the only one and now has tests; `Result_writer`,
`Trade_audit`, `Entry_audit_capture`, `Panel_runner`, `Floor_stop`/`Weinstein_stops` and
`Panel_support_floor` (via `test_panel_callbacks.ml`) all have suites.
`Entry_audit_helpers` has no dedicated file but its hop is pinned through
`test_entry_audit_capture`. No remaining instance of the pattern.

**Q2a — does excluding `Empty_window` from both terms create a `0/0` blind spot?** Yes, in
a corner — see B6 below. Non-blocking.

**Q2b — is `Empty_window` reachable, or dead?** **Reachable in the production entry path,
not dead.** The entry path is `Bar_reader.daily_view_for` → `Panel_support_floor.of_daily_view`
(`n_days = view.n_days`) → `_scan_basis`. `Snapshot_bar_views.daily_view_for` returns
`empty_daily_view` on three distinct routes: `lookback <= 0` (line 213, i.e.
`support_floor_lookback_bars <= 0`); `as_of` absent from the calendar (line 206); and
`_read_daily_tables` finding **no raw-close rows for the symbol in the window** (lines
183 / 199) — a real data condition for a newly-listed or snapshot-missing symbol, and
exactly the case the `Empty_window` docstring names. `Bar_reader.empty ()` (line 104) also
returns it unconditionally. So pinning it proves something real, and B3 was a live
mis-tag rather than a hypothetical one. (Note the contrast: a window with *some* rows
missing is NaN-filled by `walk_daily_view_window`, giving `n_days > 0` → `Raw_fallback`,
which is the correct classification — a genuine degradation.)

**Q3 — is "drift is unrepresentable" true as restated?** **True.** Verified by exhaustive
read, not by inference: `_window_is_adjustable` has exactly one call site in the whole
non-test codebase (`floor_stop.ml:140`, inside `_scan_basis`); `_rescaled` likewise
(same line); and both `_scan_callbacks` (`:149`) and `split_safe_basis_of_callbacks`
(`:151`) are pure projections of the same tuple. There is no second decision site. The
one superficially similar name elsewhere — `Svg_series._to_adjusted_basis` — is an
unconditional per-bar rescale for chart rendering with no adjustability predicate and no
connection to the stop scan, so it is not a second decision site for this basis. The
retraction replaced an overclaim with a claim that is correct as stated.

## Contract Pinning Checklist (delta)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | New/changed `.mli` claims have pinning tests | **PASS** | Delta claims and their pins: `Empty_window` semantics → `..._empty_window_is_not_fallback`; flag-off precedence over empty → `..._empty_window_flag_off`; "telemetry-only, stop unchanged" → `..._empty_window_stop_matches_flag_off`; end-to-end propagation of all four states → `test_build_entry_event_propagates_split_safe_basis` + `test_trade_audit_recorder.ml` + four-constructor sexp round-trip; re-anchor independence → `..._survives_reanchor`. The restated single-source claim is now **correctly scoped as structural rather than behavioural** and the `.mli` says so explicitly, so it is no longer an unpinned behavioural claim — and I verified it is true (Q3). Prior CP1 FAIL cleared. |
| CP2 | PR-body / status-file claims match committed tests | **PASS** | MT2 withdrawn and marked "do not cite"; the remaining mutation rows reproduce (I reproduced the sink mutation RED myself; structural reproduced MT4). No advertised test or evidence that I could not locate or reproduce. Prior CP2 FAIL cleared. |
| CP3 | Identity pinned as identity, not size | **PASS** (carried forward, and reinforced) | Untouched by the delta in substance; the new tests strengthen it — `elements_are` with per-constructor `equal_to` over all four states, and `test_split_safe_empty_window_stop_matches_flag_off` compares whole `stop_state` values. |
| CP4 | Docstring-named guards have tests | **PASS** | Both prior gaps closed: the `n_days = 0` guard (3 tests) and the re-anchor independence claim (1 test). Far-offset universal quantifier carried forward — pinned on both paths, measured at iteration 0 via MT-C; the delta does not touch `_window_is_adjustable`, so that measurement still holds. |

**Domain block S\*/L\*/C\*/T\*: NA**, carried forward. The delta adds one telemetry
constructor and documentation; it introduces no stage rule, buy/sell criterion, stop
rule or cascade change. `Empty_window` is behaviour-preserving (returns the bundle
untouched, exactly as the `Raw_fallback` branch did) and is pinned as such. W1–W3 and
R1–R3 remain untouched. R1 bit-identity carried forward: with `split_safe_floors = false`
the first branch still short-circuits before any `n_days` or adjustability evaluation.

## Findings — all non-blocking

### B5 — `Empty_window` classification is pinned only on the bar-list path, not the panel path

- **Location:** `trading/trading/weinstein/stops/test/test_support_floor.ml:1023` (the
  three new tests use `split_safe_basis_of_bars ~bars:[]`);
  `trading/trading/weinstein/strategy/test/test_panel_callbacks.ml` is untouched by the delta.
- The three new `Empty_window` tests go through `callbacks_from_bars`. But
  `split_safe_basis_of_bars` has **no wired production caller** — the delta's own
  `weinstein_stops.mli` says so ("no caller is wired to it yet"). The path a real run uses
  is `Bar_reader.daily_view_for` → `Panel_support_floor.of_daily_view` →
  `split_safe_basis_of_callbacks`, and `test_panel_callbacks.ml` has telemetry siblings for
  `Flag_off`, `Adjusted` and `Raw_fallback` but not for the fourth state.
- **Why I am not blocking on it:** `_scan_basis` branches on `callbacks.n_days`, which both
  constructors populate with the same semantics, so the branch is genuinely shared — I
  confirmed this by reading `panel_support_floor.ml:9,25` against
  `support_floor.ml:41,49`. MT-G proved the branch is pinned; MT-F proved the projection is
  pinned; `test_build_entry_event_propagates_split_safe_basis` covers `Empty_window`
  through the strategy record. The residual risk is narrow.
- **Why it is still worth saying:** "covered on the bar-list path and silently unexercised
  on the panel path" is this track's documented recurring defect class — it is the exact
  wording `test_panel_callbacks.ml:1188` uses to describe the defect #2213 existed to fix,
  and B3-on-#2213 shipped green the first time for the same reason. A fourth panel sibling
  is ~10 lines.
- **Suggested fix (follow-up is fine):** one `test_panel_callbacks.ml` case asserting
  `_panel_basis ~config:_cfg_split_on` on a zero-`n_days` daily view is `Empty_window`.
- **harness_gap:** LINTER_CANDIDATE — "every constructor of a telemetry enum has a case on
  every wired construction path" is mechanically checkable.

### B6 — an `Empty_window`-saturated arm makes the metric `0/0`, which reads as "no data"

- **Location:** `weinstein_stops.mli` §"Reading it as a metric" and the same paragraph
  echoed in `trade_audit.mli`.
- The metric is defined as `Raw_fallback / (Raw_fallback + Adjusted)` with `Empty_window`
  excluded from both terms. Excluding it is the right call — a non-event is neither a
  success nor a degradation. But an arm whose entries are all `Empty_window` then yields
  `0/0`, and the doc gives the reader no instruction to distinguish that from "the column
  is unwired". The doc does call out the analogous `Flag_off`-in-a-flag-on-arm case as "a
  wiring alarm"; the `Empty_window`-saturation case gets no equivalent.
- This is the F5 ambiguity reappearing in a corner: an arm where the mechanism was never
  given a chance to run is maximally inert, and the headline number says "undefined"
  rather than saying so.
- **Severity: low** — the count is in the artifact, so a reader can recover it; and
  saturation requires most entered candidates to have no bars, which is unlikely.
- **Suggested fix:** one sentence — report the `Empty_window` count alongside the fraction,
  and treat a zero denominator as "mechanism never exercised", not as missing telemetry.
- **harness_gap:** ONGOING_REVIEW.

### B7 — `test_trade_audit_recorder.ml` says "three" where it drives four (cosmetic, rides along)

- `test_split_safe_basis_projects_all_three_states` (L130), the docstring "Driving all
  three constructors" (L128), and the OUnit label "split_safe_basis projects all three
  states" (L189) all undercount: the list at L132 is four constructors and the
  `elements_are` at L137 is exhaustive over them.
- The assertion is correct; only the name printed on failure is wrong — and it was wrong in
  a way I noticed only because it is the test that guards the count. **My call: rides
  along, does not block.** Worth fixing on the next touch of the file so a future reader
  doesn't add a fifth constructor and trust the label.

## Prior non-blocking notes — both folded in, confirmed

The denominator caveat moved onto `split_safe_basis_of_callbacks` (the function the
strategy actually calls, not the unwired `..._of_bars` sibling) and now names **both**
narrowings — entries-not-candidates and entry-time-not-stop-maintenance — with
`Stop_recompute` / `Stop_thread` called out by name and filed as **F9**. That is a fuller
answer than I asked for: I flagged the second narrowing as undisclosed in the `.mli`, and
it is now disclosed *and* tracked.

## Quality Score

4 — Good. Every one of my four findings is genuinely closed, and I confirmed each by direct measurement rather than by reading the rework note: the iteration-0 sink mutation that was green across the full repo is now RED at both hops, and both `Empty_window` mutations are caught. Two things raise this above a routine fix: B2 was resolved by *retracting* an unsupportable claim and re-scoping it to a structural property I independently verified is true, rather than manufacturing a test that would have looked like a pin; and B3 was answered with a principled fourth constructor plus a metric definition on the type, exceeding the docstring sentence I suggested. Not a 5 because three residual items remain, one of which — `Empty_window` unpinned on the panel path (B5) — is this track's documented recurring defect class, even though the shared-branch structure makes the actual risk narrow.

## Verdict

APPROVED

No FAIL rows. CP1 and CP2 clear their prior FAILs; CP3 and CP4 pass. B5, B6 and B7 are
non-blocking and suitable as follow-ups alongside F6 / F7 / F9. F5 is closed: the
telemetry now reaches `trade_audit.sexp` through a chain that is pinned at every one of
its six value-carrying sites, so the inert fraction is trustworthy enough to qualify a
`split_safe_floors` walk-forward surface — which was the gating condition for promotion.
