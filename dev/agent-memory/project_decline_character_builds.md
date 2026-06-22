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

**Build-3 screen result (2026-06-22, `dev/backtest/faithful-short-screen-2026-06-22/FINDINGS.md`,
PR #1707 MERGED):** 5-arm SP500 2010-2026 CSV screen (long-only ref / un-gated longshort /
+neutral_blocks_shorts / +slow_grind_gate / +both). **All 3 faithful gates admit ZERO shorts →
byte-identical (md5) to long-only.** The entire un-gated short book = **5 early-2010 Stage-4
squeeze losses** (net -$33.7K; baseline 47.9% vs long-only 53.5%, MaxDD 12.9 vs 10.6). Gates are
**SAFE + faithful** (remove exactly the un-faithful squeeze shorts; gate decision is macro/index-
driven = universe-independent, robust to the 309/510 decimated data) but **benefit UNTESTABLE on
2010-2026** (no 2000-02/2008 slow-bear regime to keep profitable shorts; the only shorts that
occurred were V-recovery squeezes the gate rightly skips). Verdict = **NEEDS-DEEP-DATA**, not
reject/promote. Mirrors Build-2 exactly. Re-screen on deep 1998-2010 PIT (dot-com+GFC) — same
fetch unblocks both deep re-screens.

**Build-2 arming-speed knob BUILT (2026-06-22, PR #1708 MERGED):** `fast_v_arm_on_rate_alone`
(`Weinstein_strategy.config`, default-off → Variant_matrix axis) + classifier field
`Decline_character.config.fast_v_ignores_ma_filter`. When on, `Fast_v` arms on rate-of-decline
alone (drops the falling-MA precondition that caused the mid-March latency). Default-off =
bit-identical, no golden re-pin. 3-gate clean (CI + structural + behavioral score-5). This is the
"real lever" the Build-2 screen pointed to — now landed safe, ready to screen once deep data lands.

**Build-3 DEEP re-screen DONE (2026-06-22, PR #1709, `dev/backtest/faithful-short-deep-screen-2026-06-22/FINDINGS.md`):**
fetched survivorship-correct sp500-as-of-2000 PIT (472/526 names, 1998-2012 EODHD incl. delisted
LEH/BS/AIG) into gitignored `data/`, ran the 5 arms over 2000-2010 (dot-com+GFC). THE RESULT THAT
MATTERS:
- **In real bears the short leg WORKS** — un-gated long-short +148pp return (475.6 vs 327.1 long-only),
  MaxDD 31.6→27.6, Sharpe 0.92→1.07, Calmar 0.45→0.62. Corrects the bull-only-window impression
  (#1678, the 2010-26 shallow screen) that "shorts don't work": they work IN BEARS, get squeezed in bulls.
- **The two Build-3 flags SPLIT — opposite verdicts:**
  - `neutral_blocks_shorts` = **KEEPER / PROMOTE-TRACK**: inert in bears (all 18 shorts already
    Bearish-tape, arm-02≡baseline) + removes the bad bull Neutral squeezes (shallow screen). Strictly
    helpful-or-inert across both regimes. → escalate to WF-CV + `promotion-confirmation` grid. Could be
    the FIRST short-side mechanism to clear.
  - `enable_slow_grind_short_gate` = **TAXES THE EDGE / reject-as-is**: cuts shorts 18→5, drops the
    JNS +$49K dot-com winner, return 475→367, Sharpe 1.07→0.96; never beats neutral. Winner-touching
    tax on the short tail (short-side [[project_edge_is_the_fat_tail]]). Root cause = A-D leg inert
    (ad_bars:[]) forcing the strict weeks-below-MA≥8 leg which misses fast 2008 legs. Revisit ONLY
    after Build 0 (A-D wiring).
- **Short edge is itself a fat tail**: GENZ shorted through the GFC = +$340K dominates the whole
  18-short book. Regime governs the short leg ([[project_factor_lens_regime_governs_edge]]) → the
  right lever is a macro/tape gate (neutral_blocks_shorts), NOT a decline-shape gate (slow_grind).

**Runner reads gitignored repo-root `data/`** (NOT trading/test_data) — default_data_dir, override via
TRADING_DATA_DIR. data/ had only ~25 deep mega-caps before this fetch (why the shallow screen was so thin).

**Still open:** Build-2 arming-speed re-screen (needs the same deep data — now present in data/, ready to
run a fast-crash-stop deep screen). neutral_blocks_shorts → WF-CV. A/D Build 0 needs oversight. Barbell
70/30 cleared its grid ([[project_barbell_on_stocks]]).
