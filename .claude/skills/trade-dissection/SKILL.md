---
name: trade-dissection
description: Dissect a backtest result down to individual trades to explain WHY two arms (or a config change) diverge — by joining trades.csv + trade_audit.sexp + raw snapshot bars and reading the core signals (MA, close, prior tops, E, stop, fill) per trade. Use when a YoY / top-line comparison shows a gap and you need the mechanism, when someone suspects a signal (E, stop, stage) is "wrong in many cases", or when the user asks to go trade-by-trade, dissect a divergence, or trace an entry/stop level to its source. Turns "arm A beats arm B" into "because on trade X, signal Y was computed as Z, which caused W".
---

# Trade dissection — from a top-line gap to the per-trade mechanism

A return table tells you *that* two arms diverge; it never tells you *why*. This
skill is the procedure for driving a divergence down to individual trades and the
**core signals that produced them** — so a verdict reads "arm A wins because on
trade X the entry level E was 2× the price, which made the resting order miss the
move" instead of "arm A wins, +8000%". Born from the 2026-08-08 fill-model ladder,
where +7,321% vs +310% resolved to a single mechanism: E anchored to a stale
year-old high (`dev/notes/fill-model-ladder-v2-2026-08-08.md`).

It pairs with `screen-rigor` (report distributions, name the estimand) and
`.claude/rules/mechanism-validation-rigor.md` (the *why* is the deliverable, not
the verdict). The dissection **is** how you produce a transferable *why*.

## When it fires

- A YoY / aggregate comparison of two runs (or a config on/off) shows a gap and
  you need the causal mechanism, not the number.
- Someone suspects a per-trade signal (E / `suggested_entry`, stop, stage, volume)
  is miscomputed "in many cases" — dissection both finds the cases and quantifies
  "many".
- The user says "go trade by trade", "dissect", "top diff trades", "trace this
  entry/stop level", or asks how a specific signal was determined.

## Inputs (per run/arm, all under the scenario output dir)

- `trades.csv` — realized round-trips. Key columns (0-indexed): `0 symbol`,
  `2 entry_date`, `3 exit_date`, `4 days_held`, `5 entry_price` (the **fill**),
  `6 exit_price`, `8 pnl_dollars`, `12 exit_trigger`, `15 stop_initial_distance_pct`
  (**E-basis** — see caveat), `19 position_id`. (Newer runs append
  `stop_fill_distance_pct` — the gate-basis distance.)
- `trade_audit.sexp` — the decision-time context per `position_id`: `suggested_entry`
  (**E**, the resting-order level), `suggested_stop` (screener, E-derived),
  `installed_stop` (after the floor mechanism), `stop_floor_kind`, `stage`,
  `ma_direction`, `resistance_quality`, macro block, `alternatives_considered`.
- Raw bars via `dump_snap` — the **close / high / low the audit does NOT record**.
  Build once: `dune build trading/backtest/snapshot_warehouse/dump_snap/`; run
  `dump_snap.exe <SYM>.snap <from> <until>` → CSV (`date,open,high,low,close,adj_close,...`).

The audit records E, the stops, the stage and `resistance_quality` — but **not**
the MA value, the close, or the resistance *price* E is derived from. That gap is
itself a finding: you cannot audit E's provenance from the artifact alone; you
join raw bars to see close-vs-E.

## Procedure

1. **Rank the divergence.** Run the faithfulness harness two-arm mode
   (`faithfulness_report_cli -a <A>/trades.csv -b <B>/trades.csv`) for per-year
   Δpnl and top-symbol |Δpnl|. Pick the top 3–5 symbols — they usually carry most
   of the gap (fat tail).

2. **Pull both arms' audit for each top symbol.** Locate the block:
   `grep -n "(symbol SYM) (entry_date" <arm>/trade_audit.sexp`, then read
   `suggested_entry` / `suggested_stop` / `installed_stop` / `stop_floor_kind` /
   `stage` / `resistance_quality`. Tabulate A-vs-B side by side.

3. **Pull the raw bars** around each decision date with `dump_snap` and read the
   **close on the signal day**. Compute E/close. This is the crux: a resting order
   at E only fills if price reaches E; if E ≫ close the arm enters late/high or
   never.

4. **Pull the actual trade rows** (`awk -F, '$1=="SYM"' <arm>/trades.csv`) — fill,
   exit, days_held, exit_trigger. This shows what *happened*: filled where, held
   how long, exited why. A 1-day `stop_loss` after a late fill = whipsaw-after-
   late-entry; a 300-day `extension_stop` = rode the tail.

5. **Quantify "many".** Don't stop at anecdotes. Join E (audit, by `position_id`)
   to fill (trades.csv, by `position_id`) across ALL trades and bucket the ratio:
   ```
   perl -0777 -ne 'while (/\(entry_date \S+\) \(position_id (\S+?)\).*?\(suggested_entry ([0-9.]+)\)/gs){print "$1 $2\n"}' audit.sexp | sort > pid_E
   awk -F, 'NR>1{print $20, $6}' trades.csv | sort > pid_fill
   join pid_E pid_fill | awk '{r=$2/$3; ...bucket...}'
   ```
   Report the distribution (share ≥1.2×, ≥1.5×, mean), per `screen-rigor` — a
   median gap with a wide spread is a different claim than "always".

6. **Trace the suspect signal to its source.** Follow the field back through the
   code: `suggested_entry` → `screener.ml _build_candidate` (`entry_anchor =
   breakout_price`) → `stock_analysis.ml _breakout_and_breakdown_prices`
   (`scan_max_high` over `base_end_offset_weeks`..`+base_lookback_weeks`). Read the
   config window values. Name the exact line where the number is born.

7. **Write the *why*, decomposed.** Attribute the gap to a mechanism (timing /
   level / stop / structural tax), connect it to known findings
   (`project_edge_is_the_fat_tail`, the fill-model inversion), and state what it
   rules in/out for the next lever. A verdict without a transferable why is a draft
   (`mechanism-validation-rigor.md`).

## Caveats that bite (learned 2026-08-07/08)

- **`stop_initial_distance_pct` (col 15) is E-basis**, `|E − installed_stop| / E`,
  NOT fill-basis. When E ≫ fill it *looks* like a deep stop that isn't. Use
  `stop_fill_distance_pct` (gate-basis) or recompute vs `entry_price`. This is the
  "62% of stops > 15%" confound (`fill-model-fix-findings-2026-08-07.md` §4).
- **Audit decision date ≠ trade entry_date** for resting-order (StopLimit) arms:
  the order fills later, so `(symbol, entry_date)` joins miss. Join by
  `position_id`. (Same reason V12 under-counts on book arms.)
- **`dump_snap` prints a wide resistance-histogram tail** — `cut -d, -f1-6` for
  just OHLC.
- **Confirm the run reproduces** before trusting a dissection: a committed control
  scenario should regen bit-identical (the 2026-08-07 confound regen did).

## The deliverable

A per-trade table (MA-direction / close / prior-top-E / stop / fill / outcome) for
the top divergent trades, a distribution quantifying how common the pattern is, the
code line the suspect signal is born on, and a decomposed *why* that steers the
next session. Persist it as a `dev/notes/<topic>-YYYY-MM-DD.md` and, if it changes
a durable belief, a `project_*` memory.
