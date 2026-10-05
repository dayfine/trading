# Short-only liveness, Phase A (2026-10-04)

## Why

User direction 2026-10-04: build a standalone short-only strategy that "should just make money by itself", then
integrate with the long book. The short leg has only been tested grafted onto the long investor preset, where it
made 0 fills (`../shorts-liveness-2026-10-03/`). The short-only design read (2026-10-04) ranked the causes:
the slow-grind gate (not a book rule; ledger Reject) shut 95 % of graded short slots; the investor preset prices a
short ticket at `breakout_price` — the **top** of the prior base, not the breakdown (screener.ml:145-161;
`screener_entry_anchor.ml` `choose ~is_short:true` → Breakout) — so tickets sat 21–34 % above market; and the
mirrored structural-stop scan cannot see the rally peak at a fresh breakdown. Phase A asks only **does a short-only
book trade at all** once the non-book gate is off and tickets are priced at the current close (the book's trader
entry, Ch. 7: full position on the breakdown). No new code.

## Arms (5d = 2007-06-01 → 2012-06-29, PIT top-3000 schedule, `_v11pit`, salt 0)

| arm | spec | differs from `../shorts-liveness-2026-10-03/specs/shB-5d.sexp` |
|---|---|---|
| `soT` | `specs/soT-5d.sexp` | longs off (`max_buy_candidates 0`), `enable_slow_grind_short_gate false`, `sim_entry_trigger_at_suggested false` (ticket at the close), `require_structural_stop false` (~4–6 % buffer stop, the book's trader stop), `max_short_candidates 20`, short exposure / notional caps 0.60, `max_position_pct_short 0.10` |
| `soTs` | `specs/soTs-5d.sexp` | `soT` + `require_structural_stop true` + `support_floor_anchor_scope Nearest` (isolates the stop-geometry gate) |

Unchanged from shB: `neutral_blocks_shorts true` (book: shorts in a bear tape), `short_min_price 17`, borrow ADV
$1M, margin model on (maintenance 0.30, borrow/maintenance tiers), 2 % stop-limit band, 15 % max stop width.

## Reading rule (pre-registered 2026-10-04, before any cell runs)

1. **Live** (per arm): ≥ 10 short fills over the window **and** ≥ 5 of them filled in 2008.
2. **Dead** → name the binding gate from the arm's `trade_audit.sexp` cascade diagnostics and entry-week skip
   reasons (counts per gate, as in the 10-03 funnel). At most two follow-up iterations, each opening one gate,
   pre-registered as a Log line before it runs; then stop and record (design §5 stop rule).
3. **Sanity**: every short entry filled in a week whose screen read `Bearish` (count over trades.csv **and**
   open_positions.csv); any non-Bearish entry is a defect to trace. V6 exit 0 between the arms.
4. **Descriptive only**: P&L, max DD, win rate, top trades, 2008 vs 2009–12 split. **No verdict** on "makes money
   by itself" from Phase A: that is Phase C (26y, 3 salts, criteria M1–M5 approved by the user 2026-10-04), after
   the entry-level defect fix (Phase B).
5. Review pack built, rendered and looked at; the short-leg section (#3111) is the read.

## Files

`specs/`, `results/chain-shortonly.sh` (copy of the 10-03 chain, paths moved), `results/launch.sh`.

## Log

- 2026-10-04 — pre-registered.
