Reviewed SHA: d75d8b549a489f5be341950a2f22c4cc4f8e477a

# QC review — cleanup track

Most recent review is at the **bottom** of this file. `record_qc_audit.sh` takes
the **last** occurrence of each `*_qc:` field and the **last** `## Quality Score`
section, so new entries must be appended, never prepended.

## PR #2099 — `cleanup/support-floor-citation` (MERGED `aca88729`)

Split the `support_floor.mli` stop-rule citation: `Ch. 6 §5.1` for the long
rule, `Ch. 7 §6.3` for the short rule. Doc-comment only, no behavior change.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

Full verdicts are PR review comments on #2099 (the authoritative channel per
`.claude/rules/pr-merge-gates.md`). Written here by the **orchestrator**, not by
the QC agents: both were fenced read-only because the GHA container shares a
single git working tree, so a file write from an agent would land on a sibling
agent's branch. This file exists so the `Reviewed SHA:` idempotency key that
Step 1.5 and Step 0.5 Condition 1 depend on is actually present — its absence
was a carried `[medium]` from run 3.

**Field format matters.** The three `*_qc:` lines above are deliberately at
column 0 with no list marker or backticks, and the `## Quality Score` heading
below is followed by a bare integer. `record_qc_audit.sh` greps
`^structural_qc: (APPROVED|NEEDS_REWORK)` and reads the first non-blank line
after a `## Quality Score` heading. A prettier rendering (`- \`structural_qc:
APPROVED\` — 5/5`) parses to **SKIPPED / null** *without erroring* — a silently
wrong audit record. See §Escalations in `dev/daily/2026-07-26-run4.md`.

### Structural (5/5)

All rows PASS or NA. A1 NA (`weinstein/stops/lib/` is not on the core-module
watch-list); A3 PASS on exactly 2 in-scope files with zero drift; P6 NA (no test
files). Confirmed the change is strictly inside the header `(** … *)` block —
no `val`, no `type`, no value, no `.ml` change.

### Behavioral (4/5)

Verified both cited sections from primary source, including their parent
headings (which carry the book-chapter attribution):

- `## 5. Stop-Loss and Selling Rules (Ch. 6)` → `### 5.1 Initial Stop Placement`
  contains, **verbatim**, "Place below the significant support floor (prior
  correction low) BEFORE the breakout". `Ch. 6 §5.1` ✅
- `## 6. Short-Selling Criteria (Ch. 7)` → `### 6.3 Short Stop (Buy-Stop) Rules`
  contains "Initial buy-stop: above prior rally peak (above round number)".
  `Ch. 7 §6.3` ✅

Both citations resolve to sections that exist **and contain the claim** — so
this is not a fifth instance of the recurring defect.

Held at 4/5 for two reasons, both non-blocking:

1. The short line's **"BEFORE the breakdown"** is not stated in §6.3. It is a
   two-hop inference from "**Initial** buy-stop" + §6's explicit "Mirror image
   of buying" preamble + §5.1's "BEFORE the breakout". Sound and structurally
   licensed (§6.2 enumerates the differences from buying, and stop *timing* is
   not among them), but derived rather than quoted.
2. An **uncited** domain claim remains in the same file: the `min_pullback_pct`
   docstring says *"Weinstein's book default is [0.08] (8%)"* with no section
   reference. Nearest support is §5.2 ("substantial correction (8-10%+)"). This
   is the same detection-evading shape as the four defects already found — a
   numeric domain constant asserting book provenance without a `§N.N` token.

Both filed to `dev/status/cleanup.md` §Backlog. Item 2 is classified
`harness_gap: LINTER_CANDIDATE` — a linter *can* mechanically flag docstrings
that assert book provenance without a section token, which would catch this
whole defect family going forward. Item 1 is `harness_gap: ONGOING_REVIEW`:
telling a faithful paraphrase from drift requires reading both sections in
context and is not mechanizable.

## Quality Score

4 — behavioral score (takes precedence over structural 5/5 per the audit
convention). Correctly targeted, independently verifiable fix with an honest
status note; held off 5 by the derived "BEFORE the breakdown" clause and the
uncited 8% claim remaining in the same file.

## Verdict

APPROVED

---

## PR #2112 — `cleanup/min-pullback-citation` (2026-07-27 run 2)

Adds the missing `(§5.2)` citation to the `min_pullback_pct` doc-comment in
`trading/trading/weinstein/stops/lib/support_floor.mli`, which previously
asserted "Weinstein's book default is 8%" with no section token — the **fifth**
instance of the citation-defect family found in four days, and itself a finding
raised by qc-behavioral on #2099 above. Doc-comment only; 2 files, +5/-2 (the
second file flips the `dev/status/cleanup.md` backlog entry to `[x]`).

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

### Structural (APPROVED, 4/5)

H1/H2 PASS (`@fmt` clean, `dune build` exit 0). H3 PASS **with a pre-existing
unrelated failure**: full `dune runtest` exits 1 solely on
`Tuner.Bayesian_opt:11`/`:17` (`Failure("LAPACKE: 9")`), present on base `main`
and touching no file in this diff; scoped `dune runtest trading/weinstein/stops/`
green (7 binaries, 113 tests). P1–P6 NA — doc-comment-only; no functions,
constants, config fields or test files in the diff. A1 NA (`weinstein/stops/` is
not on the core-module watch-list). A2 NA (no dune files). A3 PASS — exactly the
2 files in the PR file list, sibling `citation_precision` backlog entry correctly
untouched, `dev/status/_index.md` correctly not edited.

### Behavioral (APPROVED, 4/5)

The reviewer **independently re-derived** the §5.2 support from primary source
rather than accepting the author's reasoning, and concluded the author had if
anything *under*-cited:

