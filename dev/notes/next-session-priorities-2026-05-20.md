# Next-session priorities (2026-05-20) — autonomous session 2026-05-18

Written end-of-session 2026-05-18 after an 8-PR delisted-universe sprint.

## TL;DR

The delisted-aware universe agenda's CODE is shipped end-to-end:
P1 (#1184 endpoint) → P2 (#1185 bulk-fetch binary) → P3 (#1186 enrichment
flag). What's left is **operational** + **P4 validation**.

If the background `fetch_delisted_bars.exe` run started 2026-05-18 05:30 UTC
has finished by next session (~10 hr wall expected), the entire remaining
work fits in ~30-60 min.

## P0 — finish the delisted-aware composition goldens (if P2-run done)

The post-P2 sequence is **3 commands + 1 scenario rerun**. All shipped
binaries; no new code needed.

```sh
# 0. Verify P2-run completed:
tail -5 /workspaces/trading-1/dev/logs/fetch-delisted-bars.log
# Expect: "Delisted-bar fetch summary: ... Targets 15766 ... Fetched OK ~14000-15000".
# If it's still running, monitor cycles_done and wait.

# 1. Refresh inventory.sexp with the new delisted-symbol metadata:
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build analysis/scripts/build_inventory/build_inventory.exe -- \
    -data-dir /workspaces/trading-1/data
'
# Wall: ~10 s (just scans data/<X>/<Y>/<SYM>/data.metadata.sexp files).

# 2. Re-enrich symbol_types.sexp with both live + delisted endpoints (P3):
docker exec -e EODHD_API_KEY="$EODHD_API_KEY" trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  echo "$EODHD_API_KEY" > /tmp/eodhd-secrets &&
  dune exec --no-build analysis/scripts/asset_type_enrichment/bin/main.exe -- \
    -inventory-path /workspaces/trading-1/data/inventory.sexp \
    -output-path /workspaces/trading-1/data/symbol_types.sexp \
    -secrets-path /tmp/eodhd-secrets \
    -include-delisted
'
# Wall: ~30 s (2 HTTP calls + concat + join + write).

# 3. Rebuild composition goldens against the unified pool:
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build analysis/data/universe/bin/build_composition_universes_runner.exe
'
# Wall: ~5-10 min (75 sexp files: top-{500,1000,3000}-{1998..2026}).
# Overwrites trading/test_data/goldens-custom-universe/composition/*.sexp.
# Diff-check expected — old goldens drop survivor-bias-only names; new
# goldens include delisted names that were active at each snapshot date.

# 4. (Optional sanity) Spot-check that delisted names made it in:
grep -c "TWTR\b\|FIT\b\|AABA\b" \
  trading/test_data/goldens-custom-universe/composition/top-500-2019.sexp
# Expect non-zero (Twitter delisted 2022, Fitbit 2021, Altaba ex-Yahoo 2019 —
# all active at 2019-05-31).
```

## P0b — re-run the random-universe sweep against delisted-aware goldens (P4)

