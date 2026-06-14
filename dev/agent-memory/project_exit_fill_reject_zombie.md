---
name: project-exit-fill-reject-zombie
description: Issue
metadata: 
  node_type: memory
  type: project
  originSessionId: ff3bb8f7-399c-4ece-a91b-10ea7048e80e
---

Issue #1553 (THM short rode 0.69→2.35 unstopped) root-caused 2026-06-12: stop REGISTERED+FIRED correctly (2022-11-10), but the cover BUY was rejected by `Portfolio.apply_single_trade` cash floor (`portfolio.ml:338-350` subtracts negative unrealized P&L in bear), `simulator.ml:349-365` `_apply_trades_best_effort` silently dropped it, `cancel_handler.ml` only reverts **Entering** (#1172 fixed entry side only) → position stuck `Exiting`; `stops_runner.ml:207` only re-evaluates `Holding`. Bug class: ANY cash-floor-rejected exit fill (long or short, any date) creates a zombie. Warmup-entry hypothesis REFUTED (PR #1549 G2 classification of this position was wrong); P0 warmup flag does NOT fix it. Fix dispatched 2026-06-12: `feat/exit-fill-reject-retry` (Exiting→Holding revert = natural retry + WARN on dropped fills + fold_health divergence signature). Open decision items: CancelExit core transition; cash-floor exemption for risk-reducing closing trades (links #1546 stale-cash-floor MaxDD>100% finding). See [[project_trade_forensics_2026_06_12]].
