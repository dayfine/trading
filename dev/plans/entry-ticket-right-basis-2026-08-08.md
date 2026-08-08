# Plan — a faithful StopLimit entry with the right basis (next session)

Follows the 2026-08-08 trade dissection (`dev/notes/fill-model-ladder-v2-2026-08-08.md`,
skill `trade-dissection`). The ladder A/B and the AXTI dissection exposed a real
defect in how the entry level **E** and the **stop** are derived. This plan is the
fix design; **nothing here is built yet** — it is the next-session brief.

## What the dissection established (the why)

1. **E = a stale year-old high.** `suggested_entry` is anchored to
   `breakout_price = scan_max_high` over `base_end_offset_weeks(8)..
   +base_lookback_weeks(52)` — the max high from ~2–14 months back
   (`stock_analysis.ml:283`, `screener.ml:127`). For any name that ran up, pulled
   back, then re-qualified Stage-2, that window grabs the OLD peak. **Quantified:
   35% of record trades have E ≥ 1.2× the actual fill; mean E/fill = 1.29; 7% ≥ 1.9×.**
2. **The stop hangs off E.** `suggested_stop = entry × (1 − initial_stop_pct)` with
   `entry` E-derived → **64% of record trades have the screener stop land ABOVE the
   fill** (a stop above entry). The Support_floor mechanism rescues it (installed
   stop above fill only 2%).
3. **The entry basis differs by arm** (`entry_audit_helpers.ml:41-51`):
   record measures stop/sizing off the **current close**; book off **E**. So the
   book's floor looks 57% away → `stop_anchor_at_entry_base` throws it out and
   installs a tight buffer-below-E stop (AXTI: 3.966). That tight stop whipsaws out
   1 day after a late fill; the record's deep close-basis floor (1.728) rides the
   56× move.
4. **Book §5.1 (re-read 2026-08-08):** stop = "below the significant support floor
   (prior correction low)"; ">15% risk from entry → **prefer other candidates**."
   So the breakout top is a **screening** signal and the 15% rule is a **candidate
   filter** — NOT a stop-anchoring mechanism. Our `stop_anchor_at_entry_base` is
   un-faithful; it exists only to paper over the inflated E.

## Why the record's Market entry is still wrong in theory (user, 2026-08-08)

The record works, but by *ignoring* E and buying at market (close/next-open)
regardless of whether price actually broke out. Weinstein's entry is a **StopLimit
that triggers when price crosses the breakout level** — "buy the breakout," not
"buy at market on the signal day." A market entry has no breakout discipline: it
fills whether or not the setup confirmed. We want a StopLimit — but resting at a
**correct, reachable** breakout level, with a support-floor stop. That is the
faithful ticket the current "book" arm only *approximated* (with the wrong E and
the wrong stop).

## The design — decouple the three roles E is overloaded into

E currently drives (a) screening/scoring, (b) the entry trigger, and (c) the stop.
Split them:

| role | correct basis | today (wrong) |
|---|---|---|
| **Screening / scoring** — valid breakout? overhead supply? | 52-wk base top + resistance histogram (keep as-is) | ✓ already |
| **Entry trigger** (StopLimit level) | top of the **current trading range** (recent local high near price) | 52-wk stale top E |
| **Stop** | **support floor** / below prior correction low (never E-derived) | `entry × (1−pct)` off E; `stop_anchor_at_entry_base` tightens to E-base |

### Change 1 — entry ticket anchors to the current range, not the 52-wk top

`local_range_top` already exists (`_local_range_top`, the
`entry_anchor_local_range_weeks` knob: split-safe max high over the last N bars,
offset 0). Make the **entry ticket** anchor there (a short window, e.g. 4–8 weeks =
the current base the stock is breaking out of), while the 52-wk `breakout_price`
stays the **screening/scoring** signal. This makes the StopLimit trigger reachable
(near price) instead of a year-old high. Default-off flag → axis → grid, per
`experiment-flag-discipline`.

- Open question: what window? The book's "breakout above the top of the resistance
  zone" is the *current* consolidation top. 4–8 weeks is a starting hypothesis;
  sweep it as an axis.
- Guard: if the stock is genuinely still far below its 52-wk top, is it really a
  Stage-2 breakout, or a Stage-1 bounce? Consider requiring price to be within X%
  of the local-range top to qualify the ticket (screening tie-in).

### Change 2 — stop is always the support floor; the 15% rule becomes a filter

- Drop `stop_anchor_at_entry_base` as the stop mechanism. Stop = support floor
  (below prior correction low), computed off a **sane entry basis** (the trigger
  level or the close, not E).
- Re-cast `max_stop_distance_pct` (15%) as a **screening filter**: if the
  support-floor stop is >15% from the trigger, **drop the candidate** (book §5.1
  "prefer other candidates"), do not tighten the stop. This is a scoring/admission
  change, not a stop change.

### Change 3 — the faithful StopLimit ticket

With 1+2, the entry order is: **StopLimit(trigger = current-range top, limit =
trigger + small band), stop = support floor below the recent correction low.** This
is the book ticket done right — reachable trigger, structural stop. Compare it
head-to-head against (a) today's record (market + deep floor) and (b) today's book
(stale-E limit + tight stop).

## Build order (next session)

1. **Audit-field add first** (cheap, high-leverage): log `close_at_decision`,
   `ma_value`, and `local_range_top` on the audit `entry_decision`, so E-provenance
   is visible in the artifact and `trade-dissection` doesn't need `dump_snap` to see
   close-vs-E. (The dissection was blind to close without raw bars.)
2. **Change 1** (entry-ticket local-range anchor) behind a default-off flag; unit +
   a synthetic where 52-wk top ≫ local top.
3. **Change 2** (support-floor stop + 15%-as-filter) behind a flag; unit where the
   floor is >15% → candidate dropped (not re-anchored).
4. **Ladder v3**: faithful-StopLimit vs record vs current-book, top-3000 26y, +
   `trade-dissection` on the top divergences. Then WF-CV + confirmation grid before
   any promotion (`promotion-confirmation`).

## Guardrails

- Every change default-off; `main` behavior unchanged until a spec flips it
  (`experiment-flag-discipline` R1/R2).
- Spine intact (`weinstein-faithful-core`): Stage-2-only, volume-confirmed breakout,
  support-floor stop, macro/sector gates — untouched. This *increases* faithfulness
  (fixes an un-faithful E/stop), so W1/W2 pass; cite book §4.1 + §5.1.
- No promotion without WF-CV + grid; the ladder is a single-surface decision input.
