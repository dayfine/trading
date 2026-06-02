---
name: project_deep_history_infra
description: "Deep-history (1999-2026) reproducible-rebuild infra + multi-regime battery seeds: build_deep_universe.sh #1388, PIT snapshots 2000/2005/2010/2015/2020, population-search direction"
metadata:
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

The deep-history capability is now reproducible infra, not load-bearing
uncommitted worktree state (2026-05-31 session).

**`dev/scripts/build_deep_universe.sh` (#1388)** — one-command rebuild of the
2000-2026 deep dataset from the committed point-in-time 2000 snapshot. 5 phases:
availability probe (survivors + delistings — the survivorship guard) → symbol
list from snapshot → parallel EODHD fetch into the CSV store
(`<f>/<l>/<SYM>/data.csv`, dot→dash e.g. BRK.B→B/B/BRK-B) → extend GSPC.INDX
golden to 1999 → validate (coverage + re-confirm delistings at real death
dates). Bars + extended golden stay **uncommitted** (rebuildable). Token: host
`EODHD_API_KEY` or the gitignored secrets file. `--probe-only` runs the audit
standalone. Validated: LEH→2008-09-17, BS→2004-01-05, YHOO→2017-06-16. Pairs
with the `fetch-historical-data` skill (the manual workflow it automates).

**First end-to-end use (#1394):** the deep dataset (cost-test worktree's
1999-2026 bars) drove the deep exit-timing surface re-validation (2000-2026, 51
folds incl. dot-com + GFC) — baseline dominated every stage3 exit-timing knob,
*harder* than on the 2010-2026 bull window. Proves the deep pipeline produces a
trustworthy multi-regime result. Watch the [[project_panel_runner_tmp_leak]]
ENOSPC trap on deep runs (purge /tmp snapshots first).

**PIT snapshots (#1386 + #1390):** `universes/sp500-historical/sp500-{2000,2005,
2010,2015,2020}-01-01.sexp` — the 5-point regime-battery seed set from
`build_universe.exe -as-of` (single-dash flags!; Wikipedia-changes replay,
reliable 1994+). Cardinality ~506-515. Bars not committed — rebuild per snapshot
via `build_deep_universe.sh --snapshot <path>`.

**Population-search direction (#1389, `dev/plans/population-search-2026-05-31.md`):**
the long-term target — maintain N experiment arms in parallel over the discrete
feature-combination space, evaluated against a sampled (universe × period)
**battery**, vs today's single live config. THE load-bearing rule: multi-arm
*amplifies* a weak selection metric (the early-admission deep reversal would
become a whole population of bull-regime artifacts under mean-Sharpe). Objective
must be **worst-case-regime (max-min), not mean**; deflation must count the
population's *lifetime* trials; goal must be a versioned artifact with a
ledger-rescore tool. Hard rule: never run multi-arm on a single-regime battery —
gated on the deep/multi-regime battery existing first. Related:
[[project_experiment_platform]], [[project_promotion_confirmation_grid]],
[[project_gspc_index_golden_2017_floor]].
