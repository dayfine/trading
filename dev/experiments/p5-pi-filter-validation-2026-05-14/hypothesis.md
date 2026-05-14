# P5 screener point-in-time filter — wiring validation (2026-05-14)

## Setup

Wired `Screener.screen_with_cooldown ?membership_at` callback + strategy-side
plumbing (`enable_pi_filter` config flag → `Bar_reader.daily_bars_for` →
`Daily_price.active_through` lookup). Two cells over the 16y
`sp500-2010-2026` long-only and long-short scenarios (Cell E baseline):

1. `pi-off` — `enable_pi_filter = false` (current default). Callback factory
   returns `None`; screener admits every symbol that survives the existing
   gates. Bit-equal to the pre-feature behaviour.
2. `pi-on` — `enable_pi_filter = true`. Strategy hands the screener a
   callback that consults each symbol's most-recent
   `Daily_price.active_through` cell via `Bar_reader`.

## Authority

- `dev/notes/historical-universe-membership-2026-04-30.md` §P5 "screener
  point-in-time filter".
- `dev/notes/historical-universe-status-2026-05-13.md` §1 phase 3 action
  item #2 — "P5 next (M) — highest-leverage gain; survivorship-aware 16y
  backtests on the existing universe".
- `dev/notes/next-session-priorities-2026-05-14.md` §P1 — dispatch.

## Hypothesis (intent)

The M5.5 verdicts — especially axis-2's catastrophic 16y STOP (MaxDD
19.9%→60.1%, 0→26 force-liquidations on `min_correction_pct=0.10`) — were
measured on **survivorship-biased data**: the current 16y universe sexp
treats every delisted symbol as if it were active forever. Re-running with
a survivorship-aware PI filter could either:

- **Confirm the STOP**: bias-aware MaxDD widens further or stays bad →
  axis-2 verdict holds; the catastrophic mode is real.
- **Invalidate the STOP**: bias-aware MaxDD narrows substantially or the
  force-liquidation count collapses → the failure mode was a survivorship
  artifact; the M5.5 axis-2 verdict must be revised.

## Implementation status (load-bearing caveat)

**The PI gate is wired but cannot yet produce a behavioural delta on the
current snapshot corpus.** Three layers must align for the gate to fire:

1. **Source layer — DONE for SP500 (Wiki+EODHD).** CSV files under
   `goldens-sp500/universes/sp500-historical/` carry the `active_through`
   column (PR-A/B/C/D, MERGED).
2. **Type layer — DONE.** `Daily_price.active_through : Date.t option` field
   present (#1076).
3. **Snapshot-pipeline layer — NOT STARTED.** The snapshot
   write/reconstitute path
   (`Snapshot_runtime.Snapshot_bar_views_helpers._make_daily_price`) hard-
   codes `active_through = None` on every reconstituted row. So even when
   the CSV input carries a delisting marker, by the time the strategy reads
   bars through `Bar_reader.daily_bars_for`, the marker is `None` and the
   PI predicate returns `true` (admit) on every symbol.

Step 3 is the foundational P3 follow-up — propagating `active_through`
through the snapshot pipeline — and is intentionally **out of scope for this
PR** per the task framing. See `dev/notes/historical-universe-status-
2026-05-13.md` §1 row "P3 — `Daily_price.active_through` field" (NOT
STARTED).

## What this PR validates today

| Cell | Expected vs baseline | What it pins |
|---|---|---|
| `pi-off` (default) | Bit-equal to pre-feature | Default-off contract: no goldens shift, no behavioural drift on any 5y / 10y / 16y scenario without a config opt-in. |
| `pi-on` (today) | Bit-equal to `pi-off` | The PI gate's hot path is exercised, but every callback returns `true` because the snapshot strips `active_through`. Validates that **wiring the seam does not regress the cascade**. |
| `pi-on` (post-P3) | Behavioural delta on 16y | Once the snapshot pipeline propagates `active_through`, this cell becomes the survivorship-aware 16y baseline. |

## Falsifiability (today)

- **`pi-off` ≠ baseline goldens** → wiring change regressed the default path.
  Sanity-fail; blocks merge.
- **`pi-on` ≠ `pi-off`** in any 5y / 16y scenario where every symbol's
  active_through is `None` (which is every scenario today) → callback
  factory is misfiring or the screener's PI gate has a bug. Sanity-fail;
  blocks merge.

## Falsifiability (post-P3, follow-up)

- **`pi-on` 16y MaxDD ≈ `pi-off` 16y MaxDD on long-only** → survivorship
  bias is not the cause of axis-2's catastrophic failure; the M5.5 verdict
  stands as-is.
- **`pi-on` 16y MaxDD ≪ `pi-off` 16y MaxDD on long-only** → survivorship
  bias inflated the failure mode; the M5.5 axis-2 verdict must be revised,
  and a re-run of the axis-2 sweep on PI-aware data is warranted.

## Headline metrics (intended after P3 lands)

Table to be filled in once `Daily_price.active_through` propagates through
the snapshot pipeline. The runner cells should pin: total return, CAGR,
Sharpe, MaxDD, force-liquidation count, total trades, win rate, average
hold days. The "Δ vs pi-off" column is the survivorship-bias attribution.

| Scenario | Cell | Return | CAGR | Sharpe | MaxDD | Force-liq | Trades | WR |
|---|---|---|---|---|---|---|---|---|
| sp500-2010-2026 long-only | pi-off | — | — | — | — | — | — | — |
| sp500-2010-2026 long-only | pi-on | — | — | — | — | — | — | — |
| sp500-2010-2026 long-short | pi-off | — | — | — | — | — | — | — |
| sp500-2010-2026 long-short | pi-on | — | — | — | — | — | — | — |

## Decision criteria (post-P3)

- **M5.5 axis-2 verdict revision** iff: pi-on 16y long-only MaxDD < pi-off
  MaxDD by ≥ 10pp AND force-liq count drops by ≥ 50% AND axis-2 `0.10` cell
  re-runs above pi-off baseline. Triggers `memory/project_m5-5-tuning-
  exhausted.md` update.
- **Keep M5.5 verdicts** iff: pi-on 16y MaxDD within ±3pp of pi-off AND
  force-liq count within ±20%. Survivorship is not the load-bearing factor.

## Test-of-record

- `trading/analysis/weinstein/screener/test/test_screener.ml`:
  - `test_pi_filter_default_admits_all` — `pi-off` bit-equality.
  - `test_pi_filter_admits_both` — explicit always-member callback.
  - `test_pi_filter_excludes_delisted` — rejection branch (in-memory).
  - `test_pi_filter_consults_as_of` — date-dependent semantics.
  - `test_pi_filter_composes_with_cooldown` — gate composition.
- `trading/trading/weinstein/strategy/test/test_pi_filter_wiring.ml`:
  - Strategy-side wiring (`enable_pi_filter` flag → callback factory →
    `Daily_price.active_through` lookup via `Bar_reader`).

The screener-layer test pins the rejection semantics directly (feeds an
in-memory predicate to the cascade); the strategy-layer test pins what's
reachable through today's pipeline (the `None` and no-bars branches +
flag-driven `Some`/`None` callback factory).
