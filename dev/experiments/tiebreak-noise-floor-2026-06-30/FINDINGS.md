# Tiebreak noise-floor controls — findings (2026-06-30)

**Question (user, 2026-06-29):** "it's funny that alphabetical performs better —
consider reverse-alphabetical, longest-symbol-length, random (shuffle then take
top-N)." These are **uninformative control tiebreaks**: they carry no return
signal, so they bracket the *noise floor* of the equal-score tiebreak. If the
informative sorts (RS-primary `Quality` #1788, earliness-primary `Quality_earliness`)
sit **inside** the band the controls span, then no sort beats unbiased sampling.

**Setup:** same breadth grid (top-500/1000 PIT-1998, 2000-2026, 13 folds,
fork-per-fold, Cell-E long-only). 3 new default-off control modes:
`Reverse_alphabetical`, `Symbol_length` (len asc → ticker), `Hash_order`
(FNV-1a pseudo-random — see the bug note below). Baseline = `Alphabetical`
(reproduces the #1788 baseline bit-for-bit: 0.667 / 0.660 Sharpe).

## Results — mean over 13 folds

### top-500 (327 syms) — narrow, Sharpe band width ≈ 0.073
| tiebreak | kind | Sharpe | Calmar | MaxDD% | ret% |
|---|---|---|---|---|---|
| **Alphabetical** (default) | unbiased | 0.667 | 0.850 | 14.79 | 17.80 |
| Symbol_length | control | **0.682** | 0.676 | 16.21 | 18.27 |
| Hash_order (FNV) | control | 0.640 | 0.762 | 14.52 | 16.33 |
| Reverse_alphabetical | control | 0.609 | 0.661 | 15.24 | 15.08 |
| Quality (RS-primary) | "informative" | 0.636 | 0.676 | — | — |
| Quality_earliness | "informative" | 0.649 | 0.657 | — | — |

### top-1000 (514 syms) — mid, Sharpe band width ≈ 0.278
| tiebreak | kind | Sharpe | Calmar | MaxDD% | ret% |
|---|---|---|---|---|---|
| Quality (RS-primary) | "informative" | **0.666** | 0.669 | — | — |
| **Alphabetical** (default) | unbiased | 0.660 | 0.690 | 17.29 | 18.68 |
| Quality_earliness | "informative" | 0.590 | 0.586 | — | — |
| Reverse_alphabetical | control | 0.589 | 0.574 | 16.07 | 15.49 |
| Symbol_length | control | 0.422 | 0.478 | 17.83 | 11.44 |
| Hash_order (FNV) | control | 0.388 | 0.405 | 17.22 | 9.61 |

## What it shows

1. **No informative sort escapes the noise band.** RS-primary and earliness-primary
   both sit *inside* the spread the arbitrary controls span, in both cells. They do
   not beat the best arbitrary sort. → Confirms the dead-lever class
   (`project_edge_is_the_fat_tail`, `accuracy_is_unreachable`): no entry-feature
   sort adds return, because no entry feature predicts the realized winner.

2. **The "best" tiebreak flips by cell — the signature of luck, not signal.**
   Symbol_length is best in top-500 (0.682); Alphabetical/RS are best in top-1000
   (0.66) while Symbol_length collapses to 0.422. A ticker's name / length is
   causally irrelevant to returns, so a sort that "wins" one cell and loses the
   next is drawing from a distribution, not exploiting an edge. **Alphabetical
   being best in prior broad backtests is partly luck-of-the-draw on a single
   path, not a property to rely on.**

3. **The tiebreak is a large, breadth-scaling source of pure selection VARIANCE.**
   The arbitrary-sort Sharpe spread widens from ≈0.073 (top-500) to ≈0.278
   (top-1000) as breadth — and thus over-subscription — doubles. With ~5 fundable
   slots and many tied grade-A breakouts, *which* tied names win the scarce cash
   swings the realized Sharpe by up to ~0.28 with **zero** information content.
   (Expect this to widen further at top-3000; not run here — a future confirmation.)

## Implications

- **For the candidate-ranking lever:** dead, definitively. Keep `Alphabetical`
  default. **Note (per 2026-06-30 user feedback): "alphabetical wins" is NOT a
  result to rely on** — it is luck-of-the-draw on one path, and relying on the
  accidental randomness of a ticker sort is not a plan. The finding is diagnostic,
  not a recommendation to trust alphabetical.
- **For the backtest corpus:** results that hinge on the alphabetical tiebreak in
  broad universes carry hidden, un-modelled selection variance (±0.07 to ±0.28
  Sharpe). Single-tiebreak broad backtests are *less robust than they look*; the
  honest comparison is variance-aware (this is why the program leans on WF-CV fold
  *distributions*, not single-window point estimates).
- **If diversification / tail-exploration has value, do it EXPLICITLY — don't lean
  on the tiebreak's accidental draw.** The variance comes from concentrating scarce
  cash into a *few* tied names. The explicit, already-mapped lever for "spread the
  bets / visit more of the long tail" is the **concentration/capacity axis**
  (`project_capacity_concentration_surface`): fund *more names at smaller size* →
  deliberately reduces dependence on *which* tied names get picked, and (since the
  cascade score is anti-predictive at the top, `project_cascade_selection_inversion`)
  the lower-ranked "unvisited tail" is not systematically worse, so widening the
  funnel is a real choice, not a gamble. **Known tradeoff:** more names dilutes the
  fat-tail amplification that bigger positions give (return↑ but DD↑ at higher
  concentration). So it is an explicit knob with a measured tradeoff — the honest
  lever, evaluated on the capacity surface, *not* a random tiebreak.
- **The variance is not free alpha to harvest by re-sorting** — no sort captures it
  (that is finding 1). It is a property to either *reduce* (capacity) or *accept*,
  explicitly. Per-screen auditability (the faithfulness audit,
  `dev/plans/per-screen-decision-audit-2026-06-30.md`) shows whether the picks that
  drove the spread differed on any *captured* signal or were genuinely arbitrary.

## Bug found + fixed (a finding in itself)

The first `Hash_order` used a rolling `h = h*31 + byte` hash. That is **monotonic
in string length** (each extra byte multiplies by 31, so a 1-char ticker always
hashes below any 2-char ticker) → "hash order" collapsed to "length order", and
`Hash_order` produced **bit-identical** results to `Symbol_length` in both cells.
Caught by the identical aggregates *before* any conclusion was drawn. Fixed to
**32-bit FNV-1a** (XOR-before-multiply diffuses bits so the value is uniform
w.r.t. length); the corrected hash order is genuinely distinct from both
alphabetical and length (test fixture: `[ZZ; AAA; M]`). Lesson: a naive
multiplicative string hash is not a random shuffle.

## Artifacts
- `out_top{500,1000}/` — baseline + reverse_alpha + symbol_length (4-variant v1;
  the v1 hash_random column is the length-monotonic bug, superseded).
- `out_top{500,1000}_hashfix/` — baseline (reproduces) + FNV `hash_random`.
- specs `spec_top{500,1000}.sexp` + `spec_top{500,1000}_hashfix.sexp`.
