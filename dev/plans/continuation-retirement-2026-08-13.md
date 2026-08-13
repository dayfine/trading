# Rule-4 retirement screen: `enable_continuation_buys` + `continuation_config`

**Date:** 2026-08-13
**Dispatch:** GHA orchestrator run 31700595897, P1 retirement program
(`dev/notes/next-session-priorities-2026-08-14.md` §"Carried forward").
**Governing rule:** `.claude/rules/experiment-flag-discipline.md` Rule 4.
**Precedent:** #2299 (scale-in retirement), #2286 (`cash_reserve_pct`), #2296
(the `trigger_on_weekly_close` *correction* — a RETIRE row pulled back out).

## VERDICT — NOT ELIGIBLE for retirement

`enable_continuation_buys` + `continuation_config` is a
**REJECT-as-default-but-legitimate-axis**, not a REJECT-do-not-revive. Per
Rule 4 it stays **KEEP, default-off**. No code is deleted by this plan.

Four independent findings, any one of which is disqualifying on its own:

1. **The row's seed is a transcription error.** The 08-09 priorities doc names
   *"scale-in v2 continuation-add"* in its graveyard seed list — that is the
   **scale-in** mechanism, retired by #2299. The inventory turned that one seed
   item into **two** RETIRE rows (`enable_scale_in` *and*
   `enable_continuation_buys`). The standalone continuation-buys mechanism was
   never seeded, so by the inventory's own scope note it is a "confirm before
   removal" row, not a ready-for-removal one.
