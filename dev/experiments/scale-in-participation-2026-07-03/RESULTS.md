# Scale-in v1 — participation-effect measurement (P0, 2026-07-03)

Measures the causal chain behind the scale-in verdict (`dev/notes/scale-in-wfcv-2026-07-03.md`,
ledger `2026-07-03-scale-in-v1-surface`): *½-sizing frees cash → previously
`Insufficient_cash` near-misses get funded → broader participation*. The verdict
inferred this from outcome shape only; here it is measured from `trade_audit.sexp`
entry decisions + `trades.csv` intervals.

Scenarios: `scenarios-sp500/` (fold-001 2001-12-31..2003-12-30, N=515) and
`scenarios-broad/` (top-3000 fold-010 2019-12-27..2021-12-25 bull-divergence fold,
fold-011 2021-12-26..2023-12-25 bear fold) × {baseline, pullback@0.5,
either_loose@0.5+ext0.25 (broad) / either@0.5+ext0.15 (sp500)}. All re-run on
current main (repro audits predated #1837).

Extraction: dedup (entry_date, symbol, disposition) tuples; skip visibility is
alternatives-of-funded-entries only (Fridays with zero funded entries record no
skips — known `decision_audit` limitation). Adds detected as overlapping
same-symbol trade intervals (sibling-position architecture).

## sp500 fold-001 (2001-12-31..2003-12-30)

| Metric | baseline | pullback@0.5 | either@0.15 |
|---|---|---|---|
| Return / trades / MaxDD | 23.5% / 40 / 10.1% | 17.6% / 61 / 11.1% | ≡ pullback (bit-identical) |
| Funded entry events (audit) | 46 | 73 | 73 |
| Unique symbols funded | 43 | 65 | 65 |
| Fridays with ≥1 entry | 22 | 27 | 27 |
| Cash-skip events (date,sym dedup) | 263 | 245 | 245 |
| Unique symbols cash-skipped | 142 | 131 | 131 |
| **Adds filled** | — | **0** | **0** |
| Avg entry size (audit) | $169k | $98k | $98k |
| Position-days (closed trades) | 1538 | 2545 | 2545 |

**Near-miss linkage:** 26 symbols entered by pullback but never by baseline;
**24/26 (92%) were in baseline's cash-skipped set.** The freed cash demonstrably
reached the near-misses.

**Findings (sp500 fold-001):**

1. **The exploit side never engaged: zero adds filled.** All 6 repeat-symbol
   trades are sequential re-entries, not sibling adds; open positions have no
   same-symbol siblings. `pullback ≡ either` bit-identity is explained the
   strong way — not "Either's extra branch contributed nothing" but "NO add of
   any kind filled." Scale-in on this fold = pure ½-size entry broadening.
2. **Participation channel confirmed causally.** +59% entry events, +22 unique
   names, 92% of the new names traceable to baseline cash-rejections.
3. **Cash-skips barely dropped (263→245, −7%).** The freed half-units were
   immediately re-consumed by more ½-size entries — the cash constraint stays
   binding; the mechanism converts position size into breadth ~1:1.
4. **The tax is now mechanically attributable:** avg entry $98k vs $169k with
   zero adds to restore size = permanent ½-exposure to whatever monster fires,
   +65% position-days for −6pp return. Confirms the verdict's "½-entry =
   explore-side fat-tail tax" WHY at the decision level.

## broad top-3000 fold-010 (2019-12-27..2021-12-25, bull-divergence fold)

| Metric | baseline | pullback@0.5 | either_loose@0.25 |
|---|---|---|---|
| Return / Sharpe / MaxDD | 72.0% / 1.30 / 18.5% | 64.9% / 1.26 / 20.9% | 54.7% / 1.21 / 15.9% |
| Funded entry events | 85 | 147 | 137 |
| Unique symbols funded | 79 | 134 | 122 |
| Fridays with ≥1 entry | 47 | 68 | 62 |
| Cash-skip events (dedup) | 496 | 685 | 634 |
| Skips per entry-Friday | 10.5 | 10.1 | 10.2 |
| **True adds filled** | — | **0** | **2** (of 137 entries) |
| Avg entry size | $187k | $115k | $114k |
| Position-days (closed) | 3609 | 5850 | 5092 |
| New syms vs baseline / in baseline skip set | — | 69 / 56 (81%) | 55 / 45 (82%) |

Skip-event counts are only visible on Fridays with ≥1 funded entry, so raw skip
counts rise with entry breadth; the normalized skips-per-entry-Friday is flat
(10.5 → 10.2) — **the cash constraint stays equally binding**.

**The 2 adds that did fill are both pathological (add/exit collision):**
- SIRI: add filled 2021-07-03 — the same day `laggard_rotation` exited the
  parent; the add itself was laggard-rotated out 7 days later at a loss.
- BAX: add filled 2020-02-26 — the same day the parent's stop fired (COVID
  crash onset); the add then rode to its own stop-loss.

