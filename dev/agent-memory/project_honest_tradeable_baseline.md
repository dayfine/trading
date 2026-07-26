---
name: project_honest_tradeable_baseline
description: "Honest-tradeable deep baseline 2026-07-10 (overlay 1e6/5e5 + stale-exit 5d armed): +6889.6% MTM / realized ≈+1600% (~11.4%/yr) — FIRST deep path where realized beats TR-SPY (8.15%); Sharpe .806, DD 40.6, Ulcer 15; overlay = QUALITY filter, gradual sign-stable 3.2× vs un-armed"
metadata: 
  node_type: memory
  type: project
  originSessionId: dbeb7536-3c56-4212-a532-4c2daa8dfc4b
---

`dev/notes/honest-tradeable-baseline-2026-07-10.md` + DEEP_RESULTS ⭐ row.
top3000-2000-2026-catstop (0.14/catstop-0.10, 364 basis, merged main incl.
#1906 pairing fix + #1910 floor-off) with realism dials ARMED:
`liquidity_config (min_entry 1e6 / min_hold 5e5)` + `stale_exit_after_days 5`.

- **+6889.6% MTM / realized ≈ $17.0M ≈ +1600% (~11.4%/yr) vs SPY-TR 8.15%/yr
  — realized beats the index for the first time on a deep path.** Sharpe
  0.417→0.806, MaxDD 40.6 (real), Ulcer 26.5→15.0.
- **WHY (decomposed, not luck):** armed/un-armed year-end ratio grows
  GRADUALLY and sign-stable (1.0→1.2→2.15 by 2008→3.2 by 2026; one
  convergence year). Overlay = QUALITY filter: fake wins gated (APPB), zombie
  capital recycled (IN1 $143k dead 20y), corrupt-bar names excluded; freed
  capital compounds in liquid names where ALL real fat-tail winners live
  (re-derives [[project_trade_realism_liquidity]] from a new angle).
- **FOLD-PROOF (2026-07-10 WF-CV, 13 biennial folds, 2×2 decomposition) —
  MIXED, 3rd path-vs-fold inversion:** the 3.2× bundle path was
  path-compounding. Fold-honest: **HOLD-EXIT (5e5) ALONE dominates baseline**
  (Sharpe .654→.753, Calmar .917→1.131, DD −5.6pp, DSR .9999, 8/13 —
  strongest fold candidate yet; promotion path = neighbor surface + regime
  grid + fold-008 realizability argument); **ENTRY GATE alone costs
  Sharpe/Calmar** (estimand caveat: simulator credits fake untradeable
  profit, so part of the "cost" is fake alpha foregone); bundle < hold-only.
  Gate FAIL all (fold-008 2016-18 low-ADV monster: baseline +69.7 vs
  hold-only +23.9 — the tail-tax exhibit). Ledger
  2026-07-10-liquidity-overlay-wfcv (Reject-promotion).
- ⭐ row stands as REALISM MEASUREMENT CONVENTION only (fake fills must not
  count), not an alpha claim; terminal MTM still AXTI ($51.7M of $66.8M
  OPV); overlay+stale-exit stay default-off.
- **4Y-FOLD SENSITIVITY (07-11, user's horizon question): hold-exit's 2y
  dominance INVERTS at 4y** (Sharpe 0.626 vs baseline 0.719, 2/6, DSR 0.872,
  off frontier) — the "strongest fold candidate" was a FOLD-HORIZON ARTIFACT;
  promotion path CLOSED. Entry gate consistent both horizons (realism
  Sharpe-for-DD trade; flip unaffected).
- **Standing methodology LAW (4 confirmations: armon, catstop, overlay-path,
  overlay-fold-horizon): paths flatter compounding; SHORT FOLDS flatter exit
  mechanisms — tail-dependent verdicts need a horizon sweep (2y vs 4y+) or
  the rolling-start matrix.** Supersedes the un-armed topline in
  [[project_deep_topline_364]] as number of record.
- **S1 EXTENDED-END VERIFICATION (07-11, end 2026-06-26, PR #1931): AXTI
  branch B — STILL HELD.** Trailing stop never advanced past the mid-May
  pullback; run rode $122→$70 give-back (~$34M MTM from peak). Topline flat
  +6885.1%, MaxDD 41.3 (AXTI-peak-relative), Sharpe 0.806→0.768 = measured
  branch-B cost to date. **Realized ≈$17.7M (+1670%, ~11.5%/yr) still beats
  refreshed SPY TR +700.0% (8.17%/yr).** extension_stop question stays with
  S2's distribution-level screen (April-28 shakeout would trap
  single-specimen thresholds). Note:
  dev/notes/axti-exit-verification-2026-07-11.md; staged scenario committed
  at test_data/backtest_scenarios/staging-honest-tradeable-ext/.

**BASIS CHANGE 2026-07-13 (dedup-v2) — new record numbers.** Returns-basis
twin dedup ([[rename-twin-dedup-returns-basis]]) removed 83 duplicate-feed
groups (91 legs, 2999→2908) from the warehouse; 28y re-run on the deduped
basis: **MTM +3407.4% ($35.07M), realized $10.37M (+1037%, 14.4% CAGR) vs
SPY TR +700% (8.17%/yr)**, 1171 trades, Sharpe 0.68, MaxDD 40.9%, 92% of
terminal NAV in 4 open positions (AXTI dominant, still held). Pre-dedup
+6885%/+1670% SUPERSEDED — clones counted double in both realized and MTM,
and the 12% haircut estimate was measured on only 10 of the real 83 groups.
Validator at full coverage on this run (audit join 1171/1171, V5/V6 clean,
V7=100 false-Virgin entries pending min_history_bars arming). Note:
dev/notes/dedup-record-rerun-2026-07-13.md.

**2026-07-14 — RECORD COMMITTED = RUN D (armed record convention, dedup-v2):**
+7,914% MTM / $70.9M realized / Sharpe 0.83 / CAGR 18.0% / MaxDD 32.3% / 1,187
trades (scenario `staging-record-convention/top3000-2000-2026-record-convention.sexp`;
DEEP_RESULTS §"RECORD OF RECORD"). E-capped long-short (+13,730%) is honest but
sizing-lottery-flattered (same AXTI entry, 1.7× ticket) — NOT the record; old
uncapped E (+22,097%) = free-leverage artifact (committed/NAV >1 in 24/26 yrs).
Levered long-short: planned only
([[levered-longshort-margin-realism plan]], dev/plans/…2026-07-14.md).
