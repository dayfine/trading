Status / handoff: historical S&P 500 universe membership (2026-05-13)
====================================================================

Companion to:
- `dev/notes/historical-universe-membership-2026-04-30.md` — original 6-phase design (P1–P6).
- `dev/plans/wiki-eodhd-historical-universe-2026-05-03.md` — interim Wiki+EODHD plan (PR-A/B/C/D).
- `dev/notes/plan-norgate-horizon-universe-2026-05-12.md` — forward-looking horizon plan.

## 1. Is the 2026-04-30 design still the canonical plan?

**Partly.** The *strategic framing* (survivorship-bias mitigation; interval-representation
universes; point-in-time screener filter; per-symbol delisted-aware bars) is still correct
and remains the north star.

The *six-phase scope*, however, has been **superseded for phases P1–P2** by the
Wiki+EODHD interim plan (`wiki-eodhd-historical-universe-2026-05-03.md`),
and substantial code has already landed on `main`:

| 04-30 Phase | Status in main as of 2026-05-13 | Where it lives |
|---|---|---|
| P1 — membership data fetch | **MERGED** (interim Wiki path, not paid S&P) | `trading/analysis/data/sources/wiki_sp500/` — `changes_parser`, `membership_replay`, `reason_classifier`, `ticker_aliases`, `build_universe.exe`. PR-A/B/C/D MERGED #803/#808/#809/#813. |
| P2 — delisted-symbol audit | **PARTIAL** | EODHD delisted bars covered by existing `Http_client.get_historical_price`; gaps tracked in `dev/notes/data-gaps.md` (~33 reassigned ex-SP500 tickers + 1 unfetchable, ACE). No formal cross-reference audit yet. |
| P3 — `Daily_price.active_through` field | **NOT STARTED** | `analysis/data/types/` unchanged; loaders still don't carry a "delisted after" marker. Missing bars currently surface as warnings, not as a typed field. |
| P4 — universe sexp interval shape | **NOT STARTED — and now arguably superseded** | Current production shape is *one sexp per as-of date* (e.g. `goldens-sp500/universes/sp500-historical/sp500-2010-01-01.sexp`, 510 symbols). Interval-encoded universes would be needed only for the deferred change-log / dynamic-membership path (PR-D in the Wiki plan, also NOT STARTED). |
| P5 — screener point-in-time filter | **NOT STARTED** | No `membership_at` callback in the screener cascade. Current path treats the loaded universe as static for a full backtest window. |
| P6 — historical-universe scenario (30y) | **NOT STARTED for survivorship-aware** | `goldens-broad/sp500-30y-capacity-1996.sexp` exists but is explicitly capacity-only + survivorship-biased. The 16y `sp500-2010-2026` baseline (#1058 long-only + long-short) runs on the *static* 2010-01-01 universe (510 symbols including delisted) — this is the "closest existing thing" to PI-aware production today. |

**Codebase changes since 2026-04-30 that affect the design:**

1. Wiki+EODHD pipeline shipped — `trading/analysis/data/sources/wiki_sp500/` is now the canonical interim source. The 04-30 doc's "P1 — owner: ops-data" is effectively closed for SP500 2010–present.
2. M5.3 streaming Phase F COMPLETE (snapshot mode is the default runtime path; `Bar_panels` deleted, `Snapshot_bar_views` is the production view layer). Any P5 screener-side filter must plug into `Panel_callbacks` / `Panel_views` rather than the (now-deleted) `Bar_reader.of_panels`.
3. The Norgate horizon plan (2026-05-12) explicitly **recommends landing PI-membership on top of EODHD FIRST**, before any Norgate switch — so P3–P5 are still the canonical next-action set, just on Wiki+EODHD substrate rather than Norgate.
4. `dev/notes/data-gaps.md` lines 139–199 already enumerate the ~33 reassigned ex-SP500 tickers + ACE (unfetchable) — partial P2 inventory.

**Verdict: design still valid: yes** for P3–P6. P1 closed via interim Wiki path. P2 partially closed; needs a formal audit pass against the data-gaps inventory.

## 2. Immediate next-action checklist (phase 3, the natural next step)

Phase 3 is the cheapest unlock for surveyed PI-aware backtests: a typed
`active_through` field lets loaders distinguish "delisted on Y" from "bar
missing for plumbing reasons" without changing the universe-sexp shape.

**Files to touch (P3 — `Daily_price` metadata extension):**

- `trading/analysis/data/types/lib/daily_price.ml` + `.mli` — add `active_through : Date.t option` field (default `None` = "still trading / unknown"). Update `[@@deriving show, eq]` callers.
- `trading/analysis/data/storage/csv/` — CSV roundtrip must read/write the new column; backward-compat: missing column → `None`.
- `trading/analysis/data/storage/csv/test/` — new round-trip test fixture with `active_through` set + unset.
- `trading/analysis/data/sources/eodhd/lib/http_client.{ml,mli}` — read-only consumer; if EODHD's response carries a delisting date, surface it; otherwise leave `None`.
- `trading/analysis/data/sources/wiki_sp500/bin/build_universe.ml` — wire delisted-date metadata into output by joining the `removed` event date for any symbol that left the index during the window. (The `change_event` already carries `effective_date`.)
- Bar-loader paths under `trading/analysis/data/pipelines/` + `Snapshot_bar_views` — treat post-`active_through` lookups as `Bar_missing_after_delisting` rather than warning-spam.

**EODHD endpoints needed (P2/P3):**

- `/api/eod/{SYMBOL}.US` — already wired; works for delisted issues including the `*_old` suffix variants. No new endpoint required.
- `/api/exchange-symbol-list/US?delisted=1` — **NEW**, optional. Use to enumerate all US-delisted symbols for the formal P2 audit and cross-reference against `data-gaps.md`. Estimated 1 fetch.
- Fundamentals API (`/api/fundamentals/{SYMBOL}`) — already wired; useful for the verification-tier-2 cap-weighted SPX cross-check (Wiki plan §Acceptance bullet 7). Not blocking P3.

**Fixtures to add:**

- `trading/analysis/data/types/test/data/daily_price_with_active_through.csv` — round-trip golden.
- `trading/analysis/data/sources/wiki_sp500/test/data/expected_universe_with_delisting.sexp` — fixture demonstrating a build_universe output where ≥1 symbol carries `active_through` metadata.
- Reuse the existing `trading/analysis/data/sources/wiki_sp500/test/data/changes_table_2026-05-03.html` snapshot (already pinned, 395 events).

**After P3:** P5 (screener point-in-time filter) becomes the high-leverage
next step — gives survivorship-aware backtests on the existing 510-symbol
2010-01-01 universe + change-log without rebuilding the universe shape.

## 3. Blockers / prerequisites

| Concern | Status | Notes |
|---|---|---|
| Data licensing (Norgate) | Vendor signup pending; **not blocking P3–P5** | The Wiki+EODHD interim path closes the licensing gap for 2010–2026. Per `plan-norgate-horizon-universe-2026-05-12.md` §Axis 1, the recommendation is to ship PI-aware on EODHD substrate first. |
| EODHD quota | Soft concern only | Per-call quota; `--fetch-prices` in `build_universe.exe` is interactive. The ~33 reassigned-ticker audit (~50 net-new symbol fetches) is well within free-tier headroom. Live backtests don't fetch at all. |
| Wiki snapshot freshness | Manual refresh | `changes_table_2026-05-03.html` is the pinned fixture. Wiki edits don't break replay — the snapshot is the authority — but post-2026-05-03 index changes (e.g. 2026-06+ additions) won't show up until someone refreshes. Not blocking P3–P6 on 2010–2026 scope. |
| Broader-universe loader | NOT a dependency | Per Axis 3 recommendation, broader-universe (Russell 1000 / 3000) is parked behind cascade re-tune. P3–P5 don't need it. |
| Pre-2010 history | Out of scope for Wiki path | Wikipedia changes table is sparse pre-2007. 30y survivorship-aware (1996–2026) requires Norgate. PI-aware 16y (2010–2026) is fully unblocked. |
| Sector drift during the window | Documented limitation, not a blocker | Wiki plan §Out: replay returns *current* GICS sector; reclassifications not tracked. Norgate fixes this when it lands. |
| Ticker reuse / `_old` suffix | Documented in `data-gaps.md`; partial inventory | ACE is unfetchable (EODHD returns the wrong issuer); ~33 reassigned tickers need the `_old` route. Closed enough for backtest, not closed enough for production reconciliation. |
| M5.3 streaming integration surface | RESOLVED | Phase F COMPLETE 2026-05-06; `Snapshot_bar_views` + `Panel_callbacks` are the new integration seam. Any P5 screener filter must plug into these (not the deleted `Bar_reader.of_panels`). |

## 4. Rough phase-by-phase effort estimates

| Phase | Scope (original 04-30 doc) | Effort | Notes |
|---|---|---|---|
| P1 — membership data fetch | Wiki+EODHD ingest, replay engine, CLI | **DONE (~850 LOC merged)** | PR-A/B/C/D #803/#808/#809/#813. Closed for SP500 2010–2026. |
| P2 — delisted-symbol audit | Cross-reference against EODHD delisted endpoint | **S** | Inventory mostly captured in `data-gaps.md`. Need a formal audit script (~150 LOC OCaml exe) + one EODHD endpoint binding (`exchange-symbol-list?delisted=1`). |
| P3 — `Daily_price.active_through` metadata | Add typed field; loader fan-out | **M** | ~300–500 LOC including CSV round-trip + storage tests + 4–5 loader-site updates. Touches a base type so qc-structural A1 will flag (not block) — generalizes to any strategy, so judgment call routes through qc-behavioral. |
| P4 — universe sexp interval shape | Augment `universes/*.sexp` to carry intervals | **M** | ~400–600 LOC. **However: arguably superseded by the change-log JSONL path (Wiki PR-D, deferred).** Recommendation: skip P4 in favor of PR-D + the static per-date sexp shape that already works. |
| P5 — screener point-in-time filter | Pre-filter in `Screener.screen` | **M** | ~250–400 LOC. New `membership_at` callback signature; plug into the existing cascade *before* stage classification. Must use `Snapshot_bar_views` / `Panel_callbacks` integration seam, not the deleted `Bar_reader.of_panels`. Highest-leverage unlock for survivorship-aware backtests. |
| P6 — historical-universe scenario | 30y goldens with PI-aware membership | **L** (16y) / **XL** (30y) | 16y `sp500-2010-2026` with PI filter + universe expansion → **L**: re-pin baselines, re-run cells. 30y `sp500-1996-2026` is **XL**: blocked on Norgate (pre-2010 Wiki sparse) + 12–15 GB RSS exceeds 8 GB GHA ceiling, so production 30y stays local-only. |

**Recommended ordering for a future planner:**

1. P3 first (M) — unblocks P5 with typed delisting awareness.
2. P5 next (M) — highest-leverage gain; survivorship-aware 16y backtests on the existing universe.
3. P2 formal audit (S) — cheap, runs in parallel with P3/P5.
4. P6 — 16y PI-aware production goldens (L). Ship as `goldens-sp500/sp500-2010-2026-pi.sexp` alongside the existing baseline so the diff is visible.
5. P4 — defer; the static-per-date sexp + change-log JSONL (Wiki PR-D) covers the same use case more cleanly.
6. 30y survivorship-aware (XL) — defer until Norgate lands.

## Cross-references

- `dev/notes/historical-universe-membership-2026-04-30.md` — original 6-phase design (this note's parent).
- `dev/plans/wiki-eodhd-historical-universe-2026-05-03.md` — interim plan (PR-A/B/C/D MERGED).
- `dev/notes/plan-norgate-horizon-universe-2026-05-12.md` — three-axis horizon plan (source / time / universe-breadth).
- `dev/notes/data-gaps.md` — `_old` suffix inventory, ACE unfetchable.
- `dev/status/data-foundations.md` — track-level status; M5.3 Phase F COMPLETE.
- `trading/analysis/data/sources/wiki_sp500/` — implementation of P1.
- `trading/test_data/backtest_scenarios/universes/sp500-historical/sp500-2010-01-01.sexp` — 510-symbol pinned PI universe (built 2026-05-03).
