# Population search over the discrete feature space — design note

**Status:** DIRECTION (not scheduled). Captures the 2026-05-31 discussion.
Gated on prerequisites below; premature to build today.

**Supersedes nothing. Extends:** the experiment-platform program
(`dev/plans/experiment-platform-2026-05-29.md`,
`memory/project_experiment_platform.md`). This is its natural endpoint.

## The idea

Today we maintain **one** live config and run experiments **sequentially** —
one variant surface at a time, promote on a ledger-backed ACCEPT through the
confirmation grid. The proposal: maintain **N arms in parallel**, each a
distinct point in the **discrete feature-combination space** ("the module is
the knob" — which `enable_*` mechanisms are on, in what combination, at coarse
values), continuously re-evaluate them against a sampled **(universe × period)
battery**, let arms compete, and periodically prune/spawn.

This is population-based / multi-armed evolutionary search. The motivation is
sound: the surface has **multiple local peaks**, a single hill-climb finds one,
and a maintained population keeps discovering better peaks while letting each
local peak refine. It fits our core reframe — the continuous 11-knob *value*
surface is flat and searched (the BO program); the lever is the discrete
*combination* space, which a population explores far better than sequential
single surfaces.

## The load-bearing risk — multi-arm AMPLIFIES a weak selection metric

The whole technique is only as good as its fitness function. The 2026-05-31
early-admission episode is the cautionary tale: a 4-cell **post-2009** grid +
Deflated-Sharpe 1.0 **unanimously** said "promote ma=13"; a single **deep
pre-2009** cell (dot-com + GFC) reversed it — the edge was a bull-regime
artifact (`memory/project_early_admission_mechanism`,
`memory/project_promotion_confirmation_grid`).

Run that same selection metric over a *population* and you don't get one overfit
winner — you get a population of bull-regime artifacts, and the search
confidently reports "many peaks, all beating baseline." **Parallel search
multiplies whatever flaw is in the fitness function.** So the prerequisite is
not the search machinery; it is a battery that cannot be fooled.

## Three things that must be true before multi-arm is safe

1. **The battery is regime-diverse, not just calendar/universe-diverse.**
   "Multiple 15y backtests sampled from a broad universe" sound independent but
   mostly are not — 2010–2025 is one macro regime; different universe *subsets*
   of the same period are correlated draws (universe diversity ≠ regime
   diversity). The count of *genuinely* independent macro cells is small
   (~dot-com 2000-02, GFC 2008, 2010s bull, COVID 2020). The battery's **worst**
   cell is the signal, not its average. This is precisely why the deep-history
   infra is load-bearing for this vision — the deep cell is the only thing that
   can veto an artifact (`.claude/rules/promotion-confirmation.md` §macro-regime
   diversity; `memory/project_gspc_index_golden_2017_floor`).

2. **Deflation counts the whole population's lifetime trials.** Deflated Sharpe's
   `n_trials` today = one matrix size. With M arms × per-arm trials × re-eval
   rounds the effective trial count is enormous; deflating against one matrix
   while searching with a population is the #1 way population search lies —
   every "newly discovered better peak" is just the max of more noise. The
   ranking tool must take a **running lifetime trial budget**.

3. **Arms carry an explicit diversity pressure** (feature-set distance). Without
   it the population collapses to one peak and you have paid M× for a single
   search.

## Defining the goal — the concrete answer

The objective that produced the overfit was a **single scalar averaged across
cells** (mean Sharpe). For a robust population objective, optimize **worst-case
regime**, not expected value:

> maximize over arms of ( **min** over regime-cells of metric )

This is robust optimization, not expected-value optimization. It encodes
"don't be a bull-regime artifact" **into the fitness function itself**, rather
than catching it after the fact with a confirmation grid. (A soft variant: a
hard floor on the worst cell + a tie-break on the average.)

## Revising the goal confidently

The user's requirement — re-pinning goals + feature sets should be a confident,
repeatable process. Buildable:

- Make the **goal a versioned artifact**: the fitness metric + the battery
  composition, pinned with an id.
- A tool **re-scores the entire append-only ledger** under a revised goal and
  reports which prior ACCEPT/REJECT verdicts flip.

Without this, goal-drift silently invalidates history — you cannot tell whether
a re-pin improved the system or merely moved the goalposts. The ledger already
being append-only makes the re-score clean.

## Prerequisites & sequencing (each gates the next)

1. **A real multi-regime battery exists and is cheap to sample.**
   `dev/scripts/build_deep_universe.sh` (PR #1388) is step one — the 2000-2026
   deep cell. Needs the other point-in-time snapshots (2005/2010/2015/2020) +
   a broad-universe cell (the experiment-platform P3 line). Until this exists,
   there is nothing to optimize worst-case *over*.
2. **Population-aware deflation** — `rank_variants` takes a running lifetime
   trial budget, not just the current matrix size.
3. **Versioned goal + ledger-rescore tool.**
4. **Then** multi-arm, launched under `.claude/rules/sweep-hygiene.md` (parallel
   arms = parallel sweeps = real disk / Docker.raw pressure — the bind-mount +
   disk-watcher infra must be solid first).

## The one hard rule

**Do not run multi-arm on a single-regime battery.** That is the overfitting
machine we just escaped (early-admission), parallelized. The deep/multi-regime
battery is the unlock — which is why the deep-data infrastructure is the
current P0, not the search engine.

## Relationship to existing rules

- `experiment-flag-discipline.md` — every arm's mechanisms are still
  default-off flags / axes; the population searches over flag combinations.
- `promotion-confirmation.md` — the confirmation grid is the *single-candidate*
  version of this note's battery; multi-arm generalizes it to a population and
  folds the grid into the fitness function.
- `experiment-gap-closing` skill — the sequential loop is the unit; the
  population runs many units concurrently with a shared deflation budget.
