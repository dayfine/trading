# Next-session priorities — 2026-06-22 PM (handoff)

**Supersedes** `next-session-priorities-2026-06-22.md`. Autonomous afternoon run
continuing the decline-character program. Main green throughout; 3 PRs merged.

## TL;DR — Build 3 is SCREENED end-to-end; the two flags split

The morning handoff's P0 (screen Build 3) is **done**, including the deep-regime
re-screen it called for. Three PRs landed:

| PR | What | State |
|---|---|---|
| #1707 | Build-3 **shallow** screen (2010-2026, bull-only) | merged |
| #1708 | Build-2 **arming-speed knob** `fast_v_arm_on_rate_alone` (default-off axis) | merged (3-gate) |
| #1709 | Build-3 **DEEP** screen (2000-2010, dot-com+GFC, 472-name PIT) | merged |

### The result that matters (PR #1709 deep screen)
On a survivorship-correct sp500-as-of-2000 universe across two real bears:
- **The short leg WORKS in bears** — un-gated long-short +148pp return (475.6 vs
  327.1 long-only), MaxDD 31.6→27.6, Sharpe 0.92→1.07, Calmar 0.45→0.62. This
  **corrects** the bull-only-window impression (#1678, the 2010-26 shallow screen)
  that "shorts don't work": they work in bears, get squeezed in bulls.
- **The two Build-3 flags have OPPOSITE verdicts:**
  - **`neutral_blocks_shorts` → KEEPER / PROMOTE-TRACK.** Inert in bears (all 18
    shorts already Bearish-tape; arm-02 ≡ baseline) + removes the bad bull-regime
    Neutral squeezes (shallow screen). **Strictly helpful-or-inert across both
    regimes** — could be the first short-side mechanism to clear.
  - **`enable_slow_grind_short_gate` → TAXES the edge / reject-as-is.** Cuts the
    short book 18→5, drops the JNS +$49K dot-com winner, return 475→367, Sharpe
    1.07→0.96; never beats neutral. Winner-touching tax on the short tail (short
    side of [[project_edge_is_the_fat_tail]]). Root cause: A-D leg inert
    (`~ad_bars:[]`) forces reliance on the strict weeks-below-MA≥8 leg, which
    misses fast 2008 legs. Revisit ONLY after Build 0 (A-D wiring).
- **Short edge is itself a fat tail:** GENZ shorted through the GFC = +$340K
  dominates the whole 18-short book.

Writeups: `dev/backtest/faithful-short-deep-screen-2026-06-22/FINDINGS.md` (deep)
+ `dev/backtest/faithful-short-screen-2026-06-22/FINDINGS.md` (shallow, corrected).

## Next steps (priority order)

### P0 — escalate `neutral_blocks_shorts` to WF-CV (the promote-track action)
It cleared both regimes in the screen (helpful-or-inert). Per
`experiment-gap-closing` → `promotion-confirmation.md`:
1. Build a `Variant_matrix` surface with the axis
   `((flag neutral_blocks_shorts) (values (true false)))` on a long-short base
   config (the `sp500-2010-2026-longshort` overlay).
2. Walk-forward CV across folds that include BOTH bull and bear regimes — the
   deep data is now local (see "Local data state"), so a 2000-2012 WF + a
   2010-2026 WF both work. Use the fork-per-fold N≥1000 path
   ([[project_laggard_broad_recheck]]) if the universe is broad.
3. Rank with Pareto + Deflated Sharpe. If it survives, run the macro-regime-
   diverse confirmation grid (a bull cell + a deep bear cell + a breadth cell)
   before flipping the default. **It is a SHORT-side gate, so a long-only/SPY
   cell is degenerate — every grid cell must enable shorts.**
Expectation from the screen: `true` should be ≥ baseline everywhere (removes bad
bull shorts, keeps all bear shorts). If WF-CV confirms, this is a default-flip
candidate (needs a ledger ACCEPT + the grid per `promotion-confirmation.md`).

### P1 — Build-2 arming-speed deep re-screen (validate #1708)
`fast_v_arm_on_rate_alone` (#1708) is built default-off but UNSCREENED. Its
canonical test is the **2020 fast-V** (where the catastrophic stop never fired due
to MA-arming latency — `fast-crash-stop-screen-2026-06-22/FINDINGS.md`). The local
`data/` deep fetch stops at **2012**, so 2020 is NOT covered yet.
- **Extend the fetch to 2021** (re-run the deep fetch with `to=2021-12-31` for the
  sp500-2000 + a sp500-2015 universe union) so `data/` spans 2008 AND 2020.
- Screen a 2×2: `catastrophic_stop_pct ∈ {0, 0.10}` × `fast_v_arm_on_rate_alone ∈
  {false, true}` on a 2018-2021 window. Hypothesis: arming on rate-alone lets the
  catastrophic stop fire BEFORE the structural gap-down in the 2020-V (the latency
  fix), capping the ~38% DD WITHOUT taxing the fat-tail winners elsewhere (it's
  armed only on Fast_v). Verify inert outside crashes. Apply screen-rigor.

### P2 — Build 0 (A-D wiring) — still needs oversight (re-pins goldens)
Wiring `Ad_bars.load` into `pipeline.ml:103` (replace `~ad_bars:[]`) activates the
A-D-lead leg of `Decline_character`. This would (a) make `slow_grind_gate` catch
distribution tops without the strict weeks-below-MA leg (potentially un-taxing it —
see P1's reject rationale), and (b) sharpen the classifier generally. **Behavior-
changing → golden re-pin → do attended, not a default-off drop.**

### P3 — barbell weight cert (unchanged from AM) — needs your weight mandate.

## Local data state (IMPORTANT for next session)
- The runner reads the **gitignored repo-root `data/`** (`default_data_dir`,
  override via `TRADING_DATA_DIR`) — NOT `trading/test_data`. Confirmed this
  session; it's why the shallow screen ran on only ~25 deep mega-caps.
- This session fetched **sp500-as-of-2000 (472/526 names) 1998-2012** into `data/`
  via EODHD (delistings retained at real death dates). **Side effect:** the ~25
  pre-existing deep mega-caps in `data/` were OVERWRITTEN to end-**2012** (lost
  their 2013-2026 bars). CI is unaffected (data/ gitignored; CI uses committed
  test_data), but **local 2013+ backtests on those names need a re-fetch.** The P1
  fetch-to-2021 would restore them.

## Process notes
- All 3 PRs were docs+fixtures or default-off code; #1708 cleared the full 3-gate
  (CI + qc-structural APPROVED + qc-behavioral score-5). A feat-agent jj-workspace
  desync (committed via parent) recurred — verified PRs uncontaminated + reset
  parent `@`; serialize jj-writing agents.

## State
Main green. 0 PRs open. Build 3 fully screened (verdicts above). Build-2 knob built,
unscreened. `neutral_blocks_shorts` is the live promote-track candidate.
