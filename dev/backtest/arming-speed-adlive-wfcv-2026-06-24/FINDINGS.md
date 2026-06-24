# `fast_v_arm_on_rate_alone` WF-CV — A-D-LIVE basis (2026-06-24)

The re-run the 06-22 work pointed to. The A-D-inert arming-speed WF-CV
(`dev/backtest/arming-speed-wfcv-2026-06-22/`) gave a weak ACCEPT (frontier-dominant,
tiny edge); the `fast_v_min_rate` threshold-surface REJECT
(`dev/backtest/fast-v-min-rate-surface-2026-06-22/`) concluded that catch-speed and
whipsaw-immunity ride the *same* 4-week rate signal, so **no rate threshold separates
them — only the A-D breadth lead could**. A-D is now the default basis (#1725) and the
deep `data/breadth/` store is populated, so this WF-CV asks: **does the now-live
A-D-lead leg let the Fast_v catastrophic stop arm cleanly (catch without whipsaw)?**

- **Spec:** `test_data/walk_forward/arming-speed-deep-2000-2026.sexp`.
- **Base:** `sp500-2000-2026-catstop` (deep long-only, `catastrophic_stop_pct=0.10` ON
  in every cell). Axis `((flag fast_v_arm_on_rate_alone) (values (true false)))`.
  Rolling 2000-2026, test 365 / step 365 → 26 OOS folds. **CSV on the deep repo-root
  `data/` with `data/breadth/` populated → A-D-LIVE** ("Loading AD breadth bars…"
  confirmed). 503/515 of sp500-2000-01-01 covered, delisted included.

## Result — still sub-promotable; A-D-live did NOT deliver the clean unlock

| Variant | Sharpe (μ) | Calmar (μ) | MaxDD % (μ) | Return % (μ) | Frontier | DSR |
|---|---|---|---|---|---|---|
| baseline (≡ false) | 0.562 | 1.030 | 9.95 | 9.30 | no | 0.9999 |
| **arm_on_rate=true** | **0.567** | **1.036** | **9.83** | **9.36** | **yes** | 0.9999 |

`true` is the sole Pareto-frontier member (marginally dominates baseline on
Sharpe/Calmar/MaxDD) but the edge is **negligible** (+0.005 Sharpe, −0.12pp MaxDD) and
DSR is **0.9999 = indistinguishable**. **Go/no-go gate FAIL: 1/26 Sharpe wins** (needs
14); worst fold (2010) trails by 0.0078.

## Per-fold — the knob fires in only 2 of 26 folds (24 byte-identical)

| fold | true | baseline | Δ return | Δ MaxDD | reading |
|---|---|---|---|---|---|
| **fold-020 (2020-V)** | 4.74% / DD 12.09 | 2.41% / DD 15.55 | **+2.33pp** | **−3.46pp** | the genuine fast-crash CATCH |
| **fold-010 (2010 chop)** | 11.48% / DD 12.80 | 12.26% / DD 12.45 | −0.78pp | +0.35pp | a recovering-dip WHIPSAW, persists |

All other 24 folds are byte-identical (Fast_v never arms outside a genuine fast
decline) — including the 2008 slow cascade (fold-008) and the 2022 grind, confirming
the mechanism is **fast-V-specific tail insurance**, not a slow-bear tool.

## What A-D-live actually changed (vs the A-D-inert 06-22 run)

The 06-22 A-D-**inert** run had `true` differing in **4/26** folds — catches 2020
(+3.0pp) **and 2018-Q4 (+1.2pp)**; whipsaws 2010 (−0.77) **and 2011 (−1.2)**.
A-D-**live** narrows this to **2/26**:

- **2011 whipsaw → GONE** (now byte-identical): the breadth lead correctly read the
  2011 dip as a recovering pullback and **didn't arm**. ✅ the hypothesis working.
- **2018-Q4 catch → GONE** (now byte-identical): the same conservatism dropped a real
  (smaller) catch. ❌ the hypothesis backfiring.
- **2020 catch KEPT**, **2010 whipsaw KEPT**.

So the A-D-lead leg makes arming **more selective on both sides** — it trims one
whipsaw *and* one catch — keeping the biggest catch (2020) and the stubborn 2010
whipsaw. **Net aggregate ≈ flat.**

## Verdict: NO promote — keep default-off axis (A-D-live retains the 06-22 weak status)

The transferable **why**: the A-D breadth lead is a *marginal selectivity refinement*,
**not** the decisive catch-vs-whipsaw separator the `fast_v_min_rate` REJECT
hypothesized. It correctly suppressed the 2011 false-arm but its added conservatism
also cost the 2018-Q4 catch, while the 2010 whipsaw survived (breadth there was weak
enough to arm anyway). The catastrophic stop's *aggregate* footprint is ~zero because
genuine fast-V crashes (2020) are rare and the mechanism is — by design — inert
everywhere else. This is the **same meta-pattern as every decline-character mechanism**
(`project_decline_character_builds`, `project_edge_is_the_fat_tail`): a faithful
tail-management tool with a narrow, regime-specific niche and a net-neutral aggregate —
correct to keep as a **default-off axis** (`catastrophic_stop_pct` armed on `Fast_v`,
the sanctioned tail-RISK insurance), never wired into the default config.

This **closes the loop** the `fast_v_min_rate` REJECT opened: A-D-live was the proposed
unlock for arming-speed; it helps at the margin but is not promotable. No further
arming-speed lever is indicated — the binding limit is that fast-V crashes are rare,
not that arming is mis-timed.

## Caveats
- A-D-live shifts the **whole strategy** per-fold (it sharpens the macro entry gate for
  baseline AND variant), so the absolute aggregate here (Sharpe 0.562) differs from the
  06-22 A-D-inert run (0.695). The clean comparison is *within* this run (true vs
  baseline, both A-D-live), which is what the gate evaluates.
- Deterministic engine: 24/26 byte-identical folds confirm reproducibility (no noisy
  pins). Static sp500-as-of-2000 universe, 26 annual folds.

Ledger: `dev/experiments/_ledger/2026-06-24-arming-speed-adlive-wfcv.sexp`.
