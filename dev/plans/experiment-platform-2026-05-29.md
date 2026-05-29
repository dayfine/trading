# Systematic experiment platform — program plan (2026-05-29)

**Filed:** 2026-05-29 PM, after the stage3-hysteresis WF-CV rejection
(`dev/notes/stage3-hysteresis-walkforward-cv-2026-05-29.md`).

## Why now

The hysteresis episode exposed how ad-hoc our exploration still is:

1. We tested **one point** (`h2-m02`), never a surface — no parameter
   search over the exit-timing behaviour we were trying to change.
2. The candidate came from the trade-autopsy tool, which is a good
   *failure-mode labeller* but a poor *knob-recommender* — its single
   suggestion failed walk-forward CV. (`memory/project_stage3_hysteresis_rejected_wfcv`.)
3. The decision discipline worked (WF-CV killed an overfit candidate),
   but the *generation* and *bookkeeping* around it are manual.

This program makes future exploration systematic: hypotheses become
**variant matrices**, evaluated by **walk-forward CV**, ranked with
proper statistics, recorded in an **append-only ledger**, and driven by
a repeatable **skill**.

## Reframe: two search spaces

| Space | What | State |
|---|---|---|
| **Continuous value surface** (11 knobs) | fine-tune existing knob *values* via Bayesian optimization | Searched (`tuning-research-driven-program-v2`) + proven **flat** (v6: GP-EI ≈ random; Cell E = meta-overfit local max). Diminishing returns. |
| **Discrete feature/mechanism space** | which code paths are active, in what combination, with coarse values — "the module is the knob" | **Largely unsearched.** Only ever tested 1–2 hand-written variants. This program targets it. |

The continuous-surface program (BO/qNEHVI/multi-fidelity) stays valid
and **shares infrastructure** with this one (Deflated Sharpe, tiered
folds, baseline aggregates). This program is the *discrete-combination*
complement, not a replacement.

## What already exists (do not rebuild)

- **Code-path toggles as config flags** — `enable_short_side`,
  `enable_stage3_force_exit`, `enable_laggard_rotation`,
  `enable_continuation_buys`, `enable_pi_filter`,
  `stage_method = MaSlope | Segmentation`. All default-off / -safe,
  all flippable via WF variant `overrides`. E1 (short on/off) and E2
  (segmentation) already ran as flag-toggle A/Bs.
