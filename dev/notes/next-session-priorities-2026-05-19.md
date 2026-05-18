# Next-session priorities (2026-05-19) — written end-of-session 2026-05-18

15-PR autonomous session shipped today (10 substantive + 2 author-existing
merged + 3 plan/QC iterations). The delisted-aware universe agenda is
**COMPLETE END-TO-END**: P1 → P2 → P3 → P4 → P5 → P6 all shipped.
Bayesian production sweep design is shipped (#1192) and **runnable**.

This doc supersedes `dev/notes/next-session-priorities-2026-05-20.md`
(written mid-session before P4/P5/P6 landed; its P0 sequence is now
all-done).

## TL;DR

```
The headline trading-system work this week is the BAYESIAN PRODUCTION
SWEEP. It runs in ~24-48 hr wall and doesn't depend on any further
infrastructure. Phase A prep (~2 hr) is the next session's
immediate work; Phase B is operator-driven background dispatch.
```

## P0 — Bayesian production sweep (Phase A + dispatch Phase B)

Per `dev/plans/bayesian-production-sweep-2026-05-18.md` (#1192, merged).

### Phase A — ~2 hr, this is the manual work

```sh
# Step 0: establish Cell-E baseline numbers on the 5-fold walk-forward
#   split (§3 of #1192). Run baseline through the walk-forward CV harness
#   (#1116). Captures: per-fold Sharpe, MaxDD, N_trades, composite. These
#   are the values §6 promote-gate compares against.

# Step 1: author bayesian_runner.exe spec at
#   dev/experiments/bayesian-production-sweep-2026-05-18/spec.sexp
#   Use the PascalCase metric-type constructors (SharpeRatio etc.) per §4.
#   7 params (sizing×2 + stops×2 + cascade×3). Bounds in §2.

# Step 2: smoke run with total_budget=5 initial_random=5
#   docker exec trading-1-dev bash -c '
#     cd /workspaces/trading-1/trading && eval $(opam env) &&
#     dune exec --no-build trading/backtest/tuner/bin/bayesian_runner.exe -- \
#       --spec dev/experiments/bayesian-production-sweep-2026-05-18/spec.sexp \
#       --out-dir dev/experiments/bayesian-production-sweep-2026-05-18/output-smoke'
#   Verify the 3 artefacts: bo_log.csv + best.sexp + convergence.md.
#   CONFIRM PARAMS ACTUALLY VARY across the 5 evals (no silent-no-op overlay
#   per the #1051 → #1061 hazard).
```

### Phase B — ~24-48 hr wall, background dispatch

Once Phase A spec is verified, dispatch full sweep with `total_budget=120`:

```sh
docker exec -d trading-1-dev bash -c '
  cd /workspaces/trading-1/trading && eval $(opam env) > /dev/null &&
  dune exec --no-build trading/backtest/tuner/bin/bayesian_runner.exe -- \
    --spec dev/experiments/bayesian-production-sweep-2026-05-18/spec.sexp \
    --out-dir dev/experiments/bayesian-production-sweep-2026-05-18/output \
    > dev/logs/bayesian-prod-sweep.log 2>&1'
```

Monitor via `bo_log.csv` row count + `best.sexp` for convergence.

### Phase C — promote decision

Apply the 5 gates in #1192 §6 to the median-fold metrics. If winner
clears all 5: create the private repo per `dev/plans/private-tuned-configs-repo-2026-05-18.md`
§4 and commit the winner as the first blessed config. If gates fail:
write up why + revised hypothesis for v2.

## P1 — Optional cleanup items

### P5 sectors backfill — extension to ~80 entries (deferred)

`#1194` shipped 40 hand-curated delistings. ~100 empty-sector entries
remain in `top-500-2019` — foreign ADRs (KBC Belgium, SBER Russia, ACL
Switzerland), EODHD ticker-reuse markers (FB_old, CTRA_old, POW_old,
COMP_old), and less-famous delistings. Closing the full gap needs:

- **Wikipedia scrape** (~1 hr engineering + may run into rate limits)
- **Sharadar via Nasdaq Data Link** ($99/mo, rejected per broader-first pivot)
- **Manual extension** (~30 min curation for ~40 more entries)

Not on critical path. Defer unless P6/P7 work resumes.

### P7 — N≥30 random-universe sweep (deferred)

Per #1191, both #1180 and #1191 N=5 random sweeps had σ ≈ 100pp →
stderr ≈ 45pp. Headline "8σ outlier" claim was overstated. A
properly-sized N=30 sweep would give a stable distribution estimate.

Wall: 30 × 3 min × 5 folds = ~7.5 hr serial, ~2 hr at parallel=4.

Defer — sample-size correction is a methodological footnote, not on
the critical path. The Bayesian sweep (P0 above) is the higher-value
use of compute time.

### Refactor pre-existing match-statement tests in `test_http_client.ml`

PR #1184 sidestepped this by putting the new delisted-endpoint test
in a standalone file. The original `test_http_client.ml` still has
~12 tests using `match result with | Ok ... | Error -> assert_failure`.
qc-structural P6 will block any future PR that touches this file until
the patterns are refactored. Effort: ~60-90 min mechanical.

## P2 — Strategic open items (no immediate action)

### M6.6 live cycle

Per the track-pacer report (#1163): "the system goal per §3 cannot
ship without it, but it is consistently deferred." Worth a quarterly
check on whether to scope a feature track.

### M7.1 / M7.2 ML + synthetic stress

Deferred until the Bayesian Phase 3 + walk-forward CV stack settles
and Phase 3 outputs converge.

### Shares-outstanding fundamentals source

EODHD Fundamentals 403 on our tier; documented in
`dev/notes/eodhd-delisted-roster-unlock-2026-05-18.md` as
SUPERSEDED — the delisted-roster discovery obsoletes the Sharadar /
AlphaVantage decision for the broader-first agenda. Q2-A bulk run
is no longer blocked on a vendor decision.

### Orchestrator-automation Phase 2

Last PR #1134 was 2026-05-04; the track has been IN_PROGRESS with no
feature dispatch since. Either spin up Phase 2 (background execution
+ harvest) or mark the track MERGED on Phase 1's stable operating
state.

### Recurring `[info]` items

`qc-structural recurring H3 false-positive on advisory linter text` +
`qc-structural review-file persistence gap` carried 7+ reconciles
without resolution. Recommended ESCALATE_TO_MAINTAINER per the
track-pacer report.

## Open follow-ups (carry from this session)

- **Wikipedia historical SP500 changes** as a P5 extension source — has
  delisting events + dates, but no GICS sector directly. Would need
  cross-referencing against the wiki SP500 components table. Not yet
  scoped.
- **Bayesian sweep --resume flag** — `bayesian_runner_runner.ml` writes
  bo_log.csv append-only but doesn't have a resume entry point. Per
  #1192 §9, this is "~1 LOC change" — but only worth doing if the
  24-48 hr run gets interrupted.
- **`dev/scripts/run_delisted_pipeline.sh`** ran twice this session
  with composition-runner --out-dir bug found + fixed (#1190). The
  fix landed; future runs should work cleanly. The script also needs
  the `--bars-root` / `--inventory` / `--sectors-csv` / `--symbol-types`
  flags (added in #1190 as well). Confirmed working in P5 v3 run.

## Session-end state snapshot

- **Data files**: `data/inventory.sexp` (56,652 entries), `data/symbol_types.sexp`
  (56,652 entries with -include-delisted), `data/sectors.csv` (10,513 rows
  incl. 40 supplemental delistings), `data/delisted_symbols.sexp` (57,592
  entries from #1184). All gitignored except sectors.csv + symbol_types.sexp
  + delisted_symbols.sexp.
- **Composition goldens**: 84 files at `trading/test_data/goldens-custom-universe/composition/`
  rebuilt with delisted-aware inventory pool + supplemental sectors.
- **Disk**: ~17-20 GB free on host. Docker container /tmp cleaned of stale
  `panel_runner_csv_snapshot_*` dirs (~61 GB reclaimed).
- **Bars cache**: ~17.5 GB total in `data/` (live + delisted Common Stock
  NASDAQ/NYSE).

## Companion docs to consult

- `memory/project_eodhd_delisted_unlock.md` — full agenda status
- `memory/project_composition_golden_survivor_bias.md` — #1180 finding
- `dev/notes/delisted-aware-p4-result-2026-05-18.md` — P4 narrative
- `dev/notes/random-universe-sweep-v2-p6-2026-05-18.md` — P6 caveat
- `dev/notes/delisted-sectors-backfill-p5-2026-05-18.md` — P5 hand-curation
- `dev/plans/bayesian-production-sweep-2026-05-18.md` — **THE NEXT THING**
- `dev/plans/private-tuned-configs-repo-2026-05-18.md` — promote target

## What was DONE this session (the 15-PR sprint)

| PR    | Track           | Summary |
|-------|-----------------|---------|
| #1179 | feat-scenarios  | Weinstein on top-500-2019 composition golden (P0b) |
| #1180 | docs            | random-universe sweep — selection-bias-driven (#1179 follow-up) |
| #1181 | docs            | composition-golden bar-coverage audit — P1 closed |
| #1182 | ci              | wire weinstein-2019-top-500 into postsubmit (F4) |
| #1183 | docs            | EODHD delisted-roster unlocks PIT-universe agenda |
| #1184 | feat-eodhd      | delisted-symbols endpoint + cached roster (P1) |
| #1185 | feat-eodhd      | bulk-fetch delisted-symbol bars (P2-code) |
| #1186 | feat-eodhd      | asset_type_enrichment -include-delisted (P3) |
| #1187 | feat-eodhd      | parallel fetcher + orchestrator + handoff notes |
| #1190 | feat-eodhd      | P4 result + composition rebuild + orchestrator fix |
| #1191 | docs            | random-universe sweep v2 reveals N=5 sampling noise |
| #1163 | ops             | weekly track pacer (existing PR, merged for user) |
| #1189 | chore           | weekly opam deps update (existing PR, merged for user) |
| #1192 | plan            | Bayesian production sweep design + run plan |
| #1194 | feat-data       | P5 sectors backfill (40 famous delistings) |
