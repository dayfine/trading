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

## ~~P0 — weekly-close stop~~ — STALE: already built + REJECTED (2026-06-19)

**Correction 2026-07-07 (pre-flight check):** this lever was ALREADY built
(`trigger_on_weekly_close`, PR #1655, default-off, merged 2026-06-19) AND
lens-screened the same day —
`dev/experiments/weekly-close-screen-2026-06-19/FINDINGS.md`: **decisively
WORSE in both regimes** (deep 1998-2026 −457pp return for −5pp DD; 2011 bull
return HALVED with MaxDD UP 5pp; decision-level stop worse on every axis).
WF-CV correctly skipped (uniformly worse). The transferable why: the strategy
already re-enters recoverers, so a looser trigger only removes the fast
loss-cut; weekly-close holds genuine breakdowns to Friday. The stop's
per-decision "forgo > dodge" is the structural premium of the fat-tail edge,
not a fixable inefficiency. Vol-scaled stop (#1662) also screened + rejected
2026-06-20. **Stop-tuning thread is CLOSED.** The flag stays a default-off
REJECT axis on main.

(Root cause of the stale claim: the MEMORY.md index line lagged the memory
file's own STATUS section — fixed. Per `feedback_status_refresh_must_verify`,
the pre-flight grep caught it before a wrong feat-agent dispatch.)

## P0 (promoted from P1) — the all-eligible multivariate screen (user-directed 2026-07-07)

Definitive large-N closure of entry-selection: regress **counterfactual
outcome** (every eligible ticket ridden through our exit machinery — the
`all_eligible` lens already computes this) on the **full feature vector
jointly**, over the 26y broad population (tens of thousands of tickets),
instead of the one-attribute-at-a-time passes that are all individually dead.

- **P0a (prerequisite, small harness PR):** fix the RS-coverage gap (~77%
  `rs_value=None` in audit/all-eligible rows) + audit which other features
  (sector, liquidity/ADV, stop distance, weeks_advancing, volume ratio,
  score components) are reliably captured on the all-eligible path.
- **P0b (read-only screen):** generate the 26y broad all-eligible population
  (grade-sweep mode), run the multivariate pass. MUST follow `screen-rigor`
  (7 checks; distribution not point-estimate; verdict calibration — a null
  here is a *no-build decision* that finally closes entry-selection with
  power, not another piecemeal null). Prior: low. Value: closure either way;
  any surviving attribute becomes a default-off axis.
- Subsumes the old "decision-audit Phase-2 forward counterfactual" thread.

## P1 (was P2) — barbell deployment gates (the passed-but-parked lever)

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

## Suggested session shape (corrected — no mechanism build needed)

1. P0a harness fix (RS-coverage; small PR), then P0b all-eligible generation
   + multivariate pass (generation is the long pole; runs in container).
2. P1 barbell breadth-confirm cell after the generation frees the container
   (no concurrent sweeps per `sweep-hygiene`).

## Standing constraints (unchanged)

Scale-in closed; reallocation class exhausted; envelope closed both
directions; entry-selection tuning dead (pending P0b's definitive pass);
no funding-side knobs — they rotate lottery tickets. Weinstein spine stays
fixed; two consecutive surfaces validated book dials.
