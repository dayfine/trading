# Next-session priorities — 2026-08-19 (overnight session)

**Supersedes** the earlier `next-session-priorities-2026-08-19.md` sections it
contradicts; the ramp-up procedure there still stands.

## Start here — one decision is waiting on you

### ⚠ #2384 (the 26-week clock flip) is HELD in draft. It needs your call.

You said "yeh just flip it" on the p = 0.100 evidence. **That evidence has since
been shown wrong in one place and incomplete in another**, so I stopped rather
than merged.

**What changed.** The golden that arms StopLimit runs **post-merge only**
(`golden-runs-sp500-5y.yml` fires on push to main, not on PRs), so no CI signal
ever covered it. I ran it by hand, paired:

| arm | return | trades | maxDD |
|---|---:|---:|---:|
| `clock=0` | **108.23%** | 238 | 16.0% |
| `clock=26` | **69.81%** | 227 | 14.5% |
| **delta** | **−38.42pp** | −11 | −1.5pp |

One-line spec diff; deterministic runs; the control lands **within 2.55pp** of
the golden's own band floor, so the local run reproduces the golden and the
40.97pp shortfall is the knob.

The PR body's table said this same spec moved **+1.40pp**. That measurement was
taken without `TRADING_DATA_DIR`, so both arms read the live store instead of
the fixtures. **Struck.**

**What it means.** The promotion rests on +126.7pp from top3000 × 2000-2026.
This is a second cell, and it is **badly dominated** — which
`promotion-confirmation.md` says is disqualifying on its own.

**The why, which transfers.** The clock is an **exposure-reduction dial**, not a
quality filter. It removes fills, and with them return *and* risk together
(238→227 trades, DD 16.0→14.5). It pays when the removed exposure would have
fired into a crash and costs when it would have compounded:

- sp500 2019-2023 — uninterrupted bull → **−38pp**
- top3000 2000-2026 — dot-com + GFC + COVID → **+127pp**

**Your options**, my preference first:

1. **Revert the default to `0`, keep the rest.** The rework docs, the 13 spec
   pins and the split are all independently good. The clock stays a default-off
   axis, and the grid decides. *(Recommended — it is also the R1-compliant
   state, and main stays untouched either way since nothing merged.)*
2. Wait for the regime grid (below), then decide.
3. Merge and re-pin the golden 110.78 → ~69.8. **I'd argue against**: that
   records a −38pp regression as the new normal on a single-cell win that sits
   below its own base's 132.5pp noise floor.

Full writeup: `dev/experiments/clock26-golden-ab-2026-08-19/`.

## Running / queued

- **Regime grid** — a *pre-registered directional test*, not a survey. Predicts
  clock **helps** on `bull-crash-2015-2020` (2018 selloff + COVID) and **hurts**
  on `covid-recovery-2020-2024` (recovery bull). Both arms arm the same
  StopLimit stack; only the clock differs. If both land as predicted, the
  exposure story is confirmed; if either flips, it is refuted. ~3h.
- **#2384** — draft, rework commit (F1/F2/F3) complete and good regardless.
- **W1 / #2381** — long-side RS gate, see below.

## What this session settled

| | |
|---|---|
| **my own retraction** | The "+7.02pp fill re-anchor defect" I reported was a **mis-join on `symbol`**. Keyed on `position_id` (n=1,133): mean **+0.28pp**, **0%** of fills beyond 20%. No defect, no build. Withdrawn in #2387. Third instance this week of the same trap — `position_id` is the only safe join key. |
| **the user's stop idea** | **Already implemented.** `_maybe_reanchor_to_entry_base` (`entry_audit_helpers.ml:83`) has since 2026-08-06 discarded the structural floor for a flat `entry × initial_stop_buffer` stop when the floor exceeds `max_stop_distance_pct`. `Cap_at_max` would be bit-identical to arming it. **No build — one surface.** Also: the book's flat stop is §5.3's **4-6%**, while **15% is §5.1's rejection threshold**, not a stop level. #2389. |
| **W1 built** | Book §4.4 rule 2 long-side RS gate. `Screener.config.min_rs_normalized` default `0.0` (provable no-op, strict `<`), `1.0` = book-faithful. Wired into the live cascade *and* the diagnostic counter. 7 tests, each verified by mutation. Live picks share `Screener.screen`, so no live/backtest divergence here (unlike the stop-width gate). |
| **#2388 filed** | `weinstein_strategy.mli` documents `stale_exit_after_days` as defaulting to `None` ("a no-op") while the shipped default is `Some 5`. Found by mechanising the reviewer's LINTER_CANDIDATE across 63 hand-duplicated `[@sexp.default]`s. Doc-only defect; the linter is the durable fix. |
| **#2386 filed** | QC agents build the parent tree, not the PR — two project rules contradict. |

## Still open, graded

| | task | impact | complexity | urgency |
|---|---|---|---|---|
| **P2** | live picks skip the 15% stop-width gate — **your decision** | HIGH | LOW | HIGH |
| **S1** | surface `stop_anchor_at_entry_base × initial_stop_buffer` | MED-HIGH | LOW (no new code) | MED |
| **D3** | tiebreak Quality vs Alphabetical — needs a fresh control | MED | MED | LOW |
| **D1b** | §4.5 triple_confirmation re-screen — blocked on #2380 | MED | LOW | LOW |
| **H1** | the ~808s per-run floor | HIGH long-run | HIGH | LOW-MED |

## Process notes worth keeping

- **A default-change PR must run the goldens that arm the affected knob by
  hand.** "1 of 27 goldens affected" is blast *breadth*; it says nothing about
  *depth*, and the postsubmit-only workflow means CI will not tell you.
- **`docker exec ... dune ...` inline wedges** when the harness backgrounds it
  at the 600s timeout (dead pipe: elapsed climbs, CPU 0.02%). Always
  `docker exec -d` + a file log + a `Monitor` until-loop. Recovery is
  `pkill -9 -f 'dune ...'` then `rm _build/.db`.
- **Extract, don't bump.** `screener.ml` hit 504 vs the 500 cap; moved
  `diagnostics_for_screen` into `screener_admission.ml`, which already owned
  the three counters it composes.