- **Loud override validation** — `Overlay_validator.apply_overrides`
  (#1069) *raises* on any unknown/unapplied override key; wired into
  `Backtest.Runner` → consumed by the WF runner per (variant, fold).
  `weinstein_strategy_config` has no `allow_extra_fields`. This is the
  precondition that makes scaling to many variants safe — it fixes the
  2026-05-12 81-cell bug where mistyped keys silently produced
  identical configs.
- **WF-CV harness** — `Window_spec` (Rolling/Explicit/Tiered),
  `Fold_gate`, `Walk_forward_runner`, `Walk_forward_report`. Stable
  spec shape `(base_scenario / window_spec / variants / baseline_label
  / gate)`.
- **Metric catalog** — Sharpe, Sortino, Calmar, MAR, Omega, ulcer,
  skew, kurtosis, concavity, CVaR, tail-ratio, alpha/beta/IR,
  stability, turnover.
- **Bayesian tuner** (Phase 3) — continuous-surface search.
- **Promoted-configs repo design** — `private-tuned-configs-repo-2026-05-18.md`
  (blessed winners + provenance; deferred until first winner).

## Gaps this program closes

### Gap A — Variant-matrix generator  *(PR-1, build)*

Today each variant is hand-written in the spec sexp. A combination
experiment ("`enable_X ∈ {on,off}` × `enable_Y ∈ {on,off}` ×
`knob ∈ {0, 0.02, 0.05}`") needs 12 hand-written variants.

Build a spec-level `axes` block:

```
(axes
 ((key (stage3_force_exit_config hysteresis_weeks)) (values (1 2 3)))
 ((key (stage3_exit_margin_pct)) (values (0.0 0.02 0.05)))
 ((flag enable_laggard_rotation) (values (true false))))
(expansion (Cartesian))   ;; or (Sampled (n 20) (seed 0))
```

- Expands to the `variants` list the existing runner already consumes.
- Each generated variant's overrides run through `Overlay_validator`,
  so a typo'd axis key fails **at expansion time**, loudly.
- `Cartesian` for small grids; `Sampled` (Latin-hypercube / random with
  fixed seed) for large ones. No `Math.random` in scripts — seed-driven.
- Baseline = the all-default / empty-override cell, auto-included.

Scope: ~150–250 LOC + tests, single PR. Reuses runner + gate + report
unchanged.

### Gap B — Loud override validation  *(done)*

Already shipped (#1069) and wired into the WF path. No work; documented
here so the platform inventory is complete.

### Gap C — Matrix-aware ranking + Deflated Sharpe  *(PR-3, build)*

`Fold_gate` is variant-vs-one-baseline. A matrix of N variants is N
trials, so best-of-N needs **selection-bias correction**:

- **Deflated Sharpe Ratio** (Bailey & López de Prado) — deflate the
  winner's Sharpe by the trial count N. Reuses the M3 design from
  `tuning-research-driven-program-v2` (T3.1). A 12-cell matrix that
  produces a "winner" at Sharpe 0.56 may not survive deflation against
  N=12 trials.
- **Pareto rank** across (Sharpe ↑, MaxDD ↓, Calmar ↑) instead of a
  single scalar — surfaces the frontier, not one blessed scalar.
- Keep `Fold_gate` as the *per-variant* go/no-go; add a *cross-variant*
  ranking layer on top.

Scope: ~200 LOC + tests. Shares the DSR module with the BO program.

### Gap D — Experiment ledger  *(PR-2, build)*

An append-only history of **every** experiment, including rejections,
so the search has memory.

```
dev/experiments/_ledger/
  <date>-<slug>.sexp     ;; one file per experiment
  index.sexp             ;; machine-readable catalog (config-hash → verdict)
```

Each entry records: hypothesis, base scenario, axes, expansion, gate,
per-variant fold aggregates, verdict (ACCEPT / REJECT / INCONCLUSIVE),
and a **config-hash** of each variant's effective override blob.

- **Dedup:** before running, the skill checks the index — if a
  variant's config-hash already has a REJECT verdict on the same
  base/window, skip it and log the skip (no silent drop).
- **Distinct from** the promoted-configs repo: the ledger is *every
  attempt + verdict* (institutional memory of what doesn't work); the
  configs repo is *blessed winners + provenance*. Ledger lives in-repo
  (history is cheap, public-safe, and co-located with the code it
  describes); winners go to the private repo per its own plan.

Seed the ledger retroactively with the known rejections: hysteresis
(×2), continuation combined-axis, M5.5 4-axis, laggard-disable
retraction.

Scope: ~250 LOC + tests (pure sexp read/write/dedup; no simulation).

### Gap E — Flag-discipline contract  *(lands with PR-1)*

Short rules doc `.claude/rules/experiment-flag-discipline.md`:

> Every new strategy mechanism lands behind a **default-off** config
> flag (or a value defaulting to the no-op). Backward-compat is
> preserved on merge; the mechanism becomes an experiment axis the day
> it lands. No mechanism is wired into the default config until it has
> an ACCEPT verdict in the ledger.

Already de-facto practice (E2, #1362); this codifies it so QC can check
it.

### Gap F — Experimentation skill  *(build, after PR-1/PR-2)*

`.claude/skills/` skill: **"experiment / trading-performance gap-closing."**
Encodes the full loop so any session can run it consistently:

1. **Identify the gap** — from trade-autopsy, a metric shortfall, or a
   failed baseline comparison.
2. **Hypothesis → axes** — name the mechanism(s) and the coarse grid.
   Prefer toggling/combining *existing* flags; if a new mechanism is
   needed, land it behind a default-off flag first (Gap E).
3. **Check the ledger** — skip config-hashes already rejected on this
   base/window.
4. **Generate the matrix** (Gap A) → run WF-CV (`safe-sweep-hygiene`
   rules: `/tmp/sweeps`, disk checks, no concurrent jj ops).
5. **Rank** (Gap C) — Pareto + DSR; apply `Fold_gate` per variant.
6. **Verdict + ledger append** (Gap D).
7. **If winner** — `promote_config.sh` → private configs repo.
8. **Memory** — write the durable finding.

Bakes in the lessons: autopsy ≠ recommender; single-window overfit;
DSR for best-of-N; sweep disk hygiene.

## Sequencing

```
PR-1  Variant-matrix generator (Gap A) + flag-discipline rule (Gap E)
PR-2  Experiment ledger + retroactive seed (Gap D)
PR-3  Matrix ranking + Deflated Sharpe (Gap C; shares DSR w/ BO program)
Skill Experimentation gap-closing skill (Gap F; once PR-1+PR-2 give it tools)
---   Promoted-configs repo (deferred to its own plan; fires on first winner)
```

Lead with PR-1 (unblocks surface testing). PR-2 before any large matrix
run (so the search has memory before it scales). PR-3 before trusting
any best-of-N "winner."

## First real use (after PR-1/PR-2)

Re-attack the autopsy's still-open missed gain (modes 1+2, ~2734%)
**as a surface, not a point**: declare axes over the exit-timing
mechanisms (hysteresis_weeks grid × exit_margin grid × the relevant
`enable_*` flags), run the matrix through WF-CV, rank with DSR. Either a
cell survives (real fix found systematically) or none does (the gain
isn't capturable by exit-timing — a stronger negative result than one
rejected point).

## Non-goals

- Not replacing the BO continuous-surface program; complementary.
- Not a new optimizer family (v6 settled that at d=11).
- Not auto-promotion: promotion stays a manual, ledger-backed decision.
