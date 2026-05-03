# Wiki + EODHD Historical Universe (interim, 2010–2026)

Date: 2026-05-03. New track. Interim survivorship-bias mitigation while Norgate vendor signup is pending. Spans 16 years (2010-01-01 → 2026-04-30) by reconstructing point-in-time S&P 500 membership from the Wikipedia "Selected changes to the list of S&P 500 components" table, joined against EODHD's delisted-aware historical price endpoint.

Authority: this plan; companion to `dev/plans/m7-data-and-tuning-2026-05-02.md` §M7.0 Track 1 (Norgate). Track: `data-foundations`.

## Status / Why

**NOT STARTED.**

The current sp500 universe (`trading/test_data/backtest_scenarios/universes/sp500.sexp`, 491 symbols) is *today's* S&P 500 — symbols that were members between 2010 and today but have since been delisted, acquired, or removed are absent. Every multi-year backtest run on it inherits **survivorship bias upward**: the universe pre-selects companies that survived to 2026.

Norgate Data ($32–66/mo) is the canonical fix per `m7-data-and-tuning-2026-05-02.md` §M7.0 Track 1, but it's blocked on user signup + plan selection. Earlier desk research (this session) established two facts that unblock an interim path:

- **EODHD has delisted price data on the €19.99 EOD All-World tier** (US history from Jan 2000), addressed via the same `/api/eod/<SYMBOL>` endpoint with optional `_old` suffix or simply the original ticker for delisted issues. No additional vendor cost.
- **Wikipedia's `List_of_S&P_500_companies` "Selected changes" table is dense from ~2007 onward** (curl confirms 11–31 rows/year for 2007–2025; 2010+ averages ~20/year — full 395 rows total, oldest 1976-07-01). Pre-2007 data is sparse (≤ ~13 rows/year, broken pre-2003).

For the **2010–2026 window (16 years)**, Wiki + EODHD is credible enough to ship. This plan defers the full 1990-present 30y rebuild to Norgate (M7.0 Track 1) and explicitly scopes itself as interim.

Cross-track impact:
- M5.x backtest scenarios (e.g. `goldens-sp500/sp500-2019-2023`) keep their pinned universes; this plan adds a *separate* `goldens-sp500-historical/` family with point-in-time universes per backtest start date.
- M7.0 Norgate work continues unchanged. When Norgate lands, this Wiki+EODHD path becomes the local cross-check oracle (§Acceptance) rather than the production source.

## Scope

**In:**

- Membership reconstruction: given a target date `D ∈ [2010-01-01, 2026-04-30]`, produce the list of `(symbol, sector)` constituents of the S&P 500 on `D`.
- Daily prices for delisted/removed symbols over their lifetime in the index (via existing EODHD client; document `_old` suffix handling and fallback semantics).
- A `build_universe.exe` CLI emitting a `(Pinned (...))` sexp universe matching the existing `sp500.sexp` layout, suitable for direct use by `goldens-sp500/` scenarios.
- A golden CSV pinning the full 2010-01-01 universe (and a small set of intermediate snapshots: 2013-01-01, 2016-01-01, 2019-01-01, 2022-01-01) for round-trip stability.

**Out:**

