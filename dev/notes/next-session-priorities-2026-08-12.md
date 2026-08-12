# Next-session priorities — 2026-08-12

> **AMENDED 03:15 after the overnight run.** Two things below are now wrong and
> the corrections are the most important content in this file:
>
> 1. **The armed-golden "blocker" I described was my own misconfiguration.** CI
>    sets `TRADING_DATA_DIR=<workspace>/trading/test_data`; I had been running
>    against the local `data/` warehouse. Under CI's path the `six-year-2018-2023`
>    golden reads 79.134696483942491 / 321 — dead on its pinned band. Local
>    reproduces CI exactly. The 27 local `runtest` failures are the same
>    misconfiguration, not a repo property.
> 2. ~~PR #2279 is a partial fix.~~ **RETRACTED — that was my error.** I claimed
>    a second nondeterminism source survived; the runs behind it were built from
>    `cleanup/*` branches cut off main *before* #2279 merged, so they exercised a
>    **pre-fix binary**. Re-run on post-merge main: `112.28323995525771` / 240
>    trades twice, byte-identical `trades.csv`, agreeing with a third measurement
>    on the fix branch itself. #2279 is complete; #2289 is closed as wrong. **The
>    armed golden is unblocked and lands in #2291** with those values pinned.
>    Lesson, applied to me: a determinism check must hold the binary fixed —
>    `git log main` for the merge before treating a moving number as a defect.
>
> **New headline result: the 26y noise floor is ~278pp**, measured from the
> sweep's own cells 07/08 — which are one configuration spelled two ways.
> `dev/notes/ladder-v4-read-2026-08-12.md`, PR #2288. Only volconf's reject
> survives it; **nearfloor's 670.0 is not a result**, and a deterministic 24-cell
> re-run at 500/5y reverses it.
>
> P0 item 1 below ("measure the null at v4 scale") is therefore **done**, for
> free, without the ~5h of dedicated re-runs it budgeted.
>
> Open PRs at handoff, all CI-green, none merged (code PRs need the two QC
> gates): #2279 fix (MERGED), #2280 harness wrapper, #2283
> harvest_rotate retirement, #2284 early_admission retirement, #2286
> cash_reserve retirement, #2288 ladder-v4 read, #2289 residual nondeterminism.
>
> **Third result (05:50): a single 26y run cannot rank cells, and now there is a
> tool for it.** #2279 made runs repeatable, not representative — the return is
> concentrated in a few trades and the cash queue is saturated, so one run is one
> draw from a lottery over which monsters get funded. **#2293** adds
> `TRADING_PATH_SEED_SALT` (a run-level dial, bit-identical when unset) so one
> config can be run K times for a **distribution**. First measurement: five salts
> on sp500/5y give mean 112.50, range 2.53pp (**~2.2% relative**), trades
> identical at 240 — against **~47% relative** for the 26y cells-07/08 pair. Same
> mechanism, >20x amplification with horizon and breadth, and 26y/top-3000 is
> where the ladder does its comparisons. **Compare distributions, not points.**
>
> The v4 sweep was **not disturbed** — 14/24 at 03:10, chain armed to auto-run
> cell-00 + cell-09 on the fixed build the moment its exit sentinel appears
> (`/tmp/chain_26y.log`, worktree `.claude/worktrees/v4-fixed`). Given the 278pp
> null, treat those two runs as a determinism check rather than as the ranking.

**Supersedes** `next-session-priorities-2026-08-11.md` for priorities. That
file's *ladder-v4 pickup instructions and Stage-A results table are still
live* — read them there, but read them through the correction below.

## The headline: armed backtests were not reproducible

Task #17 asked which of five commits regressed armed-StopLimit behaviour
between ladder-v3 and ladder-v4. **The premise was wrong — there is no
regression to find.** Two runs of the same binary over the same scenario and
the same data returned different numbers.

`Price_path.default_config` carried `seed = None`, which selects
`Random.State.make_self_init ()` per generated intraday path; nothing in the
backtest ever set a seed. Four runs of one binary on a 6y/302 armed probe:
49.2846 / 50.0589 / 49.3444 / 49.3723 — **spread 0.774pp**, which swallows
every per-commit delta the bisect produced (0.06–1.12pp, n=1 each).

No gate caught it because market orders fill at the bar's open/close and never
walk the path; only resting stop/limit orders do — the armed-StopLimit family
that no golden arms. Goldens were verifiably bit-identical run to run.

