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

**FULL VALIDATION ARC (2026-06-22 deep run, 11 PRs #1707-1717, master deep-data fetch 1998-2026
731 names into gitignored data/):**
- **neutral_blocks_shorts**: WF-CV cell-1 (2000-2026 all-regime) ACCEPT (helpful-or-inert, 25/26 folds,
  won 2003 squeeze); confirmation-grid cell-2 (2010-2026 bull) DISAGREED (flat-to-fractionally-worse) →
  **NO EDGE flip** (regime-dependent). BUT user raised a faithfulness/asymmetry basis: sidelining shorts
  in a Neutral tape is an acceptable conservative default (forgoing a Neutral short costs a thin opportunity;
  a squeezed short costs real money — favourable tail at flat mean) + it's strictly more Weinstein-faithful
  (short only confirmed bears). So a **default-on flip is on the table as a MANDATE call (faithfulness, not
  edge)** — PENDING user go. Ledgers: 2026-06-22-neutral-blocks-shorts-{wfcv,grid}.
- **fast_v_arm_on_rate_alone (#1708)**: WF-CV weak ACCEPT (frontier-dominant but small; WINS fast-V crashes
  2020/2018-Q4, WHIPSAWS choppy chop 2010/2011, INERT in the 2008 slow cascade — confirms Fast_v is
  crash-specific, not a slow-bear tool). Exposed fast_v_min_rate_pct as an axis (#1716, full 3-gate).
  Threshold SURFACE {0.08,0.12,0.16} → REJECT tuning: 0.08 optimal; raising it suppresses the whipsaw BUT
  kills the catch (2020 reverts to gap-down) — catch & whipsaw ride the SAME 4-week rate, no threshold
  separates them. Ledgers: 2026-06-22-arming-speed-wfcv + fast-v-min-rate-surface.
- **slow_grind_gate**: deep-screen REJECT-leaning (taxes the short tail; A-D-inert over-restricts).

**BUILD 0 DONE (2026-06-22, PR #1719, dev/backtest/build0-ad-breadth-2026-06-22).** It was a DATA gap
NOT a wiring gap: runner.ml:_load_ad_bars ALREADY calls Ad_bars.load ~data_dir (skip_ad_breadth=false
default); A-D was inert only because data/breadth/ was empty (Ad_bars.load returns [] on missing files).
Fix = generate synthetic ADL into data/breadth (compute_synthetic_adl.exe -data-dir data; 1998-2026,
0.92-0.93 corr vs official NYSE) + seed committed Unicorn CSVs. NO code change, NO golden re-pin (breadth
CSVs gitignored). pipeline.ml:103's ~ad_bars:[] is a SEPARATE snapshot-confidence-field path, not the
CSV-mode strategy path. **PAYOFF (faithful-short deep 2000-2010, A-D-live vs A-D-inert):** (1) the WHOLE
strategy lifts — long-only +92pp (327→419), -4pp DD, Sharpe 0.90→1.04 (A-D sharpens the MACRO ENTRY GATE,
biggest effect measured); (2) slow_grind_gate FLIPS from taxes-the-edge (367 vs 475 ungated) to
BEST-CALMAR (0.745) / BEST-DD (22.9%) — keeps 6 shorts net +$432K vs ungated 25 net +$203K (A-D-lead leg
selects genuine bear shorts, the separation the rate signal couldn't make). slow_grind now WF-CV-worthy
(running A-D-live WF-CV). **TWO DECISIONS for user: (A) make A-D-live the DEFAULT basis = commit breadth
to test_data + re-pin ALL goldens (attended, behavior-changing, well-motivated now); (B) every WF-CV this
session was A-D-INERT (old basis) — re-run on A-D-live before promotion (neutral likely holds=inert,
slow_grind clearly changes, arming-speed catch/whipsaw separation may now be possible).** Doing B-for-slow_grind
first (confirm before re-pin).

**(superseded) THE UNLOCK = BUILD 0 (A-D breadth wiring, Ad_bars.load → pipeline.ml:103).** Two independent pieces of
this session's evidence point to it: (a) slow_grind over-restricts because its A-D leg is inert; (b)
arming-speed can't separate the 2020 catch from the 2010/2011 whipsaw with rate alone — the A-D-LEAD is
the signal that distinguishes crash-that-keeps-falling from dip-that-recovers. Build 0 is behavior-changing
(re-pins goldens) → attended. After it: re-run slow_grind screen + arming-speed WF-CV. This is the P0 next
lever. Handoff: next-session-priorities-2026-06-22-EOD.md. Barbell 70/30 grid-passed ([[project_barbell_on_stocks]]).

**UPDATE 2026-06-24:** (1) A-D-live became the DEFAULT basis — decision (A) above shipped via #1725
(committed synthetic breadth to test_data + re-pinned goldens; confirmation-grid 3/3 PROMOTE) — see
[[project_ad_default_flip]]. (2) The A-D-live re-runs (decision B) are mostly DONE: slow_grind_gate
A-D-live WF-CV → NO-promote (regime-dependent, sub-promotable; `dev/backtest/slow-grind-adlive-wfcv-2026-06-22`,
ledger 2026-06-22-slow-grind-adlive-wfcv); neutral_blocks_shorts stays ≈ungated even A-D-live. The ONLY
not-yet-done, evidence-backed slice = the **fast_v arming-speed surface on A-D-live** (the fast_v_min_rate
REJECT named the A-D-lead as the unlock for the catch/whipsaw separation). (3) **DONE 2026-06-24 → NO-promote**
(`dev/backtest/arming-speed-adlive-wfcv-2026-06-24/`, ledger 2026-06-24-arming-speed-adlive-wfcv). Ran
`arming-speed-deep-2000-2026.sexp` on the A-D-live deep basis (repo-root `data/` intact — the earlier "data
gone" was a `trading/data/` vs repo-root path mix-up; 735 syms 1998-2026, breadth populated). RESULT: gate
FAIL (1/26 Sharpe wins), DSR 0.9999 indistinguishable, frontier-dominant but negligible (+0.005 Sharpe). A-D-live
narrowed the knob from 4/26 folds (inert) to **2/26**: suppressed the 2011 whipsaw (hypothesis working) BUT also
dropped the 2018-Q4 catch (same conservatism); KEPT 2020 catch (+2.33pp/-3.46pp DD) + 2010 whipsaw. So the
A-D breadth lead is a MARGINAL selectivity refinement, NOT the decisive catch-vs-whipsaw separator — the
fast_v_min_rate-REJECT unlock hope is CLOSED. Binding limit = fast-V crashes (2020) are RARE → aggregate
footprint ~zero by design. Stays default-off axis (faithful tail-RISK insurance). **The whole decline-character
program is now exhausted**: classifier + fast-crash stop + faithful shorts + arming-speed all = faithful
narrow-niche tail tools, none promotable; A-D-live itself (the broad macro-gate sharpening) WAS the one
promotable outcome and shipped as the #1725 default flip. (Data run inline in MAIN session — repo-root `data/`
is gitignored, invisible to worktree-isolated agents; EODHD secrets gone but bars already fetched.)

**KEY meta-pattern (both short/crash mechanisms): faithful tail-management tools with narrow regime-specific
niches and small/regime-dependent aggregate edges — NOT robust standalone alpha.** Consistent with
[[project_edge_is_the_fat_tail]] (the edge is the long fat tail; these are insurance/hygiene layers) +
[[project_factor_lens_regime_governs_edge]] (the short leg's value is regime-governed). The disciplined
outcome: keep them as faithful default-off axes; the one promotable-by-mandate exception is
neutral_blocks_shorts on faithfulness grounds.
