Reviewed SHA: 36a4f9bc156993f5db969dbd5703bb84ddfeaf12

## Behavioral QC — index-stage veto, 3-salt arm on the PIT band (#2884)

Scope: experiment-record PR, zero `.ml`/`.mli` changes. The "contracts" under review are the
empirical claims in `README.md`, the ledger entry, and the PR body; the pinning artifacts are the
per-salt `results/*` committed in this same PR plus the committed null band under
`pit-universe-2026-09-14/step4/results/`. No `dune` run: CI is green on all three required checks at
this tip and nothing in the diff can affect a build. `validator_diff` was not executed — the V6 gate
is decidable directly from the six committed validator reports (see CP4).

### What I re-derived independently

Re-read every committed `actual.sexp` / `summary.sexp` and re-ran the `symbol|entry_date` paired join
over all six `trades.csv` in Python (independent of `paired.sh`). Zero duplicate join keys in any of
the six files, so the `join -v1/-v2` in `paired.sh` is sound.

| claim (README §Verdict) | recomputed | ✓ |
|---|---|---|
| level 457.0/188.0/152.0 → 344.7/308.8/141.9 | 457.007/188.047/152.025 → 344.703/308.773/141.856 | ✓ |
| realised $3.85M/$1.67M/$1.40M → $2.77M/$2.66M/$0.97M | 3,847,814/1,672,606/1,401,618 → 2,772,066/2,658,019/974,039 | ✓ |
| maxDD 40.6/53.0/51.3 → 33.5/40.6/46.2 | 40.643/53.048/51.324 → 33.497/40.583/46.190 | ✓ |
| Calmar 0.165/0.077/0.069 → 0.173/0.135/0.073 | 0.16484/0.07683/0.06921 → 0.17304/0.13455/0.07342 | ✓ |
| trades 732/766/762 → 703/705/716 | exact | ✓ |
| joins 602/619/632 shared, 130/147/130 null-only, 101/86/84 arm-only | exact, incl. the per-bucket P&L ($1.29M/$0.20M/$0.76M null-only; $0.22M/$1.09M/$0.04M arm-only) | ✓ |
| 2022–23 window +$0.42M/+$0.48M/+$0.56M | +418,116 / +476,615 / +556,417 | ✓ |
| per-entry-year table, all 8 years × 3 salts | every figure reproduces to the quoted precision | ✓ |
| first divergence MLNX 2018-11-17 / 2019 / 2020 | MLNX 2018-11-17, OFIX 2019-02-12, SHEN 2020-03-21 | ✓ |
| 2003 / 2009 episodes identical | symmetric difference = 0 entries, 3/3 salts | ✓ |
| every named trade (GETY, ALTM, ADTN, ESTA, NXE, BBSI, STLD, ISEE, ZS, BBBY, GME, BBWI, SNBR, TTEC, ECHO …) | every one reproduces to the quoted $k | ✓ |

**Single-knob isolation is provable, not asserted.** `diff` of the `(overrides …)` block between
`a0-pit-null-s0-v11-params.sexp` and `v1-index-veto-s0-v11-params.sexp` is exactly one added line,
`((index_stage_veto_blocks_longs true))`; the flag is absent (default `false`) in all three null
params. **The salt-1 re-run is verifiable from the artifact itself**, not just from log prose:
`code_version 477522b7c…` + `data_dir …/sweep-veto2/…`, i.e. the lane-B knob build, not the cell
killed by the 36,000 s guard.

