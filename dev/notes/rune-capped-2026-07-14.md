# Run-E re-run with the working long-exposure cap (2026-07-14)

P0b follow-up run: the 2026-07-13 Run E (long-short) was declared NOT
quotable — its +22,097% was a leverage artifact (marked long exposure > NAV
in 269 wks, peak 158%; dead `max_long_exposure_pct` knob). #1965 shipped a
WORKING entry-walk cap (`max_long_exposure_pct_entry`, entry-price-denominated
committed notional vs marked portfolio value). This is the fair re-run.

**Config**: record convention (ext-stop 2.0/0.25 + MA-gate + honest-tradeable
dials) + `enable_short_side true` + `max_long_exposure_pct_entry 1.0`.
Dedup-v2 warehouse, 2000-01-01..2026-06-26, top-3000 PIT-2000.
Run dir: `trading/dev/backtest/scenarios-2026-07-14-172246/`.

## Headline (PRELIMINARY — single path, see caveats)

| metric | Run D (long-only armed) | Run E-capped (this) | old Run E (artifact) |
|---|---:|---:|---:|
| MTM | +7,914% | **+13,730%** | (+22,097%)* |
| realized | $70.9M | **$126.0M** ($125.6 long + $0.4 short) | ($183.9M)* |
| Sharpe | 0.83 | **0.893** | (0.97)* |
| MaxDD | 32.3% | **31.6%** | (30.6%)* |
| Calmar | — | 0.646 | — |
| trades | 1,187 | 1,287 (1,242 L / 45 S) | 1,285 |
| open at end | — | $42.5M ($13.2M unrealized) | — |

## The cap works (P0b acceptance)

- Gate fired: **3,427 `Long_exposure_cap` skip events** over 26y
  (audit-visible via the new skip reason).
- Entry-time invariant verified by reconstruction (running
  committed-at-entry long notional vs equity-curve NAV): entry-day ratio
  ≤ ~1.05 everywhere modulo trading-day date alignment, except two 2026-06
  AXTI fast-mark weeks (1.11/1.38 — intra-week NAV moves between the Friday
  walk and my daily-curve lookup, not gate failures). Post-entry drift > 1.0
  during drawdowns is expected mechanics: the cap gates NEW entries only and
  never force-trims (#1553 exit-safety).
- Validator: V1-V5, V8, V10 PASS; audit join 1286/1287.

## Decomposition (A/B run, same day) — path-sizing lottery, not short alpha

Isolation leg: long-only + cap 1.0 (no shorts), same everything else
(`scenarios-2026-07-14-191605/top3000-2000-2026-longonly-capped`):

| leg | MTM | realized | Sharpe | MaxDD |
|---|---:|---:|---:|---:|
| Run D (long-only, no cap) | +7,914% | $70.9M | 0.83 | 32.3% |
| **D + cap 1.0 (throttle only)** | **+8,505%** | **$76.2M** | **0.843** | **32.2%** |
| E-capped (D + cap + shorts) | +13,730% | $126.0M | 0.893 | 31.6% |

1. **Throttle effect (cap on long-only): small positive** — +591pp MTM /
   +$5.3M realized / Sharpe +0.013 / DD −0.1. Real but modest; single-path.
   The "cap = procyclical knife-catch suppressor" idea remains a candidate
   surface (cap ∈ {0.8, 0.9, 1.0, off} via experiment-gap-closing) but the
   26y single-path delta does NOT justify a claim.
2. **The big delta (+5,225pp MTM) is a SIZING LOTTERY, not short alpha.**
   Event-level: BOTH legs enter AXTI on the same date (2025-06-28), but the
   long-short leg's ticket is ~1.7× bigger ($112.7M vs $67.3M banked). Same
   for every top winner (SKYW 7.5 vs 4.6, DDD 7.3 vs 4.7). Root: the short
   book competes for cash from the FIRST Friday (trade #1 ABNK_old 2000-04-01
   sizes 10,163 vs 10,738 shares; 27 pre-2003 symbol-date divergences) →
   26 years of compounding path divergence → same monsters, bigger tickets.
   Shorts' direct PnL is $0.4M/45 trades. This is the fat-tail law again:
   single-path deltas are dominated by monster ticket size
   ([[project_edge_is_the_fat_tail]]); it is NOT evidence for the short side.

## Status + follow-ups

- **Honest long-short conclusion: consistent with the P0b expectation once
  path-normalized** — with the working cap, long-short ≈ long-only + noise;
  shorts add ~nothing directly (3rd confirmation on this basis). No arming
  case for `enable_short_side` from this run.
- Run D remains the record convention. E-capped numbers quotable only with
  the sizing-lottery caveat attached.
- **Throttle verdict (2026-07-14 discussion): NO surface, do not dispatch.**
  The cap stays a long-short ACCOUNTING convention (armed at 1.0 in
  long-short runs only), NOT a return lever. Faithfulness (W2): its binding
  trigger is the portfolio's own P&L (book under water), i.e.
  equity-curve-conditioned entry suppression — Weinstein modulates exposure
  off the TAPE (stage / macro climate), never off own P&L; the tape-triggered
  version of this idea IS the existing macro gate. Same lever class as the
  rejected macro-bearish-trim / regime-gating. The +591pp is single-path and
  small. If a future session considers it anyway, it must clear
  weinstein-faithful-core W2 first.
- Remaining follow-up: cap-skip date clustering vs drawdown windows (sexp
  parse) for the mechanism picture — descriptive only.
- Artifacts: validator + audit reports in container `/tmp/rune_analysis/`
  (`validator_ecap.md`, `audit_ecap.md`); A/B run dir
  `scenarios-2026-07-14-191605/`.
