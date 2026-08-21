# 6-month trade inspection — arc bundle defect dissection (2026-08-21)

Purpose per user direction (2026-08-20): *"focus on some 6 months backtest which
just produce trades and audit records so we can inspect the trades and verify
the expectations (e.g. to attack on these defects) — make no expectation on the
absolute trading metrics for these backtests."* Nothing here is a performance
verdict; every number is a mechanism observation.

## The harness

Four arms, period 2019-01-02 → 2019-06-28, universe top-3000-2019, $1M initial
cash. Specs: `trading/test_data/backtest_scenarios/staging-arc-2026-08/inspect/`.
All `expected` ranges are non-binding (only `total_trades min 1` can fail), so
the scenario runner is used purely as a trade/audit generator.

| arm | isolates | return | trades |
|---|---|---:|---:|
| `inspect-6mo-arc` | full bundle (anchor 4wk) | −4.17% | 59 |
| `inspect-6mo-anchor26` | anchor 26wk | +0.57% | 45 |
| `inspect-6mo-nobasestop` | minus `stop_anchor_at_entry_base` | −3.06% | 63 |
| `inspect-6mo-novolconf` | minus `volume_confirm_at_fill` | −4.48% | 32 |
| `inspect-6mo-bookstop` | + `initial_stop_buffer 1.0` (book-band stop) | +4.83% | 39 |
| `inspect-6mo-bothfix` | bookstop + volconf OFF (bounds the §4.2 premium) | +3.93% | 13 |

`bothfix` (mean hold 17.1d, 6 open at end) restores real holding but returns
**no more** than `bookstop` with the faithful gate on — in this window §4.2's
eject cost nothing net. That bounds the melt-up premium at ≈0 for 2019H1 and
removes any pressure to weaken the gate.

## Finding 1 — the fallback initial stop is 2.08%, half the book band ⭐

**Root cause, arithmetic-exact** (`floor_stop.ml`):

```
_fallback_reference (Long):  reference = entry × initial_stop_buffer (1.02)  ← ABOVE entry
compute_initial_stop:        stop      = reference × (1 − min_correction_pct/2)
net:                         entry × 1.02 × 0.96 = entry × 0.9792  →  2.08% below entry
```

The fallback reference stands in for a **support level**, which for a long sits
*below* entry. Inflating it 2% above entry and then taking the 4% haircut from
the inflated level halves the stop. Book §5.3's flat stop when no structural
floor qualifies is **4–6%**; counterfactuals: reference = entry ⇒ 4.00%,
reference = entry/1.02 ⇒ 5.88% — either lands inside the band. Only the
current direction falls outside.

Verified exactly on ADP 2019-02-22: `suggested_entry 153.98`,
`installed_stop 150.777216` = 153.98 × 1.02 × 0.96, `stop_floor_kind
Buffer_fallback`. Short side symmetric (~1.96%; with this entry the raw level
lands exactly on 157.00 so the 0.125 round-number nudge fires → 2.0425%).

**Blast radius in the arc arm:** 42 of 59 trades carry the 0.0208 stop
(`Buffer_fallback` 70:16 over `Support_floor`); the distribution is bimodal
with nothing between 0.04 and 0.124. 23 of 24 `stop_loss` exits are in the
tight cohort (17% win rate, −$48k of the arm's −$55k stop-leg loss). Perturbing
the cohort cutoff 0.05→0.10 changes nothing (the gap makes it robust).

**Control result — the arc flag is NOT the router.** `nobasestop` (flag off)
still shows 40 of 63 trades at exactly 0.0208 and `Buffer_fallback` 73:23. The
fallback is the **common path**: for most breakout candidates the 90-bar
≥8%-pullback support scan finds no qualifying counter-move, so the fallback
fires in any config. `stop_anchor_at_entry_base` only affects the rare
`Stop_too_wide` (>15%) cases — a handful of trades in six months. The bug is
fully pre-arc and pervasive.

**Why existing tests missed it** (`test_support_floor.ml`): the fallback
coverage is a *delegation identity* — the expectation is built from
`compute_initial_stop ~reference_level:(entry × fallback_buffer)`, the same
formula under test, so both sides move together and a direction error is
undetectable by construction. Same class as
`feedback_pin_every_element_of_a_category`: the false-OK lived in the element
with the most tests.

**Pinned:** `trading/weinstein/stops/test/test_fallback_stop_width.ml` — exact
level 150.777216, both sides' distances below the book band, and the
counterfactual isolation (4.00% / 5.88% via the same `compute_initial_stop`).
The test characterises current behaviour; when the fix lands it flips to
asserting inside-the-band.

## Finding 2 — exits fill at next open, so stop rows are less lethal than the width suggests

MCY: close 55.66 under stop 55.785 on 05-21, gapped back up, filled 56.80 →
realized −0.35% on a 2.08% stop. Four "stop_loss" rows are *profitable* trailed
stops (CSGP +7.25% after a 2-day run). The stop-leg damage is
death-by-a-thousand (24 stops averaging −1.87%), not single deep cuts. No
defect here — mechanics working as designed.

## Finding 3 — the volume eject is §4.2's own rule; 83% is the regime cost, not a defect

**Corrected 2026-08-21 after the full book read** (an earlier revision of this
section called the basis wrong; it is not). `volume_eject_runner` evaluates the
**fill week's completed weekly bar** with both §4.2 branches at 2× (lookback
4wk) — and under rt the fill week *is* the breakout week. The apparent
contradiction (ADP screener ratio 1.65× vs eject `spike_ratio 0.74`) is two
different weeks, both correctly measured: rt screens **under** the anchor, so
the screening week is pre-breakout; the fill week is the true breakout week,
and its volume genuinely failed 2×.

