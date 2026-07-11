# Liquidity-overlay WF-CV — findings (2026-07-10)

Fold-proofs the honest-tradeable single-path result
(`dev/notes/honest-tradeable-baseline-2026-07-10.md`). Spec
`test_data/walk_forward/liquidity-overlay-deep-2000-2026.sexp`: deep top-3000
2000-2026 catstop base (364 basis), 13 biennial folds, 2×2 Cartesian
(`min_entry_dollar_adv {0, 1e6}` × `min_hold_dollar_adv {0, 5e5}`) + parity
cell, snapshot mode, parallel 1.

## Result — the bundle story inverts at fold level; the HOLD-EXIT is the real lever

| variant | Sharpe | Calmar | MaxDD | DSR | frontier | gate |
|---|---|---|---|---|---|---|
| baseline (0,0) | 0.654 | 0.917 | 23.59 | 0.994 | no | — |
| parity (0,0) | ≡ baseline bit-identical 13/13 | | | | | ✓ |
| **hold-exit only (0, 5e5)** | **0.753** | **1.131** | **18.03** | **0.9999** | yes | FAIL (8/13 wins; fold-008 trails 0.96) |
| entry-gate only (1e6, 0) | 0.634 | 0.821 | 17.42 | 1.0000 | yes | FAIL |
| bundle (1e6, 5e5) | 0.609 | 0.802 | 17.69 | 1.0000 | no | FAIL |

1. **Hold-degradation exit alone dominates baseline on every aggregate**
   (Sharpe +0.10, Calmar +0.21, MaxDD −5.6pp; 8/13 Sharpe-fold wins) —
   recycling capital out of liquidity-dying names is a genuine, distributed
   improvement, the strongest fold-level candidate the program has produced.
2. **The entry gate alone REDUCES Sharpe/Calmar** (0.634/0.821 vs baseline
   0.654/0.917) while cutting DD — at fold level it forgoes more winners than
   fakes. Estimand caveat both ways: the simulator CREDITS untradeable fake
   profit (APPB-class) as alpha, so part of the entry gate's measured "cost"
   is fake profit foregone — the WF metric cannot arbitrate realizability.
3. **The bundle (the honest-baseline config) is fold-honestly WORSE than
   hold-only** — the +3.2× single-path improvement was, for the THIRD time
   this week, path-compounding flattery (armon 2010 event; catstop
   compounding; now the overlay bundle). The record-run measurement
   convention survives (realism grounds); the alpha narrative does not.
4. **fold-008 (2016-18) is the tail-tax exhibit**: baseline +69.7% vs
   hold-only +23.9% — that window's monster winner was a low-ADV name the
   overlay exited/blocked. One window's fat tail pays for a lot of junk-drag
   removal elsewhere; the strict `worst_delta 0` gate therefore fails every
   armed variant. Whether that +69.7% was realizable at size is exactly the
   estimand question the simulator can't answer.

## Verdict

- **No promotion** of any overlay knob as a default (gate FAIL; and per
  `feedback_no_reversal_timing`-adjacent discipline, one adverse fat-tail
  fold is exactly the failure mode we don't average away).
- **Hold-exit (5e5) is ledger-recorded as the leading candidate**: 8/13,
  frontier, DSR 0.9999, dominant aggregates. Promotion path if pursued:
  neighbor surface {2.5e5, 5e5, 1e6} + confirmation grid with a
  macro-regime-diverse cell, and a realizability argument for fold-008-class
  windows.
- **Honest-tradeable record run keeps the bundle as MEASUREMENT convention**
  (realism: fake fills must not count), now with the explicit caveat that
  the bundle's fold-level alpha reading is negative vs hold-only —
  DEEP_RESULTS ⭐ row updated.
- **Methodology (third confirmation, now standing):** single compounded
  paths flatter overlay/exit mechanisms; only fold distributions decide.

## 4-YEAR-FOLD SENSITIVITY (2026-07-11 amendment — the user's horizon question)

Re-ran the identical 2×2 at `test_days 1460` (6 folds; artifacts `4y-*` here).
**The hold-exit verdict INVERTS with the horizon:**

| | 2y folds (13) | 4y folds (6) |
|---|---|---|
| baseline Sharpe / Calmar | 0.654 / 0.917 | 0.719 / 0.674 |
| hold-exit only | **0.753 / 1.131** (frontier, 8/13, DSR 0.9999) | **0.626 / 0.470** (OFF frontier, 2/6, DSR 0.872) |
| entry-gate only | 0.634 / DD 17.4 | 0.677 / DD 22.2 (frontier — Sharpe-for-DD trade both horizons) |
| bundle | 0.609 | 0.670 (frontier at 4y) |

At 2y, window truncation hides the cost of force-exiting names whose
liquidity dips and later recover/run; at 4y the baseline's longer rides
re-assert and hold-exit lands BELOW baseline. **The "strongest fold candidate"
was a fold-horizon artifact — its promotion path is CLOSED** (no neighbor
surface; the fold-008 realizability autopsy is no longer promotion-relevant).
Entry-gate behaves consistently at both horizons (realism trade, not alpha) —
the 2026-07-10 realism-defaults flip is unaffected.

**LAW (upgraded, 4th inversion):** compounded paths flatter compounding;
SHORT FOLDS flatter exit mechanisms. Any tail-dependent mechanism verdict
requires a horizon sweep (2y vs 4y+) or the rolling-start matrix before it is
believed.

Ledger: `dev/experiments/_ledger/2026-07-10-liquidity-overlay-wfcv.sexp`
(notes amended). Ops notes: v1 died artifact-less to container contention
(runner writes only at end) — long WF runs get a solo container; and twice a
stale watcher whose own command line matched the pgrep shadowed the
"still running" check — match on something the watcher's argv cannot contain.
