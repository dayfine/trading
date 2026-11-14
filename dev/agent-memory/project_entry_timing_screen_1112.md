---
name: project-entry-timing-screen-1112
description: "11-12 per-trade screen on record rk k0-k4 (2,756 trades): skip-extended, range-top anchor, MA-pullback all NO-BUILD (fat tail); stale-E cap (min(E, 4wk high x1.005)) +7..+12 NAV-% 5/5 seeds -> escalate"
metadata:
  node_type: memory
  type: project
  originSessionId: 249246cf-fc3d-457f-8536-5d3b905a45a5
  modified: 2026-11-13T05:54:11.790Z
---

Prompted by the DIS 2000 walkthrough (entry 37.23 vs book 30 3/8, stopped on the pullback). Host-only replay
`dev/experiments/entry-timing-screen-2026-11-12/` (run.sh, sh+awk; merged 11-13 as #3594 7aa1ffcc4 after a QC rework; ledger slugs entry-timing-screen + stale-e-cap-screen), weekly WMA-30 matched audit ma_value on
2,756/2,756 trades; null control (code's own E through the replay fill model) reproduces the fill day 92.8 %.
Unit = NAV-% (sum P&L / NAV at screen); a seed's realised total is 256-322.

- **H1 skip if screen close > X over MA: NO-BUILD.** Negative at every X in 5/5 seeds (X=20 %: -48..-60, 3-4
  monsters lost). Win rate falls 46 % -> 12.5 % with extension, but the >=50 % bucket earns most per trade
  (+2.16, 10/80 doubled: APPS 51.1 %, BBWI 50.8 %). Band 30-50 % looks +7..+20 but 30-60 % is -29..-42 = knife
  edge on two names. Re-derives [[project_entry_shape_gates_no_build]] / [[project_edge_is_the_fat_tail]].
- **H2 E = last-N-week high x 1.005 (what `entry_anchor_local_range_weeks` does -- it REPLACES E): NO-BUILD.**
  -57..-121 per seed, all N; 2,188/2,688 code E's already sit BELOW the 4-wk high (code buys cheaper), the anchor
  demands a new high and a third never fill. Consistent with ladder-v4 anchor-w8 reversing; the flag is KEEP-AXIS and
  was already diluted for real (entry-anchor-recovery-2026-10-02, 3/3 salts both windows).
- **H2' cap stale E only (E' = min(E, 4-wk high x 1.005)): ESCALATE.** +11.6/+7.3/+6.8/+12.0/+9.7 (5/5), 78-90
  better vs 4-9 worse, k0 90 % CI [+2.2, +22.1], 2-5 % of realised. Never-filled stale tickets that would fill:
  17-24/seed, proxy -0.9..+5.7 (no flip). Two channels (#3594 QC): replay sizes at 1 % NAV risk off the lowered trigger, so the cap buys more shares
  (median +10 %, p90 +28 %); price paid +2.7..+6.5, larger size +3.0..+7.7 = 37-66 % of the gain (`results/sizing.txt`).
  Price alone positive 5/5, so escalation stands, but a cash-limited book can eat the size half: the K=5 run must
  report the split. New flag needed (no knob does min). This is the trigger half of
  [[project_entry_E_stale_high_bug]]. Gap: portfolio/cash effects -> needs K=5 paired backtest.
- **H3 buy-limit at MA x (1+m) for 8 wk when screen > 20 % over MA: NO-BUILD.** Fills (~17 %) beat the control
  (+40 pooled) but ~80 % never pull back and carry +23..+49/seed incl. monsters: pullbacks select the weak names.

**Why:** extension and stale-anchor losses are the same tickets as the monsters; only a rule that changes price
and position size without changing WHICH names fill (the cap) survives. **How to apply:** don't re-screen skip/anchor/pullback
variants; the next step is a default-off stale-E-cap flag + K=5 paired run. Artifact
https://claude.ai/artifact/2hqayoBnVnFkpskr5pqqQQ (per-trade charts for all k0 trades).
