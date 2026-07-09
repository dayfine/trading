# P1a — deep re-screens of the faithful-short gates + arming speed (364 basis)

2026-07-09. Executes P1a of `next-session-priorities-2026-07-08-PM.md`. Both
screens run the REAL mechanisms (flags built in #1696/#1708) on the deep window
they were flagged NEEDS-DEEP-DATA for: **2000-01-01..2010-12-31, sp500-2000 PIT
(515 names), CSV mode vs the restored deep `data/` store, warmup-364 basis.**
All arms fresh same-basis (no stale-baseline mixing).

**Scope honesty (screen-rigor):** the estimand is faithful (actual rule, actual
realized backtest P&L — not a forward-return proxy), but this is a SINGLE
window × SINGLE universe × SINGLE path per arm — a grid *cell*, not a WF-CV.
It cannot reject a mechanism; it prices the deep-window cell that was missing.
sp500-2000 PIT is survivor-tinted; it hits all arms equally, relative reads
stand. n(shorts) is tiny (7-16 per arm over 11y) — trade-level power is near
zero; the load-bearing signal is the portfolio path, which is exactly what the
mechanisms act on.

Raw outputs (gitignored): `dev/backtest/scenarios-2026-07-09-{052354,...}/`.
Logs: `/tmp/sweeps/p1a-{faithful-short,arming-speed}-deep-364.log`.

## Screen 1 — faithful-short gates (`experiments/faithful-short-deep-screen-2026-06-22`)

| arm | return | Sharpe | MaxDD | Ulcer | Calmar | shorts (n, realized) |
|---|---|---|---|---|---|---|
| 00 long-only reference | 251.3% | 0.798 | 40.6% | 15.7 | 0.298 | (1 leaked, see bug) |
| **01 ungated long-short** | **296.0%** | **0.869** | **30.7%** | **10.8** | **0.434** | 16, +$223k |
| 02 neutral_blocks_shorts | 287.5% | 0.844 | 38.5% | 14.4 | 0.340 | 15, +$196k |
| 03 slow_grind gate | 272.2% | 0.826 | 36.6% | 14.6 | 0.346 | 7, +$247k |
| 04 both gates | = 03 exactly | | | | | 7, +$247k |

Findings:

1. **The short leg IS additive in the deep window** — the hypothesis that sent
   this to deep data is confirmed: every long-short arm beats the long-only
   reference on return AND every risk metric (baseline: +44.8pp return, DD
   40.6→30.7, Ulcer 15.7→10.8).
2. **But the UN-GATED baseline dominates every gated arm.** Each gate reduces
   return and worsens DD vs ungated (neutral: −8.6pp ret / +7.8pp DD; grind:
   −23.8pp / +5.9pp).
3. **The WHY is hedge-shaped, not P&L-shaped.** Gated arms have BETTER direct
   short P&L (+$247k on 7 trades vs +$223k on 16) yet lower total return and
   worse DD. The blocked shorts (JNS 2001-02 → +$42k held 10 months, TEL
   Jan-2008, PRU Jul-2002, PM Oct-2008, PFG Oct-2002) are **early-bear hedges**:
   they smooth NAV exactly when the long book bleeds, and the smoothing
   compounds through the recovery. Per-trade gating evaluates the wrong
   estimand — the deep value of shorts is portfolio-level NAV insurance, and
   the slow-grind gate's 8-week confirmation arrives after the hedge window.
4. **Gate subsumption:** arm 04 ≡ arm 03 bit-identically — grind-gated shorts
   are already Bearish-tape-only; `neutral_blocks_shorts` adds nothing on top.
4b. **Year-by-year decomposition (the single-event check that corrected
   Screen 2) — Screen 1's delta is DISTRIBUTED, two episodes:** ungated-vs-
   long-only accrues +11.2% through 2001 (dot-com bear: JNS/ISRG/LH) and a
   second +9pp leg across 2008-09 (GENZ/TEL/PM/SNI), ending +12.7%. The
   grind-gated arm tracks long-only almost exactly through 2007 (the gate
   blocked ALL the 2001-style early-bear hedges) and only captures the
   late-2008 confirmed-cascade shorts. i.e. grind gate ≈ "2008-only shorts" —
   it misses the entire first bear. Robust shape, verdict unchanged.
5. **Bug (small, filed):** the shorts-OFF reference logged 1 SHORT trade
   (LH 2001-06-13→16, laggard_rotation exit, +$2.8k). A short leaked past
   `enable_short_side=false` — needs a look at the laggard-rotation path.

**Verdict (calibrated):** no-flip / no-build-priority for both gates on EDGE
grounds. Evidence across cells is now: 2010-26 → gates admit ~0 shorts (inert);
2000-2010 → gates tax the crash hedge. There is no window where they add edge.
They stay default-off axes. The `neutral_blocks_shorts` faithfulness flip
(2026-06-22 §Decision) remains a mandate call — now with its deep cost
quantified (−8.6pp return, +7.8pp MaxDD on the one window shorts matter).
This is a screen-cell decision, not a WF-CV rejection.

**Forward guidance (what the why rules in/out):** if the floor-quality program
wants short-side crash protection, build it **hedge-shaped** (portfolio-level
overlay — index short / basket short sized to long exposure during confirmed
declines), not per-trade short-selection gates. This feeds P1b: the circuit
breaker's "exit to cash" and a hedge overlay are the same lever class (NAV
smoothing in declines), and this screen says that class has real deep-window
value (+45pp / −10pp DD worth on 2000-2010 sp500).

