# Capital-management layer: explore/exploit scale-in — design

**Status:** DESIGN (not built). Product of a 2026-07-02 design session (grill).
**Frame:** *Thinking in Systems* (Meadows) — portfolio as a stock-and-flow system.
**Scope of v1:** the **reallocation** lever only (see §2). The **envelope** lever
(gross exposure / `min_cash`) is explicitly out of scope here — separate program.

---

## 1. The system frame — where the gap is

Modelling the portfolio as a system with **capital as the stock**:

- **Inflows / outflows** = entries / exits, **driven exogenously by market signals.**
  The signal layer (which symbols are Stage-2 / breakout / RS-strong / the macro
  regime) is *self-contained*: it does **not** depend on what we hold or how we're
  doing. The screener emits the same ranked list regardless of portfolio state.
- **Portfolio state IS an input to the strategy** — `on_market_close` receives a
  `Portfolio_view.t = { cash; positions }` every call. Two feedback loops already
  exist:
  - **Balancing loop (cash gate):** as positions fill, `cash` drops; a candidate
    whose cost exceeds remaining cash is skipped (`Insufficient_cash`). This holds
    gross exposure at its ceiling — it is *why* ~97% of entry decisions skip.
  - **Reinforcing loop (equity-proportional sizing):** size =
    `risk_pct × portfolio_value / stop_distance`; NAV grows → positions scale up
    (compounding), and vice-versa.
- **What is missing** — and what this design adds — is a loop that senses the
  *health / composition* of the stock and adjusts the **allocation policy**. Every
  existing portfolio→strategy feedback is a **static structural constraint** (fixed
  reserve %, fixed proportional sizing, fixed per-name cap), never an adaptive
  policy keyed on system state.

**The measured miss** (from the regime-edge investigation): ~97% `Insufficient_cash`
skips; the near-misses are *as good as* the funded ones (decision-audit: selection
is faithful; misses are cash-bound, not lower-quality). Capacity is the one
entry-side lever the data supports.

## 2. Two orthogonal levers — keep them separate

| Lever | What it controls | This doc |
|---|---|---|
| **Reallocation** | *How* capital is distributed inside a fixed exposure envelope | **v1 scope** |
| **Envelope size** | *How much* is deployed (`min_cash_pct` / `max_long_exposure_pct`) | out of scope — separate experiment |

Keeping them decoupled means v1 changes **no gross-exposure envelope** and carries
**no bear-defense trade-off** — it only improves *allocation quality*.

## 3. The mechanism — explore/exploit scale-in

**Reuse the state machine that already exists** (do NOT build a capital-pool
rebalancer):

- **Position lifecycle:** `Entering → Holding → Exiting → Closed`. Note the machine
  already *shrinks* a position (partial exit → `Holding` at reduced qty) but cannot
  *grow* one — that missing transition is the build (§4).
- **Weinstein stage, re-classified weekly on held positions:** `Stage2 { late }`
  (MA-slope deceleration) + distance-above-30-week-MA (extension).

The three "partitions" (reserved / exploring / running-winner) are **emergent from a
per-state sizing policy**, not steered by a controller. Set the rules; let the
partition float (the Meadows move — steering the partition directly is the
seductive-but-overfit version, and it manufactures churn).

