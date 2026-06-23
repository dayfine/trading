# Next-session priorities — 2026-06-22 EOD (handoff)

**Supersedes** `next-session-priorities-2026-06-22-PM.md`. A 4-6h autonomous deep
run on top of the morning/PM work. Main green throughout; **11 PRs merged this
session** (#1707-1709, 1711-1717). The decline-character program is now validated
end-to-end with honest, disciplined verdicts.

## TL;DR — both Build-3 short flags and Build-2 arming-speed are fully validated; neither auto-promotes; Build 0 is the unlock

| mechanism | status | verdict |
|---|---|---|
| **Build-3 `neutral_blocks_shorts`** | WF-CV cell-1 ACCEPT, grid cell-2 disagrees | **No EDGE flip** (regime-dependent) — but a **faithfulness/asymmetry flip is on the table** (user mandate, see §Decision) |
| **Build-3 `enable_slow_grind_short_gate`** | deep-screen REJECT-leaning | Taxes the short tail (A-D-inert over-restricts); revisit after Build 0 |
| **Build-2 `fast_v_arm_on_rate_alone` (#1708)** | WF-CV weak ACCEPT | Frontier-dominant but small; fast-V-specific (inert in 2008 cascade); whipsaws chop |
| **`fast_v_min_rate_pct` axis (#1716)** | threshold surface REJECT | 0.08 optimal; catch & whipsaw coupled on one signal — no tuning gain |

**The recurring conclusion: Build 0 (A-D breadth wiring) is the highest-value next
lever.** It is the unlock for BOTH open short/crash mechanisms:
- `slow_grind_gate` over-restricts because its A-D leg is inert (`~ad_bars:[]`), so
  it leans on a too-strict weeks-below-MA leg.
- arming-speed can't separate the 2020 catch from the 2010/2011 whipsaw with the
  rate signal alone (`fast-v-min-rate-surface`); the A-D-lead is the signal that
  distinguishes crash-that-keeps-falling from dip-that-recovers.

## ⭐ Decision awaiting you: flip `neutral_blocks_shorts` default-on?

The grid said **no flip on EDGE grounds** (true is flat-to-fractionally-worse in
the bull cell). But in discussion you raised a different, valid basis:
- We already have stage classification (bull/bear tape); in a **Neutral** tape,
  **sidelining (not shorting) is an acceptable conservative default**.
- The cost is **asymmetric and favourable**: forgoing a Neutral short costs only a
  thin opportunity (2019: −0.96pp MaxDD); taking one that squeezes costs real money
  (2003/2010). Flat mean, favourable tail.
- It is **strictly more Weinstein-faithful** (short only confirmed Stage-4 bears).

So `neutral_blocks_shorts=true` is defensible **as the default on faithfulness +
tail-asymmetry grounds**, not edge grounds. This is a mandate call.
- **If you say go:** I flip the default (`weinstein_strategy_config.ml`), re-pin the
  affected long-short goldens, and cite cell-1 ACCEPT + the asymmetry (the grid's
  "no edge win" stays honestly documented — it's a faithfulness flip, not an alpha
  flip). Behavior-changing → attended.
- **Tape vs decline-character (the distinction):** `neutral_blocks_shorts` gates on
  the **tape** (bull/bear). `slow_grind_gate` gates on **decline shape** (grind vs
  crash) — a *finer* cut that catches squeezes *within* a bear (2020 was Bearish-tape
  AND a fast-V). They stack: tape decides whether the regime allows shorts;
  decline-character decides which shorts inside it are squeeze-traps.

## Next steps (priority order)

### P0 — Build 0: wire real A-D breadth (`Ad_bars.load` → `pipeline.ml:103`)
This session produced two independent pieces of evidence that Build 0 is the
unlock (slow_grind over-restriction + arming-speed catch/whipsaw coupling).
**Behavior-changing** (activates the A-D-Line macro indicator → macro trend shifts
→ entries/exits change → goldens re-pin). Do attended, behind the existing
`skip_ad_breadth` flag. After it lands: re-run the `slow_grind_gate` deep screen +
the arming-speed WF-CV — the A-D-lead leg may separate the cases the rate signal
can't. Synthetic ADL generator: `trading/analysis/scripts/compute_synthetic_adl`.

### P1 — `neutral_blocks_shorts` default-on flip (if you mandate it, §Decision above)

### P2 — decline-character short-gate, re-tested post-Build-0
`slow_grind_gate × fast_v_min_rate_pct` surface on the deep long-short base, once
A-D is live. The threshold axis exists (#1716). The hypothesis: a tuned,
A-D-informed decline-character gate recovers the "short grinds, skip crashes"
separation the un-tuned version couldn't.

### P3 — barbell weight cert (unchanged) — needs your weight mandate.

## Experiment ledger (4 entries this session)
- `2026-06-22-neutral-blocks-shorts-wfcv.sexp` — ACCEPT (cell 1, helpful-or-inert)
- `2026-06-22-neutral-blocks-shorts-grid.sexp` — Reject(promotion) (grid disagrees → no edge flip)
- `2026-06-22-arming-speed-wfcv.sexp` — ACCEPT (weak, frontier-dominant)
- `2026-06-22-fast-v-min-rate-surface.sexp` — Reject (tuning; 0.08 optimal, catch/whipsaw coupled)

## Local data state (IMPORTANT)
- Runner reads gitignored repo-root **`data/`** (`default_data_dir`; `TRADING_DATA_DIR`
  to override) — NOT `trading/test_data`.
- This session fetched the **union of sp500-2000/2010/2015/2020 PIT universes +
  ETFs + ^GSPC, full 1998-2026 (731 names)** into `data/` via EODHD (delistings
  retained at death dates). The earlier truncation-to-2012 is RESTORED. This deep
  store backs all the WF-CV bases; it is gitignored (not committed). A fresh
  checkout / cleaned `data/` must re-fetch.

## Fixtures added this session (committed)
- Bases: `sp500-2000-2026-longshort`, `sp500-2000-2026-catstop`,
  `sp500-2000-2026-catstop-armon`.
- WF specs: `neutral-blocks-shorts-deep-2000-2026`, `neutral-blocks-shorts-cell2-2010-2026`,
  `arming-speed-deep-2000-2026`, `fast-v-min-rate-surface-2000-2026`.
- Screen scenarios: `faithful-short-{,deep-}screen-2026-06-22`,
  `build2-arming-speed-screen-2026-06-22`.

## State
Main green. 0 PRs open. Code on main: #1708 (`fast_v_arm_on_rate_alone`) + #1716
(`fast_v_min_rate_pct`) — both default-off axes, no behavior change. All mechanisms
remain default-off. The one pending behavior change is the optional
`neutral_blocks_shorts` faithfulness flip (your call).
