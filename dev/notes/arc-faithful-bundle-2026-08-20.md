# The book-faithful entry bundle — assembly + live picks A/B

**Date:** 2026-08-20
**Spec:** `trading/test_data/backtest_scenarios/staging-arc-2026-08/top3000-2000-2026-arc-faithful.sexp`
**Basis:** faithfulness, **not** performance. User directive: *"we will get
faithful right first and then later chase down the performance gap."*

## What it is

The book's §4.7 order mechanics, end to end. Most of it already existed —
`staging-record-convention/...-fullbook-graded.sexp` carries the whole **entry
ticket** half (`sim_entry_trigger_at_suggested` so the trigger RESTS at the
breakout level E rather than the current close, `enable_sim_entry_stoplimit` +
`entry_extension_max_pct 2.0` for the band, `stop_anchor_at_entry_base`). This
bundle adds the **screening** half plus the fill-time volume test:

| field | value | why |
|---|---|---|
| `entry_anchor_local_range_weeks` | `4` | **prerequisite** — see the defect below |
| `entry_freshness_basis` | `Range_top_breakout` | screen while still UNDER the range top |
| `volume_confirm_at_fill` | `true` | §4.2 confirmation applies to the week the ticket FILLS |

> **Amendment 2026-08-21** — the 6-month inspection run
> (`dev/notes/inspect-6mo-trade-dissection-2026-08-21.md`, PR #2455) found two
> of these knobs implicated in known defects. (1) `volume_confirm_at_fill`
> ejects **83% of fills**: stop-limit fills trigger days after the breakout on
> quiet tape, so the fill-day spike test refuses the mechanism's own entries
> (CHDN ejected +6.69% green at 3 days); the fill-week reading of §4.2 above is
> contested — the breakout week's volume may be the faithful basis. (2) The
> initial stop most entries receive is the **pre-existing** `floor_stop`
> fallback at 2.08% — half the book §5.3 band — independent of any bundle knob.
> The bundle is unchanged here; this note exists so the record does not
> present either knob as settled-faithful.

### The 2pp band is the book's number, not a tuned one

§"Buying Within Limits": a buy-stop at the breakout with **a limit ¼ point
above it** — on Weinstein's own 12⅛ example that is **2.06%**. (½ point ≈ 4.1%
for thinly traded names is his liquidity-conditional variant; not implemented.)

He rejects both neighbours explicitly. No limit at all: *"you are now the proud
owner of XYZ at 15"* instead of 12⅛, *"the reward/risk ratio is now far less
favorable."* Limit == trigger: *"one out of four, the stock will break out
without your ever buying it."*

That second quote matters — it is the fat-tail-miss objection, anticipated and
**priced** by the author at 1-in-4. The ¼ point exists precisely to solve it.

⚠ The book is in **points**, not percent. ¼ point on a $12 stock is 2.06%; on a
$268 stock it is 0.09%, which is unusable. Percent is the faithful modern
reading, and `weinstein-faithful-core.md` lists "numeric thresholds tuned for
the modern regime" as an explicit dial.

## ⚠ The defect this assembly hit: rt armed without its anchor

`Range_top_breakout` measures freshness against `local_range_top`, which
`entry_anchor_local_range_weeks` defines. At that knob's `0` default the anchor
is unset and the "close within 5% below anchor" test has nothing to bind
against.

Every ladder-v4 rt arm sets `4`. `staging-record-convention/*` and
`dev/weekly-picks/live-config-overrides.sexp` set it **zero times** — so a
bundle built on that base silently inherits `0`.

**A backtest smoke did not catch it.** Armed without the anchor, a 1-year 2019
top-3000 cell produced **93 trades vs 35** for the control — a large,
plausible-looking delta. That proved the field was *read*; it did not prove it
was *correctly configured*. **Liveness is not correctness.**

It surfaced only in the live picks, as an empty candidate list — which reads
like a market condition, not a misconfiguration.

## Live picks A/B — as-of 2026-08-14, top-3000, 3,154-symbol pin

**The control reproduces the committed `f88c277d5` report bit-identical** (all
20 symbols, same order), which validates universe, bars source, as-of date and
invocation together. Every difference below is therefore the config alone.

| arm | long candidates |
|---|---:|
| live baseline | 20 |
| + bundle, **no anchor** | **0** |
| + bundle, **anchor 4** | **20** |

With the anchor: **17 of 20 unchanged.** Out: PAY, TPC, INVX. In: DRI, BLK,
NDAQ (all score 75, i.e. rank-21+ names promoted to fill the cap-20 list — so
the three were refused *admission*, not merely capped).

### What the drops are NOT explained by

PAY was rank 1 at **+5.8% through** its entry, so its drop is consistent with
the book's "already run on, no longer a buy". **TPC and INVX are not**: both sit
*below* entry (−3.7%, −3.6%) while EHC at **−3.9% survived**.

rt's anchor is the 4-week `local_range_top`, **not** the screener's `entry`
level, so close-vs-entry cannot attribute these drops. Doing so needs
`local_range_top` per candidate, which the compact snapshot sexp does not carry.
Recorded as unexplained rather than given a plausible story.

## Two prior data-source traps, for the next person

1. **The backtest warehouse is not a live picks source.** Running the generator
   against `/tmp/snap_top3000_dedup_v5thin_adj` returned zero candidates because
   **5 of the baseline's top 6 picks are absent** from it — it holds the
   2000-vintage top-3000 (2,908 symbols), and the runner silently skips missing
   symbols. Live picks need `--bars <repo>/data`.
2. **CSV mode is memory-heavy.** The generator on 3,154 symbols peaks near
   **7 GB**; it cannot share the container with a backtest. One heavy job at a
   time (`container-capacity-scheduling.md`).

## What this does not claim

No performance verdict. The 26y run of this bundle measures what rt +
volume-at-fill add on top of `fullbook-graded`'s already-recorded **+287% /
MaxDD 23.2%** — and the 26y return null on this base is **132.51pp**, so nothing
short of that is interpretable. The deferred gap, stated plainly: book ticket
**+287%** vs record **+8,367%** vs **SPY-TR +687%** over the same window.