One claim in the record is **not** reproducible and is wrong as stated — item B1 below.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test | NA | No `.ml`/`.mli` in the diff. The mechanism itself (`index_stage_veto_blocks_longs`) shipped in #2863 and carries its own `test_index_stage_veto_gate.ml`, incl. an assertion that `default_config` is `false`. |
| CP2 | Each claim in the record has corresponding evidence in the committed artifacts | **FAIL** | 45+ figures reproduce exactly (table above). **One does not**: the "blocked Mar–May re-entry cohort ≈ 0 / +$0.47M / +$0.33M" triple — quoted in README §Verdict §Why and in the ledger `notes` — is computed on two different cohort windows. On the salts-1/2 window the salt-0 figure is **+$563,394**, not ≈ 0. See B1. Secondary, non-blocking: the 2022 removed-entry counts 19/13/11 do not reproduce under any single key (R1). |
| CP3 | Identity / pass-through claims pinned by identity, not by a weaker proxy | PASS | The "one knob only" claim is pinned by a literal `params.sexp` override-block diff (exactly one line), not by prose. "Trade-identical 2000 → 2018/2019" is pinned by the exact first-divergence key at each salt (MLNX 2018-11-17 / OFIX 2019-02-12 / SHEN 2020-03-21), not by a count. "2003 / 2009 inert" is pinned by symmetric-difference = 0, not by a P&L delta. |
| CP4 | Each guard called out in the record has evidence it was exercised | PASS | V6 gate: `(id V6) (passed true) (n_violations 0) (specimens ())` on **all six** reports (3 arm + 3 null) → `validator_diff -check V6` exit 0 follows by construction; the paired read is a mechanism read, not an instrument-set artifact (`mechanism-validation-rigor.md` check 8 satisfied). `chain-veto.sh` carries and logs every abort it claims: `EXPECT_HEAD` pin, `git status --porcelain` dirty check, warehouse `9364`-entry assertion, 20 G disk guard, lane lock dir. V16 counts (2 / 1 / 2) match the null's flags as stated. |

## Behavioral Checklist (Weinstein domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | **NA** | Experiment-record PR; implements no domain logic. The mechanism under test merged separately in #2863 and was reviewed there. Faithfulness of the mechanism itself is settled by tier 1: `weinstein-book-reference.md` §2.1 "Resolved 2026-09-16" — the Stage-4 index breakdown is an unconditional suspension of new buying ("Suspend buying even if you see a few stocks breaking out on their charts"), so the veto tightens spine item 6 rather than inventing a mechanism (`weinstein-faithful-core.md` W2). The README's citation of that section is accurate. No `BOOK-CHECK-NEEDED` for the arm; one tier-1-settled correction to the *forward guidance* is R3 below. |

## Rule conformance (non-checklist, all verified)

- **`universe-discipline.md` U1–U4 — PASS.** `specs/v1-index-veto.sexp` uses `universe_path
  pit-v11/composition/top-3000-2000.sexp` plus a 27-entry `universe_schedule` of
  `top-3000-{1999..2025}.sexp`. Broad throughout, vintage tracks the window (U4), no sp500 anywhere in
  the spec or in any figure backing a conclusion.
- **`experiment-flag-discipline.md` R1/R2/R4 — PASS.** On `origin/main`,
  `index_stage_veto_blocks_longs : bool; [@sexp.default false]` in both
  `weinstein_strategy_config.ml` and `screener.ml(i)`, with a test pinning the default. It resolves
  through `Overlay_validator` (the arm's `params.sexp` echoes it), so it stays a searchable axis. This
  PR flips no default. **The ledger records the required Rule-4 classification explicitly** —
  `verdict Reject` with `notes` opening "REJECT-as-default, KEEP AS AXIS (not do-not-revive:
  book-faithful, does what it says)". This is exactly the classification that was missing from past
  rejections and it means the flag is *not* retirement-eligible; the next session does not have to guess.
