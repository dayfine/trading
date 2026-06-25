---
name: project_ad_default_flip
description: "A-D-live is now the default basis — perf-fixed (#1722) + confirmation-grid ACCEPT + flip PR (#1725)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 353ebe6a-f0a4-495d-b888-ef75a009d211
---

The **A-D-default flip** (make A-D breadth live the default basis) is BUILT and
grid-confirmed, 2026-06-23.

- **P0a perf fix — MERGED #1722.** The A-D macro was O(n²) (per-tick `List.filter`
  + full cumulative re-fold over the whole breadth history). Now O(log n)/tick via
  a precomputed prefix-sum cache (`Ad_series_cache` + `macro_callbacks_of_weekly_views_cached`,
  `~ad_series` threaded through the strategy hot loop). Bit-identical (parity test).
  Also extracted `Weinstein_strategy_state` to satisfy the file-length limit.

- **The flip mechanism (corrected from the handoff doc):** `skip_ad_breadth`
  already defaults `false`; CI reads `TRADING_DATA_DIR=trading/test_data` where
  Unicorn `nyse_*` breadth (1965→2020-02) was already present. The flip = commit the
  **synthetic post-2020 tail** (`synthetic_{advn,decln}.csv`, 1998–2026, 0.92–0.93
  corr vs NYSE) into `test_data/breadth/` so the full window goes live, + re-pin the
  goldens that shift. **NOT merge-blocking** (all `perf-tier:1` required scenarios
  end ≤2020-01-03, inside Unicorn coverage).

- **Confirmation grid → ACCEPT (3/3), PR #1725.** Per `promotion-confirmation.md`:
  the single FINDINGS scenario (27y longshort) didn't suffice — a long-only spot-check
  contradicted it. Ran A-D-live vs inert (longshort) across 3 cells: sp500-2000
  1999-2026 (deep), sp500-2010 2010-2026 (post-GFC), sp500-2015 2015-2026 (recent).
  **All 3: live better risk-adjusted, none badly dominated.** ~10% return cost.
  Ledger: `dev/experiments/_ledger/2026-06-23-ad-default-flip-confirmation-grid.sexp`.
  Grid: `dev/backtest/ad-grid-2026-06-23/STATUS.md`.

- **The why (transferable):** A-D breadth's edge is **short-timing** — it helps the
  longshort (real) strategy and *costs* return in long-only bull/recovery windows
  (bull-crash-2015-2020 110→59, sp500-2019-2023-long-only 66→26). Re-pins record this
  honestly. A faithfulness flip (A-D is Weinstein's primary breadth gauge), not a
  uniform perf win.

- **Deferred follow-up — heavy-tier re-pin is INFRA-BLOCKED (2026-06-24 finding):**
  the heavy top-1000/3000 `goldens-broad/*` + `goldens-custom-universe/*` goldens shift
  but can't be cleanly re-pinned. **perf-tier3/4 run them in CSV mode** (no
  `--snapshot-dir`), and CSV mode **OOMs/crawls on top-N** (top-3000 never completes;
  top-1000 ~50min each). Running them in **snapshot mode works** (`--snapshot-dir
  /tmp/snap_top3000_1998_2026`, fast) BUT gives **non-canonical numbers** — the
  warehouse data diverges from CSV (six-year-broad snapshot=19.5% vs its 70-106% CSV
  pin; top-3000 cells `tier4-broad-10y`/`weinstein-full-pool` even CRASH in snapshot
  too). So snapshot re-pins would be WRONG vs how CI runs them. **Do NOT commit
  snapshot-mode re-pins.** Real fix needs an infra decision FIRST: either migrate
  perf-tier3/4 to snapshot mode (then re-pin to snapshot numbers) OR fix the CSV
  top-N OOM (`project_panel_runner_memory_ceiling`). These goldens are non-blocking
  (perf-tier:4 local-release-gate + 2 perf-tier:3) so stale bands don't break normal CI.
  The `all_eligible` diagnostic is the per-scenario time sink — `--no-emit-all-eligible`.
  Snapshot warehouse stores `^GSPC` as `GSPC.INDX`; macro gate works (non-zero trades).
  **DEEPER finding — needs a QUALITY REVIEW, not a re-pin.** Ran the top-1000/500 ones
  in CSV (canonical): A-D-live numbers are **2-3× the old bands** (decade 105-158→227%,
  six-year 71-106→226%, weinstein 63-94→247%), MaxDD ~59%. Old bands were pinned 06-05
  (AFTER Unicorn landed 05-11) so they were Unicorn-CSV with a NO-breadth 2020-2023 tail;
  the flip makes 2020-2023 live and the broad universe rides the recovery → huge
  **terminal MTM-inflation** (`project_broad_universe_790_mtm_inflated`: realized ≪ MTM).
  Three data paths (old Unicorn-CSV / snapshot / A-D-live-CSV) give three answers.
  Re-pinning to the 226%/59%-MaxDD CSV numbers would pin known-inflated metrics — wrong.
  Left un-re-pinned. **DEFINITIVE ROOT CAUSE (2026-06-24): test_data is an INCOMPLETE
  ~650-symbol curated store.** It covers only **462/1000** of top-1000-2014 and **309/510**
  of sp500-2010 (data/ covers 501/510). The broad/custom universes are delisting-aware
  (incl `_old`-suffixed delisted tickers test_data lacks); the runner **silently skips
  missing symbols**, so a broad golden run vs test_data CSV trades only the survivor
  subset → survivorship-inflated + data-path-dependent (test_data-subset 226% vs
  warehouse-complete 95% vs old pin 105-158). The 2-3× divergence is a DATA-COVERAGE
  artifact, NOT an A-D-live effect — the flip's effect on broad goldens is unmeasurable
  locally. **The merged flip (#1725) is SOUND regardless:** the confirmation grid ran vs
  `data/` (501/510 near-complete) so 3/3 PROMOTE holds; the feasible sp500/small re-pins
  used the SAME test_data-subset source as their old pins (change = flip effect, internally
  consistent). The broad goldens were ALREADY measuring incomplete subsets pre-flip — a
  pre-existing golden-quality issue. Real fix: provision a complete delisting-aware data
  store for the broad goldens (or run them vs the warehouse), then re-pin. Bar path scheme:
  `test_data/<first-char>/<last-char>/<SYM>/data.csv`.

Local data: the runner reads gitignored repo-root `data/` (`TRADING_DATA_DIR` override);
`data/breadth/synthetic_*.csv` (1998–2026) is the validated source copied into test_data.
