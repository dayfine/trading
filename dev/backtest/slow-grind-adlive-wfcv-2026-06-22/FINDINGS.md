# `slow_grind_gate` WF-CV — A-D-LIVE basis (2026-06-22)

The Build-0 follow-up. The A-D-live deep screen
(`dev/backtest/build0-ad-breadth-2026-06-22/`) showed `slow_grind_gate` flipping
from "taxes the edge" to **best-Calmar / best-DD** on the single 2000-2010 window.
This WF-CV asks whether that holds across rolling OOS folds, now that the
A-D-lead leg is live (`data/breadth/` populated).

- **Spec:** `test_data/walk_forward/slow-grind-gate-adlive-2000-2026.sexp`.
- **Base:** `sp500-2000-2026-longshort` (deep long-short). A-D-live `data/`. Axis
  `enable_slow_grind_short_gate ∈ {true, false}`. Rolling 2000-2026, 26 folds.

## Result — does NOT hold per-fold; the single-window Calmar was a cumulative artifact

| Variant | Sharpe | Calmar | MaxDD % | return mean |
|---|---|---|---|---|
| baseline (≡ false) | **0.661** | **1.152** | 10.93 | 10.12% |
| slow_grind=true | 0.612 | 1.064 | **10.61** | 9.18% |

Across 26 folds, `true` is **lower on Sharpe AND Calmar** and only marginally
better on raw per-fold MaxDD (10.61 vs 10.93 — the weakest axis). The single-window
"best Calmar 0.745" was driven by `slow_grind` avoiding one big **multi-year
cumulative** drawdown over 2000-2010; per-fold (annual) that effect washes out and
the per-fold return give-up dominates.

## Per-fold — genuinely MIXED (regime-dependent), net slightly negative

`true` differs in 22/26 folds (A-D-live makes the gate active in most declines):
- **Wins:** 2020 (+5.1pp), 2003 (+6.6), 2014 (+4.9), 2006 (+2.6), 2001 (+2.2).
- **Losses:** 2002 (−10.6), 2025 (−9.7), 2016 (−9.1), 2009 (−7.6), 2007 (−4.2),
  2000 (−3.9).

It **helps in some bears** (2020, 2003) and **hurts in others** (2002 & 2009 — the
dot-com / GFC *bottoms*, where gated shorts admitted late in the decline get
squeezed on the recovery, and the short-side capital draw hurts the long re-entry).
Net mean −0.94pp return. This is the same **regime-dependence** every short
mechanism this session has shown — not a robust edge.

## Verdict: NO promote — A-D improved it but not to promotable

`slow_grind_gate` A-D-live is **much better than A-D-inert** (the hard −108pp
single-window tax shrank to a mixed near-wash) — the A-D-lead leg genuinely helped
select better shorts. But it is **still sub-promotable**: per-fold Sharpe/Calmar
are worse than baseline; the marginal MaxDD reduction does not compensate. Stays a
default-off axis. (Recorded: `dev/experiments/_ledger/2026-06-22-slow-grind-adlive-wfcv.sexp`.)

## The real Build-0 payoff is BROAD, not the short gate

The headline from Build 0 is **not** a promotable short gate — it is that A-D-live
**lifts the whole strategy** (long-only +92pp / −4pp DD / Sharpe 0.90→1.04 in the
deep screen; the WF-CV baseline itself improved). That is the **macro entry gate**
getting sharper, and it argues for making **A-D-live the default basis**
(commit synthetic breadth to `test_data/breadth/` + re-pin goldens — attended)
**independent of** any short-gate promotion. The short gates remain faithful
default-off tail-tools.

## Caveat
Same long↔short capital-interaction confound on per-fold return attribution; the
aggregate Sharpe/Calmar ordering (baseline > true) is clean. A-D-live, static
sp500-as-of-2000, 26 annual folds.
