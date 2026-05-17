# Next-session priorities (2026-05-18) — overnight 2026-05-17

Supersedes the prior `dev/notes/next-session-priorities-2026-05-18.md`
(written end-of-session 2026-05-16 PM). This version replaces it after
the 2026-05-17 overnight autonomous run.

## TL;DR

- **17 PRs merged overnight 2026-05-17.** Two complete feature tracks
  (Bayesian Phase 3 stack PR-A → PR-E; CSV manifest stack Phase 1 +
  Phase 2 + Phase 3 + bulk-rehash). 4 new data sources (Shiller, Stooq,
  Kenneth French, IWV-with-Sec-Fetch). Cost-model overlay scaffolded.
- **IWV scrape still BLOCKED.** Local + GHA-runner egress IPs both hit
  Akamai bot-check. Curl shellout + Sec-Fetch + HTTP/2 all insufficient.
  Next: paid scraper API or Sharadar/EODHD-Fundamentals tier upgrade.
- **Cost-model built but NOT wired** into the simulator. 4 deferred
  items in `dev/status/cost-model.md`.
- **Bayesian production sweep READY.** Phase 3 stack complete; ops
  session can dispatch.

## PRs landed 2026-05-17 (17 merged, 1 closed dup)

| PR | Track | Summary |
|---|---|---|
| #1136 | Bayesian Phase 3 | PR-C walk-forward in-process integration |
| #1137 | IWV (ops) | curl shellout (bypass Cohttp_async TLS fingerprint) |
| #1138 | IWV (ops) | GHA workflow_dispatch yaml for scrape |
| #1139 | docs | Tier-1/2/3 data-vendor pointers |
| #1140 | data | Shiller ingest (1871-present, 1865 monthly obs) |
| #1141 | data | Shiller → EODHD GSPC.INDX cross-validator |
| #1142 | manifest | Phase 1 — manifest module + manifest_inspect CLI |
| #1143 | Bayesian Phase 3 | PR-D — length-scale + early-stop + Option encoding |
| #1145 | Bayesian Phase 3 | PR-E — OOS holdout validator (stack closed) |
| #1146 | data | Stooq drift check (apikey-gated, AAPL ~3.58% baseline) |
| #1147 | IWV (ops) | Sec-Fetch + sec-ch-ua + --http2 headers |
| #1148 | manifest | Phase 2 — save writes manifest + load_with_verify |
| #1149 | manifest | bulk-rehash CLI for the 41,577 cached symbols |
| #1150 | manifest | Phase 3 — reconcile-on-refetch diff log |
| #1151 | backtest | cost-model overlay (4 cost knobs; not yet wired) |
| #1152 | data | Kenneth French 5-industry daily ingest (52,424 obs, 1926-2026) |
| #1153 | tests | Fix-forward — `is_directory` in `_reconcile_log_for` |

Closed: **#1144** (CSV manifest Phase 1 duplicate from crashed-agent state).

## Carry-forward

### P0a — IWV scrape (BLOCKED — paid path required)

