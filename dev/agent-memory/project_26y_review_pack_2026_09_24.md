---
name: project_26y_review_pack_2026_09_24
description: "26y PIT top-3000 null review pack (s0 457% / s1 188% / s2 152%): artifact USLCZcKBJc2BjS9ou2jRBi, now reproducible via dev/scripts/review_pack.sh; 09-25 review findings (stops fill next open, picks ≈ SPY, tighter stops lose, salt = intraday path)."
metadata:
  node_type: memory
  type: project
  originSessionId: 13438ee6-bde6-4f74-839d-eef43a46dd35
  modified: 2026-09-25T20:41:03.399Z
---

User asked (09-24) for a trade-by-trade review pack of the latest 26y runs; reviewed 09-25.

**Artifact:** https://claude.ai/artifact/USLCZcKBJc2BjS9ou2jRBi (v3 09-25: Diagnostics tab, winners/losers sort fixed, N-run manifest).
**Tool (09-25):** `sh dev/scripts/review_pack.sh --out DIR LABEL=PREFIX ...` + `dev/lib/review_pack/` + test `trading/devtools/checks/review_pack_test.sh`. ~2 min for 3×26y salts once stage replays exist. Reproduced the 09-24 pack bit-for-bit on every period table and trade row.

**09-25 review findings (s0 unless noted):**
- Stop exits are close-decided Market orders filled at the NEXT OPEN, never resting sell-stops (book §5.7 says resting). 362/423 unraised stop exits fill 1 bar after the low first traded the stop; 177 of those closed back above the stop that day. P&L-neutral (intraday fill ≈ −$51k worse on s0), so a faithfulness gap, not a return lever.
- Picks are market-like: median 8-week pick return ≈ SPY most years. Bad bull years (2014, 2023) lose on EXITS (win rate 24–36 %, D/F 28–34 %); 2024 picks were genuinely weak (median −5 pp vs SPY).
- Tighter loss cutting LOSES: static hard-stop replay 3/5/6/8/10/15 % → $1.86/2.62/2.67/3.15/3.45/3.62M vs actual $3.85M. Losers are already small (median −4.6 %).
- D/F grade is hindsight (post-exit path); no entry-time field separates it (D/F 19–32 % across macro/breadth/score/volume/stop-type cohorts). Only Deteriorating breadth (−$662k, n=51, [[project_deteriorating_gate_reject]]) and Recovering (+$820k, n=20) stand out.
- Salt = intraday-path seed (`Bar_shape.seed_for_bar`), not a candidate ordering. Trade lists identical until 2006-01-19 (FORM filled 01-19 vs 01-21). 465 trades common to all 3 salts earn $2.1–2.4M in each; the whole spread is the unique trades (s0 +$1.52M incl. ECHO $647k; s1 −$0.75M; s2 −$0.69M). Nothing to externalise; the robust lever is dispersion ([[project_top_n_capacity_verdict]]).
- Flat stretches (≥1y under the prior NAV high): 2000–05 +15 pp vs SPY, 2007–10 +17.5 pp, 2011–13 −11.6, 2014–16 −16.1, 2018–19 −10.4, 2021-11→now −74.8 pp (NAV still −6 % under the 2021 high).
- 2009: macro Bearish through Q1, Bullish from Q2 but only 1 % invested until Q3 (no Stage-2 breakouts yet; `reject_declining_ma_long_entry` likely blocks early-recovery names — untested hypothesis).
- Fill checks: of the "off-bar" fills most are cent rounding or a later split basis (TRN/ENB/BWA 2:1, NEOG/FULT); only STMP's exit (delisting stub, #2672) is a real defect. The extractor now snaps split-basis fills.

**State at 09-25 evening (weekly usage limit hit; subagents blocked until 09-27 00:00 PT):**
- #2962 review pack: STRUCT ok at a2553bcc; BEHAV rework iter 1 PUSHED (9a62f04b, 24/24, Saturday/F/X/A?/off-bar/2-run pinned, grade window = grade.sh). Needs re-QC (both gates, new tip).
- #2963 sim_entry_stoplimit_fresh_bar_only (Fix A): CI build pass after fn-length fix a6e1ba21; goldens-affected FAIL = docstring cross-ref on 7 postsubmit goldens -> needs paired golden runs (flag default off ⇒ expect identical) + `paired-run-done` label. No QC yet.
- #2964 sim_stop_exit_fill_on_trigger_bar (Fix B, #2961), stacked on #2963, tip ad055b85, CI pass, local build+tests pass. No QC yet.
- #2965 perf_long_cells.sh ledger (193 cells), CI pass. No QC yet.
- require_structural_stop (investor preset): agent died on the limit mid-build; UNBUILT WIP pushed to origin/wip/require-structural-stop (56a48de44, 20 files, adds entry_audit_emit.ml extraction). Finish: build, test, open PR.
- Experiment specs (f1-stoplimit-fresh, f2-fills-faithful) in jj change xqtlxwyz (also holds a stale copy of perf_long_cells.sh — drop it). Chain after #2963/#2964 merge: f2 s0-2 + null s0 repro, cap 12000, ~4h/cell.

**State at 09-25 22:46 PT (supersedes the block above):** MERGED #2962 (review pack), #2963 (sim_entry_stoplimit_fresh_bar_only), #2965 (perf ledger), #2967 (sim_stop_exit_fill_on_trigger_bar; replaced auto-closed #2964). #2966 (require_structural_stop) both gates APPROVED at b7a3f5fd2 + paired-run-done → merge poll armed; follow-up nit: move the 2026-09-25 resolved-question paragraph out of the middle of the §5.3 bullet list in weinstein-book-reference.md. **Fixes experiment RUNNING** (lane A, /tmp/fixes-run/chain-A.log, pinned worktree .claude/worktrees/sweep-fixes @ fe082e788, artifacts /tmp/sweeps/obvious-fixes/): a0-pit-null:0 (repro check vs committed 457.01%) → f2-fills-faithful:0,1,2 → f1-stoplimit-fresh:0, ~4h/cell. Specs staged /tmp/fixes-run/specs; chain /tmp/fixes-run/chain-fixes.sh; commit specs+chain+results under dev/experiments/obvious-fixes-2026-09-25/ (qc-results lane) when done; then `perf_long_cells.sh update` the chain log. Paired goldens for #2963/#2966: all byte-identical (same md5s).
