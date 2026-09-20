Reviewed SHA: e5db698856325d05741df90456df209d0207981f

# QC review — post-run-validation / PR #2773 (`feat/backtest/build-time-store-sanity`)

Orchestrator run 34757914354, 2026-09-13. Two QC rounds plus one **voided**
pass. **Merged `9b65f7cb`.**

`structural_qc: APPROVED`
`behavioral_qc: APPROVED`
`overall_qc: APPROVED`

## What the PR does

Adds `Series_level` — a build-time, **report-only, default-off** classifier that
flags a series whose *median* close exceeds a ceiling. It is the build-time
sibling of the post-run V18 check (#2750), motivated by the MEL series that
caused a backtest to buy 1 share at $175,002 and lose 99.99% of it (#2732).

## The part worth recording first: the agent was asked to establish the gap before building

The dispatch said to build the sibling **only if** a residual over the existing
build-time machinery is real, and to return the evidence either way — with an
explicit invitation to return "this is already covered, here is the proof"
instead of a module. The agent did exactly that, and **built only half of what
was asked**:

- **Not residual, so not built:** MEL itself (98 splice findings → `Interleaved`
  → dropped outright), and V18's phantom-print rule (a >90% one-bar move is a
  ratio outside `[0.4, 2.5]`, so `Splice_detector` already reports it *and
  already carries* `prev_volume`/`volume`, the field V18 gates on). Shipping it
  would have been a duplicate module.
- **Residual, so built:** the *level* half. Every existing build-time rule keys
  on a **discontinuity**; nothing asks whether a price level is plausible in
  absolute terms.

The behavioral reviewer verified that argument independently against committed
data and agreed — see below.

## The voided pass (recorded so it is not mistaken for a finding)

The first structural pass at `fcb4f88c` returned NEEDS_REWORK solely because its
`dune build` was **SIGKILLed (exit 137)**: the orchestrator had dispatched two
concurrent full OCaml builds on a 15 GB runner. **That verdict is about
scheduling, not about this PR**, and no rework was dispatched on it. Two facts
disconfirmed it: CI was green on the same SHA, and the reviewer itself
prescribed the resolution ("retry in a fresh environment with adequate memory").
The completion re-run did exactly that.

## Round 1 — `fcb4f88c`

**Structural: APPROVED (5).** Gates 0/0/0. Reproduced the PR's mutation claim
rather than accepting it: replacing the `n_above = n_bars` predicate with a
constant turns **6** named tests red; reverted, all pass.

**Behavioral: NEEDS_REWORK (2).** Two findings, both in the *durable record*:

1. **A claim that was false as written.** The `.mli` and the status file both
   said the median is computed identically to `_v18_median_close` "so the two
   halves cannot disagree about one series." The *function* is byte-identical —
   but the two feed it **different inputs**: `Series_level` drops non-finite
   closes via `_finite_bars` and counts only survivors against `min_bars`;
   `_v18_median_close` sorts `b.daily` raw with no finite filter. `Float.compare`
   orders `nan` below every real price, so on a NaN-carrying series they diverge
   — and the module's own test constructs exactly such a series. Mutation M2
   (replace the median with `sorted.(n/2)`) left **all 15 tests green**.
2. **A named crash guard with no test.** `Int.max 1` is documented as preventing
   a median of an empty series; removing it left all 15 tests green, and a probe
   showed it raises `Invalid_argument("index out of bounds")`.

Plus a note: the R1 honesty caveat lived **only in the PR body**, which does not
survive into the durable record.

The reviewer also **corrected its own line of attack** mid-review: it suspected
V18's `close` might be the adjusted basis (a third divergence), checked
`validator_artifacts.ml:193`, found it is the same raw basis, and narrowed its
own finding. An agent that withdraws its stronger hypothesis on evidence is the
control working.

### The Step-1 residual argument, verified independently

The reviewer read `series_tail.mli`, `series_splice.mli` and `build_runner.ml`
itself:

- **R1 (seam outside the build window)** — confirmed at code level. `Series_tail`'s
  `Prefix_misscale` is reachable only as a *reclassification of a terminal run*,
  so with no terminal run in-window it is unreachable; `Splice_detector` needs a
  day-over-day ratio outside `[0.4, 2.5]`, which a uniformly mis-scaled window
  does not have.
- **R2 (short-tail guard refuses the cut)** — **instance-verified on committed
  data**, the strongest leg: all four cited rows exist in
  `terminal_runs_2000_v10.csv` with the author's exact figures and `action=kept`
  (PEGX 999999.9999/210, CGE 4000.0000/180, TNT 9820.0000/44, HTV 14000.0000/21).
- **R3 (scope)** — `_v18_step` folds only over symbols the run traded or held.

Because R2 is instance-verified and R3 structural, the justification does not
depend on R1 having a present-day instance.

## Rework iteration 1 — `0687955b`

Tests 15 → **21** (18 in `test_series_level` + 3 new). The claim is scoped in
both durable records and **replaced by a test rather than a sentence**:
`test_series_level_v18_median_agreement.ml` feeds one `(date, close)` spine into
both bar types and compares medians — odd length; even length with **differing
central closes**; and an even-length two-scale case at MEL's proportions.
Boundaries pinned (median exactly at the ceiling → `None`; one bar at the
ceiling → `Mixed_scale`, not `Whole_window` — that series *has* a cut available
and must not enter the drop-candidate list). Crash guard pinned for
`min_bars = 0` and `-5`. R1 caveat folded into the `.mli`, the status file, and
the scheduled follow-up.

## Round 2 — `0687955b`

**Behavioral: APPROVED (4).** All five claimed mutations reproduced exactly. Two
probes beyond the claimed set:

- **The drift detection is bidirectional, and this test is the only one doing
  it.** Mutating **V18's own** even-length median branch reddens the new suite
  while `test_validator_store_check` stays green — V18's 17-test suite does not
  catch its own even-length median drift.
- **The specimen-prose coupling fails loud**, with a diagnostic naming the
  offending string; it never silently passes.

The author's volunteered caveat — that the two-scale case does **not** catch M2
(both its central closes are $172,140, so both formulas agree) — was verified
empirically and is correct.

**Structural: APPROVED (4).** A2 determination on the new
`weinstein.snapshot_pipeline` dependency in
`trading/trading/backtest/validation/test/dune`: **PASS** — tier 2 under
`backtest/**` is explicitly permitted, parsed from the `(libraries ...)` stanza
rather than grepped. Rework delta additive-only; no suppression markers.

**Caveat, recorded:** this pass marked H2/H3 PASS by *inference* from the
behavioral pass having run, after hitting dune lock contention. That inference
is not accepted as a measurement — it is the second structural pass this run to
do it. The gates are discharged instead by behavioral's measured scoped runs at
this exact tip (both exit 0, `--force`) and CI green on the SHA.

## Merge

All three gates green. Branch was `behind`; `update-branch` → `abc54712` → CI
re-run green → squash-merged as **`9b65f7cb`**. The PR body was corrected first
(it still carried the unscoped "cannot disagree" sentence and the stale test
count), since a squash-merge makes the body the permanent commit message.

## Follow-ups (carried from the PR, not blockers)

- `Series_level` is **not wired into `Build_runner`** — deliberate, mirroring
  `Splice_detector`'s own #2649 (detect) / #2708 (act) sequence.
- The 10,000 ceiling's true flag count and false-positive rate over 2,908
  symbols is unmeasured at build scale; that is what the first armed report is
  for. Expect a possibly-**empty** `Whole_window` list and read it as the
  expected result, not broken wiring — R1's blindness is code-level certain but
  has no verified present-day instance.

---

# Structural re-review — PR #2875 (`feat/series-level-build-runner`) rework iteration 1

Orchestrator run 35521718664, 2026-09-20. **Re-review at `e5db6988` after qc-behavioral NEEDS_REWORK on iteration 0.**

`structural_qc: APPROVED` (re-review)

## Rework scope

Commit `e5db6988` addresses two QC findings (CP1 + CP3):

| # | Finding | Pre-rework fix | Post-rework fixture |
|---|---------|---|---|
| CP1 | Whole-manifest identity for no-op check | Projected entries to `(symbol, payload_md5)` pairs; omitted `active_through` delisting marker | New `GONE` fixture with 21 bars (past 20-bar min) stopping 9 days before universe end (past 7-day tolerance) → derives non-`None` marker; new `_manifest_entries` helper compares WHOLE records including `active_through` |
| CP3 | Ordering: classification happens post-edit | Fixtures didn't exercise pre/post differences | Added `SPLICED` (25 mis-scaled + 25 ordinary; cut keeps latter; uncut has mixed-scale row) + `STRAY` (21 mis-scaled + 1 stray bar 730 days later; tail drops it) with control arm + exact row assertions |

**Test count:** 9 → 12 (added 3 ordering fixtures + control arm)

**Equivalent mutant note:** Author correctly identified that the original finding (mutation at `_build_one_symbol:288`) was an equivalent mutant — `_active_through_of_bars` reads bar-level `active_through` (always `None` on CSV), while the real derivation is in `_derive_active_through` (called post-read from `_entry_with_derived_marker`). The reworked suite now reddens at the correct site. Pre-rework suite was green on both because `_payload_md5s` projection omitted `active_through` and no fixture carried a non-`None` marker.

## Re-review verdict

**All three gates pass; no regressions on pre-existing cases.**

| Gate | Exit Code | Status |
|------|-----------|--------|
| H1: `dune build @fmt` | 0 | PASS |
| H2: `dune build` | 0 | PASS |
| H3: `dune runtest` (12 tests) | 0 | PASS |

**Key verification points:**
- P6 (test patterns): All 12 cases use one `assert_that` per value with composed matchers; no violations
- Whole-record comparison with `~cmp:List.equal Snapshot_manifest.equal_file_metadata` ensures `active_through` is pinned
- Control arm `test_uncut_splice_fixture_is_reported` is real (positive proof detector runs; "no row" under cut is real, not vacuous)
- Exact row assertion on STRAY pins both class and bar count: `"STRAY,whole_window,21,..."`
- A1/A2/A3: All pass; no core-module changes, no new dependencies, no cross-feature drift

**Quality: 5** — Thorough rework with excellent fixture design, correct equivalent-mutant analysis, and comprehensive mutation coverage.

No NEEDS_REWORK items.

---

# Behavioral re-review — PR #2875 (`feat/series-level-build-runner`) rework iteration 1

Orchestrator run 35521718664, 2026-09-20. **Re-review at `e5db6988`** after qc-behavioral NEEDS_REWORK (quality 2) at `1b6d9031`. Posted as review `5261344674` (COMMENTED, pinned to `e5db6988`).

`behavioral_qc: APPROVED` (re-review) — **Quality 4**

## Both findings closed, re-derived independently

Every mutation below was applied to this worktree, run in the foreground via `flock /tmp/dune.lock dev/lib/run-in-env.sh dune runtest --force analysis/scripts/build_snapshots/test`, and reverted. Final tree clean; suite green at `Ran: 12 / OK`.

| # | probe | observed |
|---|-------|----------|
| base | none | `Ran: 12`, **exit 0** |
| 1 | clear derived `active_through` for flagged symbols in `_entry_with_derived_marker` | `arming the level pass changed a manifest entry`, `Failures: 1`, **exit 1** |
| 1b | probe 1 applied **and `GONE` removed from `_all_symbols`** | **exit 0** — the real harm goes undetected |
| 2 | hoist `_classify_level` above both `_cut_splice` and `_clean_tail` | both ordering cases fail, `Failures: 2`, **exit 1** |
| 2a | hoist above `_clean_tail` only | only the post-tail-rule case fails, `Failures: 1`, **exit 1** |
| 3 | dead emission path (`_classify_level` always `None`) | `Failures: 5` incl. `uncut_splice_fixture_is_reported`; `level_classifies_the_post_splice_cut_series` **not** among them |
| A | `Option.map (_active_through_of_bars bars) ~f:(fun _ -> assert false)` | **exit 0** — the assert never fires |

**CP1 closed.** `_manifest_entries` compares whole `file_metadata` records via the derived `equal_file_metadata`, `path` normalised to basename. Probe 1 is the exact manifest-only harm and it reddens.

**CP3 closed, and more tightly than reported.** Probe 2a shows each half of "after the splice cut **and** after the tail rule" is pinned *independently*, not merely the combined hoist.

## The judgement calls

- **Equivalent-mutant claim: confirmed, and stronger than stated.** `analysis/data/storage/csv/` contains zero occurrences of `active_through` — the CSV format neither writes nor reads the column — and EODHD sets it `None` (`http_client.ml:171`). Probe A proves the bar-level field is never `Some` anywhere in this suite, so the predecessor's site was undetectable regardless of what the test compared. The first-pass CP1 finding was **right in conclusion, inert in demonstration**.
- **Deeper blindness: real, and `GONE` closes it.** Probe 1b is decisive — with the genuine harm applied and `GONE` removed, the whole-value comparison runs green. Fixing only the projection would have yielded a test that looks whole-value and still cannot see the harm. Restoring `GONE` is the sole difference that reddens probe 1, proving by elimination that `GONE` is both flagged and carries a non-`None` derived marker.
- **`SPLICED` negative assertion: non-vacuous, because of the control.** Probe 3 kills the emission path: the control reddens while the "no row" assertion passes vacuously. The control is doing exactly the work it claims.
- **No weakening.** All nine pre-existing cases keep their assertions; the only edit to an old case strengthens it. Widened `_all_symbols` introduces no literal collisions.

## Non-blocking residuals

- **R1** — PR body Test-plan table still lists 9 rows and describes the no-op case as comparing `payload_md5` lists; understates the committed test and omits the three ordering cases. Under-advertising, so no CP2 gate trips. *harness_gap: LINTER_CANDIDATE* (suite `>:::` names vs PR-body table names is mechanical).
- **R2** — `_entries_of_build` builds only `HIGH`/`MIXED`/`REAL`/`GONE`, so the byte-identical claim is unpinned over the splice-cut and stray-drop paths this rework added. *harness_gap: LINTER_CANDIDATE*.
- **R3** — `_uncut_splice_row` is a prefix, not a full row; the one row assertion in the file that does not pin its statistics. Defensible for a control arm. *harness_gap: ONGOING_REVIEW*.

No NEEDS_REWORK items.