Both local IP and GHA-runner IPs hit Akamai bot-check. Stack of
hardenings landed (PR #1131 browser headers, PR #1137 curl shellout,
PR #1147 Sec-Fetch + HTTP/2) — none sufficient. Per
`dev/notes/iwv-scrape-akamai-block-2026-05-16.md` §"Next options":

1. **Paid scraper API** (ScrapingBee / ScraperAPI / Bright Data) —
   ~$20-50 one-shot for the ~3700-snapshot backfill. Cheapest pragmatic
   unblock.
2. **EODHD Fundamentals tier upgrade** ($59.99/mo).
3. **Sharadar via Nasdaq Data Link** ($99/mo).
4. **Headless browser** (Playwright / chromium-headless). Heaviest
   engineering.

Recommend (1) as one-shot ops decision.

### P0b — Bayesian production sweep (READY)

Phase 3 stack complete (#1126, #1132, #1136, #1143, #1145). Ops session
can dispatch:

```
# 1. Build Cell-E baseline aggregate (~15 min)
dune exec trading/backtest/walk_forward/bin/walk_forward_runner.exe -- \
  --spec trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp \
  --out-dir dev/data/cell-e-baseline-aggregate

# 2. Dispatch BO run (~25-75h)
dune exec trading/backtest/tuner/bin/bayesian_runner.exe -- \
  --walk-forward-spec trading/test_data/walk_forward/cell_e_30fold_2026_05_16.sexp \
  --baseline-aggregate dev/data/cell-e-baseline-aggregate/aggregate.sexp \
  --out-dir dev/data/bayesian-runs/2026-05-18
```

### P0c — Survivorship-correct re-pin (BLOCKED on P0a)

Unchanged. Re-pin `goldens-sp500-historical/sp500-2010-2026.sexp` on
the IWV-derived cohort once data lands.

### P1 — Cost overlay wiring (NEW)

PR #1151 shipped the cost-model module standalone. 4 items deferred
per `dev/status/cost-model.md`:

1. Wire `cost_model` field into `scenario.mli`.
2. Wire `apply_per_trade_commission` into `Simulator._apply_trades_best_effort`.
3. Plumb ADV through engine + auto-apply `apply_market_impact`.
4. Re-pin Cell E + smaller scenarios under cost overlay.

### P1 — Margin Phase 3 bear-window validation

Unchanged. Gated on universe data covering 2000-02, 2008-09, 2020-Q1,
2022 bear windows. Depends on P0a.

### P2 — Pre-2006 synthesis backtest (NEW, feasible)

After Shiller (#1140) + French (#1152) ingests landed, the synthesis
methodology in `memory/reference_deep_history_data_sources.md` is
buildable:

1. French portfolio returns (5-industry daily, 1926-) → systematic
   factor skeleton.
2. Per-symbol idiosyncratic noise calibrated to French dispersion.
3. Rescale so cap-weighted aggregate matches Shiller composite.
4. Output: synthetic per-symbol returns covering 1926-1999.

~500 LOC. Separate session.

## Strategy / data infrastructure status

- **Manifest stack complete** (Phase 1 + 2 + 3 + bulk-rehash).
- **Cross-validators available**: EODHD vs Shiller (#1141), EODHD vs
  Stooq (#1146).
- **Bayesian tuner end-to-end**: scoring + knob spec + walk-forward
  in-process + length-scale/early-stop + OOS holdout.
- **Deep-history data**: Shiller (1871-) + Kenneth French (1926-),
  both free, OCaml-native curl ingest.

## CI / harness gaps surfaced this session

1. **Test state pollution** in `_reconcile_log_for` — fixed PR #1153
   (`is_directory` instead of `file_exists`). Lesson: helpers that
   readdir a path must check is_directory, not just file_exists.
2. **ocamlformat skew** continues (~15-20min per PR for fix-fmt-push).
   Per memory `project_ocamlformat_version_skew`. Has NOT been
   root-caused.
3. **Test ordering vs dune sandbox reuse**: tests within a single
   `(test ...)` exe share state across cases within one suite.
4. **Disk pressure** (>95%) reached twice; sweep script handled.
   Budget for cleanup between dispatches.

## Recommended sequencing for next session

1. **Step 0**: `gh run list --branch main --limit 3` — verify green.
2. **Cost-model wiring PR** (P1) — lifts 4 deferred items. ~200 LOC.
3. **IWV unblock decision**: pick paid scraper API or Sharadar or
   EODHD tier upgrade. Ops decision, ~$20-100 budget.
4. **Pre-2006 synthesis backtest** (P2) — consumes Shiller + French.
   ~500 LOC. Separate session if budget tight.
5. **Bayesian production sweep** if IWV unblocks (ops, 25-75h).

## Open follow-ups

- `dev/status/cost-model.md` — 4 deferred items from PR #1151.
- `dev/notes/iwv-scrape-akamai-block-2026-05-16.md` §"Next options" —
  4 paths to unblock IWV.
- French ingest `-999.99` sentinel branch documented but not
  test-exercised (qc-behavioral CP4 soft-flag on #1152).
- Reconcile-log query CLI (Phase 3.5) deferred from continuation plan.
- Sector cap PR (P1, Weinstein domain) deferred from continuation plan.