The add trigger evaluates revealed strength but never consults exit-side state
(laggard flag, stop proximity) — when an add finally clears the extension gate
it can be pressing into a name the exit channels are simultaneously rejecting.
Related to the catastrophic-stop sibling-alignment follow-up from #1831's
behavioral review.

## broad top-3000 fold-011 (2021-12-26..2023-12-25, bear fold)

| Metric | baseline | pullback@0.5 | either_loose@0.25 |
|---|---|---|---|
| Return / Sharpe / MaxDD | −10.2% / −0.42 / 23.6% | −9.4% / −0.41 / 23.3% | −1.8% / −0.03 / 18.6% |
| Win rate | 17.5% | 18.0% | 13.8% |
| Funded entry events | 67 | 120 | 98 |
| Unique symbols funded | 61 | 108 | 91 |
| Fridays with ≥1 entry | 40 | 56 | 47 |
| Cash-skip events (dedup) | 466 | 640 | 504 |
| **True adds filled** | — | **1** (JJSF) | **1** (CHKP) |
| Avg entry size | $123k | $72k | $80k |
| Position-days (closed) | 2341 | 3152 | 3028 |
| New syms vs baseline / in baseline skip set | — | 61 / 48 (79%) | 48 / 40 (83%) |

Both filled adds are again same-day add/exit collisions (JJSF add filled
2023-04-29 = parent exit day; CHKP add filled 2022-05-03 = parent exit day).
Running total: **4 adds filled across all six broad cells + sp500, 4/4
collided with a same-day parent exit.**

## Instrumented add flow (f011 rerun, temp eprintf at `Scale_in_runner._fund_adds`)

Both f011 scale-in cells re-run with emit logging; results bit-identical to
the uninstrumented runs (non-invasive).

| f011 | emit-Fridays | evaluated | **funded (cash reserved)** | **filled** |
|---|---|---|---|---|
| pullback@0.15 | 21 | 26 | 20 (≈$590k cumulative) | **1** (JJSF) |
| either_loose@0.25 | 29 | 43 | 22 (≈$736k cumulative) | **1** (CHKP) |

## Root cause: the add order cannot fill except adversely

`Weinstein_order_gen._entry_order` translates every `CreateEntering` — adds
included — into **`StopLimit (entry_price, entry_price)`**, a zero-width
stop-limit, with the add's `entry_price` set to **Friday's close** of a stock
that just signalled *strength* (`Scale_in_runner._sized_add` passes
`~entry_price:close`). Consequences:

- If the name keeps behaving strongly (gap up / run on Monday), the stop
  triggers but the limit at Friday's close can never fill. **The designed
  "press the winner" fill is structurally unreachable.**
