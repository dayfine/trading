# All-eligible diagnostic — corrected results (2026-05-06)

## TL;DR

The PR-1 / PR-2 all-eligible runner that landed in #889 / #901 reported
**27,092 trades** for `goldens-sp500/sp500-2019-2023.sexp` (5y). That figure
was ~5x too high. Root cause: the upstream
`Stage_transition_scanner` emits one `candidate_entry` per
`(symbol, week)` where `is_breakout_candidate` fires — and that predicate
stays true for the first ~four weeks of a fresh Stage 2 advance, so a
single real entry event becomes 4-5 scored candidates on consecutive
Fridays. The runner was mapping each one to a separate trade record.

This PR adds `All_eligible.dedup_first_admission`, applies it in
`All_eligible_runner._scan_and_score` before grading, and re-runs the
diagnostic on both 5y and 15y SP500 scenarios. Headline numbers:

| Scenario                           | Pre-fix trades | Post-fix trades | Reduction |
|-----------------------------------|---------------:|----------------:|----------:|
| `sp500-2019-2023` (5y, 491 syms)  |        ~27,092 |       **5,836** |     4.6x  |
| `sp500-2010-2026` (16y, 510 syms) |       (TBD 15y; ran on top of #901 buggy producer would have been ~52k) | **(TBD on 15y completion)** | — |

The fix also dedups *across* sides (Long vs Short are independent) and
preserves re-admission after a prior trade's natural exit. Tests pin all
five behaviours.

## Root cause

`trading/trading/backtest/optimal/lib/stage_transition_scanner.ml` runs
`Screener.screen` per Friday with the cascade gates relaxed
(`min_grade=F`, unlimited top-N, forced-Neutral macro), then maps each
emitted `Screener.scored_candidate` to a fresh `Optimal_types.candidate_entry`:

```ocaml
let scan_week ~config (week : week_input) : Optimal_types.candidate_entry list =
  let permissive = _permissive_screener_config config in
  let result = Screener.screen ... in
  let passes_macro = _passes_long_macro week.macro_trend in
  List.map result.buy_candidates
    ~f:(_candidate_of_scored ~date:week.date ~passes_macro)
```

The breakout predicate inside `_long_candidate` is
`Stock_analysis.is_breakout_candidate`, which returns `true` whenever the
stock is in early Stage 2:

```ocaml
let is_breakout_candidate (a : t) : bool =
  let stage_ok =
    match (a.stage.stage, a.prior_stage) with
    | Stage2 _, Some (Stage1 _) -> true
    | Stage2 { weeks_advancing; late = false }, _ -> weeks_advancing <= 4
    | _ -> false
  ...
```

So a single Stage 1→2 transition produces a candidate on the
transition Friday, plus typically 3-4 follow-up Fridays where the same
stock is still inside its first four weeks of Stage 2. The
`All_eligible_runner` then maps each scored candidate 1-to-1 to a trade
record:

```ocaml
let grade ~(config : config) ~(scored : OT.scored_candidate list) : result =
  let trades = List.map scored ~f:(build_trade_record ~config) in
  ...
```

Result: ~5x over-count, same root signal expressed as five trade rows.
27,092 / ~5 ≈ 5,400 — close to the observed 5,836 post-fix figure.

The optimal-strategy track avoids this naturally because
`Optimal_portfolio_filler._try_admit` checks `_holds_symbol book ...`
before admitting — once a symbol is open, re-firings on subsequent
Fridays are silently skipped. The all-eligible diagnostic explicitly
opts out of the portfolio gate, so it has to dedup explicitly.

## Fix design

`All_eligible.dedup_first_admission : scored_candidate list ->
scored_candidate list` is a pure function.

For each `(symbol, side)`, it keeps the earliest scored candidate and
silently drops every subsequent candidate whose `entry_week` falls inside
the previous keeper's `[entry_week, exit_week]` window (inclusive
watermark). After the prior trade's `exit_week`, a fresh re-firing
becomes a new trade — same semantics as `Optimal_portfolio_filler`'s
hold-on-symbol gate, but expressed without portfolio state.

