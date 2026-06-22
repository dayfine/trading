---
name: project_decline_character_builds
description: "The decline-character idea (slow-grind vs fast-V) is built — classifier + 2 branches, all default-off, on main as of 2026-06-22"
metadata: 
  node_type: memory
  type: project
  originSessionId: a597a2cb-6465-49c3-a8ba-4a906ced022d
---

The 2020-crash discussion (long side exits a fast-V ~3-4wk late at the bottom,
eats ~38% DD; shorts squeezed in the V) produced a shared primitive + two branches,
**all default-off**, merged 2026-06-22:

- **#1692 Build 1 — `Decline_character` classifier** (`Slow_grind | Fast_v |
  Not_declining`), pure/lookahead-free, `trading/analysis/weinstein/macro/lib/decline_character.mli`.
- **#1695 Build 2 — fast-crash absolute stop** `catastrophic_stop_pct` (default 0.0),
  armed ONLY on `Fast_v` (tail-RISK insurance, dormant in normal tapes; the sanctioned
  winner-touching exception per [[project_edge_is_the_fat_tail]]). Lookahead-free via a
  `prior_decline_character` ref consumed before the macro step. `catastrophic_stop.mli`.
- **#1696 Build 3 — faithful short** `neutral_blocks_shorts` (Bearish-only) +
  `enable_slow_grind_short_gate` (both default false = prior behavior). Fixes the
  short-gate that fired in Neutral chop (the 2020-V squeeze, corrects the #1678 NO-BUILD
  which was run on a semi-faithful gate: shorts admitted `Bearish|Neutral`, not bears-only).

**Honesty caveat (gates the payoff):** the novel A/D-LEAD input is NOT wired — pipeline
still passes `~ad_bars:[]` (`snapshot_pipeline/lib/pipeline.ml:103`). The classifier runs
on its computable-now legs (rate-of-decline = Build 2's Fast_v; weeks-below-declining-MA =
Build 3's Slow_grind). Wiring real A/D (Build 0) CHANGES macro behavior → re-pins goldens →
needs oversight, NOT a default-off drop.

**NOT yet validated** — all three are unproven default-off axes. Next: SCREEN each (flag
on/off, regime-decomposed, screen-rigor) → WF-CV → promotion grid. Plan +
exact next steps: `dev/notes/next-session-priorities-2026-06-22.md` +
`dev/notes/decline-character-exploration-2026-06-21-PM.md`. Barbell `floor_weight` axis
landed via #1697 (orchestrator) — P0.2 cert ready, weight choice is user-mandate.

**Build-2 screen result (2026-06-22, `dev/backtest/fast-crash-stop-screen-2026-06-22/FINDINGS.md`,
PR #1703):** the fast-crash stop **NEVER FIRED** — all `catastrophic_stop_pct ∈
{0,.08,.10,.12}` byte-identical. WHY: `Fast_v` arms only with the index *below a
falling MA* (+4wk drawdown), which in 2020 wasn't true until ~mid-March — by then the
structural **gap-down `stop_loss` already exited every long** (Feb 28–Mar 13). **The
binding constraint is arming LATENCY, not stop width.** Verdict = needs-different-test-design
(not reject). Forward: the real lever is **`Decline_character` arming SPEED — arm `Fast_v`
on rate-of-decline ALONE, drop the falling-MA precondition for the fast-V path** — NOT
`catastrophic_stop_pct`. Also re-run on a broad PIT universe (survivors exit clean; the
longs that ride to the bottom live in the broad tail). Caveat: 27-name survivor universe
only saw -13.8% DD (not the motivating -38%).
