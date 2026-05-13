# M5.5 validation — `installed_stop_min_pct = 0.08` on 10y + 16y horizons

## Hypothesis

The 5y axis-1 winner (`installed_stop_min_pct = 0.08`, PR #1079) generalizes
to longer horizons. Specifically:

1. **Calmar holds or improves vs baseline on 10y + 16y long-only + 16y long-short.**
   This is the GO/NO-GO criterion. A Calmar regression on either long horizon
   is a NO-GO and the lever should not be promoted as a Cell E default.
2. **The Sharpe-vs-MaxDD profile generalizes** — Sharpe rises by some amount,
   MaxDD rises by less (multiplicatively), reflecting the same "wider stops
   let winners ride" mechanism observed on 5y.
3. **Avg-hold rises meaningfully** (the 5y run showed +66% avg-hold; the
   hypothesis is the lever is a hold-period stabilizer).
4. **Trade count drops** vs baseline (the 5y run showed −34%; widening the
   stop floor reduces churn).

## Falsification

- Calmar drops below baseline on either 10y or 16y → NO-GO, don't promote.
- Sharpe drops with MaxDD rising → "wider isn't free" cost outweighs Sharpe
  benefit on the longer cycle.
- Avg-hold doesn't rise or falls → mechanism didn't generalize; 5y win was a
  coincidence of the 5y window.

## Method

Three cells (one per horizon), each is a single-cell sweep applying the
overlay `((screening_config ((candidate_params ((installed_stop_min_pct 0.08))))))`
to the existing Cell E baseline:

1. `decade-2014-2023` (10y, broad-1000 universe, long-only, tier-4)
2. `sp500-2010-2026` (16y, survivorship-aware 510-symbol universe, long-only,
   tier-3-historical)
3. `sp500-2010-2026-longshort` (16y, same universe, long-short)

Run via `scenario_runner --dir ... --parallel 3 --no-emit-all-eligible`. The
`--no-emit-all-eligible` flag suppresses the slow all-eligible diagnostic
(saves ~30 min per cell on 16y) — not needed for validation.

Output is compared against the canonical baselines re-pinned by PR #1066
(2026-05-13, post-NAV-fix #1063).

## Baselines (current main, from PR #1066)

| Horizon | Return | Trades | Sharpe | MaxDD | Calmar | AvgHold |
|---|---:|---:|---:|---:|---:|---:|
| 10y `decade-2014-2023` (broad-1000) | 343.0% | 552 | 0.60 | 46.4% | 0.35 | 40.6d |
| 16y `sp500-2010-2026` (long-only) | 307.2% | 683 | 0.71 | 19.9% | 0.45 | 46.8d |
| 16y `sp500-2010-2026-longshort` | 316.1% | 708 | 0.70 | 19.8% | 0.46 | 46.6d |

## Decision rule

| Calmar Δ on BOTH long horizons | Action |
|---|---|
| ≥ +0.02 (and 16y long-short doesn't degrade) | Promote 0.08 as Cell E default for the next iteration |
| ±0.02 (neutral) | Keep 0.08 as a candidate; try 0.06 or 0.10 in a narrower follow-up sweep |
| ≤ −0.02 on either long horizon | NO-GO; pin 5y result as horizon-specific; do not promote |

The 5y winner had Calmar +0.13 — a Δ this large repeating on 10y/16y would
confirm the lever is universal.
