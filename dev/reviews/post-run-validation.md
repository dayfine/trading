Reviewed SHA: 0687955b9f3f0940a473aba73aa7430677441802

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