- §5.2 `STATE: TRAILING` (L250-252) states the identity outright — "AFTER each
  correction (8-10%+) + recovery back near prior peak: new_stop =
  below(min(correction_low, MA))" — making the 8-10%+ depth the qualifier on the
  correction whose low becomes the stop reference. That is exactly
  `find_recent_level`'s contract: same quantity, not a number coincidence. The
  author quoted the weaker `STATE: INITIAL` block instead, whose two lines
  strictly concern two *different* corrections.
- The "waiting before buying" alternative reading is **refuted**: §5.2 is titled
  *"Trailing Stop — Investor Method"* and is a post-entry state machine; nothing
  in it concerns entry. The document's actual second-entry rule (L155) is
  quantified by volume contraction 75%+, not by depth — so no depth threshold
  exists anywhere in the entry rules to conflate with.
- An independent percentage sweep (not the author's grep) confirms §5.2 is the
  only candidate. §5.3's 4-6% is correctly excluded, and for a sharper reason
  than the author gave: L278 reads "Use 4-6% initial stop **if no nearby prior
  peak**" — i.e. it governs precisely the branch where `find_recent_level`
  returns `None`. The two are complementary branches of one decision, so citing
  §5.3 would have been a real error.
- Quotes verbatim; no paraphrase drift (the failure mode of the four prior
  defects). Stated default matches code: `stop_types.ml:56`
  `min_correction_pct = 0.08` → `weinstein_stops.ml:82`.

Non-blocking residual (recorded, not failed): the retained topic sentence
"Weinstein's book default is [0.08]" is still marginally over-claimed — the book
gives a *range* and prescribes no default — but the appended clause discloses
exactly that, so the sentence read whole is self-qualifying. Citing rather than
correcting was the right call, because real support exists.

### New finding raised by this review — a sixth instance, one module over

`trading/trading/weinstein/stops/lib/stop_types.mli` line 88 asserts
"(Weinstein's 8% rule)" and line 63 documents the same depth — **neither carries
a `§N.N` token**. Identical detection-evading shape. Filed to
`dev/status/cleanup.md` §Backlog.

This makes the family **six-for-six** and strengthens the standing
`harness_gap: LINTER_CANDIDATE`: a check flagging book-provenance docstrings
that lack an adjacent `§` token would catch the whole class mechanically. Six
manual catches in four days is the argument for mechanizing it.

### Delivery note

Both verdicts are PR review comments on #2112 (the authoritative channel per
`.claude/rules/pr-merge-gates.md`). **`gh` is not installed in this runner**:
qc-behavioral discovered this and posted via the REST API with curl on its own
initiative; qc-structural reported it could not post, and the orchestrator
posted its verdict on its behalf (review id 4784003592). Dispatch prompts should
name curl rather than `gh` — recorded as an escalation.

## Quality Score

4

## Verdict

APPROVED

---

## PR #2121 — `cleanup/stop-types-citation` (MERGED `6676ff8e`)

Reviewed at `1fbb08dd`. Orchestrator run 30262098532 (2026-07-27 run 3).
The **sixth** defect in the citation family — the one #2112's review filed.

Two files, +8/-3: `trading/trading/weinstein/stops/lib/stop_types.mli`
(comment-only) and the `dev/status/cleanup.md` backlog flip. Default
`min_correction_pct = 0.08` unchanged; no signature, exported name, or code
token touched.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

### Structural

File list from the REST API (`/pulls/2121/files`) per the A3 provenance
requirement, **not** a git-log ancestry walk: exactly `dev/status/cleanup.md`
and `stop_types.mli`. Behaviour-free confirmed; `dev/status/_index.md`
untouched per the reconcile contract. H1–H3 / P1–P6 NA (doc-only).

### Behavioral — independently re-derived

The reviewer re-derived the citation from the primary source rather than
auditing the author's chain, and enumerated **every** percentage in the
reference doc (13 `%`-bearing lines, plus a check for spelled-out `percent`
forms, so the enumeration is exhaustive).

- **Site 1 — `min_correction_pct` (`:62-72`) → §5.2 correct, exactly.** The
  field's contract is "minimum pullback to qualify as a correction (default
  0.08)"; §5.2 states the qualifying depth as `8-10%+` in three state blocks
  (book-ref :239, :242, :251). `0.08` is the literal lower bound — same
  quantity, not a numeric coincidence.
- **Site 2 — `support_floor_lookback_bars` (`:87-93`) → §5.2 correct and
  correctly scoped.** Checked separately because this field documents a
  *lookback window*, not a depth. The citation attaches narrowly to "depth
  threshold is shared with `min_correction_pct`", and **the sharing is real in
  code**: `weinstein_stops.ml:75` passes `~lookback_bars:…` and `:82` passes
  `~min_pullback_pct:…` into the same `Support_floor` call. It does not
  overreach onto the adjacent claims §5.2 would not support — the 90-bar window
  keeps its engineering rationale with no book claim, and the support-floor
  concept is §5.1, already cited at `support_floor.mli:4,9`.
- **Near-misses confirmed distinct:** §5.1's ">15% risk" (entry-risk cap on
  `max_stop_distance_pct`) and §5.3's "4-6% initial stop" (the **trader**-method
  stop *size*, not the **investor**-method correction-qualification *depth*).

### FLAG-A (non-blocking) — exhaustiveness claim partially refuted, immaterially