Full record: `dev/notes/backtest-nondeterminism-2026-08-11.md`.
Memory: `project_backtest_nondeterminism_intraday_path`,
`feedback_run_the_null_control_first`.

## Open PRs — both green on CI, both need the two QC gates

Neither was merged: `.claude/rules/pr-merge-gates.md` requires qc-structural +
qc-behavioral on code PRs, and no QC agents were dispatched this session.

- **#2279 `fix/deterministic-intraday-path`** — the fix. `Market_state` derives
  the seed from the bar (`Bar_shape.seed_for_bar`). Proof of no collateral
  movement: the unarmed `six-year-2018-2023` golden is bit-identical pre/post
  (100.63260509255689); the armed probe goes from a new number every run to
  48.969233055332253 twice, and 51.900914377999626 twice at 5y/500 scale. Also
  extracts `Bar_shape` from `price_path.ml` (502 → 414 lines) after CI's
  file-length linter tripped — verified behaviour-neutral.
- **#2280 `harness/docker-dune-wrapper`** — `dev/scripts/docker_dune.sh`
  (task #13), a dune wrapper that runs detached with an `exit=` sentinel so the
  docker-exec wedge is unreachable by construction. Used for ~20 builds and 2
  full `runtest`s this session with no wedge. Carries the short armed probe
  scenario (~3.5 min/run vs 1h46m).
- #2281 (docs, the P0 correction) — merged.

## P0 — settle what the noise actually cost us

In order:

1. **Measure the null at v4 scale.** The 6y/302 null (0.774pp, 1.6% relative)
   does **not** bound the 26y/top-3000 null. Run one v4 cell k≈3 times on the
   pre-fix build at `4ecbe1154` (~1h45m each, so ~5h) — do this *after* the
   sweep finishes, not alongside it.
2. **Re-run v3-w4 and v4-cell00 on the fixed build.** That is the only way to
   learn whether any part of the 317.80 → 343.90 gap was real.
3. **Then, and only then, read Stage A.** The large effects stand on magnitude
   alone — cell 09 nearfloor (670.0) and cell 10 volconf (−47.6) are nowhere
   near any plausible noise floor. **Cells 01–05 do not** and must not be
   quoted as one-axis effects until (1) lands.

## P1 — the armed golden (the durable close of the structural hole)

Now possible, because armed runs are reproducible. **Bands cannot be pinned on
this host**: local `data/` differs from CI's committed tree — the same
`six-year-2018-2023` golden reads 100.63 locally against a pinned CI band of
~79.13, and 27 local `runtest` failures are `Sys_error` on a
`data/backtest_scenarios/` tree that does not exist here. Procedure: land the
armed scenario into the postsubmit golden set with sentinel bands, read the
first postsubmit `actual.sexp`, re-pin in a follow-up.

## Sweep state at handoff

**Ladder v4 still RUNNING, undisturbed.** 12/24 cells at 00:10 PT 08-12,
pinned worktree `.claude/worktrees/sweep-ladder-v4` at `4ecbe1154`. Cell 12
(`rt-ttl4`) has been running 2h08m against a ~1h45m norm — my concurrent
probes competed for CPU, so **expect completion later than the original
~midday estimate**, roughly evening 08-12. Pickup commands are in the 08-11
doc. Container memory peaked ~3.0GB of 7.75GB with both workloads; disk 74G
free.

Do not run backtests alongside it if wall-clock matters.

## Carried forward, unchanged

From the 08-11 task list: #19 (per-mechanism integration smoke scenarios —
F5's unit tests were correct and still missed a 3× candidate explosion), #4
(position_id join; audit ticket-age capped at ~1 week), #18
(`stop_initial_distance_pct` empty on ~56% of trades.csv rows), #12 (DSR
best-of-N = 24, not 13), #14 (base-extent anchor), #8 (blind-judge first run),
#9 (18 retirement trim PRs), #15, #16, #10, #11, #6.

P1 from 08-11 (the capital-constraint / ordering question) is untouched and
still framed correctly there — ordering/capacity, not selection accuracy.

## Method note worth keeping

The bisect produced a clean-looking five-row table and a plausible mechanism
story (a float-boundary rewrite in PR-5's volume refactor, `a >= k*b` → `a/b >=
k`) before anyone checked whether the measurement could carry a conclusion.
The tell was that *every* commit appeared to move the metric — the shape of a
noise floor, not of five effects. **Run A-vs-A before A-vs-B.**
