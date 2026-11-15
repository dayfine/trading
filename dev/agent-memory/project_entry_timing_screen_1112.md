---
name: project-entry-timing-screen-1112
description: "11-12 screen: H2' stale-E cap +7..+12 NAV-% escalated; K=5 26y (11-14): cap as built NO-BUILD (-0.82 log, DD 41-45 %: gate's bear brake removed + monsters crowded out); gate-held G flat/INCONCLUSIVE; stop the line"
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

**K = 5 26y outcome (2026-11-14; pre-registration #3608 at aab060262; results PR stale-e-cap-k5): NEITHER PASSES — stop the stale-E line.**
- **C, the cap as built (`entry_cap_local_range_weeks 4`): NO-BUILD by the harm bar.** Median Δ ln(1+R) −0.819, 0/5 seeds positive (−0.60..−0.93); max DD 25–32 % → 41–45 %; CAGR −2.5..−3.9 pp/yr.
- **G, cap + `entry_cap_stop_gate_on_uncapped` (#3609): INCONCLUSIVE.** Median −0.038, 2/5 up; D > 0 in 2/5. C vs G "admissions cost".
- **Why C lost:** the 15 % gate read from the capped E′ admits ~660 names/seed (~25/yr). The gate is the book's **bear brake**: S's 2001/2002/2008 lists show 15–19 gate skips per placed ticket and S entered nothing in 2008; C bought 20–23 names in the spring-2008 rally (macro gate open), 0 won; its max DD is one episode in every seed, 2007-07-19 → 2009-07-08. In normal years the admissions fill the book (70 % invested, 7.5 positions vs 56 %, 5.3) and crowd out S's monsters (ADSK 2003, APPS 2020, MMYT 2023: −101.5 NAV-%/seed). On their own the admissions net +64..+88/seed (win the V-recoveries 2003+2009, lose the bears) but run median −5 %/trade, p25 a full stop.
- **Why G is flat:** same-week re-pricing pays +4.2..+5.8 NAV-%/seed (~+0.05 log/26y), but a lower trigger also fills earlier and laggard rotation (hysteresis 2, 13-week RS) ejects the early fill inside the unbroken base: ROL 2016-09-02 (G week 0, rotated after 26 d at −0.6 %; S filled on the breakout 7 weeks later, +52 %) = −4.79/seed and decides the D bar (ex-ROL D > 0 in 4/5). The 11-12 screen held exits fixed: 60–72 % of its H2′ gain was earlier fills credited with the null's exit.
- **How to apply:** the "Why" above ("only a rule that changes price/size without changing WHICH names fill survives") was wrong for the cap — it changes which names fill (gate) and when (timing). Don't revisit stale-E / cap / anchor levers; the stale E is load-bearing. Entry-timing screens replay exits from the moved fill (laggard rotation included). Any lever that moves the gate's effective distance is read for positions count, by-year admissions and the S tickets it crowds out. Related: [[project_max_stop_filters_structural_stops]], [[project_entry_anchor_stale_e]], [[project_recovery_reentry_gap]], [[project_record_gap_is_concentration]].
