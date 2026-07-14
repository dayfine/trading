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

## Reading — and why E-capped ≠ "D + small hedge term"

The P0b expectation was E-capped ≈ D + ~0 (shorts made $0). Shorts indeed
made ≈$0 again ($0.4M / 45 trades). But E-capped realized nearly 2× D. NOT
leverage (invariant above; short proceeds are trivial). Three candidate
drivers, undecomposed:

1. **The cap doubles as a drawdown entry throttle.** It binds when marked NAV
   sits BELOW entry-denominated committed notional — i.e. when holdings are
   under water. In those windows it suppresses new entries that cash alone
   would have funded (3,427 skips). That is procyclical knife-catch
   suppression — a mechanism D does not have. If the delta is real, most of
   it likely lives here, NOT in the short book.
2. **Short-enabled path effects** — 45 shorts + Stage-4 candidacy changes the
   Friday competition and cash paths.
3. **Single-path compounding luck** — one path, fat-tail-dominated basis;
   per the standing LAW (horizon-sweep / rolling-start before tail-dependent
   verdicts) this number is NOT a verdict.

## Status + follow-ups

- Long-short numbers are now QUOTABLE AS PRELIMINARY (the P0b realism
  precondition is met) but E-capped is NOT the record convention; Run D
  remains the record basis pending decomposition.
- Follow-ups: (a) cluster the 3,427 cap-skips by date vs drawdown windows
  (sexp parse) to pin driver #1; (b) an A/B: long-only + cap 1.0 (no shorts)
  isolates the throttle from the short-side path effects — cheap, one run;
  (c) if the throttle is the driver, it is a NEW lever class
  (entry-suppression-in-drawdown, tail-preserving, faithful) — route through
  experiment-gap-closing as a surface (cap ∈ {0.8, 0.9, 1.0, off}) before
  any claim.
- Artifacts: validator + audit reports in container `/tmp/rune_analysis/`
  (`validator_ecap.md`, `audit_ecap.md`).
