# Universe depth and the structural stop at live size (pre-registration)

User, 2026-11-23, after the NAV-scale read (#3704): "we can try expand the universe (the limit is fidelity?), with no
structural floor etc". The NAV-scale read found that at a $100k account the liquidity floor and the participation cap
do not keep cheap names out: the universe (top-3000) and the `No_structural_stop` gate do. This run tests those two.

This file is committed before any cell runs. Nothing below changes after the first result.

## Data

- Store: `bars/data-20261123` in the private R2 bucket (16,203 symbols). Built 11-23 from the 11-01 store plus 2,683
  NYSE/NASDAQ/AMEX names and 1,649 names now on OTC/PINK, fetched so every name with joint rank ≤ 4000 (and ≥ $1M ADV
  for OTC/PINK-now names) in any year 1998–2026 is present. The OTC/PINK-now set fixes a survivorship hole: EODHD
  labels each name with today's exchange, so failed ex-NASDAQ names were missing.
- Lists: `pit-v13/composition/top-{3000,4000}-YYYY.sexp`, 1998–2026, ranked by true dollar volume over everything
  equity-like in the store, with no exchange filter; twin-deduped in the warehouse build like pit-v12.
- Warehouse: built from those lists in a cloud session (#3706), uploaded to R2 as `v13pit-<n>`; corporate actions `corpact-2026-11-23`.
- Known residue: a few foreign or vendor-splice names with absurd ADV (HSBA, SBER, VPI, LDG) sit at the top of both
  v12 and v13; they hit every arm alike.

## Arms (4 configs × K = 5 seeds = 20 cells)

All arms: the record spec `dev/experiments/record-kseed-2026-10-27/specs/rk-k{0..4}.sexp` (26 years,
2000-01-01 → 2026-06-26, `tiebreak_seed` k), `initial_cash` 100,000, plus the live-size lines of
`dev/weekly-picks/live-size-overrides.sexp` APPENDED after the record overrides (later wins). That is the P-100k arm of
the NAV-scale run, on the new universe. One build.

| arm | universe schedule | `require_structural_stop` |
|---|---|---|
| S3 | pit-v13 top-3000 | true (record) |
| U4 | pit-v13 top-4000 | true |
| N3 | pit-v13 top-3000 | false |
| UN4 | pit-v13 top-4000 | false |

`universe_size` is set to the list size (3000 or 4000).

## Tripwire and validity

- **Build tripwire:** NAV-scale P-100k k0 (v12 warehouse `v12wk-9236`) is re-run at the run build and must reproduce
  its `trades.csv` md5 (`results/k0/ns-P-100k-k0-s0-trades.md5.txt`). If it does not, stop.
- **V6** on every paired read (U4 vs S3, N3 vs S3, UN4 vs U4) at the same seed. A V6-failing seed is dropped; < 4
  valid seeds = INVALID.
- **Liveness:**
  - U4 is live if, on ≥ 3 of 5 seeds, at least 10 of its round trips are in names that are in top-4000 but not
    top-3000 for that decision year.
  - N3 is live if, on ≥ 3 of 5 seeds, at least 20 % of its entries carry a `Buffer_fallback` initial stop.
  - A dead arm gets no read.

## What is measured (per arm, median over seeds; whole run and 2000–08 / 2009–16 / 2017–26)

1. ln(final / initial).
2. Max drawdown and Ulcer index.
3. Share of entries at or below $14 raw, and funded doublers (≥ +100 %) among them; all doublers.
4. Round trips by universe band (ranks 1–3000 vs 3001–4000 of that year's list) and their summed NAV%.
5. Entries by initial-stop kind (`Support_floor` vs `Buffer_fallback`) and the win rate, median return and doublers of each.
6. `No_structural_stop` skips per year (S3, U4).
7. Descriptive, no decision: S3 against NAV-scale P-100k (same config on v12), i.e. what the v13 universe rebuild
   (survivorship fill + true-dollar ranking) moves on its own.

## Decision rule (fixed now)

Paired Δ = ln(arm_final / control_final) at the same seed.

| verdict | condition |
|---|---|
| PASS | median Δ ≥ +0.20, ≥ 4/5 positive, median ΔDD ≤ +3 pp |
| PAYS-WITH-RISK | median Δ ≥ +0.20, ≥ 4/5 positive, median ΔDD > +3 pp |
| HARM | median Δ ≤ −0.20, ≥ 4/5 negative |
| INCONCLUSIVE | anything else |
| DEAD / INVALID | liveness fails / < 4 valid seeds |

- **U4 vs S3 (universe depth).** PASS or PAYS-WITH-RISK: depth adds return at live size, and the next step is a
  confirmation cell (different period or vintage) before the live picks move to top-4000. INCONCLUSIVE: depth adds
  nothing measurable; picks stay on top-3000. HARM: depth costs; do not widen.
- **N3 vs S3 (structural stop).** Prediction stated now: HARM (the 09-28/30 hybrid lost heavily on 4 % fallback
  stops). Whatever the result, `require_structural_stop false` is **not promotable**: it breaks Weinstein spine item 5
  (initial stop below the base). A PASS would only open a book-backed question: which stop placement for names with no
  qualifying correction keeps the spine.
- **UN4 vs U4** (secondary, same thresholds): whether the stop effect differs in the deeper universe.

A Δ inside the 0.45-log single-cell floor that is not traced to the lever's own trades is reported as no effect.

## Known confounds, stated in advance

- **The v13 lists differ from v12** in two ways at once (survivorship fill, true-dollar ranking). All four arms share
  them, so they cancel in every paired Δ; measure 7 shows their combined size.
- **Live-size floors** ($100k entry, $50k hold) bind more in ranks 3001–4000 (ADV at rank 4000 is $0.14–2.8M by year).
  That is the live configuration and is intended.
- **One market history**; ≥ 4/5 is a consistency check, not a significance test.
- **Data quality:** ranks 3001–4000 sampled at 2.4 % hard-defect rate vs 0.7 % in 1–3000; a big U4 effect must be
  traced to named trades and checked against the bars before it is believed.

## Run plan

Cloud sessions, one per seed (4 cells + the k0 tripwire), on warehouse `v13pit-<n>` with `corpact-2026-11-23`. Price-bearing outputs to
trading-results; mark-free summaries here. Read by `results-analyst`, reviewed by `qc-results`.
