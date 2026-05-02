# Data Inventory + Reproducibility

Date: 2026-05-02. New track. Surfaces a real gap: if `trading/test_data/` (or `dev/data/`) was deleted today, no record exists of which symbols were fetched when, from which source, with what range, or what version. Refetching would silently produce a different dataset (vendor revisions, point-in-time changes, adjusted-close updates) and nobody would notice.

Authority: this plan; no prior design doc exists.

## Status

NOT STARTED.

## Context

Current state of data on disk:

```
trading/test_data/
├── A/, B/, ..., Z/        ← per-symbol CSVs from EODHD, ~10K symbols
├── breadth/                ← AD breadth bars (synthetic)
├── backtest_scenarios/     ← scenario sexp files (universe, period, expected metric ranges)
└── universes/              ← universe sexp files (sp500.sexp, etc.)

dev/data/                   ← scratch / not gitignored consistently
```

What's missing:

1. **No fetch log**. Per-symbol CSVs have file mtimes but no record of:
   - Which API endpoint produced this (EODHD `/eod`, `/intraday`, `/dividends`, `/splits`)
   - Which fetch ran (date, request ID, vendor revision tag)
   - Which date range was requested (vs returned — partial fills possible)
   - Which API key / quota consumed
2. **No hash manifest**. If a CSV is corrupted or silently overwritten with stale data, no checksum to detect it. Reruns silently use the wrong data.
3. **No vendor-version tag**. EODHD revises historical adjustments (splits, dividends, mergers) over time. The same symbol fetched today vs 6 months ago can have different adjusted_close values for the same date. No record of which "version" we're on.
4. **No reconciliation log**. When refetch produces different values, no automated diff or alert. Silent drift.
5. **No reproducibility**. Re-fetching from scratch today would *probably* produce similar data, but no guarantee. CI runs against committed fixtures (small) but local backtests use the un-tracked per-symbol cache.

## Why this matters

- **Backtest reproducibility**: a baseline run today should match a baseline run 6 months ago (same scenario + same code + same data). Today, the data side is silently changing. Pinned baselines (e.g. `goldens-sp500/sp500-2019-2023.sexp` ranges) protect against code drift but not data drift.
- **G14-class bugs surface differently across data versions**: a split-adjustment bug detected on 2026-04-30 EODHD may not reproduce on 2026-05-02 EODHD if vendor revised the adjustment. Without a version tag, can't pin which data version a bug was filed against.
- **ML training data integrity**: M7.1 ML pipeline trains on `optimal-strategy` oracle labels derived from per-trade context (M5.2e). Silent data drift = silent label drift = silent model degradation. Need verifiable provenance.
- **Norgate vs EODHD parity**: when M7.0 Norgate ingest lands, we'll have two data sources for overlapping symbols. Need a way to detect divergence + trace which source any given metric came from.

## Goal

A manifest + fetch-log + hash-verify system that makes the data side as reproducible as the code side.

## M-track structure

This is a new sub-track under M7.0 (data foundations). Three phases:

### Phase 1: Manifest writer + reader (~400 LOC)

Goal: every fetched CSV produces a sidecar manifest entry with full provenance.

Files to create:
- `analysis/data/storage/manifest/lib/manifest.{ml,mli}` — types + serializer
- `analysis/data/storage/manifest/lib/dune`
- `analysis/data/storage/manifest/test/test_manifest.ml`
- `analysis/data/storage/manifest/bin/manifest_inspect.ml` — CLI: `manifest_inspect <data-dir>` prints inventory summary

Manifest schema (one per data directory):
```sexp
((schema_version 1)
 (created_at "2026-05-02T10:30:00Z")
 (last_updated "2026-05-02T11:42:15Z")
 (entries
  (((symbol "AAPL.US")
    (source EODHD)
    (endpoint "/eod/AAPL.US")
    (date_range ((from 1990-01-01) (to 2026-05-02)))
    (rows_count 9156)
    (sha256 "a3f7c2b8e9d4...")
    (vendor_revision_tag "2026-05-01")
    (fetched_at "2026-05-02T10:31:14Z")
    (fetch_id "req-1c8f3d4e")
    (api_key_id "eodhd-prod"))
   ((symbol "TSLA.US") ...)
   ...)))
```

Wire into existing `Csv_storage.save`: every save also writes/updates the manifest entry.

Acceptance:
- Saving a new symbol creates a manifest entry
- Re-saving updates the entry (sha256, last_updated, fetched_at)
- `manifest_inspect <dir>` prints: total symbols, oldest fetch, newest fetch, missing-manifest count
- Round-trip stable

### Phase 2: Hash-verify on load (~200 LOC)

Goal: every load checks sha256 against manifest. Mismatch → loud error, not silent drift.

Files to touch:
- `analysis/data/storage/csv/lib/csv_storage.{ml,mli}` — extend `load` to verify against manifest sha256
- `analysis/data/storage/csv/test/test_csv_storage.ml` — add corruption-detection test

