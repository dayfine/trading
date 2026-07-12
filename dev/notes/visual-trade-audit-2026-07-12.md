# Visual trade audit + entry-gate screens — diagnosis and correction (2026-07-12)

User-directed (interactive audit session): chart the record run's most
impactful trades, read them for entry/exit quality, and screen any
gate hypothesis before building. 56 stage charts generated (top-40 by
|PnL/NAV-at-exit| + top-15 dollar losses + the 2 open positions); ~20 read
closely. This note records BOTH the chart-read hypotheses AND the screens
that killed them — the correction is the finding.

## Chart-read taxonomy (12 biggest losses)

- **"Class A" — V-bounce after a decline, tagged fresh Stage2, under old
  tops** (8): COO, ANF, ASTE, AIR, TFX, OLED, STRA, BF-B. All resumed the
  downtrend within days; stops capped each at −5..−15% (worst −$590k COO).
- **Whipsaw on a legitimate setup** (3): CCL, AWR, BKE (CCL then ran +70%
  without us). The known premium.
- **Spike-chase** (1): FNMA — bought week-2 of a vertical 2× move; stop
  could not hold the retrace; stock then 4×'d.
- Winners read for contrast (SKYW, DDD): visually long flat bases.

Mechanical observation that motivated the screens: 7 of the 8 "Class A"
entries print `ma_direction Rising` at entry (the bounce drags the WMA-30
slope positive) — only AIR reads Declining, so the validated declining-MA
gate catches ~1/8.

## Screen 1 — overhead-resistance gate (prior-top headroom): NO-BUILD

Paired per-trade screen over 877 basis-clean trades, X ∈ {15,25,40} × 5y/3y:
- Median entry headroom is 16.5% — the strategy ROUTINELY buys near prior
  highs; every variant blocks 22-39% of ALL entries (character-change flag)
  and strips the momentum leaders (AMD, DY, REGN: $11.5M winner PnL
  foregone at X=25). net_pnl_avoided NEGATIVE at every X.
- The "Class A" losses sit at headroom 27-133% — the SAME deep-crash region
  as the monsters (SKYW 261%, FARM 590%, BCSI 230%). Zero of the 8 blocked
  at X=25. No X separates losses from monsters. Sign robust to basis
  convention.

## Screen 2 — base-quality / recent-Stage4 gate: NO-BUILD

Full stage-timeline features for all 1,140 entries (prior-chained
stage_dump, 709 symbols, 0 errors):
- The "defect" shape IS the standard entry: weeks_since_S4 ≤ 8 for 84% of
  all entries; basing < 4 weeks for 78%. Feature-identical twins across the
  outcome divide: FARM(ws4 2/bw 1) ≡ TFX/STRA/ASTE/BF-B; DDD(6/5) ≡ OLED;
  BCSI(3/2) ≡ COO/ANF. SKYW = 8/5.
- Every gate variant blocks 64-94% of entries, net −$4.2M to −$17.4M, and
  blocks all four monsters at the thresholds that catch the loss cluster.
- Why the chart-read failed: the classifier tags most of a visually-long
  base as Stage4 (price under a declining MA catching down) — "long flat
  base" is not expressible in stage-timeline features. A price-geometry
  feature would be next, but the powered entry-selection null (162k-ticket
  screen, R²=0.0034) stands against the lever class.

## The corrected conclusion (transferable)

**The big losses and the monsters are the same ticket.** The strategy's
standard entry is a V-bounce recovery weeks after a Stage-4 print; stops
cap the failures at −5..−15% of position while the feature-identical
successes pay +$2.9-5.2M. "Never make these trades again" is structurally
equivalent to "never buy the monsters." This re-derives
edge-is-the-fat-tail at the entry-shape level, now with event-level power,
and closes BOTH gate hypotheses as alpha/quality levers.

## What survives as REAL fixes (correctness, not alpha)

1. **Resistance-mapper data starvation** — spec wants 520 weekly bars;
   backtest panels carry ~52 and the live weekly-review warehouse ~110, so
   COO (backtest) and CWST (live picks, same night) print false
   `Virgin_territory` under years of tops. Fix the LABEL (feed history or
   degrade to insufficient-window); build no gate. Also repairs the live
   report text.
2. **Rename-twin double-count** — ~$2.14M of the record run's $18.0M
   realized PnL (11.9%) is clone legs (10 confirmed groups: NLS/BFX,
   ISIS/IONS, WLY triple, COR/ABC triple, BKR/BHI, BLL/BALL, SWM/MATV,
   TXNM/PNM, NVRI/HSC, SJW/HTO). Live universe is clean (0 active twins in
   a 17,860-pair scan); the dups live in historical PIT snapshots. Fix =
   twin dedup in snapshot builders (>95%-identical adjusted_close over
   ≥100 overlapping days) + re-pin; haircut the realized headline ~12%
   until then (≈$17.7M → ≈$15.6M, ~11.0%/yr — still > SPY TR 8.17%/yr).
3. **CEF/asset-type universe leak** — ~55 clear non-equities in the live
   universe (FTHY bond CEF surfaced as a top pick; PHYS/PSLV bullion
   trusts; ~28 bond CEFs; ~22 equity CEFs; plus ~27 SPAC shells, ~32 BDCs
   debatable). Root cause: EODHD exchange-symbol-list mislabels them
   "Common Stock"; the builder's equity filter ran on bad data. Fix at
   universe build: fundamentals `General::Type` enrichment or curated
   blocklist + SPAC vol/age gate.
4. **trades.csv export-join defect** — `exit_trigger` and
   `stop_trigger_kind` come from different joins (symbol-keyed vs
   position-keyed) and misalign on re-traded symbols (41 blank-trigger
   rows, 27 with contradictory kinds). Fix: key both by position_id.
5. **Declining-MA gate arming for broad** — unchanged, has its own WF-CV
   support (#1775 ARM-FOR-BROAD); catches the AIR class.

Validator harness (#1937) consequence: V9 (prior-top) and V10 (spike) stay
**report-only statistics permanently** — both measured harmful as gates.

Charts + screen working files: session scratchpad (regenerable;
stage_chart / stage_dump commands in the session log).