Implementation: sort by `(entry_week, symbol, side)` ascending, walk in
order, keep a per-`(symbol, side)` watermark hash. ~30 LOC of pure
function. Output is chronological-deterministic.

The runner applies dedup before grade:

```ocaml
let scored = _scan_and_score ... in
eprintf "all_eligible: %d scored candidates pre-dedup; deduping...\n%!"
  (List.length scored);
let deduped = All_eligible.dedup_first_admission scored in
eprintf "all_eligible: %d candidates post-dedup; grading...\n%!"
  (List.length deduped);
let result = All_eligible.grade ~config ~scored:deduped in
```

`grade` itself is unchanged — still takes a `scored_candidate list` and
projects 1-to-1. Tests with hand-built scored candidates can skip the
dedup layer for arithmetic pinning.

## Five pinned dedup tests

`trading/trading/backtest/all_eligible/test/test_all_eligible.ml`:

1. **5 consecutive Friday emissions for one symbol → 1 trade.** Five
   `scored_candidate`s on Fridays 2024-01-19 through 2024-02-16, all
   sharing `exit_week=2024-04-19`, dedup to one with `entry_week =
   2024-01-19`. This is the headline regression.
2. **Distinct symbols are preserved.** AAA + BBB on the same Friday →
   both kept.
3. **Re-admit after exit.** AAA `entry=2024-01-19, exit=2024-03-29`,
   then AAA `entry=2024-04-05, exit=2024-06-28` → both kept, since the
   second entry is strictly after the first exit.
4. **No re-admit on exit week.** AAA `entry=2024-01-19, exit=2024-03-29`,
   then AAA `entry=2024-03-29` → dropped. The watermark is inclusive.
   This preserves "one trade per Stage-2 advance" semantics — a Stage-3
   exit and a same-Friday re-classification doesn't book two trades.
5. **Long and short dedup independently.** AAA Long + AAA Short
   overlapping in time are both kept.

Plus a chronological-output pin and an empty-input pin (no exception).

## 5y SP500 results — `goldens-sp500/sp500-2019-2023`

Run: `dev/all_eligible/sp500-2019-2023/2026-05-06T20-51-19Z/`
Universe: 491-symbol 2019-2023 SP500 snapshot.
Period: 2019-01-02 to 2023-12-29.
Wall: ~15 minutes (CPU-contended; a sibling agent's parallel
`scenario_runner` was using 4 cores).