### 3.1 Explore — small, broad initial entries
- Initial fresh entry = **½ risk unit** (0.5% vs today's 1%) → ~2× more fresh names
  fit within the same envelope → wider survey net.
- Because we are cash-rationed ~97% of the time, "half-enter when candidates exceed
  cash" collapses to **always half-enter** when the mechanism is on. Unconditional
  in v1.

### 3.2 Exploit — one add, on the first pullback, into revealed strength
- **Max 1 add** (Weinstein's ½ + ½: buy on breakout, add the other ½ on the first
  pullback to the breakout level / rising MA).
- **Trigger = following revealed strength, never predicting** (winners ≈ losers at
  entry; score is anti-predictive). The add fires on a **market-revealed event**,
  not a conviction score. v1 default trigger = **first-pullback-hold** (the pullback
  that holds above the breakout / near the MA *is* the reveal that the breakout
  didn't fail). Trigger is a knob `{pullback | early_new_high | either}`.
- **Gated by `not-late` AND `not-extended`** (distance-above-MA). `late` catches
  slope deceleration; extension catches price level. Note distance-above-MA is
  *rate-relative-to-trend*, not calendar time — a fast move outruns its 30-week MA
  (big gap → extended, excluded); a slow grinder lets the MA rise underneath it
  (small gap → still add-eligible). This is Weinstein's own "don't buy extended"
  measure and it is already computed.
- **Add sizes in RISK units, not notional %** (avoids the NAV-drift trap: "15% + 15%"
  references two different NAVs). Initial = ½ risk unit; the add brings the position
  to a **full risk unit (1%)**; notional **capped at the existing
  `max_position_pct_long` (0.30)**. Total *risk* is deterministic; notional floats
  with NAV/stop as today, capped.
- **Each add is its own risk unit with its own stop** → a whipsawed add is cut like
  any laggard, costing ~1 risk unit, not the whole position.

### 3.3 Arbitration under scarcity (the loop's behavior)
When freed cash (exit / laggard-cut) is contested by a fresh entry *and* a
continuation-add:
- **Signal-driven priority:** an add fires only on a rare, strong revealed event, so
  when one fires it **outranks a fresh (unproven) entry** for cash. Absent a trigger,
  cash flows to fresh entries.
- **Consequence (good):** the explore/exploit ratio **emerges from the
  continuation-event rate** — many pullback-holds in a strong trend auto-shift capital
  to exploit; chop keeps you exploring. Regime-adaptive with **no explicit regime
  signal** (regime-timing the weight is the known-dead lever).
- **Guard:** an **exploration floor** (minimum fresh-entry budget) so the reinforcing
  exploit loop cannot fully starve the net that finds the *next* winner.

### 3.4 The accepted trade-offs (named, not hidden)
- **Add-quality over add-quantity:** we concentrate into winners *early* (near
  support, low cost-basis creep) then **hold and ride** — we deliberately do *not*
  keep feeding an extended monster. This **caps tail-amplification of the giants** in
  exchange for never adding at a bad price.
- **Pullback under-sizes gap-and-go monsters:** the fastest, biggest winners often
  never give a clean pullback, so a pure-pullback trigger leaves us ½-size in exactly
  the names that become the tail. **This is the #1 thing the backtest must measure.**
  If confirmed, the `either` trigger (add on pullback-hold OR early not-extended
  new-high) is the fix.

## 4. Build boundary

- **Explore side** (smaller initial entry) = a *sizing-policy* change. No
  state-machine work.
- **Exploit side** (the add) = a **new `Holding → add` transition** — the machine
  shrinks positions today but cannot grow one. This is the real build.

## 5. Knobs (all land default-off / no-op per `experiment-flag-discipline.md`)

| Knob | Default (no-op) | When enabled |
|---|---|---|
| `enable_scale_in` | `false` (today's single full entry) | master switch |
| `initial_entry_fraction` | `1.0` | `0.5` |
| `max_adds` | `0` | `1` |
| `add_trigger` | — | `pullback` (v1), `early_new_high`, `either` |
| `add_extension_max` (distance-above-MA gate) | — | tunable (Q4 — keep open) |
| `add_requires_not_late` | — | `true` |
| `exploration_floor` (min fresh-entry budget) | `0` | tunable |
| per-name total cap | reuse existing `max_position_pct_long` (0.30) | — |

Deferred as *later* knobs (not v1): `HALF_ENTRY_ONLY_WHEN_XYZ` conditioning
(candidate-supply / profit — the profit-conditioning is the equity-curve/#1464
direction, keep it in the *envelope* program, not here); extension-threshold
refinement.

## 6. Validation plan

1. **Land default-off** (no-op = today's behavior; goldens unchanged — verify parity).
2. **Make it a `Variant_matrix` axis** the day it lands (searchable).
3. **WF-CV surface**, bear-inclusive folds, on the broad universe (top-3000 / sp500),
   per `experiment-gap-closing`.
4. **Instrument the monster-under-sizing check** (§3.4): does the pullback trigger
   leave the top-tail winners at ½-size? Compare tail-position final sizes vs a
   full-single-entry baseline.
5. **Promotion needs the confirmation grid** (`promotion-confirmation.md`), not a
   single-window win.

**Faithfulness:** this is Weinstein's *own* scale-in dial (½ on breakout, ½ on the
first pullback — "The Trader's Way") applied inside the existing engine. It is a
sanctioned **dial** (`weinstein-faithful-core.md` W2), not a portfolio overlay — it
does **not** raise the barbell faithfulness question (no passive sleeve).

## 7. Why this one is worth building (vs the levers that were rejected)

- It is **not winner-touching in the bad way** — it never trims a running winner
  (that class is rejected: harvest-rotate, macro-trim, late-stop-tighten). It only
  *cuts failed fresh entrants* (laggard rotation, already on) and *adds to confirmed*
  ones.
- It is a **reallocation inside a fixed envelope**, so it does not re-open the
  gross-exposure/bear-defense trade-off.
- It is **tail-aligned**: sample broadly to catch the monster, then feed the ones the
  market confirms — the opposite of diluting or taxing the tail.