Behavior:
- Manifest entry exists + sha256 matches: load proceeds (silent)
- Manifest entry exists + sha256 mismatch: `Error (Status.Internal "data corruption: <symbol> sha256 mismatch (manifest=X, file=Y)")`
- No manifest entry for symbol: `Warning` log + load proceeds (legacy data)
- Configurable strictness via `?verify_mode = Strict | Warn | Off`

Acceptance:
- Tampered CSV rejected on load (Strict mode)
- Tampered CSV warns + loads in Warn mode
- Pre-manifest-era data loads without error in any mode (legacy passthrough)

### Phase 3: Fetch-log writer (~300 LOC)

Goal: every API fetch writes a structured log entry. Separate from manifest (manifest is current state; log is history).

Files to create:
- `analysis/data/storage/fetch_log/lib/fetch_log.{ml,mli}`
- `analysis/data/storage/fetch_log/test/test_fetch_log.ml`

Log location: `dev/data/fetch-log/<YYYY-MM>.jsonl` (one line per fetch, monthly rotation).

Schema (JSONL):
```json
{"ts":"2026-05-02T10:31:14Z","source":"EODHD","endpoint":"/eod/AAPL.US","symbol":"AAPL.US","date_range":["1990-01-01","2026-05-02"],"rows":9156,"bytes":428193,"sha256":"a3f7c2b8...","duration_ms":1234,"api_key_id":"eodhd-prod","status":"ok"}
{"ts":"2026-05-02T10:31:15Z","source":"EODHD","endpoint":"/eod/INVALID.US","symbol":"INVALID.US","status":"error","error":"404 not found","duration_ms":234}
```

Wire into all EODHD client call sites + future Norgate client.

Acceptance:
- Every successful fetch appends a log entry
- Every failed fetch appends a log entry with error reason
- Log is append-only (never rewritten)
- Monthly rotation works (one file per `YYYY-MM`)
- Log queryable via `jq` for ad-hoc analysis (e.g. "all fetches of AAPL.US in last month")

### Phase 4 (later): Reconciliation tooling (~300 LOC)

Goal: detect vendor-revision drift. When the same symbol is refetched and CSV content differs, generate a structured diff + alert.

Files to create:
- `analysis/data/reconciler/lib/reconciler.{ml,mli}` — diff two symbol snapshots
- `analysis/data/reconciler/bin/reconcile.ml` — CLI: `reconcile <symbol>` compares latest fetch vs manifest history

Output: per-bar diff (open/high/low/close/adjusted_close/volume) showing which dates changed, by how much.

Defer until Phase 1-3 land.

## Files (rollup)

| Phase | New paths |
|---|---|
| P1 manifest | `analysis/data/storage/manifest/{lib,test,bin}` |
| P2 hash-verify | extend `analysis/data/storage/csv/lib/csv_storage` |
| P3 fetch-log | `analysis/data/storage/fetch_log/{lib,test}` |
| P4 reconciler | `analysis/data/reconciler/{lib,bin}` |

## Risks / unknowns

- **Backward compat**: existing data on disk lacks manifest. Phase 2 must handle this gracefully (Warn mode default for first 30d, then Strict).
- **Manifest size**: ~10K symbols × ~500 bytes/entry ≈ 5 MB manifest sexp. Manageable but consider sharding by first letter (matching CSV layout).
- **Concurrent writes**: parallel fetches race on manifest update. Use file locking OR per-symbol manifest entries (eliminates contention).
- **Vendor revision tags**: EODHD doesn't expose a "data version" header. Best we can do is fetched_at timestamp + sha256. Accept this limitation; document explicitly.
- **API key rotation**: storing api_key_id in plaintext manifest is fine (not the secret itself). But useful for audit only.

## Acceptance for the plan as a whole

- Phase 1 manifest landed; every new fetch creates manifest entry
- Phase 2 hash-verify landed; corrupted/tampered CSV detected on load
- Phase 3 fetch-log landed; structured history queryable via jq
- A backtest run on 2026-05-02 produces results that can be reproduced on 2026-11-02 by:
  1. Reading the run's manifest snapshot
  2. Refetching (or restoring from backup) data matching the manifest sha256
  3. Re-running with same code
- The test harness includes a "reproducibility test" that verifies this end-to-end

## Out of scope

- Norgate ingest itself (separate M7.0 sub-track)
- Vendor-revision tracking that requires API support EODHD doesn't expose
- Real-time data (we're weekly cadence; data freshness measured in days, not seconds)
- Cloud storage / S3 sync — local FS only

## Dependencies

```
P1 manifest ─→ P2 hash-verify
            ─→ P3 fetch-log
            ─→ P4 reconciler (much later)

(P1 unblocks downstream Phase 2/3; P4 only useful after several months of fetch-log history)
```

P1 starts whenever queued. Independent of M5.x work in flight.