The eject itself is the book's explicit instruction (Ch. 4): *"if there is no
significant increase in volume when the breakout occurs, then avoid that
stock. If you have purchased it with a buy-stop order, then sell it for a fast
profit when it advances after the breakout (which it will usually do)."* CHDN
ejected at **+6.69% green** is literally that sentence executing.

Of 42 fills with a recorded lifecycle outcome in the arc arm: **35 Ejected, 4
Held, 3 Skipped_other_exit** — only 5 confirm. That 83% is the **faithful cost
of §4.2 in a quiet-volume melt-up regime** (2019H1 V-recovery; the melt-up-lag
law — monsters run on quiet tape and Weinstein's volume gate refuses them).
The remaining faithfulness gap is timing only: the book sells *into the
post-breakout advance*; the runner sells at the next open unconditionally.

Consequences in the rows: CHDN ejected +6.69% green at 3 days, RAMP +3.48% at
5 days. Only two exit triggers exist in the entire arm (stop_loss 24 /
volume_eject 35); mean hold 4.4 days; 2 positions open at period end. A weekly
system whose recorded edge is the fat tail
(`project_edge_is_the_fat_tail`) holds nothing longer than 11 days.

The eject leg is net **positive** ($+17k) — it is not the loss; it is the
tail-killer.

**Control result — `novolconf` confirms the isolation.** With the eject off:
mean hold 3.6 → **15.0 days** (max 62), `laggard_rotation` exits reappear, 5
positions open at period end — and **CHDN is still open and riding** instead of
being ejected +6.69% at 3 days. Return is still −4.48% because the tight-stop
bleed remains (29 tight stop-outs, −$61k): the eject caps the tail, the
fallback stop does the bleeding, and fixing the eject alone does not stop the
bleed.

## Finding 4 — funding, reframed (my earlier "oversized position" claim was wrong)

Initial cash is **$1M**, not $100k. ADP's `initial_position_value 139,506` =
14.0% of NAV = exactly `max_position_pct_long 0.14` — sizing is correct. The
real fault is sizing reads NAV while fills need free cash: at 70% deployed with
`min_cash_pct 0.30`, free cash is ~$19k against ~$139k tickets, producing the
`Insufficient cash` rejections (6 in this short window; 146 in the 26y run).
That is precisely the G2a/G2b/G3 funding hole already tracked (A1-1/2/3), not a
sizing bug.

## Canonical-example tests (user direction)

Per *"the more canonical examples we found and fixed should be built into
integration tests / scenarios"*, following the `test_axti_entry_construction.ml`
pattern (unit-pin the arithmetic chain; a goldens-small scenario changes
ranking/sector-RS/macro and tests the wrong thing):

1. ✅ ADP fallback-stop chain — `test_fallback_stop_width.ml` (this PR).
2. ☐ volume-eject canonical (CHDN +6.69% ejected green at 3 days) — now a pin
   of *faithful* behaviour (§4.2's "sell it for a fast profit when it
   advances"), not of a defect; `novolconf` shows the same entry riding to
   period end with the gate off.
3. ☐ funding rejection canonical — belongs with the G2a/G2b build (A1-1/2).

## Fix ordering (the controls' answer)

1. **Fallback stop direction — VERIFIED zero-code fix.** The defect is the
   *value* of the existing `initial_stop_buffer` config field (1.02 = reference
   above entry), not missing code (`project_stop_anchor_flag_already_exists`).
   The `bookstop` arm arms `((initial_stop_buffer 1.0))` in the bundle: modal
   stop lands at exactly 0.0400 (25/39), stop_loss exits collapse 24 → 4,
   return −4.17% → +4.83% on the same window. Bundle-scoped, no goldens moved.
   The **global default flip** (moves every fallback-path golden, breaks
   record-baseline comparability) is a separate user decision; the
   characterisation test flips to in-band when that lands.
2. **Volume eject — NO FIX; the rule is faithful** (see the corrected Finding
   3). The mechanism measures the fill week = the breakout week on weekly bars
   and executes the book's own low-volume sell instruction. What remains is a
   *measurement* (the melt-up premium the gate forgoes, bounded by the
   `novolconf` / `bothfix` arms) and one timing nuance (sell-into-advance vs
   next-open) — a possible future dial, not a bug.
3. Funding (G2a/G2b/G3) — already tracked, unchanged by these results.