- Pre-2010 (Wikipedia table is too sparse — see §Open questions).
- Russell 2000 / Russell 1000 / non-US indexes (Norgate scope).
- Multi-market expansion (separate M7.0 Track 2).
- Alternative-share / dual-class handling beyond what EODHD already exposes.
- Sector reclassifications during the window (use the symbol's *current* GICS sector from the main constituents table; document the bias as a known limitation).
- Full vendor-revision provenance — that's `dev/plans/data-inventory-and-reproducibility-2026-05-02.md` §P1.

## Architecture

Module boundary (lives entirely under `analysis/data/`, qc-structural A2-clean — no `trading/trading/` writes):

```
trading/analysis/data/sources/wiki_sp500/
├── lib/
│   ├── changes_parser.{ml,mli}      ← parse Wikipedia changes-table HTML/Wikitext
│   ├── membership_replay.{ml,mli}   ← replay (today_universe, change_list) → universe at D
│   ├── reason_classifier.{ml,mli}   ← bucket free-text "Reason" into M&A / bankruptcy / mcap / other
│   ├── ticker_aliases.{ml,mli}      ← curated map for symbol changes (FB→META, GOOG dual class, etc.)
│   └── dune
├── bin/
│   ├── build_universe.ml            ← CLI: --as-of YYYY-MM-DD --output universe.sexp
│   └── dune
├── test/
│   ├── test_changes_parser.ml
│   ├── test_membership_replay.ml
│   ├── test_reason_classifier.ml
│   ├── data/
│   │   ├── changes_table_2026-05-03.html        ← pinned snapshot of Wikipedia raw HTML
│   │   ├── current_constituents_2026-05-03.csv  ← pinned S&P 500 today-table snapshot
│   │   └── expected_universe_2010-01-01.sexp    ← golden replay output
│   └── dune
└── dune-project
```

### Data flow

```
(Wikipedia HTML snapshot)            (Wikipedia main table snapshot)
        │                                       │
        v                                       v
 changes_parser.parse  ──→ change_event list    │
                              │                 │
                              v                 v
                    membership_replay.replay_back ──→ (sym, sector) list as of D
                              │                                      │
                              │                                      v
                              │                            EODHD client (existing)
                              │                                 get_historical_price
                              │                                      │
                              v                                      v
                     build_universe.exe  ──── joins ──→ universe.sexp + price CSVs
```

Key design points:

- **Pure replay, no I/O in the lib layer.** `Changes_parser` and `Membership_replay` are pure (string → typed result). The CLI in `bin/` is the only I/O caller. This matches the qc-behavioral CP1–CP4 contract for analysis modules.
- **Pinned input snapshots, not live HTTP.** The Wikipedia HTML snapshot lives in `test/data/` (and is also the input to `bin/build_universe.exe`'s default fixture path). A `--wiki-html <path>` flag overrides for refresh. Refresh is a manual operation, not a backtest-time fetch.
- **Reuse existing EODHD client.** `Http_client.get_historical_price` (`trading/analysis/data/sources/eodhd/lib/http_client.ml:169`) already covers daily-bar fetching for any ticker EODHD knows — including delisted issues. No client changes required for this plan; `_old` suffix handling is a runtime concern documented in `ticker_aliases`.
- **Reverse-time replay is the algorithm.** Start with `current_constituents_2026-05-03.csv` (today's universe). Iterate `change_event list` newest-to-oldest; for each event with effective date `> D`, *undo* it (re-add the removed symbol, drop the added symbol). At loop end the working set is the membership on `D`.

### Existing surfaces this plan touches

| Path | Touch type |
|---|---|
| `trading/analysis/data/sources/eodhd/lib/http_client.{ml,mli}` | **read-only** — call `get_historical_price` for delisted symbols |
| `trading/analysis/data/sources/eodhd/lib/exchange_resolver.{ml,mli}` | **read-only** — US-only for this plan |
| `trading/test_data/backtest_scenarios/universes/sp500.sexp` | **untouched** — current universe stays as a recent-decade-only golden |
| `trading/test_data/backtest_scenarios/goldens-sp500-historical/` | **new directory** for historical universe goldens |
| `dev/data/wiki_sp500/` | **new directory** (gitignored, except small fixture under `test/data/`) |

## Files to touch

New:

- `trading/analysis/data/sources/wiki_sp500/dune-project`
- `trading/analysis/data/sources/wiki_sp500/lib/dune`
- `trading/analysis/data/sources/wiki_sp500/lib/changes_parser.{ml,mli}`
- `trading/analysis/data/sources/wiki_sp500/lib/membership_replay.{ml,mli}`
- `trading/analysis/data/sources/wiki_sp500/lib/reason_classifier.{ml,mli}`
- `trading/analysis/data/sources/wiki_sp500/lib/ticker_aliases.{ml,mli}`
- `trading/analysis/data/sources/wiki_sp500/bin/dune`
- `trading/analysis/data/sources/wiki_sp500/bin/build_universe.ml`
- `trading/analysis/data/sources/wiki_sp500/test/dune`
- `trading/analysis/data/sources/wiki_sp500/test/test_changes_parser.ml`
- `trading/analysis/data/sources/wiki_sp500/test/test_membership_replay.ml`
- `trading/analysis/data/sources/wiki_sp500/test/test_reason_classifier.ml`
- `trading/analysis/data/sources/wiki_sp500/test/data/changes_table_2026-05-03.html` (pinned ~50 KB HTML excerpt)
- `trading/analysis/data/sources/wiki_sp500/test/data/current_constituents_2026-05-03.csv` (pinned ~30 KB CSV)
- `trading/analysis/data/sources/wiki_sp500/test/data/expected_universe_2010-01-01.sexp` (golden)
- `trading/test_data/backtest_scenarios/goldens-sp500-historical/sp500-2010-01-01.sexp` (output of build_universe.exe; ~500 symbols)
- `.gitignore` — exclude `dev/data/wiki_sp500/` (cached HTML refreshes) but keep test fixtures committed

Untouched (read-only callers from this plan): the entire `trading/analysis/data/sources/eodhd/` tree.

## Sub-PRs

Three sub-PRs, ~850 LOC total. Each independently mergeable.

### PR-A — `changes_parser` + `reason_classifier` (~250 LOC)

Pure-function HTML/Wikitext parsing. No I/O, no EODHD calls.

- `Changes_parser.parse : string -> change_event list Status.status_or` where
  `type change_event = { effective_date: Date.t; added: ticker_id option; removed: ticker_id option; reason_text: string }`.
  `ticker_id` records both the EODHD-style ticker and the linked Wikipedia security name.
- Robust to: footnote `<sup>` markers, empty Added/Removed cells (cf. 1999-04-12 Actavis), trailing `\n` inside `<td>` cells, `class="mw-redirect"` on links.
- `Reason_classifier.classify : string -> reason_category` mapping:
  - `"acquired"`, `"purchased"`, `"merged with"`, `"acquisition"` → `M_and_A`
  - `"bankruptcy"`, `"filed for"` → `Bankruptcy`
  - `"market capitalization"`, `"market cap"` → `Mcap_change`
  - `"spinoff"`, `"split off"` → `Spinoff`
  - else → `Other`
- Tests: round-trip on the pinned `changes_table_2026-05-03.html`; assert ≥395 events parse; assert specific known events (e.g. 2026-04-09 CASY/HOLX, 2009-09-21 CRM/IR).

Acceptance: `dune test` green; parser handles all 395 rows from the May 3 2026 snapshot.

### PR-B — `membership_replay` + `ticker_aliases` (~300 LOC)

Pure replay engine.

- `Membership_replay.replay_back : current:constituent list -> changes:change_event list -> as_of:Date.t -> constituent list Status.status_or` where
  `type constituent = { symbol: string; security_name: string; sector: string }`.
- Reverse-iterates events newest→oldest; for each event with `effective_date > as_of`:
  - drop `added.symbol` from working set (it joined after `D`)
  - re-add `removed.symbol` to working set (it was a member on `D`)
  - error if `added.symbol` not present in working set (sanity check — would imply the change list disagrees with current constituents)
- `Ticker_aliases.canonicalize : string -> string` curated map for symbol changes Wikipedia tracks loosely:
  - `FB` ↔ `META` (renamed 2022-06-09)
  - `GOOG` / `GOOGL` dual-class handling
  - `BRK.A` / `BRK.B`
  - Approximately 10–15 known cases; documented in the .mli with citations
  - Conservative default: pass-through unchanged
- Tests:
  - Replay from 2026-05-03 to 2026-05-03 → identical to current constituents (no-op fixed point)
  - Replay back across one known event (2026-04-09: drop CASY, restore HOLX) → 1-symbol diff matches expectation
  - Replay back across 2022-06-09 META rename → working set contains FB, not META, on 2022-06-08
  - Replay back to 2010-01-01 → universe size in `[480, 520]` (S&P 500 has small drift; never exactly 500 due to dual-class)

Acceptance: full replay 2026-05-03 → 2010-01-01 produces a golden universe of expected cardinality; round-trip stable.

### PR-C — `build_universe.exe` CLI + EODHD wiring + 2010 golden (~300 LOC + ~30 KB data)

Glue layer + CLI + first canonical golden universe.

- `bin/build_universe.ml`:
  - Args: `--as-of YYYY-MM-DD` (required), `--wiki-html <path>` (default: pinned fixture), `--current-csv <path>` (default: pinned fixture), `--output <path>`, `--fetch-prices` (optional, calls EODHD), `--token-file <path>` (EODHD token if fetching)
  - Output: `(Pinned (((symbol XXX) (sector "..."))))` matching the existing `sp500.sexp` layout
  - With `--fetch-prices`, also fetches daily bars for any symbol not already present in the local CSV cache and writes to `dev/data/wiki_sp500/<sym>.csv`
- Documentation in the bin's `--help` text covers:
  - `_old` suffix handling for ticker reuse (some tickers are reassigned post-delisting; EODHD distinguishes via the suffix; bind a small allowlist)
  - The interim nature ("for full 1990-present, use Norgate per M7.0 Track 1")
- Pinned golden: `goldens-sp500-historical/sp500-2010-01-01.sexp`. Optionally also 2013/2016/2019/2022 snapshots for incremental coverage; defer the latter four to a follow-up if PR-C is at the LOC ceiling.
- Smoke test (CI-cheap): build the 2010-01-01 universe with `--fetch-prices` disabled and assert size + spot-check 5 known-removed symbols (e.g. `LEH`, `WB`, `CFC`, `AIG` was-still-in, `BSC`).
- **Auto-fetch on cache miss**: with `--fetch-prices` set, if a replay-membership symbol has no local CSV under `dev/data/wiki_sp500/<sym>.csv` (or `analysis/data/sources/eodhd/cache/<sym>.csv`), invoke `Http_client.get_historical_price` to fetch and cache. Logs a single line per fetch. Without `--fetch-prices`, missing symbols produce a warning + are excluded with a `(skipped …)` comment in the output sexp. The "12 missing today" pattern (per `dev/notes/data-gaps.md` §sp500-universe-coverage) recurs at any historical date and is closed by this same flag.

Acceptance: `goldens-sp500-historical/sp500-2010-01-01.sexp` checked into the repo; the existing backtester (`backtest_runner.exe`) can load it and run a 2010–2011 simulation end-to-end without symbol-resolution errors. Network-dependent acceptance (full price fetch for ~50 net-new delisted symbols) is local-only, not gated in CI.

### PR-D (follow-up) — change-log output for dynamic universe (~200 LOC, optional)

Static-sexp output of PR-C handles fixed-universe backtests. For mid-window rebalancing — where stocks join/leave the index *during* a backtest run — emit a change-log instead:

- `bin/build_universe.ml --change-log --from YYYY-MM-DD --until YYYY-MM-DD --output <path>.jsonl` writes one event per line: `{"date": "...", "action": "added"|"removed", "symbol": "...", "sector": "..."}`
- New `Membership_replay.is_member : t -> symbol:string -> as_of:Date.t -> bool` for runtime PIT lookup
- Backtester integration: optional `--universe-change-log <path>` flag (separate PR; lives in `feat-backtest`); if present, screener filters candidates by `is_member` at each tick
- This PR is OPT-IN — does not change static output behavior

Out of scope for first delivery (PR-A/B/C). File when M5.x scenarios show appreciable drift between static and dynamic universes.

## Open questions

1. **Ticker reuse / `_old` suffix.** EODHD reassigns some tickers post-delisting (e.g. `GM` → 2009 General Motors bankruptcy; `GM` → 2010-onwards "new" GM). Their convention is undocumented in our codebase. Need to confirm via spot-test: does `EODHD /api/eod/GM` return the new GM only, or both? Is `GM_old` a real endpoint or a fiction? Plan: PR-A includes a one-shot probe script (`bin/probe_eodhd_old_suffix.ml`) that queries 5 known reassigned tickers and reports what comes back; results documented in `Ticker_aliases`'s .mli. If `_old` is real, route delisted issues through it; if not, accept the data limitation and exclude affected symbols from the historical universe with a logged warning.
2. **Mergers — Wiki "Reason" column is free-text, not structured.** Confirmed via curl: examples include `"Blackstone Inc. and TPG Inc. acquired Hologic."`, `"Market capitalization change."`, `"Harnischfeger filed for bankruptcy."`. `Reason_classifier` extracts a coarse category but the free-text is preserved verbatim for audit. Acceptance threshold: ≥85% of 2010+ events classify into a non-`Other` bucket. If we hit `Other` ≥15%, surface a known-failures list and either expand the classifier or accept.
3. **Symbol changes (FB → META, etc.).** Wikipedia tracks these inconsistently — sometimes as a single rename row in the changes table, sometimes only on the company's own page. Plan: maintain a small curated `Ticker_aliases` map (10–15 entries) seeded from manual research. PR-B docs the discovery process so future renames can be added without architectural change. Wiki rename detection ("Renamed from X to Y") is *not* in scope.
4. **Test approach for replay correctness given no ground-truth pre-Norgate.** Three layers of assertion:
   - **Self-consistency**: replay-then-replay-forward round-trips to current constituents.
   - **Known-event spot checks**: pin a small set of historically-attested membership facts (Lehman in S&P 500 on 2008-09-15; AIG on 2008-09-15; both removed within days). Sourced from contemporaneous press releases cited in PR-B.
   - **Cardinality bounds**: `|universe(D)|` in `[480, 520]` for any D in the window (S&P 500 holds ~500 with dual-class drift).
   This is *not* equivalent to Norgate-grade ground truth; we accept that explicitly. When Norgate lands, a one-off cross-check job (Norgate vs Wiki-replay) becomes the definitive correctness test, and divergences seed `Ticker_aliases` updates.
5. **Sector drift during the window.** The replay returns *current* GICS sector for each symbol — an XOM in 2010 was sector "Energy", which is correct, but a reclassified company would carry today's sector throughout. Documented as a known limitation; Norgate plan covers point-in-time sector if needed.
6. **Refresh cadence.** Wikipedia gets edited continuously. Plan: pin an HTML snapshot (`changes_table_2026-05-03.html`), commit it, treat refresh as a manual session-level operation. PR-A documents the refresh recipe (curl + sed extract). No live web-fetch at backtest time.
7. **Output shape — static sexp vs change-log.** PR-C ships the static sexp (one universe per `--as-of` date; matches existing `goldens-sp500/` format). For mid-window rebalancing — where a stock joins or leaves the index *during* a backtest — the static-universe approach is biased: stocks added mid-window aren't tradeable; stocks removed mid-window keep trading until delisted. For Weinstein (long-horizon, weekly cadence) the bias is small but real. PR-D (deferred follow-up; ~200 LOC) emits a change-log JSONL covering the full window, plus a backtester opt-in `--universe-change-log` flag that calls `Membership_replay.is_member` at each tick. File when M5.x scenarios show appreciable drift between static and dynamic universes.

## Acceptance

Measurable, end-to-end:

1. **Parse**: `Changes_parser.parse` on the pinned 2026-05-03 HTML returns `Ok events` with `List.length events = 395` and ≥98% of `Reason_classifier.classify event.reason_text` non-`Other` for events from 2010+.
2. **Replay round-trip**: `replay_back ~as_of:2026-05-03 ~current ~changes` is the identity (no events filtered → no diff). `replay_back ~as_of:2010-01-01` produces a working set of size in `[480, 520]`.
3. **Known-event spot checks** (committed as table-driven test cases, seeded by hand from press releases):
   - Lehman Brothers (`LEH`) ∈ universe on 2008-09-14, ∉ universe on 2008-09-22. (Note: 2008 is *outside* the official 2010+ scope — this test is best-effort using the sparser pre-2010 changes data and may be marked allow-fail.)
   - General Motors (`GM` original) ∈ universe on 2009-05-01, ∉ universe on 2009-06-08.
   - Facebook (`FB`) ∈ universe on 2013-12-23, with the alias hop to `META` from 2022-06-09.
   - At least 10 such cases curated.
4. **Backtest end-to-end**: `goldens-sp500-historical/sp500-2010-01-01.sexp` is loaded by `backtest_runner.exe` for a 2010-01-01 → 2011-12-31 window. **No symbol-resolution errors**, no missing-bar panics. Symbols with no available daily bars produce a warning + are skipped, not a fatal error. The number of fatal-skipped symbols is logged and ≤ 5% of the universe.
5. **Diff vs current `sp500.sexp`**: the 2010-01-01 universe has ≥40 symbols not present in today's `sp500.sexp` (the survivorship-bias delta — these are exactly the names backtests on the current universe miss).
6. **Universe completeness — auto-fetch closes data gaps**: at any `--as-of` date in `[2010, 2026]`, running `build_universe.exe --as-of <date> --fetch-prices` resolves every replay-membership symbol to a local CSV under `dev/data/wiki_sp500/<sym>.csv` (or skips with a `(skipped …)` annotation in the output sexp + a `dev/notes/data-gaps.md` log line). Without `--fetch-prices`, missing symbols produce warnings; the same "12 missing today" pattern recurs at any historical date (per the existing `sp500.sexp` header comment) and is closed by this same fetch path. ops-data agent owns gap resolution per `.claude/agents/ops-data.md` §"Known gaps".
7. **Index-reconstruction verification — cap-weighted SPX cross-check**: compute cap-weighted total return of replay-membership × per-symbol EODHD prices × shares-outstanding (from EODHD fundamentals API; no float adjustment in tier-2) and compare to SPX historical. Quarterly absolute deviation ≤ 5% over 2010–2026 (tier-2 cap-weight; tier-3 with float + divisor would close to bps but requires separate vendor — out of scope). Divergences > 5% in a single quarter flag potential `Ticker_aliases` updates or missed change-events. Tier-1 fallback (equal-weight return correlation ρ > 0.95 vs SPX) when fundamentals data is unavailable.

### Verification tiers (table)

| Tier | Method | Vendor cost | Match quality | Use |
|---|---|---|---|---|
| 1 | Equal-weight monthly-return correlation vs SPX | none (already have prices) | ρ > 0.95 expected | smoke check; cheap |
| 2 | Cap-weight (shares outstanding, no float) | EODHD fundamentals (existing tier) | within 2–5% per quarter | **canonical correctness oracle** |
| 3 | Cap-weight + float-factor + S&P divisor | float + divisor vendor (separate) | within bps | overkill; deferred |

## Cross-links

- **Norgate plan** — `dev/plans/m7-data-and-tuning-2026-05-02.md` §M7.0 Track 1. This plan is explicit interim work and does **not** alter the Norgate plan's status (still `BLOCKED on user vendor signup`). When Norgate ingests, this Wiki+EODHD source becomes a **cross-check oracle** for the first 2000–2010 backtest run (plan §Acceptance bullet 4).
- **Data-foundations track** — `dev/status/data-foundations.md`. Add a new §Track 1.5 entry under M7.0 with status `IN_PROGRESS`, blocking on neither Norgate nor Synth-v1.
- **Data inventory + reproducibility** — `dev/plans/data-inventory-and-reproducibility-2026-05-02.md`. The pinned Wikipedia HTML snapshot under `test/data/` is the manifest source-of-truth for this plan's reproducibility; no integration with the P1 manifest writer is needed (Wiki HTML is not an EODHD CSV). When P1 lands, the EODHD-fetched delisted bars routed via `--fetch-prices` *will* flow through the standard manifest pipeline because `build_universe.exe` calls the existing `Http_client` + (eventually) `Csv_storage.save`.
- **qc-structural A2 boundary** — this entire plan lives under `analysis/data/sources/wiki_sp500/`. No `trading/trading/` writes. A2 PASS by construction (`.claude/rules/qc-structural-authority.md` allow-list intentionally does not include this path; that's correct — `trading/trading/backtest/**/dune` is the only `analysis/`-import exception, and this plan creates no new such imports).
- **qc-behavioral** — pure infra/data PR. CP1–CP4 only; the Weinstein-domain S*/L*/C*/T* checklist is NA per `.claude/rules/qc-behavioral-authority.md` ("pure infra / harness / refactor PR; domain checklist not applicable").
- **No Python** — all parsing in OCaml (`Yojson` for JSON, hand-rolled or `lambdasoup`-style HTML traversal for the changes table). Per `.claude/rules/no-python.md`.