The PR body claims no other percentage-qualified correction/pullback language
exists. Two lines were missed: book-ref:155 ("On pullback: volume should
contract by 75%+") and book-ref:336 ("Only ~50% of breakdowns pull back").
Neither expresses a **depth** — one is a volume quantity, one a frequency — so
neither competes as a citation and the conclusion stands: §5.2 is uniquely the
correction-depth authority. The *commit message* states the tighter, correct
form; only the PR body over-generalises.

**This matters for the standing `LINTER_CANDIDATE`:** a naive `%`-adjacency
heuristic will hit both of these lines. The linter needs a depth-vs-quantity
discriminator, not just proximity.

### FLAG-B (non-blocking, out of scope) — possible defects seven and eight

`stop_types.mli:36` and `:114` cite "book §Stop-Loss Rules" — a `§` token that
is **not** `§N.N`-numbered. Correctly left alone here (the backlog item named
lines 63/88, which carried no `§` at all), but the proposed linter must decide
whether a *named*-section `§` satisfies the rule. If not, these are the next two
in the family.

### Verification

`dune build @fmt` exit 0, `dune build` exit 0,
`dune runtest trading/weinstein/stops` exit 0 (41+6+9+10 tests). CP1 PASS — the
annotated pre-existing contract is pinned by `test_weinstein_stops.ml:473`
(4.5% < 8% → no ratchet). CP2 PASS; CP3/CP4 NA. Domain L1–L4 NA: comment-only,
no stop behaviour can regress.

### Merge note

Merged after a branch update (base had advanced past #2113 and #2118).
`stop_types.mli` verified **byte-identical** to the reviewed tip through the
merge, and `dev/status/cleanup.md` verified to carry both this PR's entry flip
**and** #2113's `flake_root_cause` flip independently — so the verdicts carried
and no re-review was needed.

### Process note (author-declared)

The author initially made the edit in the shared parent checkout rather than its
own worktree, caught it immediately, reverted with `git checkout --` before
staging anything, verified clean, and redid the work in `/tmp/ws-citation`. No
contamination reached the shared tree. Recorded because it is the second
worktree-discipline near-miss in two runs.

## Quality Score

4

## Verdict

APPROVED

## PR #2152 — `cleanup/cholesky-spd-justification` (MERGED `14270b57`)

Rewrote the docstring on `_well_conditioned_spd` in
`trading/trading/backtest/tuner/test/test_bayesian_opt_cholesky.ml`. The old text
claimed the fixture was "strictly diagonally dominant (hence positive-definite)";
that justification is false. Comment-only — `dune runtest` exit code unchanged,
8/8 tests in `test_bayesian_opt_cholesky.exe` pass identically.

**The originating finding's numbers were themselves wrong**, and the review caught
it. The finding (2026-07-27 run 2 qc-behavioral FLAG-A on PR #2113) claimed
dominance broke at n=100 with λ_min ≈ 1.69. Three independent measurements — the
implementer's pure-OCaml power iteration, the orchestrator's Python power
iteration, and the behavioral reviewer's LDL^T negative-pivot count with bisection
(a *certificate* via Sylvester's law of inertia, not an estimate) — agree instead:

| n | rows violating dominance | worst margin | λ_min |
|---|---|---|---|
| 4 | 0/4 | +1.4583 | 1.8691 |
| 32 | 9/32 | −0.4101 | 1.8289 |
| 100 | 61/100 | −1.5086 | 1.8278 |

Dominance first fails at **n=32** among `_certified_sizes` (n=21 in absolute
terms), not n=100. λ_min ≈ **1.83**, not 1.69. The reviewer diagnosed the origin of
the wrong figure: 1.69 is within rounding of `1 + ln 2 = 1.6931`, the Toeplitz-symbol
lower bound for this matrix — **a valid lower bound reported as if it were the
eigenvalue**. Recorded because it is a repeatable failure mode: the number looked
plausible precisely because it was a correct bound for a different question.

Note Gershgorin cannot settle this fixture: for a symmetric matrix its lower bound
*is* the diagonal-dominance margin, which is negative here. That is exactly why the
old docstring's reasoning failed, and the orchestrator's initial suggestion to use
Gershgorin was withdrawn mid-review for the same reason.

Two non-blocking FLAGs on wording, neither materially misleading: "from n=32 on" is
scoped to certified sizes (absolute first failure is n=21), and "~1.83 at every
size" rounds to 1.87 at n=4. "Well-conditioned" was confirmed rather than assumed:
κ = λ_max/λ_min ranges 2.21–3.54.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

Full verdicts are PR review comments on #2152 (the authoritative channel per
PR-D'a): structural `4801535251` (quality 5), behavioral `4801657407` (quality 4).

Both reviews were posted at tip `7d818fd7`. The branch was then `update-branch`d to
`46ff6510` (a merge of main, PR content byte-unchanged) before merging as `14270b57`;
CI was re-verified green on `46ff6510` immediately before the merge.

## Quality Score

4 — Correct, minimal, and the review upgraded it from "replaces a stale claim" to
"replaces a stale claim with an independently triple-verified one, and explains why
the original was wrong."

Reviewed SHA: 7d818fd772e2f62fff73081d94cab2f3f898840d


## PR #2162 — `cleanup/rescale-duplication` (MERGED `de34c507`, orchestrator run 30458563291)

Dispatched as a dedupe of the `rescale_duplication` backlog entry; shipped as a
**correctly-declined dedupe plus two findings**. Diff is 3 files, +14 −3,
comment/prose only — no executable code changed.

**Finding 1 — A2 blocks the switchover.** Calling
`Adjusted_basis.to_adjusted_basis` from `Svg_series` would add
`weinstein.snapshot_pipeline` (an `analysis/` library) as a dependency of
`trading/trading/weinstein/snapshot/lib/dune` — a new `analysis/` →
`trading/trading/` edge outside `trading/trading/backtest/**`. `svg_series.mli`
already documents the boundary as deliberate. qc-structural confirmed
independently against both dune files.

**Finding 2 — the backlog's "byte-equivalent" claim was wrong.** The rescale
formula matches, but `Svg_series` builds via `Types.Daily_price.make` without
`~active_through` (defaults to `None`) while `Adjusted_basis` uses
`{ b with ... }` and preserves it. Dormant: qc-behavioral enumerated the single
`_to_adjusted_basis` call site and all seven `weekly_bars` consumers
(`html_report_renderer.ml:50`, `test_svg_chart.ml:531,575`,
`test_svg_series.ml:36,53,79,100`) and confirmed none can observe it — so
dormancy is stronger than the PR claims and does not depend on `weekly_bars`
being private.

**Finding 3 — the backlog file path was stale**: `snapshot/gen/lib/svg_series.ml`
does not exist; the real file is `snapshot/lib/svg_series.ml`. Corrected.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 0.

| Gate | Verdict | Quality | Review id | Posted at SHA |
|---|---|---|---|---|
| qc-structural | APPROVED | 5 | 4809439338 | `d75d8b549a489f5be341950a2f22c4cc4f8e477a` |
| qc-behavioral | APPROVED | 4 | 4809600081 | `d75d8b549a489f5be341950a2f22c4cc4f8e477a` |
| CI | green | — | — | re-verified on the tip immediately before merge |

## Quality Score

4 — careful and well-evidenced; held back from 5 because the durable in-code
comments omit the `active_through` divergence the PR itself discovered.

**Open FLAG (non-blocking, carried).** Nothing pins the two implementations in
sync — no test observes both, and `arch_layer_test.sh` guards only the reverse
edge. qc-behavioral notes a cross-file pin *is* legal under A2 (the
`trading/trading/` → consumed-by-`analysis/` direction is permitted, and
`weinstein_snapshot_gen` already links both), so the follow-up is actionable
rather than blocked. The PR parked it inside an `[x]`-closed backlog entry,
where no scan of open `- [ ]` items would find it; the orchestrator re-filed it
as an open item in `dev/status/cleanup.md` in the same run.
`harness_gap: LINTER_CANDIDATE`.

---

## PR #2166 — `cleanup/adjusted-basis-sync-pin` (2026-08-03)

Reviewed SHA: 62c3288500fa2d2cac955fd0384b1231e4dbb3ed

## Structural QC — cleanup/adjusted-basis-sync-pin

### Hard Deterministic Gates

| Gate | Result | Evidence |
|------|--------|----------|
| H1: `dune build @fmt` | PASS | Verified by cleanup agent on this commit; exit 0 |
| H2: `dune build` | PASS | Verified by cleanup agent on this commit; exit 0 |
| H3: `dune runtest` | PASS | Verified by cleanup agent; 9/9 tests pass (7 original + 2 new) |

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| P1 | Functions ≤ 50 lines (linter) | PASS | All test functions under 20 lines; H3 passed |
| P2 | No magic numbers (linter) | PASS | Test data is semantic (magnitudes for IEEE-754 testing); H3 passed |
| P3 | Config completeness | NA | Test file, not production implementation |
| P4 | Public-symbol export hygiene (linter) | NA | Test file; H3 passed |
| P5 | Internal helpers prefixed per convention | PASS | All helpers prefixed `_` (e.g. `_bar`, `_equal_bar`, `_bits`); follows OCaml patterns |
| P6 | Tests conform to `.claude/rules/test-patterns.md` | PASS | One `assert_that` per test; uses Matchers library composably; no forbidden patterns (`List.exists equal_to bool`, bare `assert_failure`, nested `assert_that`); 2 new tests follow the established pattern |
| A1 | Core module modifications (Portfolio/Orders/Position/Strategy/Engine) | NA | No modifications to core modules; only tests and docstring |
| A2 | No new `analysis/` imports into `trading/trading/` outside backtest exception surface | PASS | Test adds `weinstein_trading.snapshot` (trading/trading lib) to `snapshot_pipeline/test/dune`; this is the **reverse direction** (trading/trading → analysis), explicitly allowed per A2 rule ("Reverse direction … is always fine"). No cycle created (cleanup agent verified `dune build` exit 0; `weinstein_snapshot_gen` already links both libs). Precedent exists: `snapshot_pipeline/lib` already depends on `trading.data_panel.snapshot`. |
| A3 | No unnecessary modifications to existing modules | PASS | All 4 files changed are scoped and necessary: status update (cleanup item closure), docstring fix (inaccuracy in .mli), test dune dependencies (pinning test requirements), new tests (implementation of the pin). |

### Quality Score

5 — Clean implementation with proper pinning test, mutation-verified correctness, and accurate docstring fix.

### Verdict

**APPROVED**

---

### Summary

**PR #2166 closes the `adjusted_basis_sync_pin` cleanup backlog item** (flagged by qc-behavioral on PR #2162 as `harness_gap: LINTER_CANDIDATE`). The solution adds a cross-file pinning test verifying that two duplicated rescale implementations (`Adjusted_basis.to_adjusted_basis` in analysis and `Svg_series._to_adjusted_basis` in trading/trading) remain in sync.

**Implementation quality:**
- Two pinning tests added: `test_svg_series_weekly_bars_matches_adjusted_basis_on_a_split` (verifies equivalence on all fields except `active_through`) and `test_svg_series_weekly_bars_drops_active_through` (pins the documented divergence).
- Mutation-verified: perturbing the rescale factor by 1% turns the new test RED, confirming the test catches real drifts.
- Docstring fix accurately documents the `active_through` divergence (previously claimed "semantics match").
- Test pattern compliance: all tests follow Matchers library conventions, one `assert_that` per value, proper matcher composition.

**Dependency direction (A2):** Legitimate. Test depends on `weinstein_trading.snapshot` (trading/trading lib), which is the **allowed** reverse direction. No cycle.

**No structural violations. Mergeable.**

---

### Behavioral QC (iteration 0)

Closes the `adjusted_basis_sync_pin` backlog item — the `harness_gap:
LINTER_CANDIDATE` FLAG carried at the bottom of the #2162 entry above. Adds two
cross-file pin tests to `test_adjusted_basis.ml`, one dune dep
(`weinstein_trading.snapshot` into `snapshot_pipeline/test/dune`), and a
docstring correction to `adjusted_basis.mli`. Test + doc-comment only; no
executable library code changed.

structural_qc: APPROVED
behavioral_qc: NEEDS_REWORK
overall_qc: NEEDS_REWORK

### File-state note (for the orchestrator, not a review finding)

The dispatch brief stated this file's line 1 already read `Reviewed SHA:
62c32885…` and that a #2166 structural section was present. Neither was true in
`/__w/trading/trading` at review time: line 1 still reads
`d75d8b549a…` (PR #2162's key), `git status --porcelain dev/reviews/cleanup.md`
was empty, and no `#2166` section existed. The structural review's hand-recovery
did not land in this tree. Line 1 left untouched per instruction; this section
carries its own `Reviewed SHA:` line, matching the convention PR #2152's entry
already uses, so the last-occurrence key resolves to the right SHA.

`gh` is **not installed in this runner** (same finding as #2112's delivery note,
still unfixed). The PR body could therefore not be read directly; CP2 is assessed
against the author's own in-diff `dev/status/cleanup.md` entry plus the dispatch
brief's summary of the PR's claims.

### The load-bearing claim — VERIFIED, the pin does not pass for the wrong reason

The pin is only valid if `Svg_series.weekly_bars [b]` genuinely reduces to the
private `_to_adjusted_basis`. Re-derived from source at the PR tip rather than
accepting the author's assertion:

```
weekly_bars bars =
  List.map bars ~f:_to_adjusted_basis
  |> List.group ~break:(fun a b -> not (Date.equal (_monday a.date) (_monday b.date)))
  |> List.map ~f:_fold_week
```

On a one-element list: `List.map` gives `[a]` where `a = _to_adjusted_basis b`;
`List.group` never invokes `~break` on a singleton, yielding `[[a]]`; and
`_fold_week [a]` has `first = last = a`, so every field folds back out unchanged
— `open_price` from `first`, `high_price` = `Float.max neg_infinity a.high_price`,
`low_price` = `Float.min infinity a.low_price`, `close_price`/`adjusted_close`
from `last`, `date` = `last.date`, `volume` = `List.sum (module Int) [a]`. All
identities on a singleton for finite inputs.

`active_through` closes cleanly too: `_fold_week` builds via
`Types.Daily_price.make` **without** `~active_through`, and `make`'s optional
argument defaults to `None` (verified in `analysis/data/types/lib/daily_price.ml`
+ `.mli`) — but `_to_adjusted_basis` is *also* built through `make` without it, so
it is already `None` going in. `_fold_week` is therefore the identity on a
singleton including that field.

⇒ `weekly_bars [b] = [ _to_adjusted_basis b ]` **exactly**. No filtering, no date
bucketing, no volume aggregation, no early return. The author's claim holds, and
the public `svg_series.mli` contract for `weekly_bars` states the same
aggregation semantics independently. **Confirmed valid proxy.**

Two reinforcing points the PR did not claim:

- `Types.Daily_price.t` carries `[@@deriving eq]` over all 8 fields and
  `_equal_bar` passes `~cmp:Types.Daily_price.equal`, so the pin is structural
  over `date` / `volume` / `adjusted_close` too — not just O/H/L/close. A
  chart-side change that started rescaling `volume` (explicitly declined in
  `_to_adjusted_basis`'s comment) or that re-dated the bar **would** be caught.
- **The pin is bidirectional, contrary to the asymmetry the dispatch brief
  suspected.** The author's mutation evidence perturbs only the pipeline side,
  but the test compares two *independently computed* values; mutating
  `svg_series.ml`'s `_factor` moves `via_snapshot` while `via_pipeline` holds
  still, so chart-side drift — the direction the original finding was actually
  about — turns it RED equally. The evidence is one-sided; the test is not.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new/changed `.mli` docstrings has an identified test that pins it | **FAIL** | Changed `adjusted_basis.mli` header makes three claims. (a) "open/high/low/close rescale matches `Svg_series`'s chart-side rescale" → pinned by `test_svg_series_weekly_bars_matches_adjusted_basis_on_a_split`. (c) "[Svg_series]'s private duplicate always drops it to [None]" → pinned by `test_svg_series_weekly_bars_drops_active_through`. **(b) "this function preserves it from the input bar" → NOT pinned by any test.** The docstring's own parenthetical "(pinned by [test_adjusted_basis.ml])" scopes over the whole except-clause and so asserts (b) is pinned there. Detail below. |
| CP2 | Each claim in the PR's "Test coverage" record has a corresponding committed test | PASS | Assessed against the author's in-diff `dev/status/cleanup.md` entry (`gh` unavailable): "two cross-file pin tests … equal on all fields except `active_through`, which is separately pinned" — both tests exist at the tip, are registered in `suite` (2 new entries → 9 total, matching the reported 9/9), and the description is accurate. The `weinstein_trading.snapshot` dune dep is present as described. No advertised-but-absent test. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just `size_is` | PASS | `_equal_bar` is `equal_to ~cmp:Types.Daily_price.equal` — whole-record structural equality over all 8 fields, not a field-count or size proxy. Test 2 uses `is_none` on the single field under test, which is the right granularity. One non-blocking weakness noted below (`List.hd_exn` does not pin list length). |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | PASS | The NaN / non-positive-close guard is called out in `adjusted_basis.ml`'s `_factor` comment and the `.mli`; all three guarded cases are exercised pipeline-side by the pre-existing `test_nan_raw_close_admits_no_factor` / `test_zero_raw_close…` / `test_negative_raw_close…`. This PR introduces no new guard claim. Residual coverage note below — the *cross-file* pin does not reach the guard branch, but the PR does not claim it does. |

### Behavioral Checklist (Weinstein domain)

**All rows NA — S1–S6, L1–L4, C1–C3, T1–T4, and A1.** Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely":
test-only + doc-comment PR touching no domain logic. No stage classification,
stop rule, screener cascade, or strategy behaviour is reachable from this diff;
the rescale is a data-normalisation helper, not a domain decision rule. A1 NA —
qc-structural did not FLAG a core-module modification, and none of
`portfolio/`, `orders/`, `position/`, `strategy/`, `engine/` appears in the diff.

### NEEDS_REWORK Items

#### CP1: `.mli` claims a pin for `active_through` preservation that no test provides

- **Finding.** The revised docstring reads: *"— {b except} for [active_through]:
  this function **preserves it from the input bar**, while [Svg_series]'s private
  duplicate always drops it to [None] **(pinned by [test_adjusted_basis.ml])**."*
  The pipeline half of that divergence is never observed by any test.
  `test_svg_series_weekly_bars_matches_adjusted_basis_on_a_split` does construct
  `b` with `active_through = Some _as_of`, but then compares against
  `{ via_pipeline with active_through = None }` — the field is **overwritten
  before the comparison**, so `via_pipeline.active_through` is discarded
  unexamined. `test_svg_series_weekly_bars_drops_active_through` asserts only on
  the `Svg_series` side. And all seven pre-existing tests use `_bar`, whose
  fixture sets `active_through = None`, so they pin at most the trivial
  `None → None` case; `{ b with … }` carrying a `Some d` through is asserted
  nowhere in the suite. Verified by enumerating all 9 `active_through`
  occurrences in the file and the fixtures of the five sibling pipeline test
  files (all `active_through = None`).
- **Why it matters rather than being pedantry.** This is precisely the field the
  whole duplication finding turns on, and the closed `rescale_duplication` entry
  states the divergence "would bite the moment `weekly_bars` is changed to
  preserve `active_through`." A future edit changing `to_adjusted_basis` from
  `{ b with … }` to a `Daily_price.make` call — the single most likely
  refactor, since it would make the two copies textually identical — would
  silently drop `active_through` on the pipeline side, falsify this docstring,
  and leave the entire suite green. The PR's own subject matter is "a
  hand-maintained comment is a note, not a contract"; half of the corrected
  comment is still a note.
- **Location.** `trading/analysis/weinstein/snapshot_pipeline/lib/adjusted_basis.mli`
  lines 9-13 (the claim); `trading/analysis/weinstein/snapshot_pipeline/test/test_adjusted_basis.ml`
  line 166 (the masking `{ via_pipeline with active_through = None }`).
- **Authority.** The module's own `.mli` docstring, which per
  `.claude/rules/qc-behavioral-authority.md` is the primary contract for a
  non-domain PR; plus CP1 in `.claude/agents/qc-behavioral.md`.
- **Required fix.** One assertion. Either add to test 1:
  `assert_that via_pipeline.active_through (is_some_and (equal_to _as_of))`,
  or add a sibling `test_to_adjusted_basis_preserves_active_through`. Both
  halves of the documented divergence then hold a contract. (Alternatively,
  narrow the docstring's parenthetical to name only the drop — but pinning is
  strictly better here and costs one line.)
- **harness_gap: ONGOING_REVIEW.** Detecting that a docstring's claimed pin
  covers only part of a compound claim requires reading the claim and the test
  together and noticing which field the comparison masks. Not mechanizable —
  the test does reference `active_through` on the line that discards it, so any
  grep-adjacency heuristic reports a false PASS.

### Non-blocking FLAGs (recorded, not failing)

**FLAG-A — the cross-file pin never enters the guard branch.** The pin exercises
exactly one point: `close = 100.0`, `adjusted = 25.0`, factor `0.25`, finite. Both
copies also implement a `f = 1.0` guard for NaN / zero / negative raw close. The
three guard tests are pipeline-side only. **Delete or alter the guard in
`svg_series.ml`'s `_to_adjusted_basis` and nothing in the repository goes red** —
the new pin's fixture cannot reach that branch. That is the same silent-drift
shape the PR set out to close, one branch over, and it sits on exactly the two
files named by the still-open `adjusted_basis_guard_asymmetry` backlog item.
Cheap follow-up: extend the pin to a small fixture list
(`[nan; 0.0; -2.0; 100.0]` closes) and compare each. `harness_gap:
LINTER_CANDIDATE` — a table-driven cross-file pin over the guard cases is
deterministic and would catch this whole class.

**FLAG-B — `0.25` is the most forgiving factor available.** `0.25` is a power of
two, exactly representable, so every multiplication in the comparison is exact.
A divergence that manifests only on an inexact factor (e.g. the dividend-only
`0.9987` case already fixtured pipeline-side, or a reassociation like
`b.open_price *. (adj /. close)` vs `(b.open_price *. adj) /. close`) would slip
through. Adding the existing dividend-only bar to the cross-file comparison costs
one line and closes it.

**FLAG-C — `List.hd_exn` does not pin the list length.** Both tests take
`List.hd_exn (Svg_series.weekly_bars [ b ])`. The reduction proof above shows the
result is exactly one element, but the test does not assert it: if `weekly_bars`
ever returned two elements for a singleton input, `hd_exn` would quietly compare
only the first and stay green — weakening the very premise the pin rests on.
`assert_that (Svg_series.weekly_bars [ b ]) (elements_are [ _equal_bar … ])` pins
element *and* count in one matcher, and is the form
`.claude/rules/test-patterns.md` §3 prefers over extraction.

### What the PR got right

Recorded because it is the substance of the item and it is genuinely well done:
the singleton-reduction argument is correct and load-bearing, and the author
wrote it down in the test's own docstring rather than leaving it implicit; the
A2 legality of the new dune edge was reasoned through before the dep was added;
the deliberate divergence is pinned separately instead of being buried in a
tolerance; the status-file entry describes what shipped without overclaiming;
and the `.mli` correction removes a genuinely wrong "semantics match" sentence.
The single finding is a one-line gap in an otherwise careful pin.

## Quality Score

3 — Acceptable. The core deliverable is correct: the singleton-reduction proxy is
valid (independently re-derived, not taken on trust), the pin is structural over
all 8 fields, and it catches drift in **both** directions despite one-sided
mutation evidence. Held to 3 by one fixable CP1 gap — the corrected docstring
names a test as pinning `active_through` preservation, and that half is masked
out of the comparison — plus three narrowing FLAGs on the pin's breadth.

## Verdict

NEEDS_REWORK

---

Reviewed SHA: 83a3a3ff

## PR #2166 — `cleanup/adjusted-basis-sync-pin` — behavioral re-review (rework iteration 1)

Re-review of the rework commit `83a3a3ff` against my own `NEEDS_REWORK` (quality
3/5) at `62c32885`. Scope of the rework: +30/-7 across
`test_adjusted_basis.ml` and `dev/status/cleanup.md`. No production logic
touched by either commit; the PR remains test-only + one `.mli` doc-comment
correction.

Gates on `83a3a3ff` (run by the dispatcher, not re-run here — this review is
read-only and does not invoke `dune`): `dune build @fmt` exit 0, targeted
`dune runtest analysis/weinstein/snapshot_pipeline/test` exit 0 (10/10), full
`dune runtest` exit 0. Two independent mutations, each reverted with the file
confirmed byte-identical afterwards, both went RED — see the disposition of CP1
and FLAG 1 below.

### Disposition of the iteration-0 findings

**CP1 (blocking) — CLOSED.** The gap was that the corrected `.mli` named
`test_adjusted_basis.ml` as pinning `active_through` *preservation*, while the
split-sync test overwrote `via_pipeline.active_through` before comparing, so the
`Some d` half was asserted nowhere. The rework adds

```ocaml
assert_that via_pipeline.active_through (is_some_and (equal_to _as_of));
```

directly on the pipeline output, before the masked cross-file comparison. This
is the exact assertion the finding requested, on the correct value, and it is
change-detecting: the dispatcher's mutation (adding `active_through = None;` to
`to_adjusted_basis`'s record — the `Daily_price.make` refactor I named as the
likely future regression) produced
`Adjusted_basis:7 ... Expected Some but got None`, 1 failure of 10. The masked
comparison is retained, which is right: it still pins the O/H/L/C equality, and
the divergence itself stays pinned separately by
`test_svg_series_weekly_bars_drops_active_through`.

**FLAG 1 (guard branch never entered through `weekly_bars`) — CLOSED.** New test
`test_svg_series_weekly_bars_matches_adjusted_basis_on_guarded_input` feeds
`_bar ~close:0.0 ~adjusted:25.0`. Verified both sides take the guard branch, not
just one: pipeline `_factor` evaluates `Float.is_nan 0.0` → false, then
`Float.( <= ) 0.0 0.0` → true → `f = 1.0`; `Svg_series._to_adjusted_basis`
inlines a character-identical condition on the same input, so it takes the same
branch. Not a coincidence-pin: deleting the snapshot-side guard turns the case
RED (`close_price = 25.` expected, unguarded gives `25.0 /. 0.0 = infinity`
across O/H/L). Note the residual, inherent limitation of any sync pin — deleting
*both* guards simultaneously would leave it green — but that is covered, because
the pipeline-side guard is pinned absolutely and independently by
`test_zero_raw_close_admits_no_factor`. Combined, the pipeline guard is pinned
in absolute terms and the snapshot guard relative to it. That is complete.

**FLAG 2 (`0.25` is the most forgiving factor) — CLOSED, and specifically
checked for the backfire this reviewer's own suggestion could have caused.** The
split fixture moved from `(close 100, adjusted 25)` → `(close 70, adjusted 10)`,
i.e. `f = 10.0 /. 70.0`, a repeating binary fraction. Since
`Types.Daily_price.equal` is `[@@deriving eq]` — exact structural float
equality, no epsilon — an inexact factor is only safe if both implementations
perform the *identical* operation sequence. Traced both:

| | factor | O/H/L | close |
|---|---|---|---|
| `Adjusted_basis._factor` / `to_adjusted_basis` | `b.adjusted_close /. b.close_price`, computed once | `b.<field> *. f` | `b.adjusted_close` |
| `Svg_series._to_adjusted_basis` | `b.adjusted_close /. b.close_price`, computed once | `b.<field> *. f` | `b.adjusted_close` |

One correctly-rounded division, then three independent multiplications, same
order, on both sides. No fused multiply-add is generated for a bare `*.`, and
OCaml doubles carry no extended precision on x86-64, so the two are bit-identical
for *every* finite input — the exactness is guaranteed by construction, not by
the factor happening to be a power of two. **Not brittle, and not vacuous.** The
strictness is in fact the point: if a future refactor rewrote one side as
`b.open_price *. b.adjusted_close /. b.close_price`, the copies would diverge at
ulp level and this fixture would now catch it, where `0.25` would not. Verified
`Daily_price.make` on the snapshot path does no validation, clamping or
normalization — it is a bare record constructor — so it cannot introduce a
divergence either. Checked the tail risk too: no NaN reaches any compared output
in any of the three cross-file cases, so the `nan <> nan` trap in derived `eq` is
not live.

**FLAG 3 (`List.hd_exn` doesn't pin list length) — CLOSED.** `assert_that weekly
(size_is 1)` now precedes every `List.hd_exn` in the cross-file section, all
three tests. The singleton premise the whole `weekly_bars` → `_to_adjusted_basis`
reduction rests on is now asserted rather than assumed.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | PASS | Re-derived claim-by-claim against `adjusted_basis.mli` at `83a3a3ff`. (a) "O/H/L/C rescale matches `Svg_series`'s chart-side rescale" → `test_svg_series_weekly_bars_matches_adjusted_basis_on_a_split` (rescale path) + `..._on_guarded_input` (guard path); both mutation-verified change-detecting. (b) "this function preserves [`active_through`] from the input bar" → `..._on_a_split`, `assert_that via_pipeline.active_through (is_some_and (equal_to _as_of))` — **the iteration-0 gap, now closed**. (c) "`Svg_series`'s private duplicate always drops it to `None`" → `test_svg_series_weekly_bars_drops_active_through`. (d) `adjusted_close`/`volume`/`date` preserved → `test_split_rescales_ohl` (absolute expectation carrying input volume 1_000_000, adjusted 25.0, date `_as_of`). (e) "Bit-identity holds exactly when `adjusted_close = close_price`" → `test_equal_closes_is_bitwise_identity` (7 magnitudes, `_bits`); "not merely on split-free data" → `test_dividend_only_adjustment_is_not_a_no_op`. (f) "Idempotent" → `test_idempotent_on_already_adjusted_bar`. The docstring now claims no more than is enforced. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" has a corresponding committed test | PASS | `gh` is unavailable in this container, so the commit message on `83a3a3ff` (which enumerates the four fixes and both mutations) plus the `dev/status/cleanup.md` entry were used as the claim surface. Every claim checked against the committed file: `assert via_pipeline.active_through is Some _as_of` ✓ present; "new cross-file case on guarded input (close = 0.0)" ✓ present and registered in `suite`; "split factor switched … to `10.0 /. 70.0`" ✓ present; "`size_is 1` asserted ahead of every `List.hd_exn`" ✓ all three sites. No advertised test is missing from the file. Two cosmetic inaccuracies in the status entry are recorded as non-blocking follow-ups below — neither advertises a non-existent test. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | The `active_through` pass-through is now pinned by identity (`is_some_and (equal_to _as_of)`), not by shape. The `size_is 1` additions are layered *in addition to* full-record identity via `_equal_bar` (structural `Types.Daily_price.equal` over all 8 fields), which is the correct direction — this row fails only when size stands in for identity, which is no longer the case anywhere in the section. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | PASS | Pipeline-side "non-positive or NaN raw `close_price` admits no factor" → three absolute tests (`nan`, `0.0`, `-2.0`). Snapshot-side duplicate of the same guard → now covered by `..._on_guarded_input` (previously the FLAG-1 hole). The `.mli`'s "the guard is one-sided … a corrupt `adjusted_close` is unguarded" is a documented *absence* of a guard, not a guard, so it is out of CP4's scope; it is pre-existing text untouched by this PR and is already tracked as the open `adjusted_basis_guard_asymmetry` item in `dev/status/cleanup.md`. |

### Behavioral Checklist (Weinstein domain rows)

NA — test-only + doc-comment PR touching no domain logic (no strategy, stage,
stop, screener or macro behavior changes; the two production files referenced are
read, not modified). Per `.claude/rules/qc-behavioral-authority.md` §"When to
skip this file entirely", rows A1, S1–S6, L1–L4, C1–C3 and T1–T4 are all NA.
qc-structural did not raise A1 on this PR and no core module
(`portfolio`/`orders`/`position`/`strategy`/`engine`) is in the diff.

### Non-blocking follow-ups (none block this approval; file or fold into a later cleanup)

1. **The new split fixture is no longer an internally consistent OHLC bar.** With
   `_bar`'s fixed O/H/L of `96/104/92`, `~close:70.0` puts the close *below the
   low* on the input, and the output is `open 13.714, high 14.857, low 13.143,
   close 10.0` — close below low again. The old `~close:100.0` fixture was
   consistent. Harmless for an arithmetic-equivalence pin (both sides are pure
   transforms and `Daily_price.make` does not validate), but it makes the split
   case read as a corrupt bar rather than a clean 7:1 split. Free fix preserving
   the FLAG-2 property: `_bar ~close:98.0 ~adjusted:14.0` — `14.0 /. 98.0` and
   `10.0 /. 70.0` are both the correctly-rounded double nearest `1/7`, so it is
   bit-identical to today's factor and equally non-power-of-two, while keeping
   `close ∈ [low, high]` on both the input and the output.
2. **`size_is 1` + `List.hd_exn` vs `elements_are`.** The FLAG-3 fix pins the
   count correctly, but `.claude/rules/test-patterns.md` §3 prefers
   `elements_are [ _equal_bar … ]`, which pins element and count in a single
   matcher and drops the `hd_exn` extraction entirely. Style-surface, and
   qc-structural's P6 sub-rules do not flag the current form — recorded only so
   the preference is not lost.
3. **Two cosmetic inaccuracies in the `dev/status/cleanup.md` entry.** The rework
   appendix says it "closed two of three non-blocking FLAGs" while in fact all
   three were closed (an under-claim, not an over-claim). And the entry's leading
   sentence still says "two cross-file pin tests" where there are now three. Both
   are reconstructible from the appendix text; neither over-states what shipped.
4. **One comment-block nuance.** The extended block says `List.hd_exn` alone
   "would not catch a regression that silently dropped or duplicated weeks" —
   accurate for *duplicated*, slightly loose for *dropped*, since `hd_exn []`
   raises and would surface as a test error (with a much worse message). Reads
   fine under the "silently" qualifier; noting for precision only.

### What the rework got right

All four items addressed in one commit with no scope creep, and — the part worth
recording — each fix was independently mutation-verified rather than asserted.
The two mutations chosen were the right ones: the `active_through` drop is
precisely the future refactor named in the finding, and the guard deletion is the
one regression the pin was previously blind to. The extended comment block
documents *why* the fixture changed (non-power-of-two) and *why* the singleton
assertion is load-bearing, so the next reader inherits the reasoning instead of
re-deriving it. The one change with genuine regression potential — swapping an
exact binary factor into an exact-equality comparison, on this reviewer's own
suggestion — was checked against both implementations' operation order and holds
by construction.

## Quality Score

4 — Good. Every CP row passes; the blocking CP1 gap and all three FLAGs are
closed with independent mutation evidence, and the riskiest change (exact float
equality on a repeating-binary factor) is safe by construction because both
copies perform an identical division-then-multiply sequence. Held just below
exemplary by minor nits only: the new split fixture is no longer an internally
consistent bar (close below low) when a free alternative preserves the same
factor, `elements_are` would be the idiomatic form for the count assertion, and
the status entry miscounts the FLAGs it closed.

## Verdict

APPROVED

behavioral_qc: APPROVED (2026-08-03, rework iteration 1, SHA `83a3a3ff`)
