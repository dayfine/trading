# Plan — arc readiness: features, validation, compression

**Date:** 2026-08-20
**Standing frame (user, 2026-08-20):** *"we are not yet trying to get this arc to
beat record. We are trying to get the necessary features in place together
first."*

That reframes every measurement. The question is **not** "does mechanism X clear
its null" — at a 132.5pp (26y) / 278pp (ladder-v4) noise floor, most single
mechanisms cannot clear anything, and today's broad-5y cell showed one arm's own
salt-to-salt spread (9.24pp) exceeding the arm-to-arm gap (−6.22pp). The
question is **"is every necessary feature built, correct, composable, and
faithful?"**

Three axes, each with a measured current state and a concrete next step.

---

## Axis 1 — arc features built and working

**State: ~85%.** Seven mechanisms, all built and tested (1–4 test files each).
Six of seven verified running *together* — `ladder-v4-async-ticket-2026-08-10`
cell `v4-16` arms `Range_top_breakout` + rescreen + rest-4wk + `Drop_over_max` +
volconf simultaneously (checked as armed values, not mere field mentions).

**The one hole is the funding leg.** `dev/plans/ticket-funding-2026-08-16.md`
defines four steps:

| step | state |
|---|---|
| G1 — land `ticket_age_weeks_at_cancel` + `cancel_reason` (#2348) | ✓ done (3 impl, 5 test files) |
| step 2 — measure the cohort from artifacts | ✓ done — 3,530 rejections, median shortfall 52%, 63% in bursts |
| step 3 — build each axis behind its own flag | **1 of 3** |
| └ G2a `entry_fill_reject_retries` (retry) | **absent** — 0 mli, 0 impl, 0 tests |
| └ G2b `entry_fill_size_to_available` (resize) | **absent** — 0 mli, 0 impl, 0 tests |
| └ G3 `reserve_cash_for_resting_tickets` (reserve) | built + tested, **armed in 0 specs** |
| step 4 — one grid over all three + null | **blocked** on G2a/G2b |

G3 is real, not a stub — `Entry_walk._spendable_cash` holds back
`_resting_long_ticket_cost`, floored at 0, with a docstring naming the exact
leak (`remaining_cash` is re-seeded from `portfolio.cash` each tick, so a ticket
resting from week N is invisible in week N+1 and its money is committed twice).

### Actions

1. **Build G2a and G2b** behind default-off flags, R1/R2-compliant, same shape
   as G3. `feat-weinstein`, one mechanism per PR.
2. **Arm G3 in a combined arc cell** so it stops being the only mechanism never
   exercised.
3. **Then run step 4's three-way grid.** Note this is an *internal* comparison
   among alternatives, not a run at the record — so the noise floor that blocks
   everything else does not block it.

---

## Axis 2 — validation and testing tools

Three capabilities. Two are strong; one has no tooling at all.

### (a) Trade performance — strong, but low-power

`variant_matrix`, `variant_ranking` (Pareto), `deflated_sharpe`, `fold_health`,
`rolling_start` + convexity/dispersion stats, 15 artifacts per scenario run.

**The gap is not a missing tool — it is that nothing reports effect-vs-null
automatically.** Nulls are hand-built with salted re-runs every single time, and
they are the binding constraint on every verdict this program issues. Worse,
today's measurement showed **nulls do not transfer across scales** (26y÷5y
ratios ranged 1.2×–134×, against 1/√n's predicted 0.46×), so a null measured
once cannot be reused on a different window.

**Action:** a `null_report` step that, given a set of salted paired cells, emits
per-metric gap, that metric's own null, and the ratio — the Rule-4 table I build
by hand in every writeup. Low effort, high leverage, and it makes the
"is this inside the noise" question un-skippable rather than optional.

### (b) Execution correctness — the best-developed leg

`decision_audit` (counterfactual / screen_record / weekly_adapter),
`trade_audit` + recorder + basis + report + ratings + `trade_score`,
`entry_audit_capture` / `exit_audit_capture` / `audit_recorder`,
`screener_cascade_diagnostics`, HTML report. **No action needed.**

### (c) Book faithfulness — no tooling, and a known open violation

There is **no automated check** anywhere in `trading/devtools/` or `.github/`.
"Faithful" appears only in `.mli` prose. Enforcement is qc-behavioral's manual
S1–S6 / L1–L4 / C1–C3 checklist, applied per-PR by an agent reading docstrings.

And the record convention currently uses a **non-book** market + deep-floor fill
rule; the honest book rule scores ≈ +310% (`project_fill_model_inversion`,
logged as an open decision for the user). So the axis with no tooling is also
the one with a live known divergence.

**Faithfulness is genuinely hard to enforce mechanically** — it is a question
about intent and interpretation, not a predicate over source. The answer is not
to automate the judgment but to **make the lookup cheap, authoritative, and
cumulative.**

#### The book is a first-class resource

```
/Users/difan/Downloads/486827303-Stan-Weinstein-s-Secrets-For-Profiting-in-Bull-and-Bear-Mark-pdf.txt
```

12,417 lines, 540 KB, 20 chapter markers, greppable. Verified today: a search
for `30-week moving average` returns the primary passage at line 738.

**Caveat that matters in practice:** the extraction carries OCR spacing
artifacts — line 738 reads `the y e a r s` — so **exact long-phrase greps
fail**. Search short distinctive terms (`30-week`, `Stage 2`, `breakout`,
`protective stop`) and read surrounding context, rather than quoting a sentence
and grepping it verbatim.

It stays **outside the repo** (purchased copyrighted text; do not commit it).
Its path is recorded here and in the rule.

#### The three-tier protocol

1. **First stop — `docs/design/weinstein-book-reference.md`** (423 lines). The
   distilled decision rules. If it answers the question, done.
2. **Second stop — the book itself**, whenever the reference is *silent*, or
   *ambiguous*, or a claim about faithfulness is *contested*. This is the
   authority; the reference is a summary of it.
3. **Always write back.** When a faithfulness question is resolved from the
   source, append the answer plus its citation (chapter + a short distinctive
   quote, not a page number — OCR pagination is unreliable) to
   `weinstein-book-reference.md`.

Step 3 is the load-bearing one. It turns the reference into a **cache of
resolved faithfulness questions that grows toward the questions actually
asked**, with the book as the backing store. Faithfulness stays a judgment, but
each judgment gets made once.

**Action:** add `.claude/rules/book-as-authority.md` recording the path, the OCR
caveat, and the three-tier protocol; cite it from
`weinstein-faithful-core.md` W2 (which already demands adaptations "cite
Weinstein authority") and from `qc-behavioral-authority.md`'s authority
hierarchy.

**Separately: resolve the fill-model A/B.** It is the one open faithfulness
question that changes what every other measurement means, because it determines
whether the arc's baseline represents the strategy we intend to run.

---

## Axis 3 — compression, automated

**State: not happening.** Rule 4 is net-zero — 0 promotions, 0 net retirements,
+7 inert mechanisms in 11 days.

Measured surfaces:

| surface | size |
|---|---:|
| `dev/notes/` | 368 files, **53,200 lines** |
| `dev/plans/` | 139 files, **28,718 lines** |
| `weinstein_strategy_config.mli` | 1,787 lines for **81 fields** — 1,554 lines (87%) are docstring |
| committed `.sexp` | 1,897 — but mostly PIT data and reproducibility records |

### The reason it never happens

**Every prune list built today shrank by half or more on inspection:**

| list | headline | defensible after checking |
|---|---:|---:|
| retirement "confirm" flags | 5 | **2** |
| orphaned experiment dirs | 145 files | **53** |
| superseded priorities docs | 106 | **84** (9,579 lines) |

The headline count always overstates; **the per-row verification is the actual
work**, and nobody budgets it. That is why the flag inventory has sat unworked
since 08-09 — it reads as five deletions and is two.

One trap worth encoding, because it cost a wrong recommendation today: a
"cited by nothing" test **also catches this week's work**, because the citation
graph lags by days. It measures citation *age*, not deadness.

### The fix: automate the verification, not the deletion

This is `harness-maintainer` work and it belongs on GHA, offline.

**Deliverable:** `dev/scripts/prune_candidates.sh` (POSIX sh — no Python per
`.claude/rules/no-python.md`) plus a scheduled workflow writing
`dev/health/prune-candidates-<date>.md`. It **proposes, never deletes.**

Three checkers, each emitting a verified row with its evidence:

1. **Superseded priorities docs** — every `next-session-priorities-*` except the
   newest, that is cited by no ledger entry, plan, status file, or rule.
   *Today: 84 files / 9,579 lines.*
2. **Orphaned experiment dirs** — cited by nothing **and** older than a 30-day
   quarantine, so the current arc is never proposed.
   *Today: 53 files across 18 dirs.*
3. **Rule-4 flag eligibility** — for each default-off flag with a ledger REJECT,
   run the live-reference test (specs, presets, goldens, in-flight plans) and
   the live-assignment grep, and report the flag's eligibility with counts.
   *Today this reclassifies `catastrophic_stop_pct` (135 specs, incl. the live
   record baseline) from RETIRE to KEEP.*

**Invariants the script must encode** — each one cost an error today:

- `\s` is **not portable** in BSD grep. Use `[[:space:]]`. A `\s` pattern
  matched nothing and silently reported every flag as already removed.
- **Every checker carries a self-test** against a known-present item; if the
  sanity probe returns zero hits, abort rather than report an empty result as a
  clean bill of health.
- **Quarantine recent work** (30 days) so citation-graph lag never proposes
  live artifacts.
- **A path name is not its content** — `goldens-sp500-historical/` contains
  top-3000 scenarios; read the scenario, not the directory.

Wire it as a `dune runtest` check too, so the sanity probes are exercised in CI
rather than only on the cron.

### Why this makes compression actually happen

The output is a **pre-verified worklist**, so acting on it is a mechanical
docs-only PR rather than a research task. The expensive half moves offline to
GHA where latency is free (2 cron slots/day is ample for a weekly sweep), and
the session only spends time on the delete-and-merge.

---

## Sequencing

1. **Now, no container needed:** the book-authority rule (axis 2c) and the
   `prune_candidates.sh` brief for `harness-maintainer` (axis 3).
2. **Next dispatches:** G2a and G2b (axis 1), one mechanism per PR, `feat-weinstein`.
3. **Then:** the funding three-way grid (axis 1 step 4) — internal comparison,
   not blocked by the noise floor.
4. **Open for the user:** the fill-model A/B (axis 2c). It gates what "iterating
   within this arc" is measured against.

Deliberately *not* on this list: any further single-mechanism A/B against the
record. Per the standing frame, that is not what this arc is for yet.
