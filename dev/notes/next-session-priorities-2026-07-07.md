# Next-session priorities — 2026-07-07 (rev 2)

**Supersedes** the morning revision of this file (cash-reserve items now resolved) and `next-session-priorities-2026-07-06.md`. Main green.

## What 2026-07-06→07 added (all merged)

- **Cash-reserve arc closed** (#1867 mechanism → #1872 REJECT verdict → #1875
  forensics): 30% reserve = clear loss; response non-monotonic. Forensics
  pinned the exact mechanism: the flipped 2022 fold was ONE funding slot
  (TDW re-breakout, 2022-02-05) that only r20 happened to have cash for; r10
  leaked its freed cash into other entries (D/CBSH/CAH), r30's subtraction
  priced the slot out. **Envelope program closed both directions.**
- **Session synthesis (the frame for what follows):** precision is
  structurally poor (winners ≈ losers at entry; sort is FAITHFUL; all single
  signals dead) AND candidates oversubscribe capacity ~4:1 (~20 admitted vs
  ~5 fundable/Friday). Funding-side knobs therefore only rotate lottery
  tickets. The levers that change the lottery's expected value: more tickets
  (breadth — have), bigger claim per winner (concentration — have, at 0.30),
  **not surrendering winners early (holding discipline — GAP)**, orthogonal
  layers (barbell — passed grid, NOT deployed).

## P0 — weekly-close stop (the unbuilt holding-discipline lever)

The inventory gap surfaced 2026-07-07: stops fire **intraday on bar.low**;
the book's L3 rule is **weekly CLOSE**. The stop-lens already measured our
stops as whipsaw-dominated — forgone upside +30–33% vs disaster dodged −19%
(`project_weekly_close_stop_lever`, plan `weekly-close-stop-2026-06-19.md`).
Directly tail-PRESERVING (fewer whipsaw ejections of eventual winners) — the
favored lever class, and a faithfulness fix at the same time.

Steps (the standard loop):
1. Build `stop_trigger_mode : Intraday | Weekly_close` (or equivalent) as a
   default-off config field per `experiment-flag-discipline` (default =
   current intraday behaviour, bit-identical). Note the catastrophic-stop
   interaction: the fast-crash absolute stop (#1695) should arguably STAY
   intraday as the tail-risk insurance while the trailing stop moves to
   weekly-close — make that split explicit in the design.
2. Broad top-3000 13×2y WF-CV surface {Intraday=baseline, Weekly_close},
   possibly × a small stop-buffer axis. ~9h.
3. Verdict + ledger; confirmation grid only if ACCEPT.

## P1 — the all-eligible multivariate screen (user-directed 2026-07-07)

Definitive large-N closure of entry-selection: regress **counterfactual
outcome** (every eligible ticket ridden through our exit machinery — the
`all_eligible` lens already computes this) on the **full feature vector
jointly**, over the 26y broad population (tens of thousands of tickets),
instead of the one-attribute-at-a-time passes that are all individually dead.

- **P1a (prerequisite, small harness PR):** fix the RS-coverage gap (~77%
  `rs_value=None` in audit/all-eligible rows) + audit which other features
  (sector, liquidity/ADV, stop distance, weeks_advancing, volume ratio,
  score components) are reliably captured on the all-eligible path.
- **P1b (read-only screen):** generate the 26y broad all-eligible population
  (grade-sweep mode), run the multivariate pass. MUST follow `screen-rigor`
  (7 checks; distribution not point-estimate; verdict calibration — a null
  here is a *no-build decision* that finally closes entry-selection with
  power, not another piecemeal null). Prior: low. Value: closure either way;
  any surviving attribute becomes a default-off axis.
- Subsumes the old "decision-audit Phase-2 forward counterfactual" thread.

## P2 — barbell deployment gates (the passed-but-parked lever)

70/30 barbell passed its promotion grid 2026-06-20 — the only lever ever to —
and has sat since. Remaining gates: (a) breadth-confirm cell (re-run the grid
cell on the top-3000 basis), (b) a deployable overlay design (how the
SPY-floor + engine-NAV blend is actually operated live). If both clear, this
is the first live capital-protection change with ledger evidence behind it.

## Carried / small

- **check_limits wire-or-delete** (human decision; DELETE now natural — the
  cash-floor half was settled by the reserve REJECT).
- P4 continuous-RS display (live-picks UX only).
- Faithful per-week universes (M6.6). Deferred.
- Harness nits: `write_ledger_entry.exe` doesn't regen `index.sexp`;
  GH check-attach latency breaks naive merge-wait loops (wait for ≥2
  COMPLETED, not just zero-pending).

## Suggested session shape

1. Dispatch P0 mechanism build (feat-weinstein) first — it's the long pole
   (build + QC + ~9h sweep; sweep runs overnight).
2. While P0's sweep runs: P1a harness fix (small PR), then P1b generation.
3. P2 breadth-confirm cell fits after the P0 sweep frees the container
   (no concurrent sweeps per `sweep-hygiene`).

## Standing constraints (unchanged)

Scale-in closed; reallocation class exhausted; envelope closed both
directions; entry-selection tuning dead (pending P1b's definitive pass);
no funding-side knobs — they rotate lottery tickets. Weinstein spine stays
fixed; two consecutive surfaces validated book dials.