- **`mechanism-validation-rigor.md` — verdict calibration PASS.** The verdict is
  "REJECT-as-default, keep as an axis", derived mechanically from a rule pre-registered in the
  README and the ledger `hypothesis` field *before* any cell ran (commit `3b058291`, ahead of the
  first results commit `5ea34a98`). The rule was applied as written and not moved after seeing data.
  The record explicitly refuses to quote the level as the mechanism ("never quote s1 +121pp or s0
  −112pp"), and discounts its own Calmar 3/3 clear rather than banking it. Notably the verdict does
  **not** depend on that discount: realised clears 1/3, so the conjunctive rule fails regardless of
  how Calmar is read — which is the right structural property for a record to have.
- **`sweep-hygiene.md` — PASS on both documented traps.** (a) The metric extraction is
  `${out}/${name}/actual.sexp`, scoped to one arm — **not** the `${out}/*/actual.sexp` glob that
  concatenated two arms' metrics in three of four chains on 2026-08-20. The tripwire
  (`awk '{n=gsub(/total_return_pct/,"&"); if(n>1) …}'`) is clean over every committed results file.
  (b) Specs staged at `/tmp/veto-run/specs`, outside any VCS tree; the null artifacts are read from
  the **pinned** worktree behind a HEAD pin + dirty check, not through the parent tree.
- **`CELL_TIMEOUT` is now sized from the measured arm** — the defect that cost salt 1 is fixed in the
  committed script: default `60000` s vs the slowest observed arm cell 30,789 s (cap 256) / 15,523 s
  (cap 12,000), i.e. ≥ 1.5× per `perf-review-weekly.md`. Minor packaging note in R4.
- **`promotion-confirmation.md`** — not applicable (REJECT, no default flip, no grid owed).

## NEEDS_REWORK Items

### B1 (CP2): the 2020 blocked-re-entry triple is computed on two different cohort windows; the salt-0 figure is wrong

- **Finding.** README §Verdict §Why and the ledger `notes` both present "the blocked Mar–May
  re-entry cohort is worth ≈ 0 / +$0.47M / +$0.33M" as a like-for-like triple across salts. It is not.
  Salts 1 and 2 use a fixed **2020-03-15 → 2020-05-31** window (12 and 13 null-only entries,
  +$466,057 and +$329,357 — both reproduce exactly, and the README explicitly notes "ZS 05-29 inside
  it" / "ZS inside it again"). Salt 0 instead uses **2020-03-21 → 2020-04-29**, a window that stops at
  the last removed entry the author chose to attribute to the veto, giving 10 entries and −$3,099
  (which also reproduces exactly — the arithmetic is right, the window is not the same one).

  On the salts-1/2 window, salt 0 is **12 entries / +$563,394** — the *largest* of the three, not
  "flat". The two extra entries are LACO 2020-05-27 (+$74,122) and **ZS 2020-05-29 (+$492,371)**.

  The salt-0 window cannot be defended on mechanism grounds, by the record's own claims: the composite
  and index-stage series are **salt-independent** (the README asserts `macro_trend.sexp` is
  md5-identical across all three salts, "the composite is untouched, as designed"), so the week
  2020-05-29 is either a veto week at every salt or at none. ZS appears as a null-only entry at the
  identical date `2020-05-29` at all three salts. The README counts it inside the blocked cohort at
  salts 1 and 2 and outside it at salt 0. Both cannot be right.

  This matters because it is one of the two legs of the transferable *why* — the part
  `mechanism-validation-rigor.md` calls "the real deliverable". As written, the salt-0 entry concludes
  "**the COVID re-entry cohort the veto blocks was flat**, not the monster cohort … Monster lottery,
  not mechanism", which reads the 2020 cost as a draw at that salt. Corrected, the 2020 recovery tax is
  a **property at 3/3 salts** (+$0.56M / +$0.47M / +$0.33M), exactly symmetric to the 2022 grind save
  at 3/3 — which *strengthens* the REJECT and sharpens the forward guidance rather than weakening it.
  Leaving it uncorrected understates the re-admission-lag cost that the forward guidance proposes to
  attack.

- **Location.**
  - `dev/experiments/index-stage-veto-2026-09-16/README.md` L105–109 (salt-0 "2020 re-entry episode"
    bullet: "net ≈ −$3k", "was flat", "Monster lottery, not mechanism")
  - same file, L211 (salt-1 bullet's cross-salt comparison "vs ≈ −$3k at salt 0")
  - same file, L266–267 (Verdict §Why: "worth ≈ 0 / +$0.47M / +$0.33M")
  - `dev/experiments/_ledger/2026-09-21-index-stage-veto.sexp`, `notes` field ("blocked Mar-May
    re-entry cohort ~0/+$0.47M/+$0.33M")

- **Authority.** `.claude/rules/mechanism-validation-rigor.md` check 6 ("compute the **paired
  per-event** difference … not two pooled population means") and check 1 (estimand — the statistic
  must be a faithful proxy for the quantity the mechanism changes; a cohort window chosen post hoc
  from where the removals happened to stop is not). Plus §"The real deliverable is the *why*":
  "Attribute the result to a mechanism, decomposed … Each implies a *different* next move."

- **Required fix (text only — no re-run; the corrected numbers are already derivable from the
  artifacts committed in this PR).** Recompute the salt-0 blocked cohort on the same
  2020-03-15 → 2020-05-31 window used at salts 1–2 (12 entries, +$563,394), correct the triple to
  **+$0.56M / +$0.47M / +$0.33M** in both README §Verdict §Why and the ledger `notes`, and replace the
  salt-0 "was flat / monster lottery, not mechanism" reading with the corrected one. If the narrower
  salt-0 window is kept for any reason, state the window explicitly next to *each* of the three
  figures and do not present them as a comparable triple. Note in passing that the corrected read makes
  the two legs symmetric (2022 save 3/3, 2020 tax 3/3) and is worth saying so.

- **harness_gap:** ONGOING_REVIEW. Choosing a cohort window and holding it fixed across salts is a
  judgment call about the estimand; no linter can detect a post-hoc window. The nearest mechanical
  backstop would be for `paired.sh` to emit the episode cohorts on fixed windows (it already has an
  `--- episodes` section, but its 2020 window is `2020-03-01:2020-12-31`, not the Mar–May re-entry
  window actually quoted) so that per-salt figures are produced by one script rather than by hand.

## Residuals (non-blocking — file, do not hold the PR for these)

**R1 — 2022 removed-entry counts do not reproduce under any single key.** README quotes 19 / 13 / 11
null-only 2022 entries. Under `symbol|entry_date` (the key `paired.sh` itself uses; zero duplicate
keys in all six files) it is **19 / 17 / 15**, nets −$484,629 / −$357,130 / −$444,311. Salt 2's "11"
matches a stricter "symbol absent from the arm entirely" definition (11 entries, −$390,940); salt 1's
"13" matches neither (that definition gives 12). Salt 0's quoted net "−$524k" vs the recomputed
−$484,629 is a third small drift. **Every named trade in all three lists reproduces exactly**, and the
load-bearing aggregate (the 2022–23 window delta, +$418k / +$477k / +$556k) is exact — so this is
bookkeeping, not a wrong conclusion. Consequence for the text: Verdict §Why's "removes 11–19 losing
entries a year" should read **15–19** under a uniform key, and "that lose −$0.5M net" is generous for
salt 1 (−$0.36M).

**R2 — the lower-peak-artifact argument is not independently checkable from this PR.** The NAV
peak/trough/give-back figures (null peak 2021-02-11 $5.52M, troughs $2.59M / $1.73M, the $0.54M salt-2
trough gap, the 2022 give-back pairs) come from `equity_curve.csv`, which `chain-veto.sh` **does** copy
to `$ART` but which is not in the committed `results/` set. I could corroborate only directionally
(arm `final_portfolio_value` below null at s0 and s2; maxDD + return consistent). This is the single
piece of reasoning that converts the Calmar 3/3 clear into "not a real improvement", so it is the one
worth being checkable — and it is a zero-cost fix, since the file already exists. Recommend committing
`v1-index-veto-s{0,1,2}-v11-equity_curve.csv` (and the null's, if not already on the band). Not
blocking: the verdict does not rest on it, because realised fails the conjunctive rule at 2/3 salts
regardless.

**R3 — the forward guidance's "book question" is already answered by tier 1, and answered against
it.** README §Forward guidance and the ledger `notes` both propose pairing the veto with "a faster
re-admission (veto lifts when the index closes above the MA rather than waiting for the MA slope — a
§2.1 Stage 4 → 1 book question)". `weinstein-book-reference.md` §2.1 "Resolved 2026-09-16" — the same
entry this experiment cites for its own faithfulness — already settles it in the opposite direction:
"it's not enough for the industrials to temporarily pop above the MA … if the average continues
pointing lower"; buy aggressively only once "the levelled MA is penetrated on the upside." So lifting
the veto on a close above a still-falling MA is the **less** faithful option, not an open question.
This is *not* a `BOOK-CHECK-NEEDED` (tier 1 settles it; the book itself is unreachable from this GHA
runner per `book-as-authority.md` §"Environment-aware protocol", and does not need to be). Recommend
rewording so the next session doesn't run that arm believing the reference is silent — a faithful
faster-re-admission dial would key off MA *levelling*, not a price cross.

**R4 — the committed `chain-veto.sh` reproduces lanes B+ only.** Its defaults are
`CELL_TIMEOUT=60000` and `WTREL=.claude/worktrees/sweep-veto`, but salt 0 ran at `CELL_TIMEOUT=36000`
in `sweep-veto` while salts 1–2 ran at 60,000 in **`sweep-veto2`**. The header discloses the guard
drift in prose, which is the right call, but a reader re-running salt 0 from the committed script gets
lane B's guard with lane A's worktree. Suggest spelling the per-lane `WTREL`/`EXPECT_HEAD`/
`CELL_TIMEOUT` triple out in the usage line. (`REPO=/Users/difan/Projects/trading-1` is a
macOS-local path, consistent with precedent for chain scripts — not a finding.)

## Quality Score

2 — Below standard on one axis only: a headline triple quoted in both the Verdict's transferable-why
and the durable ledger entry is computed on inconsistent cohort windows and is wrong at salt 0
(≈ $0 vs the correct +$0.56M). The rest of the record is unusually strong — pre-registration ahead of
the first cell, raw per-salt artifacts committed, single-knob isolation provable from `params.sexp`,
V6 = 0 on all six reports, correct REJECT-as-default calibration with the Rule-4 keep-as-axis
classification recorded explicitly, and 45+ figures that re-derived and reproduced exactly. The fix is
text-only and no re-run is needed.

## Verdict

NEEDS_REWORK

---

## Structural QC (re-review at 45ea37ba — rework iteration 1) 

**Scope:** Text-only rework addressing qc-behavioral NEEDS_REWORK. Delta: 4 files, +286/−26 lines, **zero `.ml`/`.mli`/`dune` changes**. No executable logic touched; no build impact.

**Gates run:** POSIX shell linter (`posix_sh_check.sh`) on `chain-veto.sh` — PASS. No `dune` gates run (build is contended and the delta guarantees no code impact). CI status: `perf-tier1-smoke` and `goldens-affected` both passed; `build-and-test` in_progress.

**Files changed in rework 36a4f9bc → 45ea37ba:**
1. `dev/experiments/_ledger/2026-09-21-index-stage-veto.sexp` — ledger notes updated to correct the cohort windows (−1/+2 lines) and added CAVEAT on uncommitted equity_curve.csv
2. `dev/experiments/index-stage-veto-2026-09-16/README.md` — Verdict and Forward guidance sections rewritten to correct the 2020 blocked re-entry figures and clarify the book-settled faithfulness question
3. `dev/experiments/index-stage-veto-2026-09-16/chain-veto.sh` — **comment-only**: +3 lines documenting per-lane parameter variants (lane A vs lanes B+)
4. `dev/reviews/index-stage-veto.md` — new file with full behavioral review (206 lines; first line `Reviewed SHA: 36a4f9bc…`)

**Verification:**
- results/ artifacts: **zero changes** (unchanged between tips)
- paired.sh and other scripts: **unchanged** 
- POSIX portability: **pass** (114 scripts clean)
- Ledger sexp: **parses** (valid s-expression with balanced parens)
- dev/reviews first line: **correct** (pinned SHA is 36a4f9bc, the prior tip under behavioral review)

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | NA | Zero `.ml`/`.mli`/`dune` in diff; format pass is guaranteed. POSIX linter pass on shell scripts. |
| H2 | dune build | NA | Same; no code path touched. CI perf-tier1-smoke and goldens-affected already passed. |
| H3 | dune runtest | NA | Same; no test infrastructure touched. The mechanism under test (`index_stage_veto_blocks_longs`) is tested in #2863. |
| P1 | Functions ≤ 50 lines | NA | No functions in diff. |
| P2 | No magic numbers | NA | No code in diff. |
| P3 | Config completeness | NA | No config changes in diff. |
| P4 | Public-symbol export hygiene | NA | No `.mli` in diff. |
| P5 | Internal helpers prefixed per convention | NA | No helper functions in diff. |
| P6 | Tests conform to test-patterns.md | NA | No test files in diff. Mechanism tests live in #2863. |
| A1 | Core module modifications | NA | No modifications to Portfolio/Orders/Position/Strategy/Engine — diff is experiment record only. |
| A2 | Dependency-direction rules respected | NA | No dune files touched. |
| A3 | No unnecessary modifications | PASS | Diff contains only corrections to the rework's own narrative (README/ledger) and the QC review record. All 4 files in the rework delta are present in the GitHub API file list (confirmed via REST API); no stray files introduced. Behavioral review corrections (B1/R2/R3 findings) are exactly what the rework addresses. |

### Quality Score

5 — The rework precisely targets every structural issue the behavioral review surfaced (B1 cohort-window correction, R3 reworded faithfulness guidance, CAVEAT added), with no scope creep. Comment-only shell change passes POSIX linter. Ledger sexp is well-formed. The behavioral review's prior APPROVED checklist (CP1/CP3/CP4/rule conformance) stands unchanged; only the factual corrections to narrative landed. Clean iteration.

### Verdict

APPROVED

---

**Re-review complete at SHA 45ea37ba9c36479e016c8c9cd4ba67b0f8140e60.** Prior APPROVED at 36a4f9bc is superseded by this rework-iteration review. No blockers for merge once build-and-test completes (expected ~minutes).

---

## Behavioral QC (re-review at 45ea37ba — rework iteration 1)

Reviewed SHA: 45ea37ba9c36479e016c8c9cd4ba67b0f8140e60 (rework iteration 1)

Re-review of the text-only rework addressing my NEEDS_REWORK at `36a4f9bc`. Scope: 4 files, no
`.ml`/`.mli`/`dune`. **No `dune` run** — the delta cannot affect a build, structural already ran the
POSIX gate, and my work here is arithmetic over the committed CSVs. `git diff 36a4f9bc 45ea37ba --
'*/results/*'` is **empty**: the artifacts I verified last round are byte-identical, so nothing I
previously confirmed (V6=0 on all six reports, single-knob `params.sexp` isolation, salt-1 lane-B
provenance, pre-registration ordering, U1–U4 broad PIT, the metric-glob tripwire) is in the delta.

### What I re-derived — independently, not from the author's report

Own `csv`+dict join on `symbol|entry_date` over all six `trades.csv`, written fresh for this pass.

| quantity | author reports | I get | ✓ |
|---|---|---|---|
| duplicate join keys, all six files | 0 | 0 (703/705/716 arm, 732/766/762 null) | ✓ |
| salt 0 cohort, fixed 2020-03-15→05-31 | 12 / +$563,394 | 12 / **+$563,394** | ✓ |
| salt 1, same window | 12 / +$466,057 | 12 / +$466,057 | ✓ |
| salt 2, same window | 13 / +$329,357 | 13 / +$329,357 | ✓ |
| salt 0, narrow 03-21→04-29 | 10 / −$3,099 | 10 / −$3,099 | ✓ |
| the two dropped entries | LACO 05-27 +$74,122; ZS 05-29 +$492,371 | exact | ✓ |
| 2022 removed, uniform key | 19/17/15; −$484,629 / −$357,130 / −$444,311 | exact | ✓ |
| *new* claim added in §Why: cohort net of arm-only substitutes | +$0.61M / +$0.49M / +$0.36M | +$608,765 / +$485,269 / +$356,214 | ✓ |
| 2020 entry-year deltas | −$0.5M / −$0.76M / −$1.35M | −$516,211 / −$754,893 / −$1,353,531 | ✓ |

**Every figure matches, including a claim the author added that I had not asked for and that is also
correct.** The corrected salt-0 triple leg (+$563,394 on 12 entries) is the number the artifacts
support; the README now carries it.

### B1 — closed

Corrected in every load-bearing place: README §Verdict §Why, the salt-0 log bullet (the "was flat /
monster lottery, not mechanism" reading is gone and replaced with the corrected one), the salt-1
cross-salt comparison, the new §Correction note item 1, and the ledger `notes` (now "blocked
re-entry cohort on the FIXED 2020-03-15..05-31 window +$0.56M/+$0.47M/+$0.33M = 12/12/13"). §Why
states the symmetry explicitly and accurately.

**The author's claim to have found two spots beyond my line list is true and verified** — L115–116
(the salt-0 "2020 entry-year gap (−$516k) is the re-entry tax, not the funding lottery it was first
read as") and L130 (YE NAV "2020 −$1.02M (the blocked re-entry cohort, then path divergence)"). Both
were stale under the old reading and both are now correct.

**I found one more they missed — R5 below.** It is a single sentence in a log bullet that the same
rework corrected two lines above it, so it is self-contradicting rather than load-bearing. Residual,
not a block.

### Did the correction overshoot? No.

Verdict is unchanged: `(verdict Reject)`, "REJECT-as-default, keep as an axis", and the Rule-4
classification "not do-not-revive: book-faithful, does what it says" survives verbatim in the
ledger. §Why's new claim is "the two legs are symmetric at 3/3 salts — the 2022 grind save
reproduces at every salt and so does the 2020 re-entry tax", which is exactly what the artifacts
show and is the correct strengthening: it converts a salt-dependent-looking draw into a clean
both-earns-and-pays REJECT. It does not claim the veto is *worse* than before, and it does not touch
the pre-registered rule or its arithmetic (realised 1/3). No overclaim in the other direction.

### R2 — disclosure judged on its merits: the right call, and the caveat is honest

I confirmed no `equity_curve.csv` exists for this slug anywhere in the tree, so the fix genuinely
required a re-run that was out of scope. Judging the disclosure rather than checking a box:

- **The dependency is genuinely absent.** The pre-registered rule is conjunctive (realised **AND**
  Calmar at ≥2/3). Realised clears 1/3 — s0 $3.85M→$2.77M fail, s1 clear, s2 $1.40M→$0.97M fail — all
  three from `actual.sexp`, which *is* committed. The conjunction therefore fails at 2/3 salts
  however Calmar is read. The un-backed NAV figures support only the *commentary* that the Calmar 3/3
  clear is a lower-peak artifact; that commentary sits on top of an already-decided verdict. So "the
  verdict does not rest on it" is **true**, not a hedge.
- **The caveat is prominent, not buried.** §Correction note item 3 is a top-level section placed
  immediately before §Verdict — a reader reaches it before the conclusion — and the ledger `notes`
  carries it as a trailing `CAVEAT:`. It names the load-bearing use explicitly ("including the
  lower-peak argument that discounts the Calmar 3/3 clear") rather than hiding behind a generic
  disclaimer, and it records the forward fix. That is the correct shape for a disclosure.

Accepted as closed by disclosure.

### R3 — reframed correctly, and the author's correction to my citation is right

Verified directly: `grep -c "Resolved 2026-09-16" docs/design/weinstein-book-reference.md` in this
branch returns **0** — the entry is absent from the branch checkout — while `git show
origin/main:docs/design/weinstein-book-reference.md` carries it at §2.1 with both quotes verbatim
("not enough for the industrials to temporarily pop above the MA … if the average continues pointing
lower"; "the levelled MA is penetrated on the upside"). **The branch simply predates the entry, so
the citation is accurate at merge time** and a reviewer re-checking inside the worktree would be
misled. Noting it here so a future reader is not confused. The reframing itself is sound: README
§Forward guidance and the ledger now both state the price-cross version is settled *against* by
tier 1 and that a faithful dial must key off MA levelling — not an open book question. Tier 2 not
attempted (unreachable from this runner, per `book-as-authority.md` §Environment-aware protocol);
tier 1 on `origin/main` settles it. No `BOOK-CHECK-NEEDED`.

### R1, R4 — closed / partially closed

R1 fixed: 19/17/15 with nets appears in all three log bullets, in §Why ("removes 15–19 entries a year
that lose −$0.36M to −$0.48M net"), in §Correction note item 2, and in the ledger. R4 addressed by
comment; see R6 for a small inaccuracy the new comment introduces.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Claims in new `.mli` docstrings pinned by tests | NA | No `.ml`/`.mli` in the diff. Mechanism shipped in #2863 with `test_index_stage_veto_gate.ml` incl. a default-`false` assertion. |
| CP2 | Each claim in the record has corresponding evidence in the committed artifacts | **PASS** (was FAIL) | The 2020 cohort triple is now computed on one fixed window at all three salts and re-derives exactly (+$563,394 / +$466,057 / +$329,357). The 2022 counts re-derive under a uniform key (19/17/15). A newly-added §Why claim (cohort net of arm-only substitutes) also re-derives exactly. The one remaining figure class that is not artifact-backed (NAV peak/trough/give-back) is now explicitly disclosed as asserted, with the dependency correctly characterised — see R2 above. Residual R5: one un-updated log sentence. |
| CP3 | Identity / pass-through claims pinned by identity | PASS | Unchanged from `36a4f9bc`; artifacts byte-identical. Single-knob isolation still pinned by a one-line `params.sexp` override diff; trade-identity by exact first-divergence key; 2003/2009 inertness by symmetric-difference = 0. |
| CP4 | Each guard called out has evidence it was exercised | PASS | Unchanged. V6 `(passed true) (n_violations 0) (specimens ())` on all six reports → `validator_diff -check V6` exit 0 by construction (`mechanism-validation-rigor.md` check 8). `chain-veto.sh` aborts unchanged (HEAD pin, dirty check, warehouse assertion, disk guard, lane lock); the rework is comment-only. |

## Behavioral Checklist (Weinstein domain rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1, S1–S6, L1–L4, C1–C3, T1–T4 | — | **NA** | Experiment-record PR; implements no domain logic. Mechanism faithfulness settled by tier 1 (`weinstein-book-reference.md` §2.1 on `origin/main`): the Stage-4 index breakdown is an unconditional suspension of new buying, so the veto tightens spine item 6 rather than inventing a mechanism (`weinstein-faithful-core.md` W2). |

## Residuals (non-blocking — file, do not hold)

**R5 — one stale sentence the rework missed, self-contradicting its own corrected paragraph.**
README L238, closing the salt-1 "Two-salt read" bullet: *"the fat-tail tax on the recovery is real at
one salt of two."* That is the pre-correction framing (true only when salt 0's cohort was read as
flat). Two lines above, in the same bullet, the rework correctly writes *"the 2020 cost reproduces
(−$0.52M entry-year at s0 around a +$0.56M blocked re-entry cohort, −$0.76M around a +$0.47M cohort
at s1)"* — i.e. both salts. §Verdict §Why (L313) and §Correction note (L275–276) both say 3/3.
Non-blocking because the durable, load-bearing statements are all correct and a reader hits the
contradiction inside a paragraph that flags itself as corrected; but it is a one-word fix ("at both
salts") if this is touched again. Grepped the full README for every other instance of the old
framing (`≈ 0`, "flat", "lottery", "−$516k", "−$1.02M", "19 / 13 / 11", "11–19", "a draw",
"salt-dependent") — L238 is the only survivor.

**R6 — the new `chain-veto.sh` comment misstates one of the four defaults it documents.** The added
line says *"lanes B+ (salts 1-2, = the defaults below): WTREL=.claude/worktrees/sweep-veto2 …"*, but
the actual default on the next line is `WTREL=${WTREL:-.claude/worktrees/sweep-veto}` — **lane A's**
worktree. `CELL_TIMEOUT` (60000) and `SNAPSHOT_MAX_MMAP_HANDLES` (12000) do default to lane B;
`WTREL` does not. So the committed defaults reproduce neither lane cleanly, which is exactly the R4
hazard, now with a comment asserting otherwise. The per-lane quadruple itself is correct and useful —
only the "= the defaults below" parenthetical is wrong. Either change the default to `sweep-veto2` or
drop the parenthetical.

**R7 — the R2 caveat's enumeration is one category short.** It disclaims "every peak/trough/give-back
number", but the year-end NAV-diff series (L130, L228, L257) comes from the same uncommitted
`equity_curve.csv` and is not named. Widening the phrase to "every NAV-derived figure" would close it.

## Quality Score

4 — The rework is precise and complete on the blocking finding: the corrected triple re-derives
exactly, it landed in all five places I cited plus two I did not, the §Correction note is an
unusually good artifact (states the window, names the two dropped entries with dollar figures, gives
the mechanism argument for why the narrow window was indefensible, and states the consequence for the
read), and the author added a further correct claim rather than doing the minimum. R2 is closed by a
disclosure that is honest, well-placed, and correctly reasoned about its own load-bearingness. Short
of 5 only for R5 — a prose correction that left one contradicting sentence inside a paragraph it
otherwise fixed, which is the known residual failure mode of this kind of edit — plus the small
comment inaccuracy in R6.

## Verdict

APPROVED
