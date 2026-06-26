# Short-side realism fixes — scope (2026-06-26)

**Next-session P0.** The longshort backtest numbers (e.g. the A-D grid's +3408%
deep-1999-2026 cell, 2026-06-23) are **inflated by unmodeled short mechanics** and
cannot be banked as absolute returns. The recent June 21-22 short work
(decline-character, faithful-short gating) improved short *selection* (which shorts
to take) but is **default-off** and touched **none** of the realism mechanics below.
Until these land, no longshort absolute return is believable. Concentration work is
**tabled** until this is done (the merged long-only 0.30 re-pin #1753 stays — it's
orthogonal; just no further concentration follow-ups until shorts are legible).

Sources: `dev/notes/short-side-gaps-2026-04-29.md` (G1-G4),
`dev/notes/long-short-margin-mechanics-2026-06-12.md` (G5 regulatory research),
`memory/project_trade_forensics_2026_06_12.md` (G5 still open), the short-supply
NO-BUILD (#1678).

## The gaps and the fix order

The five gaps are **not** five independent fixes — G3+G5+G4 are the entry/hold/exit
sides of **one margin model**. Recommended sequence:

### 1. G1 — short stops fire incorrectly  (SMALL — already diagnosed, DRAFT fix exists)
**Bug** (`Stops_runner`): (a) `_handle_stop` hardcodes `~stage:(Stage2 {weeks_advancing=1})`
regardless of side → short warmup ticks spuriously tighten the stop below entry, so a
small counter-bounce fires a profitable-territory exit (the ALB pathology); (b)
`_make_exit_transition` hardcodes `actual_price = bar.low_price` — correct worst-case
for longs, but a short's worst-case cover fill is `bar.high_price`.
**Fix**: `_compute_ma` also returns the classified stage (side-favourable warmup default:
Stage2+Rising for longs, Stage4+Declining for shorts — both no-tighten); select
`actual_price` by side. Reproducer tests already drafted in
`trading/trading/weinstein/strategy/test/test_stops_runner.ml`
(`test_g1_short_no_exit_on_counter_bounce`, `test_g1_short_exit_records_high_not_low`).
**Why first**: smallest, fully diagnosed, unblocks *correct* short exits (without which
every downstream number is garbage). Land the DRAFT.

### 2. G2 — round-trip metrics blind to shorts  (SMALL — legibility, do early)
`Metrics.extract_round_trips` pairs Buy→Sell only; Sell→Buy short round-trips are
silently dropped (shorts invisible in `trades.csv`, only in `trade_audit.sexp`).
**Fix surface**: `trading/trading/simulation/lib/metrics.ml` — add Sell→Buy pairing;
realized short P&L = entry_price − cover_price (mirror of long). **Why early**: makes the
short leg auditable so the margin-model work below is debuggable.

### 3. THE MARGIN MODEL  (LARGE — G3 + G5 + G4 unified; the core fix)
This is what removes the free-leverage inflation. Build as a config-driven module +
wire into sizing/cash/liquidation. Regulatory spec already researched (the G5 note):

- **G5 / Reg T initial margin** — opening a short locks collateral = **150% of short
  market value** (100% proceeds + 50% new equity). I.e. a $10k short needs $5k *new*
  equity. This **caps short capacity** by capital (the thing 3408% ignores).
- **G3 / cash floor on shorts** — falls out: the locked collateral IS the floor at
  entry. `_check_sufficient_cash` / `_calculate_cash_change` in
  `trading/trading/portfolio/lib/portfolio.ml` must decrement collateral at Sell entry,
  refund on cover, and gate short entry on available equity.
- **G5 / FINRA maintenance margin** — per-position ongoing requirement:
  short ≥$5/share = max($5/share, 30% MV); short <$5 = max($2.50/share, 100% MV).
  Low-priced shorts are brutally capital-hungry → the 30% tier only binds above
  ~$17/share, so keep/enforce the **`short_min_price ≈ 17`** universe filter.
- **G4 / margin call** — when account equity < aggregate maintenance requirement,
  **force-liquidate** shorts (worst-offender first); **log + emit a signal** (never
  silently swallow — every margin call is evidence the primary stop failed).

**Decision items for the human/review before building**:
- Margin params as `Portfolio_risk.config` fields (Reg-T %, maintenance tiers,
  `short_min_price`), default to the regulatory floor; default-off-safe (long-only
  unaffected). Per `experiment-flag-discipline.md`.
- Strict-collateral vs soft-accumulator for G3 — recommend **strict** (mirrors real
  brokers, makes capacity honest), which the margin model gives for free.

### 4. (Later) borrow / locate / carry cost  — realism layer 2
Short borrow fee (carry), hard-to-borrow/locate availability, squeeze risk. Lower
priority than margin; do after the margin model proves out. A flat borrow-bps carry
cost is the cheap first cut.

## Acceptance test (how we know it worked)
Re-run a longshort number that currently looks inflated (the sp500-2000 deep ~1999-2026
longshort, or a broad cell) **before and after** the margin model. Expect the absolute
return to **drop substantially** (margin caps short capacity + removes free leverage)
and NAV to never go negative. The 3408% should become a believable, lower figure. THEN
the relative A-D-live live-vs-inert grid (and any longshort comparison) is trustworthy
as an absolute, not just relative.

## Out of scope / explicitly deferred
- **Concentration** (max_position_pct_long): tabled. #1753 (long-only 0.30 re-pin)
  stays merged; no broad-concentration matrix / follow-ups until shorts are legible.
- Short **selection** faithfulness (decline-character, neutral_blocks_shorts) — already
  built default-off; revisit only after the *mechanics* are real.

## Suggested PR sequence
1. `fix(stops): G1 short-stop firing` (land the DRAFT + reproducer tests).
2. `feat(metrics): G2 short round-trip pairing`.
3. `feat(portfolio): margin model — Reg T initial + collateral (G3/G5 entry side)`.
4. `feat(portfolio): FINRA maintenance margin + margin-call force-liq (G5/G4)`.
5. Re-pin the longshort goldens to the now-realistic numbers + record the before/after.
6. (Later) `feat: short borrow/carry cost`.
