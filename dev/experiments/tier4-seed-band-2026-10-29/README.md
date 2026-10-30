# Tier-4 goldens-broad seed band (2026-10-29)

Follow-up to #3404 / `tier4-seeded-repin-2026-10-29`. That PR pinned the four goldens-broad cells to
±15 % around one seed-0 draw. This run adds tiebreak seeds 1–4 (`((screening_config ((tiebreak_seed k))))`
prepended to the golden's `config_overrides`, otherwise the golden spec on main) so the pins can cover the
seed-to-seed path noise (#3419) instead of one draw.

Run: pinned worktree at `7615dde7d`, `SNAPSHOT_MAX_MMAP_HANDLES=12000`, one cell at a time, `chain.sh` /
`chain.log`. 16 cells, all finished, none crashed. Seed 0 is the new arm in
`../tier4-seeded-repin-2026-10-29/results/` (same build).

## Per-seed values (seed 0, 1, 2, 3, 4)

| cell | metric | k0 | k1 | k2 | k3 | k4 |
|---|---|---:|---:|---:|---:|---:|
| bull-crash-2015-2020 | max_drawdown_pct | 28.6 | 27.9 | 19.0 | 30.3 | 28.5 |
| bull-crash-2015-2020 | total_return_pct | 73.4 | 96.0 | 160.1 | 52.7 | 93.1 |
| bull-crash-2015-2020 | total_trades | 157.0 | 171.0 | 159.0 | 161.0 | 161.0 |
| covid-recovery-2020-2024 | max_drawdown_pct | 31.2 | 76.0 | 31.3 | 74.2 | 77.2 |
| covid-recovery-2020-2024 | total_return_pct | 34.5 | 227.0 | 24.0 | 532.9 | 385.2 |
| covid-recovery-2020-2024 | total_trades | 158.0 | 168.0 | 172.0 | 141.0 | 141.0 |
| decade-2014-2023 | max_drawdown_pct | 60.8 | 77.0 | 76.8 | 59.1 | 76.9 |
| decade-2014-2023 | total_return_pct | 503.9 | 471.5 | 566.8 | 320.4 | 737.1 |
| decade-2014-2023 | total_trades | 281.0 | 292.0 | 278.0 | 279.0 | 275.0 |
| six-year-2018-2023 | max_drawdown_pct | 77.1 | 56.0 | 73.0 | 38.9 | 57.0 |
| six-year-2018-2023 | total_return_pct | 378.5 | 77.9 | 279.9 | 21.6 | 228.5 |
| six-year-2018-2023 | total_trades | 177.0 | 203.0 | 201.0 | 198.0 | 164.0 |

All six pinned metrics per seed: `seed-metrics.txt` (cell, metric, value; rows in seed order 0–4).

## The pin

Each pinned metric = [min over seeds 0–4] × 0.85 .. [max over seeds 0–4] × 1.15; total_return_pct gets at
least 5 pp each side. Seed 0 (the default) sits inside every band by construction.

## Reading

- **The spread is the finding.** Changing only the tiebreak seed moves total return 52→160 % (bull-crash),
  24→533 % (covid-recovery), 22→378 % (six-year) and 320→737 % (decade). On these cells one draw says almost
  nothing about the strategy; the band is a regression tripwire for gross breakage (a crash, zero trades, a
  sign flip, an order-of-magnitude move), not a performance read. Same lesson as the 26y K=5 record band
  (#3467): quote broad cells as a seed band, never one draw.
- **Trade count is the tight metric** (spread ≤ ~25 %), so it is the most sensitive part of these pins.
- **Max drawdown is bimodal on two cells:** covid-recovery 31 % (k0, k2) vs 74–77 % (k1, k3, k4), and
  decade splits the same way (59–61 % vs 77 %); six-year spreads 39–77 %. On covid the high-DD seeds are also the high-return ones. Not
  dissected here; worth a look when these windows next carry a verdict.

## Verifies

Verifies: none.