## Screen 2 — arming speed (`experiments/build2-arming-speed-deep-screen-2026-07-08`, NEW fixtures)

Long-only, same window/universe. 2×2: catastrophic_stop_pct {0, 0.10} ×
fast_v_arm_on_rate_alone {false, true}.

| arm | return | MaxDD | Result |
|---|---|---|---|
| d2-00 cat0 armoff (baseline) | 251.4% | 40.6% | |
| d2-01 cat10 armoff | 266.6% | 38.8% | catstop alone +15.2pp, −1.8pp DD |
| **d2-02 cat10 armon** | **283.1%** | **38.8%** | armon adds +16.5pp on top, DD flat |
| d2-03 cat0 armon | 251.4% | 40.6% | ≡ baseline exactly (isolation clean) |

Findings (CORRECTED 2026-07-09 after year-by-year decomposition — the first
version of this section overclaimed "arming speed NOT inert deep"):

1. **catstop 0.10 is the real deep value, and it is DISTRIBUTED**: year-end
   equity vs cat0 baseline shows +3.7% through 2001, +5.9% through 2002, a
   further +3.1% incremental in 2008, +4.3% cumulative by 2010. The stop fired
   usefully across the deep bears (where the falling-MA precondition was
   already satisfied → the default arming sufficed). Consistent tail-insurance
   value, not a single lucky event.
2. **armon (rate-alone arming) is INERT 2000-2009 — including 2008**:
   armoff/armon year-end equities are IDENTICAL through 2009. This CONFIRMS
   the 06-22 WF-CV fold story (fold-008 byte-identical) on the new basis. The
   entire +16.5pp endpoint gap is ONE divergence in 2010 (+4.5% that year —
   the May-2010 flash-crash era), and the 06-22 WF-CV's 2010 fold had armon
   NEGATIVE (−0.77pp whipsaw). Single event, sign-unstable across
   path/basis → **path-dependent noise, not deep edge.** armon's value case
   remains exactly what the 06-22 ledger said: fast-V crashes from highs
   (2020, 2018-Q4), where the MA precondition lags.
3. **Wiring isolation is clean:** armon without catstop is bit-identical to
   baseline (the flag only routes through stop arming).

**Verdict (calibrated, corrected):** the deep cell supports **catstop**, not
armon. catstop 0.10 has never had its own WF-CV axis (the 06-22 arming-speed
WF-CV had catstop ON in both arms) — the natural next surface is
`catastrophic_stop_pct {0, 0.10}` WF-CV on the deep base, which would give
catstop the fold-distribution evidence for a promotion-grid conversation
(trader-dial, `weinstein-faithful-core` W2: protect against the crash that
invalidates the stage read). armon keeps its weak 06-22 ACCEPT unchanged and
drops back to fast-V-specific insurance; no new escalation from this screen.

## Both screens — basis note

Numbers are NOT comparable to the 06-22 screen absolutes (210 basis, and the
old runs predate the deep-store restore). Relative reads within each screen are
same-basis and clean.
