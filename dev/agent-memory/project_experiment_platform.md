---
name: project_experiment_platform
description: Systematic experiment-platform program — make discrete feature/mechanism exploration systematic via variant matrices + WF-CV + ledger + DSR + a skill
metadata: 
  node_type: memory
  type: project
  originSessionId: 06e65263-c45b-4e42-8886-80b198264969
---

Program started 2026-05-29 PM after the stage3-hysteresis WF-CV rejection
([[project_stage3_hysteresis_rejected_wfcv]]) exposed how ad-hoc exploration
still is (tested one point, never a surface). Plan:
`dev/plans/experiment-platform-2026-05-29.md` (#1368). Track status:
`dev/status/experiment-platform.md`.

**Core reframe:** the continuous 11-knob *value* surface is already searched
(BO program `tuning-research-driven-program-v2`) and proven **flat** (v6:
GP-EI ≈ random, Cell E = meta-overfit local max). The unsearched lever is the
**discrete feature/mechanism space** — which `enable_*` code paths are active,
in what combination, with coarse values. "The module is the knob." This program
is the discrete-combination complement to the BO program (shares DSR, tiered
folds — not a replacement).

**Gaps + status:**
- A. Variant-matrix generator — **DONE, PR-1 #1369.** `Walk_forward.Variant_matrix`:
  declare `axes` (key-path or flag + values) + `expansion` (Cartesian | Sampled
  {n;seed}) → expands into the WF `variants` list; validates every generated
  override against the default config via `Overlay_validator` at expansion time
  (raises on typo'd key — the 2026-05-12 81-cell silent-drop guard). Optional
  `axes` block on `Walk_forward.Spec.load`; backward-compatible.
- B. Loud override validation — already shipped (#1069), reused by A.
- E. Flag-discipline rule — **DONE, PR-1.** `.claude/rules/experiment-flag-discipline.md`:
  every new mechanism lands behind a default-off flag; becomes an axis the day it
  lands; not wired into default config until an ACCEPT verdict in the ledger.
- D. Experiment ledger — **TODO PR-2.** `dev/experiments/_ledger/` append-only
  per-experiment sexp + index, config-hash dedup; retro-seed known rejections
  (hysteresis ×2, continuation-combo, M5.5 4-axis, laggard-disable).
- C. Matrix ranking + Deflated Sharpe — **TODO PR-3.** Best-of-N = N trials →
  DSR deflation + Pareto rank over (Sharpe, MaxDD, Calmar) on top of `Fold_gate`.
  Shares DSR module with BO program (M3).
- F. Experimentation skill — **DONE, #1374.** `.claude/skills/experiment-gap-closing/SKILL.md`
  (invocable). Encodes the loop: gap → hypothesis → axes → check ledger → matrix
  → WF-CV → DSR/Pareto rank → verdict → ledger append → promote winner → memory.

**Platform built-out COMPLETE (Gaps A–F all merged: #1368/#1369/#1371/#1372/#1374).**

**First real use — DONE (#1375, 2026-05-30):** swept the autopsy exit-timing
knobs as a *surface* (hysteresis_weeks {1,2,3} × stage3_exit_margin_pct
{0.0,0.02,0.05}, 31 folds). **REJECTED the whole surface** — every cell ≤
baseline on mean Sharpe/Calmar/return, monotonically degrading; best cell 4/31
Sharpe wins; no cell raw-beats baseline (no DSR candidate). The autopsy's
exit-timing missed gain is NOT recoverable by these knobs — far more decisive
than the single-point rejection. Recorded in the ledger
(`2026-05-30-exit-timing-surface.sexp`). Writeup: `dev/notes/exit-timing-surface-2026-05-30.md`.
Validated the platform end-to-end (unattended hypothesis→surface→310 backtests
→ranked verdict→ledger). **Next gap-closing target: a DIFFERENT mechanism class**
— exit-timing is exhausted (e.g. autopsy `late_stage2_admission` entry-timing, or
cross-sectional rotation), run through the same loop.

Distinct from the promoted-configs repo (`private-tuned-configs-repo-2026-05-18.md`,
deferred): the ledger = *everything tried + verdicts* (in-repo); that repo =
*blessed winners + provenance* (private).
