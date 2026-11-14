# Axis observatory: keep paired runs going, read them as curves over time (plan, 2026-11-14)

User, 2026-11-14: *"we should keep running some axis combinations (it should just cost compute / RAM but no / little
token)? to track the effects and discover where the opportunity is / analyze the effects of multiple layers of gates"*,
then, on noise: *"I think the main thing is to have a continuous run and observe the trend over time, among other
things."*

Status: plan. Nothing here is built yet except P0 (two PRs in flight, below).

## 1. Why read curves instead of endpoints

Every 26-year verdict this program has written reads one number per cell: the end NAV. That number is one draw.

- The record's seed SD is 0.225 log, and a single list name can move the end by 0.2 log
  (`memory/project_26y_path_noise_floor`, `project_record_kseed_band`).
- So endpoint verdicts keep reducing to "which monster landed where" (`project_edge_is_the_fat_tail`).

The paired curve carries far more information than its last point. For an arm A and the baseline S on the same build and
seed, define

    D(t) = ln(NAV_A(t) / NAV_S(t))

- **A real mechanism shows as slope.** D drifts the same way across many years and across regimes (bull, bear,
  chop), and its steps come from many trades.
- **A lottery shows as a step.** One trade, or one cash cascade, moves D once, and the first-diff names it.
- **A regime lever shows as a sign that follows the regime.** For example, the 15 % stop gate pays in 2000–02 and 2008
  and costs in recoveries (stale-E K=5, #3621).

What the curve read reports per arm (all paired, per seed):

1. D(t) weekly, 2000–2026, with the five seeds overlaid.
2. Yearly increments of D: 26 per seed. Report the sign rate across years and seeds, and the split by macro state and
   by bull/bear year.
3. The five largest steps of D, each traced to the trades that made it (`firstdiff`), and the share of D_end they
   carry.
4. Drawdown and Ulcer deltas, mean positions held, entries by year, and how many of S's tickets the arm crowded out.
   The last three come from the stale-E lesson: any lever that moves the gate's effective distance is read for
   them.

**Limits, stated up front.**
- There is still one market history. Seeds re-draw picks inside score ties; they do not re-draw the market.
- Years are path-dependent: positions and cash carry across them. So a yearly sign rate is descriptive, not 26
  independent tests.
- A curve read finds where to look. Promotion still needs a pre-registered read on a disjoint window
  (`dev/rules/promotion-confirmation.md`; nested windows re-measure the parent, `project_26y_path_noise_floor`).

## 2. What runs: three streams, plus one diagnostic

### 2.0 The gate funnel (one cell, P1)

Before choosing combinations, measure the gates themselves.
- One record-config S cell with `--emit-candidates`, on a build with the shadow entry walk (P0, below).
- Per Friday, the read gives:
  - how many names each gate removes: macro, the breakout sub-gates, sector, grade, the top-N cut, no structural
    stop, `Stop_too_wide`, cash;
  - for the removed names, what they did next (capped 30-week ride, monster rate), so each gate gets a counterfactual
    population;
  - the gate-before-cap screen: on how many Fridays a buyable name ranked 21+ was crowded out by unbuyable names
    above it while cash was free;
  - score against outcome over the whole post-cascade population, not just funded names. This re-tests ranking after
    the RS-trend fix (#2380, 08-26), because every earlier selection test ran with a constant RS term.

This one cell decides which axes the queue runs first. A gate that removes few names, or whose removed names do no
better than its admitted ones, is not worth a combination.

### 2.1 Baseline drift: the record over commits

- Re-run S k0–k4 on main after every merge that the goldens check marks behaviour-changing, and otherwise weekly.
- Plot the record's level, and D against the previous run, over commits.

Today we learn that a merge moved the book only when some experiment's tripwire fails. This makes it a time series and
attributes each move to a merge.

### 2.2 The axis queue: combinations

- A committed queue file lists arms. Each arm is a config overlay of dials already on main, citing the ledger row it
  comes from (`feedback_check_ledger_before_proposing_a_dial`).
- Each arm runs as K=5 seeds paired with S on the same build.
- Order:
  1. First, one dial at a time against S (main effects), ordered by the funnel.
  2. Then two-way combinations only where both main-effect curves show slope.
  3. Never a full factorial: knob-soup is what `weinstein-faithful-core.md` W3 rules out.

Candidate dials (all default-off or dial values on main today; the funnel picks the order):

| dial | ledger | why it is in |
|---|---|---|
| `max_buy_candidates` 20 / 40 | top-N grid 09-22 | the cut the funnel measures |
| `max_stop_distance_pct` 12 / 15 / 18 | stale-E K=5 11-14 | the bear brake; read by regime |
| `entry_cap_local_range_weeks` + `entry_cap_stop_gate_on_uncapped` (G) | 11-14 | flat at the endpoint, untraced by year |
| `candidate_ranking` `Price_band_seeded` | 11-13/14 | closed on endpoint; the curve read is new |
| laggard rotation hysteresis / RS window | `project_laggard_broad_recheck` | ROL 2016 was the G decider |
| stop buffer by macro state | `project_stop_buffer_by_macro_state_axis` | keep-as-axis |
| index-stage veto, macro-suspend | keep-as-axis rows | regime levers; the curve read is their natural read |
| gate-before-cap | not built | only if the funnel says it binds |

### 2.3 Forward weeks: the only new draws

- As the bar store refreshes, extend S and any live preset over the new weeks.
- These are true out-of-sample points, at 52 a year. It needs the data refresh (SPY refresh ends 2026-09-28, a
  carried item).

## 3. The read is mechanical: an analyst only when a flag trips

- `obs_read.sh`, one per arm pair, produces the §1 report from the per-arm files.
- It appends one row per arm to `dev/experiments/observatory/surface.tsv` in the public repo. That file is mark-free:
  yearly and regime aggregates, step shares, counts.
- The weekly D(t) curves and every price-bearing file go to `dayfine/trading-results` (EODHD terms,
  `project_eodhd_terms_private_bucket`).
- A private artifact page shows all arms' curves.

**Flag rule, set before any arm runs.** An arm is flagged for a results-analyst read only when all of these hold:
- the median D_end over seeds is at least 0.20 log;
- the yearly-increment sign is positive in at least 60 % of years, in at least 4 of 5 seeds;
- the largest single step carries under half of D_end.

The harm mirror flags the other way. A flag opens a pre-registration on a disjoint window. It is not a promotion.

**Multiple comparisons.** `surface.tsv` keeps the count of arms run. The more arms, the more one clears the bar by
chance: with ten arms the best single seed sits about 1.5 SD (≈ 0.35 log) up on noise alone. Any flagged read quotes
the count.

## 4. Where it runs and what it costs

- **Cloud lanes.** One Claude cloud session per lane, chain detached with `setsid nohup`
  (`feedback_cloud_brief_detach_long_chains`). There is no analyst per cell. Tokens are the session's launch, its
  heartbeats and its finish. Measure them on the first lane and record them in the perf ledger before adding lanes.
  - A 26y top-3000 cell is ~2.3 h, so about ten cells per lane-day sequentially.
  - Peak RSS is ~9 GB with `--emit-candidates`; only the funnel cell needs it.
- **Local container.** Zero tokens. Runs only when no QC wave or build is on
  (`dev/rules/container-capacity-scheduling.md`).
- **Private repo.** Cloud sessions can reach `dayfine/trading-results` since 2026-11-14: a routine created with it in
  `sources` succeeded. Push is checked on the first run.

## 5. Rules it keeps

- **Universe:** top-3000 PIT v12 only (U1); a top-1000 cell is a scope check, not a validity test (user, 11-14).
- **Faithfulness:** Weinstein-faithful dials only (W2/W3).
- **Same build per pair:** an S tripwire md5 per build.
- **V6:** gate every pair on V6 before reading it.
- **EODHD:** public files hold aggregates only.

## 6. Phases

| phase | what | cost |
|---|---|---|
| P0 (in flight) | shadow entry walk in `candidates.sexp`; Friday pipeline demo unit | two feat PRs |
| P1 | one S cell with the funnel; funnel, gate-before-cap and score-vs-outcome reads | one cloud cell + awk |
| P2 | `obs_read.sh`, `surface.tsv`, the curves page; the baseline-drift lane | harness PR + one lane |
| P3 | main effects in funnel order | one lane, ~2 arms/day |
| P4 | two-way combinations where both mains slope; forward weeks after the data refresh | as P3 |

## 7. Decisions

- **Lanes.** Recommended: two cloud lanes (baseline drift + queue) once P2 lands, then grow by measured token cost.
- **The flag rule in §3.** It is set here, before any arm runs; change it only before P3 starts.
