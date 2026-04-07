# Data Management for Agents and Regression Tests

**Status:** Design (not yet implemented)
**Assigned to:** feat-data-layer agent
**Blocking:** `docs/design/t2a-golden-scenarios.md` (screener regression tests)

---

## Problem

The `data/` directory at repo root contains ~37,000 cached CSV files (one per
symbol), but there is no documented convention for:

1. How test binaries reference `data/` (dune run dir vs absolute path)
2. What symbols and date ranges are available without scanning the filesystem
3. How an agent fetches a missing symbol before writing a test that depends on it

Without these, the T2-A golden scenario tests cannot be written reliably: they
require real AAPL history going back to 2017, and an agent has no way to verify
it's available or fetch it if not.

---

## Components

### 1. Data path convention for dune tests

**Problem:** When dune runs a test binary, the working directory is
`_build/default/<path-to-test>/`, not the repo root. A hardcoded relative path
like `../../data/` breaks as soon as the test moves. An absolute Docker path
like `/workspaces/trading-1/data/` breaks outside Docker.

**Solution:** Define a `TRADING_DATA_DIR` environment variable, resolved once in
a shared helper, with a fallback to the canonical Docker path.

```ocaml
(* analysis/weinstein/data_source/lib/data_path.ml *)

(** Returns the path to the shared data directory.
    Reads TRADING_DATA_DIR env var; falls back to /workspaces/trading-1/data. *)
val default_data_dir : unit -> Fpath.t
```

```ocaml
let default_data_dir () =
  match Sys.getenv "TRADING_DATA_DIR" with
  | Some p -> Fpath.v p
  | None   -> Fpath.v "/workspaces/trading-1/data"
```

Tests that need real data call `Data_path.default_data_dir ()` — no relative
path arithmetic, no hardcoding. The Docker default works in CI and for
all agents; the env var override works for local development at any path.

**dune integration:** No changes needed. The env var is read at runtime; dune
does not need to know about it.

### 2. Data inventory file

**Problem:** 37,000 CSV files. To know whether AAPL daily bars from 2017-2023
are available, you either stat every file or read metadata sexp files one by
one. Neither is practical for an agent briefing.

**Solution:** A single JSON inventory file at `data/inventory.json`, generated
by a script, listing every cached symbol with its available date range and
cadence.

```json
{
  "generated_at": "2026-04-08",
  "symbols": [
    { "symbol": "AAPL",   "cadence": "daily", "start": "1980-12-12", "end": "2025-05-16" },
    { "symbol": "GSPCX",  "cadence": "daily", "start": "1997-01-02", "end": "2025-05-16" },
    { "symbol": "IWM",    "cadence": "daily", "start": "2000-05-26", "end": "2025-05-16" }
  ]
}
```

**Script:** `trading/analysis/scripts/build_inventory/build_inventory.ml`

```
usage: build_inventory.exe --data-dir <path>
```

Walks `data/`, reads each `data.metadata.sexp`, writes `data/inventory.json`.
Run time: ~10 sec for 37K files (metadata-only reads, no CSV parsing).

Agents can read `data/inventory.json` directly to know what's available before
writing a test.

**When to regenerate:** After any fetch script run. The inventory is not
auto-maintained; it is a generated artifact. Add a note to
`dev/agent-feature-workflow.md`: "run `build_inventory.exe` after fetching new
symbols."

### 3. Fetch script

**Problem:** An agent writing a new regression test may need a symbol not yet
cached. Without a fetch mechanism, the agent either hardcodes unavailable data
or fails silently.

**Solution:** `trading/analysis/scripts/fetch_symbols/fetch_symbols.ml`

```
usage: fetch_symbols.exe --symbols AAPL,GSPCX --data-dir <path> [--api-key <key>]
```

- Reads `EODHD_API_KEY` env var if `--api-key` not given
- For each symbol: fetch daily OHLCV from EODHD, write to `data/`, update
  `data.metadata.sexp`
- Idempotent: re-running for an already-cached symbol appends only new bars
- After completion, re-runs `build_inventory.exe` to update `inventory.json`

Agents can call this via `! fetch_symbols.exe --symbols AAPL` in the Claude
Code session before writing a test that depends on that symbol.

### 4. Universe rebuild

**Problem:** `data/universe.sexp` (consumed by `Live_source` and `Historical_source`)
does not exist. It must be populated from `get_fundamentals` + `get_index_symbols`
(EODHD API), but that's a full API call. For testing and backtesting, we only need
the symbols actually present in `data/`.

**Solution:** `Universe.rebuild_from_data_dir` — reads `data/inventory.json`,
constructs a minimal `universe.sexp` from symbols present locally. Sector/industry
fields will be empty (requires `get_fundamentals`), but the symbol list is usable
for backtesting.

```ocaml
(* universe.mli addition *)

(** Build universe.sexp from symbols found in data/. Sector metadata will be
    empty; use [fetch_universe.ml] script to populate from EODHD fundamentals. *)
val rebuild_from_data_dir :
  data_dir:Fpath.t -> unit -> (unit, Status.error) result
```

This unblocks simulation and screener backtests that loop over the cached
universe without needing a live API call to bootstrap `universe.sexp`.

---

## Dependency for t2a-golden-scenarios.md

`docs/design/t2a-golden-scenarios.md` depends on items 1 and 2 above:

| t2a requirement | Blocked on |
|---|---|
| Tests load AAPL history via `Historical_source` | §1: data path convention (agent needs `Data_path.default_data_dir`) |
| Agent verifies AAPL 2017–2024 history is available | §2: inventory file |
| Agent fetches missing symbols before writing tests | §3: fetch script |

**Implementation order:**
1. `Data_path.default_data_dir` (§1) — small, unblocks all tests immediately
2. `build_inventory.exe` (§2) + regenerate `data/inventory.json`
3. `fetch_symbols.exe` (§3) — needed only if inventory reveals gaps
4. `Universe.rebuild_from_data_dir` (§4) — independent, needed for simulation

Once §1 and §2 are done, the T2-A screener golden scenario tests can be
assigned to a subagent with a reliable briefing on what data is available.

---

## Files to create / modify

| File | Change |
|---|---|
| `trading/analysis/weinstein/data_source/lib/data_path.ml` | new: `default_data_dir` |
| `trading/analysis/weinstein/data_source/lib/data_path.mli` | new: interface |
| `trading/analysis/weinstein/data_source/lib/dune` | add `data_path` module |
| `trading/analysis/scripts/build_inventory/build_inventory.ml` | new script |
| `trading/analysis/scripts/build_inventory/dune` | new: executable stanza |
| `trading/analysis/scripts/fetch_symbols/fetch_symbols.ml` | new script |
| `trading/analysis/scripts/fetch_symbols/dune` | new: executable stanza |
| `trading/analysis/weinstein/data_source/lib/universe.ml` | add `rebuild_from_data_dir` |
| `trading/analysis/weinstein/data_source/lib/universe.mli` | add to interface |
| `data/inventory.json` | generated artifact (run `build_inventory.exe`) |

---

## Out of scope

- Macro data feeds (index bars, A-D breadth, global indices) — tracked as known
  gaps in `dev/status/data-layer.md`. The T2-A golden scenarios construct
  `Macro.result` directly and do not require macro data.
- Real-time or intraday data — not needed.
- Multi-symbol concurrent fetch optimization — the existing EODHD client
  handles throttling; `fetch_symbols.exe` can call it sequentially.
