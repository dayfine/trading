---
name: project-warmup-trading-running-start
description: "Warmup trading is a net-beneficial \"running start\", NOT the bug"
metadata: 
  node_type: memory
  type: project
  originSessionId: ff3bb8f7-399c-4ece-a91b-10ea7048e80e
---

WF-CV (2026-06-13, top-1000-2000, 22 folds 2002-2024, `suppress_warmup_trading` off/on) **reverses the #1549 prior**. #1549 hypothesized the strategy's warmup-window trading was a bug (a 2009 fold's warmup straddled the GFC bottom → portfolio depleted to 35% before measurement). The flag (#1555) was built to test suppressing it. Verdict: **suppress FAILS the gate** (9/22 Sharpe wins, needs 11; worst fold Δ1.44≫0.30). Baseline (warmup trades = current default) mean Return 16.78% / Sharpe 0.372 / Calmar 0.955 vs suppress 6.82% / 0.252 / 0.640. 

WHY: warmup-trading is a **running start** — warm indicators let the strategy enter during the 210-day warmup and carry positions into the window. In GFC folds (006/2008, 007/2009) suppress *helps* as #1549 predicted (−12 vs −23, −2.4 vs −11), but in most BULL folds it *hurts* (misses the head-start), and bull benefit dominates. So #1549's degenerate fold is the **tail cost** of a net-beneficial always-invested behavior, not a systematic bug. Warmup-trading is also the more *realistic* measurement for a continuously-deployed strategy (you don't restart from cash each year).

DECISION: keep `suppress_warmup_trading` **default-off** (no goldens move). Flag stays a searchable axis (measure cash-restart / neutralize a specific crash-warmup fold). The right disposition for the #1549 degenerate fold is the `Fold_health` guard (now wired, #1558) — **detect** the rare crash-warmup fold, don't suppress warmup globally. 

IMPORTANT methodology note: the flag bites whenever the warmup window has WARM (fully-formed) indicators. Two cases: (1) WF folds — `warmup_start = fold_start − 210d` mid-data, always warm. (2) **Interior** scenario starts where the data warehouse extends before the start (e.g. rolling-start matrix interior starts: warmup_start mid-warehouse, snap floor 2010-06) — also warm. **Refined 2026-06-13** (corrects the earlier "scenario-level off/on is MOOT" claim, which holds ONLY for a *cold* start where start == warehouse floor, e.g. the warmup-comparison standalone cells / the matrix's earliest 2011 start = verified zero 2010 entries). Interior-start probe (2015, top-1000): OFF 24.9% vs ON 12.6% return (~2×) — NOT moot. So rolling-start matrices DO change under the flip ([[project-rolling-start-matrix-first-run]] now stale-semantics; re-run `dev/experiments/warmup-matrix-rerun-2026-06-13/`). Full writeup: `dev/experiments/warmup-comparison-2026-06-12/`. See [[project_exit_fill_reject_zombie]].
