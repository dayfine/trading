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
