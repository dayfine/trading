# Queued local step — composition-policy universe artifact (P1'.2)

**Run AFTER the matrix re-run completes** (`/tmp/warmup-rerun/` — watcher
`btuf70jr5`). This is the keystone that unblocks the ~5 data-gated tracks
(backtest-infra P2 matrix, backtest-perf matrix, stage-accuracy broad WF-CV,
experiment-platform continuation top-3000, cash-floor NS4). **Local-only** — it
needs the maintainer bar store (`/workspaces/trading-1/data`, 6.6G); GHA has
neither the bars nor the volumes, so this cannot be a remote dispatch.

## Why it's gated

The 84 checked-in composition goldens (28yr × {500,1000,3000}, 1998-2025) are
**volume-less** (`avg_dollar_volume` absent → decodes `None`). Verified:
`grep -c avg_dollar_volume top-3000-2011.sexp` = 0. So `apply_composition_policy`'s
ADR $-volume liquidity filter is a no-op on them. Must regenerate with volumes
first (builder now populates `avg_dollar_volume`, #1542 / `feat/composition-dollar-volume`).

## Prereqs (verified present 2026-06-13)

- `/workspaces/trading-1/data/{symbol_types.sexp (3.8M), sectors.csv (184K), inventory.sexp (5.2M)}` ✓
- bar store `/workspaces/trading-1/data` (6.6G) ✓
- bins: `build_composition_universes_runner.exe`, `apply_composition_policy.exe` ✓

## Step 1 — regenerate goldens WITH volumes (overwrites the 84 goldens)

```bash
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && \
  dune exec analysis/data/universe/bin/build_composition_universes_runner.exe -- \
    --bars-root /workspaces/trading-1/data \
    --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
    --sectors-csv /workspaces/trading-1/data/sectors.csv \
    --inventory /workspaces/trading-1/data/inventory.sexp \
    --out-dir trading/test_data/goldens-custom-universe/composition/ \
    --start-year 1998 --end-year 2026 --top-n 500,1000,3000'
```

⚠ **Consequential — golden re-pin.** This rewrites all 84 goldens (4-field →
5-field +`avg_dollar_volume`). Backward-compatible per the plan (`[@sexp.option]`,
default `adr_min_dollar_volume=None` ⇒ behaviour bit-identical), so it's
behaviour-neutral, but it's a large diff → its own data PR with maintainer
sign-off, NOT bundled into the matrix writeup. Verify a sample golden now carries
volumes (`grep -c avg_dollar_volume top-3000-2011.sexp` > 0) and that
`dune runtest analysis/data/universe/` stays green (the round-trip decode test).

## Step 2 — emit the policy-filtered universe artifact(s)

Per consumer universe (matrix wants top-3000-2011; generalize to the years/breadths
each data-gated track needs). Exact flags verified against
`apply_composition_policy.ml`:

```bash
docker exec trading-1-dev bash -c 'cd /workspaces/trading-1/trading && eval $(opam env) && \
  dune exec analysis/data/universe/bin/apply_composition_policy.exe -- \
    --snapshot trading/test_data/goldens-custom-universe/composition/top-3000-2011.sexp \
    --symbol-types /workspaces/trading-1/data/symbol_types.sexp \
    --out-snapshot /tmp/policy/top-3000-2011-policy.sexp \
    --out-report /tmp/policy/top-3000-2011-drop-report.txt \
    --exclude-reits --exclude-preferred --adr-min-dollar-volume <THRESHOLD>'
```

Set `<THRESHOLD>` (the ADR $-volume floor) from the weekly >1%-ADV gate spec / the
P1 brief — do NOT invent it. Inspect the drop report to sanity-check what the
filters remove before trusting the artifact.

## Step 3 — hand off to the data-gated cluster

The policy snapshot(s) feed the definitive matrix re-run + the broad-universe
WF-CV tracks. These are also local-bar-store jobs → run them serially after this,
not concurrently (sweep-hygiene: one heavy container job at a time).

## Sequencing reminder

matrix (running) → Step 1 regen → Step 2 policy emit → data-gated re-runs.
Each is a local container job; do not overlap them.
