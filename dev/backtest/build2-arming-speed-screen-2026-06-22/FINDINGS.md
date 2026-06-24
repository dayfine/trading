# Build-2 arming-speed (`fast_v_arm_on_rate_alone`) — screen FINDINGS (2026-06-22)

Screens the #1708 knob the fast-crash-stop screen
(`dev/backtest/fast-crash-stop-screen-2026-06-22/FINDINGS.md`) pointed to. That
screen found the Build-2 catastrophic absolute stop **never fired** because
`Decline_character.Fast_v` arms only once the index is *below a falling MA*
(~mid-March 2020) — by then the structural gap-down stop had already exited every
long at the bottom. **The binding constraint was arming LATENCY, not stop width.**
`fast_v_arm_on_rate_alone` (#1708, default-off) lets `Fast_v` arm on
rate-of-decline alone, dropping the falling-MA precondition. This tests whether
that makes the catastrophic stop actually catch a fast-V crash.

- **Design:** 2×2 `catastrophic_stop_pct ∈ {0.0, 0.10}` × `fast_v_arm_on_rate_alone
  ∈ {false, true}`, long-only (isolates long crash-protection), sp500-2015
  universe (506), CSV mode on the deep `data/` store.
- **Crash window:** 2018-2021 (spans the 2020 fast-V). **Inert-elsewhere window:**
  2013-2017 (no fast-V crash).

## Headline — dormant in bulls, transformative in the 2020-V crash

### 2018-2021 (the 2020 fast-V)
| arm | cat_pct | arm-on-rate | Return | Sharpe | MaxDD | Calmar |
|---|---|---|---|---|---|---|
| b2-00 baseline | 0.0 | false | 3.78% | 0.135 | 20.19% | 0.046 |
| b2-01 slow-arm stop | 0.10 | false | 4.25% | 0.145 | 20.85% | 0.050 |
| **b2-02 arm-on-rate (#1708)** | 0.10 | **true** | **11.26%** | **0.282** | **11.09%** | **0.244** |
| b2-03 sanity (no stop) | 0.0 | true | 3.78% | 0.135 | 20.19% | 0.046 |

### 2013-2017 (no-crash bull) — INERT
| arm | Return | Sharpe | MaxDD | Calmar |
|---|---|---|---|---|
| bull-00 baseline | 137.41% | 1.533 | 9.06% | 2.085 |
| bull-02 arm-on-rate + stop | 137.41% | 1.533 | 9.06% | 2.085 |

`trades.csv` **md5-identical** across bull-00/bull-02. In a bull with no fast-V the
stop is **completely dormant** — zero tax on the winners.

## Verdict: PROMISING (strong) — escalate to WF-CV

The arming-speed knob is the missing piece that turns the catastrophic stop into
genuine, faithful fast-crash insurance:
- **No-op without the stop** (b2-03 ≡ baseline, md5-identical): the knob only
  matters when a consumer (the catastrophic stop) reads `Fast_v`.
- **Stop is near-useless without the knob** (b2-01 ≈ baseline): slow MA-gated
  arming = the latency the fast-crash screen diagnosed; the stop barely fires.
- **Knob + stop is transformative in the 2020-V** (b2-02): return 3.8→11.3%,
  Sharpe 0.135→0.282, MaxDD **20.2→11.1% (halved)**, Calmar 0.046→0.244.
- **Dormant in bulls** (md5-identical): armed only on `Fast_v`, which never
  triggers absent a fast crash → zero cost in normal regimes.

This is the textbook **tail-RISK-insurance** profile sanctioned by
`weinstein-faithful-core.md` / [[project_edge_is_the_fat_tail]]: a winner-touching
mechanism armed ONLY on `Fast_v`, so it does **not** tax the let-winners-run fat
tail in normal/bull regimes, yet provides large crash protection. Cleaner than the
Build-3 `slow_grind_gate` (which taxed the edge) — this is dormant-or-strongly-
helpful, not helpful-or-harmful.

## The WHY (mechanism, attributed)

In 2020 Feb-Apr the knob converts **gap-down exits into intraday exits**:
| | gap_down | intraday | non_stop |
|---|---|---|---|
| b2-01 slow-arm (2020 Q1) | 7 | 1 | 1 |
| b2-02 arm-on-rate (2020 Q1) | **3** | **5** | 1 |

With early arming, the catastrophic stop fires **intraday at −10% from the trailing
high** (`bar.low ≤ trailing_high*(1−0.10)`) — exiting the V on the way down,
*before* the structural trailing stop would have caught it at the next session's
**gap-down open** (a much worse fill near the bottom). Same number of 2020 exits (9),
but at materially better prices → MaxDD halves and the re-entry captures the
recovery (return rises, not falls). The knob fixes *when* the stop arms; the −10%
band fixes *where* it exits.

## Caveats / next (screen-rigor)
- **Two windows, one crash.** 2018-2021 has exactly one fast-V (2020). Needs WF-CV
  across regimes — crucially the **2008 GFC** (a slower cascade with fast legs):
  does rate-armed `Fast_v` catch 2008 *without over-firing* in choppy non-crash
  bears? The deep `data/` (1998-2026) supports this.
- **Single stop width** (`catastrophic_stop_pct = 0.10`). Sweep {0.08, 0.10, 0.12}
  as a second axis — the screen fixes the band; WF-CV should vary it.
- **Long-only** isolates crash protection; re-confirm under long-short later.
- Promote only via WF-CV + the macro-regime-diverse confirmation grid
  (`promotion-confirmation.md`). This screen earns the *escalation*, not the flip.
