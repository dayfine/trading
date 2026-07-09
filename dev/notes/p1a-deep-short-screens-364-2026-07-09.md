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

Findings:

1. **Arming speed is NOT inert in the deep window** — contradicts the 06-22
   expectation ("fast-V-specific, inert in 2008 cascade"). The 2008 cascade
   (and/or 2000-02 legs) contains rate-detectable fast episodes where the MA
   confirmation delay costs; rate-alone arming lets the catastrophic stop fire
   earlier: +16.5pp over catstop-armoff at identical MaxDD.
2. **catstop 0.10 itself helps deep** (+15.2pp, −1.8pp DD) — consistent with
   its tail-insurance design (sanctioned winner-touching exception).
3. **Wiring isolation is clean:** armon without catstop is bit-identical to
   baseline (the flag only routes through stop arming).

**Verdict (calibrated):** promising — this was the missing macro-regime cell
for the arming-speed mechanism (#1708 already carries a weak WF-CV ACCEPT from
2026-06-22 + the adlive re-run 06-24). Combined cells now: 2018-21 (helps the
2020 fast-V), 2013-17 bull (inert), 2000-2010 deep (helps, +2.9pp/yr, DD flat).
Escalation path per `promotion-confirmation.md`: a deep-window WF-CV (fold
distribution, not this single path) is the remaining evidence before a
`catstop=0.10 + armon=true` preset-promotion conversation. Note this is a
PRESET/tail-insurance promotion (trader-dial), so it also needs the
`weinstein-faithful-core` W2 citation (book: protect against the crash that
invalidates the stage read).

## Both screens — basis note

Numbers are NOT comparable to the 06-22 screen absolutes (210 basis, and the
old runs predate the deep-store restore). Relative reads within each screen are
same-basis and clean.
