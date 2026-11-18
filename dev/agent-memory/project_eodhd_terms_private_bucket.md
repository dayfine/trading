---
name: project-eodhd-terms-private-bucket
description: "EODHD terms read 2026-10-30 — Non-Professional may store/analyze privately; a private cloud bucket for own research is OK, never share"
metadata:
  node_type: memory
  type: project
  originSessionId: 249246cf-fc3d-457f-8536-5d3b905a45a5
  modified: 2026-11-14T22:53:35.165Z
---

EODHD terms (read 2026-10-30): a Non-Professional user may "store, manipulate, and analyze the data for private, non-commercial purposes"; "redistributing… or granting access to the Information" to others is forbidden. Cloud storage is not mentioned. A private bucket only the user (and their own cloud sessions) can read reads as storage, not redistribution — OK.

**Why:** gates #3476 (backtests on Claude cloud). The terms question is settled; what remains is the user creating the bucket + granting the cloud env access.
**How to apply:** don't re-research the terms; keep the bucket private, never put bar data in the repo, an artifact or a shared link; commercial use would need EODHD's professional licence. Related: [[project-env-cloud-label]].

**Cloud access (2026-10-31):** `EODHD_API_KEY` set in the Default env (env_011CV2KYxeXLs26U85qQo3rV) and `eodhd.com` allowed; a cloud session fetched SPY EOD and the delisted list (both http 200). Never print the key.

**Results artifacts → private repo (user, 2026-11-14).** The public trading repo's committed run outputs let anyone back out raw closes (ΔNAV of a one-position day = qty × Δclose; open-row marks; validator specimens; cell logs print fill prices). User created private **`dayfine/trading-results`**; from the stale-E K=5 read on, price-bearing per-arm files go there under the same `dev/experiments/<name>/results/...` paths: `equity_curve.csv`, `trades.csv`, `open_positions.csv`, `tickets.tsv`, `splits.csv`, `firstdiff.txt`, the cell `.log`, `validator.sexp.{md,sexp}`. Public keeps specs, scripts, mark-free reads, `actual/summary/params/macro_trend.sexp`, `entries.tsv`, chain/validator/v6diff logs. Public results PR names the trading-results SHA. History before 11-14 not scrubbed: user confirmed 2026-11-15 ("leave it") for #3608's frozen README fill prices too. `dayfine/trading-parameters` (private, 05-21) is the promoted-config pin, not for results.
**Chains (#3633, 11-15):** `dev/rules/sweep-hygiene.md` §"Chains that publish" — `collect` (public, mark-free) vs `publish` (trading-results); reference `gate-funnel-2026-11-15/chain.sh`; the observatory `lane.sh` follows it. **Cloud access unblocked 2026-11-14 ~14:54 PT:** the user added the repo to the Claude GitHub app; a RemoteTrigger create with both repos in `sources` now succeeds (disabled placeholder `trig_01EGdsscqsgyTNNLHwbG7h5T`, reserved for the gate-funnel cell). First cloud push worked 2026-11-15 (gate funnel, a3a2dadc2). The routine now carries the observatory lane prompt.

**11-17 (USER "move to private"):** 709 more price-bearing `*trades*.csv` (59 dirs, entry_price/exit_price or entry_px/exit_px) copied to trading-results e0252b2 at same paths, deleted from public in PR #3673; index `dev/experiments/TRADES-PRIVATE.md`. Returns-only trade files (34) stay public. No history purge (user). Big pushes to trading-results need `git -c http.postBuffer=524288000 push`.

**11-17 second move (USER "Move them too"):** #3675 moves 515 dev/experiments files (345 non-empty open_positions.csv, 125 force_liquidations.sexp, 3 trade_audit.sexp, 41 final_prices.csv, twin-dedupe arm-only-trades.txt) to trading-results 3ccfce9 + 0d2eec7; index §Position files in TRADES-PRIVATE.md. Still public (listed there with counts, user call pending): 240 equity_curve.csv, 5 bar/close dumps (fresh-eyes spy-weekly OHLC, ourstages_all, joined, index-hedge spy-weekly-stage, warehouse splices adj closes), short-setup/short-wide-top event tables, arc-rerun audit_extract + OHLC tables, 15 terminal_runs, passing quotes, 39 run files outside dev/experiments (dev/backtest 12, warmup-fix-runs 21, all_eligible 6).

**11-17 bar fixtures (USER "Move to private, CI fetches"):** public repo tracks 650 real EODHD bar CSVs in trading/test_data/<A-Z>/ (goldens/tests run on them). Decision: move to trading-results, CI checks it out with a read-only deploy key; repo stays public; history purge separate. Issue #3676 (P1).

**11-17 third move (USER "Move all of them"):** #3675 merged (958d301). #3678 deletes 493 dev/experiments files: trading-results a5753f7 (334: 240 equity_curve.csv, dumps, 52 event tables, audit_extract, terminal_runs), dca23d2 (124 fresh-eyes orders/logs + arc reprice, #3675 review N4), 96f047f (35 found by #3678 review's VALUE scan: firstdiff trade dumps, graded.csv, *-equity.csv, ours.csv, splice-scan, EODHD MISS lines, fresh-eyes level tables). Lesson: header scans miss header-less price files — scan by value. Still public (pending user): ~215 value-scan hits = runner logs quoting fill prices on rejected fills + cash/return/ratio tables; plus 303 *validator*.md reports quoting sample prices as entry=/prior_top= tokens (~10.5k lines; a value scan must split key=value). Outside dev/experiments: f72dd07 + 192fba1 (47 files), deletes in full-gate #3680 (also drops .gitignore trades negations, anonymizes review_pack shorts fixture).