2. **One of its two cited ledger REJECTs is about a different mechanism.**
   `2026-07-05-continuation-add-v2-surface` tested `Scale_in_detector`'s
   `Consolidation_breakout` add trigger (#1855), gated by `enable_scale_in` —
   code that #2299 already deleted. It never armed `enable_continuation_buys`.
   Citing it here double-counts a verdict already spent on scale-in.
3. **No do-not-revive is recorded anywhere.** The opposite is recorded: the
   experiment's own report names regime-gated continuation as the recommended
   next test, and makes retirement *conditional on that test failing*. It was
   never run.
4. **It is the config home of a Weinstein-documented dial** ("The Trader's
   Way" continuation buy, Ch. 3) in an open, uncancelled plan
   (`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`), and
   `.claude/rules/weinstein-faithful-core.md` explicitly holds that the #1366
   rejection tested a mis-designed graft rather than the mechanism.

---

## Context

### What the mechanism is

`Continuation` (`trading/analysis/weinstein/continuation/lib/`) detects
Weinstein's *continuation buy* — an established Stage-2 advance that pulls
back to the rising 30-week MA, consolidates, and re-breaks out. It is armed
only through one production path:

```
weinstein_strategy_screening.ml:104
  (if config.enable_continuation_buys then Some config.continuation_config
   else None)      -> Stock_analysis.config.continuation
```

`Stock_analysis` runs the detector when that field is `Some`; the default
config leaves it `None`. Defaults: `enable_continuation_buys = false`,
`continuation_config = Continuation.default_config`.

### Step 1 — eligibility evidence

**(a) Ledger entries.** Two exist; only one is on-point.

| entry | mechanism actually tested | verdict | on-point? |
|---|---|---|---|
| `dev/experiments/_ledger/2026-05-14-continuation-combined-axis.sexp` | `enable_continuation_buys=true` + `continuation_config` weeks=2 / range=0.15 | `Reject` | **yes** |
| `dev/experiments/_ledger/2026-07-05-continuation-add-v2-surface.sexp` | `enable_scale_in` + `Scale_in_detector` `Consolidation_breakout` add trigger (#1855) | `Reject` | **no** |

The 07-05 entry's own hypothesis field reads: *"the book's ACTUAL continuation
buy … **as the scale-in add trigger**"*, and its verdict note says *"**SCALE-IN
PROGRAM CLOSED**"*. #2299 already cited it — correctly — to retire
`enable_scale_in`. The code it exercised (`Scale_in_detector`,
`Scale_in_runner`) no longer exists on main. It says nothing about the
standalone continuation *entry* mechanism.

That leaves exactly **one** on-point REJECT, and it is weak by the program's
current standards:

- Two single-run windows (5y `sp500-2019-2023`, 16y `sp500-2010-2026`), one
  universe. **Not** WF-CV, no folds, no Deflated Sharpe, no deep 2000-2026
  macro-regime cell — i.e. it does not meet
  `.claude/rules/promotion-confirmation.md`'s grid standard, nor Rule 4's
  *"failed across every tested context"* bar.
- The entry's own comment concedes the record is partial: *"the full nested
  combined-axis blob … field names were not recovered from the 2026-05-14
  sweep notes, so the hash reflects `(enable_continuation_buys true)` on top
  of default. Dedup on this entry is approximate."*

**(b) The do-not-revive question — resolved explicitly, not inferred.**

Rule 4: *"A REJECT with neither classification is not retirement-eligible —
record the classification first, don't guess it at removal time."* Every place
the classification could live says **keep**, and none says do-not-revive:

- `dev/agent-memory/project_continuation_combined_rejected.md`:
  *"Continuation-buys … should stay **default-off**. Don't pursue further
  single-axis or combined-axis tuning of the existing config knobs. **If the
  mechanism is to come back, it needs a different design (eg gated by macro
  regime, gated by sector strength, etc.)**"* — a *named, uncancelled revival
  direction*, which is the textbook keep-as-axis shape ("coherent
  regime-dependent … dial").
- `dev/experiments/continuation-combined-2026-05-14/report.md`
  §"Next-step follow-up" lists three live options and recommends **option (1),
  regime-gated continuation buys**, explicitly making retirement the *fallback
  if option (1) fails*: *"cheap to test, decisively answers whether the
  regime-conditioned variant survives 16y. **If it fails, fall back to (2)
  [retire]**."* **Option (1) was never run** — no ledger entry for a
  regime-gated continuation surface exists. The record's own stated
  precondition for retirement is unmet.
- `dev/experiments/continuation-tuning-2026-05-14/report.md` §"Tertiary":
  *"the book's continuation pattern is too rare on a 5y / 500-sym universe to
  evaluate meaningfully. **Defer continuation-buys evaluation to the 16y
  horizon** … Until then, keep default-off."* — a power complaint, i.e. the
  same "not rejected, under-tested" shape that keeps the decline-character
  trio on the KEEP-AXIS list.

**Contrast with #2299, which is what makes that precedent inapplicable here.**
Scale-in's resolution was defensible because the *one* revival path its
terminal entry named (an envelope pair-sweep) had itself been **explicitly
cancelled** and that cancellation was **recorded** —
`dev/agent-memory/project_envelope_knobs_dead.md` + #1861 ("envelope knobs are
dead code — P0 pair-sweep cancelled"). *There was no live path left.* For
continuation, both named revival paths (regime-gating; the trader-preset
bundle) are open and uncancelled. Same-shaped contradiction, opposite
resolution — because the deciding fact is different.

**(c) The Weinstein-faithful constraint — the crux, not a footnote.**

`.claude/rules/weinstein-faithful-core.md` lists entry mode
(*"base vs continuation — both his"*) among **the dials**, and its
§"Why this is load-bearing" says:

> The program's three big rejections (**continuation-buys #1366**,
> early-admission, stage3-hysteresis) were all *trader-mode dials grafted
> one-at-a-time onto the investor base*. That is neither faithful … This rule
> prevents that failure mode: adapt a dial only within a coherent preset, keep
> the spine fixed, and **test presets as wholes**.

So a live rule file states that the single on-point REJECT tested the
mechanism in a configuration the project now considers invalid. W2 further
requires every adaptation to be *config-expressed*: deleting the field removes
the only config home for a book-documented dial, so a future trader preset
could not be expressed without re-implementing it.

The open plan `dev/plans/weinstein-trader-investor-presets-2026-05-31.md`
names `enable_continuation_buys` as the Trader preset's **entry-mode** config
home, and `dev/agent-memory/project_trader_investor_modes.md` — after the
2026-06-01 10-week MA rejection — closes with the explicit caveat:

> Caveat: tested the MA-period dial **IN ISOLATION**, not Weinstein's full
> trader *package* — **continuation entries** + early exits + sizing.

The "trader-preset bundle audit + WF-CV" item sat on the priorities backlog
through 2026-07-19 and was displaced by the P0 entry-ticket program — it was
**dormant, never cancelled**. Under Rule 4's "unused" test (*not referenced by
any live scenario spec, preset, golden config, or **in-flight experiment
plan***) that dormant-but-open plan is a live reference.

*Is the counter-argument (early-admission was on the same "three grafts" list
and was still retired) fatal?* No. Early-admission earned a **27-year
deep-grid reversal** that flipped four independent post-2009 cells, and its
memory records **"do not revive"** in terms. Stage3-hysteresis accumulated
**9 Rejects across two surfaces**. Continuation has one pre-WF-CV two-window
run and an explicitly-unfinished follow-up. Membership in that list confers no
immunity — but neither does it substitute for the terminal evidence the other
two have and this one does not.

### Step 2 — live-consumer evidence (run on `main`, for the record)

```
$ git grep -n 'enable_continuation_buys *=' -- 'trading/**/*.ml' \
    | grep -v /test/ | grep -v 'sexp.default'
trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml:200:    enable_continuation_buys = false;
```

One hit — the `default_config` assignment (the #2296 live-consumer check
passes: no non-default arming anywhere, including the snapshot generator).

```
$ git grep -rn 'enable_continuation_buys' | grep -v '^dev/notes'
```

Production code: `weinstein_strategy_config.{ml,mli}` (field + docstring),
`weinstein_strategy.mli` (mirror + module-doc x2),
`weinstein_strategy_screening.ml` (the arming site),
`stock_analysis.mli` (doc reference). Sexp specs: all under
`dev/experiments/continuation-*/` (archived rejected surfaces) — **no** live
scenario spec, preset, or golden config under `trading/test_data/`.

Non-archival references that would be orphaned by deletion:
`dev/plans/weinstein-trader-investor-presets-2026-05-31.md`,
`dev/plans/experiment-platform-2026-05-29.md`,
`dev/plans/bayesian-multi-param-scaling-2026-05-16.md` (*"binary; rejected on
16y but **let the optimizer try with walk-forward gate**"* — an explicit
instruction to keep it searchable),
`.claude/skills/experiment-gap-closing/SKILL.md` (cited as an example axis),
`dev/agent-memory/project_trader_investor_modes.md`,
`dev/reviews/screener-failed-breakout.md`.

`Continuation` module reach: `stock_analysis` (`continuation : Continuation.config
option` in both config and result records, plus `_continuation_callbacks_of` and
the `analyze_with_callbacks` call), the strategy config record type, and
`weinstein.continuation` in three `dune` files. So a removal would not be a
config-field-only deletion — it would delete a library and cut a typed field out
of `Stock_analysis`'s public config and result records, which is a wider blast
radius than any retirement so far.

## Approach

**Chosen: record the NOT-ELIGIBLE determination, correct the worklist, delete
nothing.** This mirrors #2296, which pulled `trigger_on_weekly_close` back out
of RETIRE when the removal attempt surfaced disqualifying evidence — the
inventory carries a `## Correction log` precisely for this.

Rejected alternatives:

- **Remove anyway, flagging the conflict in the PR body (#2299's shape).**
  Rejected: #2299's flag was defensible because its revival path was recorded
  as cancelled. Here it is not, one of the two cited verdicts belongs to a
  different mechanism, and the seed itself was a transcription error. Deleting
  on that basis manufactures eligibility.
- **Run the regime-gated surface first, then decide.** Correct sequencing but
  out of scope for a retirement dispatch: it is a multi-hour WF-CV experiment
  (`experiment-gap-closing`), not a cleanup PR. Recorded as the follow-up.
- **Amend the ledger to add a do-not-revive classification.** Rejected: an
  agent must not invent a classification the evidence does not support. Rule 4
  says record it first — that requires a human decision or a real experiment.

## Files to change

| file | change |
|---|---|
| `dev/plans/continuation-retirement-2026-08-13.md` | this file — the determination + evidence |
| `dev/notes/mechanism-flag-inventory-2026-08-09.md` | move the `enable_continuation_buys` + `continuation_config` row from RETIRE to KEEP-AXIS; add a `## Correction log` entry (same shape as the 08-12 `trigger_on_weekly_close` correction) |
| `dev/status/cleanup.md` | one Completed line recording the outcome |

**No files under `trading/` are touched.** `dev/status/_index.md` untouched.

## Risks / unknowns

- **Risk: the retirement program stalls on this row.** Mitigated — the
  inventory still holds seeded-ready rows
  (`enable_macro_bearish_exposure_trim` + companion, `vol_scaled_stop_*`,
  `stage3_exit_margin_pct`) that carry unambiguous classifications.
- **Unknown: does a human overrule?** The user may hold that the
  trader-preset program is dead and the dial with it. That is a legitimate
  call — but it is a *decision to record*, not one to infer. Recording the
  gap is exactly what Rule 4 asks for.
- **Risk: #2299 was itself wrong** (it also removed a preset-table dial —
  the investor ½/½ sizing). Not re-litigated here. Note the asymmetry: the
  *trader* preset's sizing value is "full size on breakout", which is the
  current default, so #2299 did not remove a trader-preset dial. Continuation
  removal would.

## Acceptance criteria

- [x] Both ledger entries read; the keep-as-axis vs do-not-revive
      contradiction resolved **explicitly**, with the deciding fact named
      (the cancelled-vs-open revival path).
- [x] Exhaustive live-consumer grep run — flag name, `continuation_config`,
      the `Continuation` module, and its `dune` deps.
- [x] Weinstein-faithful tension addressed as the central question.
- [x] Verdict stated up front; **no code deleted**.
- [x] Docs-only diff → goldens trivially bit-identical (no `trading/` file
      touched); `dune build` exit code reported.

## Out of scope

- Any deletion of `enable_continuation_buys`, `continuation_config`, or the
  `Continuation` module.
- Re-litigating #2299 / #2286 / #2284.
- Running the regime-gated or trader-preset-bundle surface.
- `dev/status/_index.md` (orchestrator reconciles).

## Follow-ups this determination creates

1. **Decision needed (human):** is the trader-preset program
   (`weinstein-trader-investor-presets-2026-05-31.md`) alive? If it is
   formally closed and that closure is *recorded* — the way
   `project_envelope_knobs_dead` closed scale-in's revival path — this row
   becomes retirement-eligible immediately and the removal is mechanical.
2. **Experiment (if the program is alive):** the regime-gated continuation
   surface the 2026-05-14 report recommended, as a proper WF-CV surface with a
   deep 2000-2026 macro-regime cell. A REJECT there *is* terminal and retires
   the row.
3. **Worklist hygiene:** the other RETIRE rows whose ledger citation is
   `2026-07-05-continuation-add-v2-surface` should be re-checked for the same
   double-count — that entry's verdict was spent on `enable_scale_in`.
