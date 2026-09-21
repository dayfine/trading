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
