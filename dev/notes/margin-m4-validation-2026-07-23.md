# Margin M4 validation protocol — run record (2026-07-23)

Executes `dev/plans/levered-longshort-margin-realism-2026-07-14.md` §M4 on the
promoted-bundle basis (post-#2047, HEAD `0764fdebc`), warehouse of record
`/tmp/snap_top3000_dedup_v5thin`. Protocol: no levered number is quoted
anywhere before all three stages pass.

## Stage 1 — parity gates: ALL PASS (bit-identical)

Four contiguous 28y record-convention arms (top-3000, 2000-01-01..2026-06-26,
`scenarios-2026-07-23-162636/`, fixtures `staging-margin-m4-parity/`).
Byte-compare = `cmp` over 13 output files per pair (actual.sexp, trades.csv,
equity_curve.csv, summary.sexp, trade_audit.sexp, macro_trend.sexp,
final_prices.csv, open_positions.csv, splits.csv, universe.txt,
stale_holds.sexp, force_liquidations.sexp, fold_health.sexp — params.sexp /
wall_seconds / progress excluded by design).

| gate | pair | verdict |
|---|---|---|
| margin-off ≡ baseline (cross-commit) | HEAD arm 1 (bundle overrides verbatim) vs 07-22 record actuals (`scenarios-2026-07-22-231614/top3000-2000-2026-rcb-f000`, code `7ef57ed2`) | **13/13 IDENTICAL** — #2047 default flip + full merged margin stack (M1a/M1b-1/M1b-2/M2/M3a/M3b) at no-op defaults leave the +8,689% record path bit-identical |
| margin-off ≡ baseline (explicit threading) | arm 2 (every margin field written explicitly at its no-op: `initial_long_margin_req 1.0`, `long_margin_rate_annual_pct 0.0`, `maintenance_long_pct 0.0`, `short_borrow_min_dollar_adv 0.0`, `margin_config` disarmed + M3b fields at defaults) vs arm 1 | **13/13 IDENTICAL** — Overlay_validator → create_deps → Margin_runner threading is a true no-op, not just the absent-field path |
| req=1.0/rate=0 ≡ E-capped | arm 4 (E-capped + explicit `initial_long_margin_req 1.0` + `long_margin_rate_annual_pct 0.0` via the same override mechanism the M4.3 surface uses) vs arm 3 (E-capped anchor) | **13/13 IDENTICAL** — the leverage surface's unlevered corner anchors bit-identically to the E-capped baseline on the shorts-on path |

## The new unlevered frontier anchor (arm 3, first E-capped number on the promoted bundle + v5thin basis)

Shorts on, `max_long_exposure_pct_entry 1.0`, margin model DISABLED (the #1965
honest-unlevered convention). NOT byte-comparable to the 07-14 E-capped run
(that was pre-bundle, dedup_v2 warehouse) — this re-anchors the frontier for
stage 3:

- **+10,589% MTM / Sharpe .906 / MaxDD 31.1% / 1,285 trades**, Sortino 1.52,
  Calmar .62, Ulcer 10.4, 3 force-liquidations.
- MTM-heavy: $48.6M open positions, $16.8M unrealized of $106.9M final equity.
- vs long-only promoted record +8,689% / Sharpe .83 / DD 30.3.
- Single-path 28y numbers — context only; the stage-3 WF-CV surface + DSR is
  the decision lens (per `mechanism-validation-rigor`).

## Stage 2 — squeeze stress cells: faithful cells DONE (no false fire, zero events); forced-engagement cell RUNNING

Faithful-path results (`scenarios-2026-07-23-204311/`): all three cells sane —
dot-com +223% / DD 17.7 / Sharpe 1.49; GFC +41% / DD 14.0 / .58; meme-era
+109% / DD 21.1 / 1.32. No crashes, no pathological equity paths.

**Margin-event audit: ZERO force-cover / buy-in / long-reduce events across
all three squeeze windows.** Why, structurally:

- Weekly trailing stops cut adverse short moves at ~7-15%, far before the
  tiered maintenance band (30-83% adverse move) is reachable — the stop is
  always the earlier trigger on bar-cadence faithful paths.
- Short admission is thin (9 dot-com / 26 GFC / 0 meme shorts pass the
  Stage-4 + macro + $1M borrow-ADV gates) and skews to higher-priced names;
  3 GFC shorts sat inside the $5-17 (83% maintenance / 25%-yr HTB) band
  without breaching. No held short was ever marked below $5, so the buy-in
  stress mode was correctly silent.
- Meme cell admits zero shorts at all (macro/supply-gated — consistent with
  the P1a "shorts are supply-gated" finding).

Verdict framing (per mechanism-validation-rigor): these cells certify
**do-no-harm** (armed tier tables + buy-in mode produce no spurious events on
squeeze-shaped faithful paths) and **cost-channel realism lives in borrow fees
+ collateral locks, not force-covers**. They do NOT exercise the force-cover
ordering — a forced-engagement cell (GFC window, punitive thresholds:
maintenance 0.90 flat / 0.90-1.20 tiers, buy-in HTB < $25) runs purely to
generate events for the per-event ordering audit; its economics are
deliberately meaningless.

`staging-margin-m4-stress/`: dot-com 2000-2003, GFC 2007-2010, meme-era
2020-2022 (there are no GME/AMC/BBBY bars in the warehouse — the top-3000-2000
composition predates them; "GME window" = the squeeze-shaped tape, same reading
as the 07-09 floor ablation). Short book armed: `margin_config.enabled true`,
FINRA maintenance tiers (sub-$5 → 100%, $5-17 → 83%, base fallback 0.30), HTB
borrow-rate tiers (sub-$5 → 100%/yr, $5-17 → 25%/yr, flat 50bps fallback), M3b
`short_buyin_stress_mode` at `htb_price_below 5.0`, `short_borrow_min_dollar_adv
$1M`. Long side = promoted record dials + entry cap 1.0 (unlevered — stage 2
isolates SHORT-side squeeze mechanics; long leverage enters only in stage 3).
Deliverable: force-cover / buy-in ordering audit per event off trade_audit.sexp
(`margin_call` vs `buyin_stress` vs `maintenance_reduce` labels).

### Forced-engagement cell + verdict (stage 2 CLOSED)

The faithful cells produce zero events, so a forced-engagement cell
(`staging-margin-m4-forced/top3000-gfc-m4s-forced`, GFC window, punitive
thresholds: maintenance 0.90 flat / 0.90-1.20 tiers, buy-in HTB < $25;
economics deliberately meaningless) was run to exercise the channels
(`scenarios-2026-07-23-211430/`):

- **Engagement + timing PROVEN:** all 33 armed shorts were force-covered
  within ~1 tick of their constructed at-entry maintenance breach (the other
  7 were beaten to the exit by regular stops — per-tick precedence as
  designed). No stuck positions, run completes clean (+36%, DD 15.6%).
- **Label forensics BLOCKED — harness gap, issue #2057:** the
  `StrategySignal {label = margin_call | buyin_stress | maintenance_reduce}`
  reasons never reach trades.csv `exit_trigger` / trade_audit.sexp (blank),
  while strategy-side labels (laggard_rotation etc.) propagate fine. The
  per-event ORDERING audit therefore rests on the unit pins (weakest-first
  fixture in test_long_maintenance, collision dedup in test_short_buyin)
  until #2057 is fixed. Observability-only gap; no mechanics defect observed.

**Stage-2 verdict: PASS with documented gap** — do-no-harm on faithful
squeeze paths, engagement/timing proven on the forced path, ordering pinned
at unit level, label propagation filed as #2057.

## Stage 3 — leverage surface: RUN 07-23/24 — **REJECT, all six cells fail the gate**

Spec `test_data/walk_forward/margin-m4-leverage-BROAD-2000-2026.sexp` (broad
13×2y, promoted-bundle base, priced dials: rate 8%/yr, long maintenance 0.30,
short margin armed with the stage-2 tier tables). Report
`/tmp/sweeps/margin-m4-surface/walk_forward_report.md`; ledger
`2026-07-24-margin-m4-leverage-surface` (Reject).

| cell | Sharpe μ | Return μ±σ | MaxDD μ | gate |
|---|---|---|---|---|
| baseline (promoted bundle) | .827 | 36 ± 39 | 14.1 | — |
| req=1.0, shorts off, margin armed | .827 | 36 ± 39 | 14.1 | 0/13 wins, **gap 0.0000 every fold** (no-op corner ✓) |
| req=1.0, shorts on | **.883** | 41 ± 47 | 14.5 | FAIL 6/13, worst −.944 |
| req=0.75 (1.33×), shorts off/on | .558/.572 | 100 ± 190 | **49.6** | FAIL 4-6/13, worst −1.76 |
| req=0.5 (2×), shorts off/on | .341/.413 | 37 ± 280 | **89.0** | FAIL 4-5/13, worst −1.99, ruined folds |

The why (transferable): the cost structure is a steady whipsaw premium +
rare monsters. Leverage amplifies the premium in every chop fold, but the
monster folds were already ~fully invested (min_cash 0.30 binds) — asymmetric
amplification, Sharpe collapses monotonically in leverage. At 2× the raw
return is LOWER than at 1.33× (37 vs 100): volatility drag + M2 maintenance
force-reduces selling into weakness (engaging at path level; labels pending
#2057). The short sleeve's small value (.827→.883 at cash account) is
invariant to long leverage — it hedges the tape, not the leverage — and is
not gate-robust. **The fat tail cannot be scaled, only taxed** — leverage
joins the winner-touching reject family. No promotion candidate, no
confirmation grid, no default flips. M4 protocol COMPLETE.

### Addendum (user question 07-24): the barbell reading of the fold table

The per-fold pattern is regime-shaped: 1.33× wins exactly in post-bear
dawns (2002-03 +196 vs +27, 2010-13, 2016-17, 2020-21 +643 vs +134) and
bleeds in chop/late-cycle (2006-07, 2014-15, 2018-19, 2024-25). Hindsight
bound: levering 1.33× ONLY in the six winning folds chains to ~45× more
terminal wealth than baseline — regime-CONDITIONAL leverage is potentially
enormous. Deflators: (1) fold resets forgive the 22-53% levered DDs inside
even the winning folds; (2) a real-time lagging label (time-since-MA-flip-up
< ~1.5y) catches 2010/2012/2016/2020 but ALSO flags 2024 which LOST (dawn
signal, melt-up tape — the strategy's known lag regime is the leak);
(3) 2002-03 starts inside the bear, so a lagging signal captures only its
back half. Disposition: this is the parked REGIME-BARBELL program's
question — leverage as a second regime-conditional payload on the same
lagging signal (faithful as a dial; not reversal timing). Designed test
when green-lit: default-off regime-conditional `initial_long_margin_req`
axis, WF-CV + bear-cell grid, with the 2024 melt-up-lag fold as the named
falsifier. Unconditional leverage remains REJECT.
