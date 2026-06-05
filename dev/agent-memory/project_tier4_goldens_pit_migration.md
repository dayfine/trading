---
name: project-tier4-goldens-pit-migration
description: The 4 goldens-broad regression cells used a non-reproducible top-N of the live sectors.csv and drifted silently (off the per-PR CI path); migrated 2026-06-05 to frozen PIT composition universes. The composition snapshots are a full per-year PIT-clean series.
metadata: 
  node_type: memory
  type: project
  originSessionId: aa2adf7e-e475-44dd-8bb7-1dc413997573
---

2026-06-05. Surfaced while reusing the covid golden's config for a dial eval: a
flag-off reproduction of `covid-recovery-2020-2024` read **139.9% / 52.9% MaxDD**
vs the pinned **294.5% / 38.6%** (2026-05-11). Nothing flagged it — it's a
`perf-tier: 4` on-demand cell, off the per-PR path.

**Root cause = non-reproducible universe, NOT a strategy regression.** The 4
`goldens-broad/` cells (covid / six-year / decade / bull-crash) used
`universe_path=universes/broad.sexp` (the `Full_sector_map` sentinel) +
`((universe_cap (1000)))` = "load the live `data/sectors.csv` (now 10,513 rows,
growing) and take the **first-1000 sorted**" (`runner.ml:_apply_universe_cap` →
`List.take`). *Which* 1000 shifts whenever sectors.csv changes (e.g. #1194's +40
backfill on 2026-05-18, after the pin). Re-pinning that universe just re-drifts
(it was re-pinned twice already). NB: the bar data did NOT change values — only an
`active_through` column (8th) was added to the CSV schema, which is result-neutral
when `enable_pi_filter=false` (the default).

**We have a full PIT-clean composition universe series** under
`trading/test_data/goldens-custom-universe/composition/`: `top-{500,1000,3000}-{1998..2025}.sexp`
— one frozen list **per year × per breadth**. PIT-clean / survivorship-correct
(verified: `top-3000-2019` contains SIVB/FRC/BBBY which failed *after* 2019;
`top-3000-1998` has LEH/AIG). The *top-500* subset is a mega-cap SIZE selection
(outperforms) — use ≥1000 for representative breadth; that size bias is NOT a
survivorship bias. The `universe_snapshot` consumer bridges these into the runner;
`golden-runs-custom-universe` CI already runs a composition cell.

**Fix shipped (#1448 plan, #1449 migration, both merged):** repointed the 4 cells
to `top-1000-<window-start-year>.sexp`, dropped `universe_cap`, re-pinned ±20% from
fresh local runs on current main (N=1000 fits the 7.75 GB ceiling). New PIT centers:
bull-crash→61.6%/14.2%DD, six-year→88.6%/57.9%, covid→41.3%/36.1%, decade→131.6%/26.7%.
Lower than the top-N pins because that universe was a drifting artifact. The tier-4
gate resolves `universe_path` against `test_data/backtest_scenarios`, so
`../goldens-custom-universe/composition/...` resolves (the bare `--goldens-broad`
flag uses a `data/`-based fixtures-root and does NOT — those cells run via the gate).
Plan + #5 reconcile: `dev/plans/goldens-broad-pit-migration-2026-06-05.md`,
`dev/status/backtest-infra.md` follow-up #5. Related: [[project_composition_golden_survivor_bias]].