- The order DOES fill when price falls back to Friday's close — i.e. exactly
  when the strength thesis has failed. **The only reachable fills are
  adversely selected.** All 4 fills observed across every cell collided with
  a same-day parent exit, and CHKP's add (emitted late March) filled
  2022-05-03 mid-decline, months later, then rode to its own stop.
- For breakout entries the same order shape is correct (the stop-limit sits
  at the breakout level ABOVE current price — price rises through it). The
  add path reused it with a price that is already the market price.

So the v1 "exploit" channel never functioned as designed anywhere: sp500 died
at the extension gate (ext 0.15, breakouts already 10–20% above the 30w MA);
broad at ext 0.25 emitted orders freely (43 evaluated / 22 funded in the bear
fold alone) but converted them to ≈nothing but adverse fills.

## Attribution of the fold-011 smoothing — honest version

The decisive contrast inside fold-011: **pullback has MORE breadth than
either_loose (120 entries/108 names vs 98/91) yet lands ≈ baseline (Sharpe
−0.41 vs −0.42), while either_loose delivers the entire improvement (−0.03,
DD 23.6→18.6).** So the bear-fold neutralization is NOT the participation
channel (breadth per se), and with 1 fill each it is NOT functioning adds
either.

What mechanically remains, per the instrumentation:

1. **Friday cash reservation** — funded adds deduct their cost from the same
   Friday's screener entry budget (`portfolio.cash −. scale_in_cash` in
   `Weinstein_strategy`). Measured: ≈$590–736k cumulative on $1M capital,
   real in BOTH variants — but similar in magnitude, so it cannot alone
   explain the pullback↔either_loose gap.
2. **Emit-timing + path divergence** — either_loose reserves on more and
   different Fridays (29 vs 21) with a different symbol mix; each displaced
   entry compounds path-divergently for the rest of the fold (bear-fold
   entries are 14–18% win-rate, so displacement tends to help there and hurt
   in fold-010's bull tape: either_loose 54.7% vs pullback 64.9% vs baseline
   72.0% return).

n=1 fold per cell — the split between these two channels is not identifiable
from this data, and does not need to be: **both are side-effects of emitting
unfillable orders, not the designed mechanism.** The WF-CV aggregate's
"either_loose = mild risk smoother (10/13 DD wins)" characterization
therefore describes a strength-conditional entry-throttle artifact + noise,
not continuation-adds.

## Implications for the ledger entry (material amendment)

1. Ledger WHY(2) — "at ext 0.25 the Either arm lives and supplies ALL the
   incremental risk benefit; the continuation-add is the risk-improving
   half" — is **contradicted**: the Either arm emits but does not fill.
   "Adds DO fire ~4/fold" in the notes counted funded orders, not fills.
2. The REJECT verdict stands (nothing here rescues return), but what was
   actually tested = "½-sizing + breadth + an unfillable-add cash-reservation
   throttle", NOT the designed explore/exploit reallocation.
3. **The untested-shape guidance gets a prerequisite:** before any full-size
   entries + continuation-adds surface, the add path needs (a) a fillable
   order type (stop-market above close, or market-at-open), (b) an
   add/exit-coherence gate (don't emit adds for symbols the same tick's
   laggard/stop/stage channels are exiting), and (c) an explicit
   `add_fraction` knob (v1 sizes adds as `1 − initial_entry_fraction`, so
   full-size entries currently get zero-size adds).

## What this measurement confirms from the original verdict

- ½-sizing → breadth conversion is real and near-lossless: near-miss linkage
  79–92% everywhere, skips-per-Friday flat — cash constraint always binds.
- The fat-tail tax WHY(1) survives and is now decision-level: avg entry
  roughly halves, no add ever restores size, bull-fold returns bleed
  (sp500 f001: 23.5→17.6%; broad f010: 72.0→54.7/64.9%).
- WHY(3) breadth-reverses-the-sign survives in outcome terms, with the
  mechanism now correctly attributed (throttle artifact, not diversifying
  adds).