After step 3 above, the `top-3000-2019.sexp` pool now includes ~3000
delisted-aware names. Re-sample 5 subsets + re-run the scenarios from
`dev/experiments/random-universe-sweep-2026-05-18/scenarios/` (committed in
#1180 as universes/random-2019/sample-{1..5}.sexp).

But the random-2019/sample-*.sexp universes were built from the OLD
top-3000-2019.sexp (live-only). To get a fair P4 comparison, either:

(a) Re-sample 5 new subsets from the new delisted-aware top-3000-2019.sexp
    and run those. Best comparison; small re-derivation work
    (~20 LOC awk in `dev/notes/random-universe-sweep-2026-05-18.md`).

(b) Just re-run the existing 5 sample scenarios. Their `(Pinned ...)` lists
    are the OLD names (survivors-only); the SCENARIOS show what the
    Cell-E strategy does on those exact names with current bar data.
    NOT a P4 test of the universe-construction fix; just a regression.

(c) Best: do BOTH. (a) confirms the central claim ("delisted-aware
    universes narrow the σ gap"); (b) confirms strategy stability.

Re-run command per scenario:

```sh
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /workspaces/trading-1/dev/experiments/random-universe-sweep-2026-05-18/scenarios \
    --parallel 3 \
    --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios \
    --no-emit-all-eligible
'
# Wall: ~10 min for 5 scenarios at parallel 3 (no all_eligible).
```

Plus the comparison cell:

```sh
docker exec trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) &&
  dune exec --no-build trading/backtest/scenarios/scenario_runner.exe -- \
    --dir /workspaces/trading-1/trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios \
    --parallel 1 \
    --fixtures-root /workspaces/trading-1/trading/test_data/backtest_scenarios
'
# Wall: ~5 min for the weinstein-2019-top-500-composition cell.
# Compare metrics to #1179's pinned baseline (174.69% / Sharpe 0.62 / MaxDD 59.06).
# Expected: return drops toward market-neutral; the σ gap to random samples
# narrows substantially.
```

## P0c — write up findings

After P4 results land:

- `dev/notes/random-universe-sweep-followup-2026-05-XX.md` — the
  delisted-aware re-run. Same comparison table shape as
  `random-universe-sweep-2026-05-18.md`. Pin: before/after random-sample
  mean; before/after top-500-2019 baseline; observed σ gap reduction.
- Update `trading/test_data/backtest_scenarios/goldens-custom-universe-scenarios/weinstein-2019-top-500.sexp`
  header: revise the "BRIDGE SMOKE TEST" warning if the new run shows the
  cell is now closer to a fair alpha benchmark.
- `memory/project_eodhd_delisted_unlock.md` — mark P4 done, capture
  whether the survivor-bias claim was fully borne out.

## P1 — Bayesian production sweep (was IWV-gated)

Per `dev/notes/next-session-priorities-2026-05-19.md` §"Bayesian production
sweep": this was gated on IWV / paid-scraper / Sharadar / EODHD tier. The
delisted-roster discovery (#1183/#1184) ungates it — see
`memory/project_eodhd_delisted_unlock.md`.

Now that delisted-aware composition goldens exist (after P0), the Bayesian
sweep can target a TRUE point-in-time universe pool. Concrete next step:

```
dev/plans/bayesian-phase3-production-sweep-2026-05-XX.md
```

Should specify: which parameters, which years, walk-forward CV folds,
quality metric (Sharpe? Calmar? Custom?). Probably ~4-8 hr of orchestrator
wall time on N=24 parallel candidates.

## P2 — Optional / smaller items

### Refactor pre-existing match-statement tests in `test_http_client.ml`

PR #1184 sidestepped this by putting the new test in a standalone file.
The original file still has ~12 tests using `match result with | Ok ... | Error -> assert_failure`.
qc-structural P6 will block any future PR that touches this file until the
patterns are refactored.

Effort: ~60-90 min (mechanical conversion to `assert_that (is_ok_and_holds ...)`
+ matcher composition).

### Add CI for the new fetch_delisted_bars / fetch_delisted_symbols binaries

Currently the only smoke test is the local end-to-end run. Could add a
tiny integration test that mocks the HTTP fetch and verifies the on-disk
sexp shape.

Effort: ~30 min per binary. Low priority since the binaries are
human-operated, not invoked by automated pipelines.

### Stooq drift check / IWV scrape

Both still blocked. Stooq drift check (existing branch) might be cheap to
revisit if the user wants alt-vendor cross-validation. IWV is permanently
Akamai-blocked (confirmed 2026-05-18).

## Open follow-ups (carry from prior sessions)

- `dev/status/cost-model.md` 4 deferred items — still deferred
- Tunable-parameter inventory + private tuned-configs repo (`dev/notes/tunable-parameters-inventory-2026-05-18.md`) — apply once a config is worth blessing
- Decomposition + Composition unification — close as not-worth (deferred per priorities-2026-05-19)
- Update `dev/notes/vendor-comparison-historical-universe-2026-05-16.md` to demote IWV → fallback once delisted-aware goldens land

## Recommended sequencing for 2026-05-20

1. **Step 0**: check P2-run log; if not complete, monitor + delay.
2. **P0 sequence** (steps 1-3 above, ~10-15 min wall).
3. **P0b sub-step (a)** — re-sample 5 universes from new top-3000-2019 + run.
4. **P0c writeup**.
5. If time permits, **P1 Bayesian sweep prep**.