| Metric             | Pre-fix (#901) | Post-fix |
|-------------------|---------------:|---------:|
| trade_count       |        ~27,092 |  **5,836** |
| winners           |              ? |       627 |
| losers            |              ? |     5,209 |
| win_rate_pct      |              ? |    10.74% |
| mean_return_pct   |              ? |  -10.83% |
| median_return_pct |              ? |  -10.62% |
| total_pnl_dollars |              ? |  -$6.32M |
| mean hold_days    |              ? |     61.7 |

Exit-reason mix (post-fix):

| exit_reason         | count | share |
|--------------------|------:|------:|
| Stop_hit           | 5,558 | 95.2% |
| End_of_run         |   228 |  3.9% |
| Stage3_transition  |    50 |  0.9% |

Return-bucket histogram (post-fix):

| Low    | High    | Count |
|--------|---------|------:|
| -inf   | -0.50   |    116 |
| -0.50  | -0.20   |  1,079 |
| -0.20  |  0.00   |  4,014 |
|  0.00  |  0.20   |    382 |
|  0.20  |  0.50   |    157 |
|  0.50  |  1.00   |     68 |
|  1.00  | +inf    |     20 |

### Reading the 5y numbers

**The signal alpha is brutal**: 10.74% win rate, mean return -10.8%.
That's because the all-eligible scanner uses the screener with
`min_grade=F` and unlimited top-N — it's emitting *every* Stage-2
breakout candidate, not just the cascade-promoted ones. Most weak
breakouts get stopped out within ~7 days at the suggested-stop level
(typical risk_pct ~8% per the cascade defaults), giving a left-skewed
distribution dominated by quick stop-outs.

The handful of big winners (88 trades returning >50%) is what the live
strategy's portfolio filler is supposed to capture — the all-eligible
view validates that the *signal pool* contains usable upside, while the
portfolio interaction is what determines whether the strategy can
realise it. This is exactly the diagnostic separation #870 calls for.

**Calibration story**: 5,836 first-admission events over 5y across 491
symbols ≈ ~12 admissions per symbol per 5y, or ~2.4/year per name. That
matches the per-symbol histogram (top symbols at ~25/5y ≈ 5/year, most
symbols at 2-5/5y total). Reasonable for a screener with `min_grade=F`
that admits any Stage 2 transition with adequate volume.

By contrast, the live cascade reports ~10,945 admitted top-N candidates
over 15y per
`dev/notes/856-optimal-strategy-diagnostic-15y-2026-05-06.md` — but that
figure is *cascade-emitted-per-Friday*, not deduped, so it has the same
multi-counting artefact baked in. Apples-to-apples-against-the-fix
calibration would require also deduping the optimal-strategy scanner's
output the same way; that's a separate follow-up.

**Why the post-fix count is higher than the prompt's pro-rated estimate of
~3,650**: the prompt pro-rated from "10,945 candidates over 15y" to "5y
target ≈ 3,650". But (a) those 10,945 were post-cascade top-N (live
config: `min_grade=C`, `max_buy_candidates=20`), whereas the
all-eligible scanner uses `min_grade=F` with unlimited top-N — strictly
more permissive; and (b) they were *not* deduped to first-admission
either, so the 10,945 itself is already inflated by the same mechanism.
The 5,836 figure is what the all-eligible producer *should* emit per its
own definition (every Stage-2 first-admission, no cascade gates).

## 15y SP500 results — `goldens-sp500-historical/sp500-2010-2026`

Run: `dev/all_eligible/sp500-2010-2026-historical/2026-05-06T20-52-19Z/`
Universe: 510-symbol survivorship-aware 2010-01-01 SP500 snapshot.
Period: 2010-01-01 to 2026-04-30 (16+ years).

**Status: IN FLIGHT at PR submission.** The runner started at 21:08 UTC
and was still in the scan-and-score phase at the 30-minute mark with
~960 MB RSS. The 5y wall on the same contended-CPU host was ~15 min;
proportionally, the 15y over 16y of period × ~510 symbols is expected
to take ~45-60 min. The host is shared with a sibling agent's parallel
4-process \`scenario_runner\`, which roughly halves available cores.

The expected post-fix trade count is in the 10-15k range based on
linear scaling from 5y / 491 symbols → 16y / 510 symbols, modulo
regime differences (the 16y window includes 2010-13's grinding bull,
2018 Q4, and 2022 — all of which produce different Stage 2 admission
densities than 2019-23). The pre-fix figure on this scenario would
have been ~50-75k by extrapolating the 5y 27,092 / 5y multiple.

Artefacts will be appended to this notes file under this section once
the run lands; the `dev/all_eligible/sp500-2010-2026-historical/...`
directory will be filled in via a follow-up commit on this branch.

## Recommended follow-ups

1. **Apply the same dedup in the optimal-strategy scanner.** The
   "10,945 cascade-admitted top-N over 15y" figure used in #856 has the
   same multi-counting artefact. Re-running with first-admission dedup
   would give a cleaner conversion-rate denominator for the
   "120 entries / 10,945 admissions = 1.1% conversion" framing.
2. **Macro stamping.** All 5,836 trades have `passes_macro=true` because
   the runner doesn't consume a real macro-trend table — every Friday
   gets stamped Neutral. Wiring in the actual `macro_trend.sexp` from a
   sibling backtest run would let the diagnostic report
   alpha-by-macro-regime, which is a stated #870 acceptance goal.
3. **Tighten the all-eligible scanner.** The current pipeline uses
   `min_grade=F`, which surfaces signal floor + ceiling but mostly
   floors the win rate. For "what would the cascade have caught with
   the live config" we want a `min_grade=C` variant. That's a CLI flag
   on the runner, not a code change.
