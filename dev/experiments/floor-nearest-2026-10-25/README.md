# floor-nearest-2026-10-25: Nearest support floor under `require_structural_stop`, pre-registered

Status: **PRE-REGISTERED, NOT RUN.** This directory holds the chain, the one p0 spec and the read rule below, written
before any SN cell ran. The null it is read against (path-stability arm S, 6 cells) finished on 2026-10-24 and its
numbers are quoted here; SN's are not known to the author.

## Why this arm

The record N arm skips about 20,000 decisions over 26 y as `No_structural_stop` (every year, 87–97 % of top-N
decisions). On the path-stability S p0 cell it is 8,302 skips against 190 placed tickets. A host-only screen of the
26y record skips (2026-10-25, memory `project_floor_and_refresh_screens`) found:

- 67 % of skips have no 8 % pullback after the 90-bar high, because the high is at or near the end of the window: the
  stock is making new highs, which is the shape the strategy wants to buy.
- With `support_floor_anchor_scope Nearest` (an existing default-off dial: the nearest correction that meets
  `min_correction_pct`, not the one after the window extreme), about 8× more tickets get a structural stop within
  `max_stop_distance_pct`, at a similar per-trade mean in a crude 26-week proxy (+5.0 % vs +7.1 % placed; > +50 %
  tail 6.3 % vs 5.1 %).

The proxy has no ranking, capital or trailing stops, so it cannot say whether the extra tickets beat the current picks
for a slot. That is what this backtest measures. The stop stays structural (book Ch. 6: no automatic percentage stops);
only which correction anchors it changes.

Prior record: the 08-16 Nearest grid (`dev/experiments/nearfloor-confirmation-grid-2026-08-16/`, memory
`project_nearfloor_is_risk_not_return`) did not promote Nearest: 0 of 3 cells cleared their null on return, with a real
loss on top-3000 × 2010–2026. That grid predates `require_structural_stop`. With the gate off, Nearest only tightens
stops on tickets that would be placed anyway. With the gate on, it also turns skips into entries, which is a different
mechanism. The 08-16 finding (a crash-depth dial whose effect depends on deep prior lows in the window) is a standing
prior against it.

## Design

- **Arm SN** = path-stability arm S (`../path-stability-2026-10-23/specs/ps-S-p0.sexp`: the record N body, Seeded tie
  order, 2019-01-01 → 2024-12-31, top-3000 pit-v12 schedule) plus one override:
  `((stops_config ((support_floor_anchor_scope Nearest))))`. The spec differs from ps-S-p0 by that line, the name, the
  description and the header comment.
- **Null** = path-stability S, already run: 6 cells, same build (`3db869d32`), same warehouse, same lists (md5
  `51fba79e…`), same five deleted names (SHEN, ODFL, SLAB, DECK, DIOD), same seeds (pk sets `tiebreak_seed k`).
- **K = 6** SN cells: p0 unperturbed, and p1–p5 delete the null's k-th name with `tiebreak_seed k`. Names are copied from
  the null, never re-chosen.
- **Validity.** SN p0 is gated on `validator_diff -check V6` against the null's A-p0, and each SN pk against SN p0, as in
  the null's chain. An excluded cell is dropped and named.
- **Cost.** 6 cells at about 3,000–3,600 s each (the null's S/SC cells), about 6–7 h, alone in the container.

## Metrics and decision rule (written before any SN run)

Per arm over its included cells: spread = sample SD of ln(1 + R); median ln(1 + R), Sharpe, max DD and Calmar.
Null values (path-stability `summary.txt`, 2026-10-24): spread(S) = **0.2108**, median ln(1 + R) = **1.0313**, median
max DD 23.29 %, median Calmar 0.674.

1. **Liveness first.** From SN p0's trade audit: `No_structural_stop` ≤ 0.75 × 8,302 **and** `Placed` > 190 (S p0's
   counts). If either fails, the mechanism did not do what the screen predicted. The run is recorded as "not live as
   screened", with no return read, and the next step is to find out why.
2. **Return.** Δ = median ln(1 + R)(SN) − median ln(1 + R)(S), with the bar b = spread(S) = 0.2108.
   - Δ ≥ +b → **PROMISING**: escalate to a new pre-registration covering 26 y plus a pre-2009 cell
     (`promotion-confirmation.md`; the 08-16 lesson makes the pre-2009 / crash-depth cell mandatory). Not a promotion.
   - Δ ≤ −b → **NO-BUILD decision** for this lever at this window. The dial stays default-off as an axis.
   - otherwise → **INCONCLUSIVE**: no escalation on return.
3. **Do-no-harm on PROMISING.** If median max DD(SN) − median max DD(S) > 100 × b pp, the result reads "PROMISING
   with a DD cost": a user decision, not an automatic escalation. Calmar is reported beside it.
4. **Reported, not decision-bearing:** spread(SN)/spread(S); how many of the 36 SN × S cross pairs SN wins; the
   divergence onset of each SN pk; the review-pack signals of SN p0; the tail (trades above +100 % total return per
   cell and the top trade's share of P&L), read from the committed `trades.csv`.

**Power, said up front.** With n = 6 per arm and spread 0.21, the standard error of a difference in medians is about
0.15, so the bar b = 0.21 is about 1.4 SE. Only a large effect can register. An INCONCLUSIVE result does not show that
Nearest has no effect. The cells cannot be paired: every SN pk diverges from its null partner within weeks (the null's
divergence onsets are all in Feb–May 2019), so the comparison is between unpaired distributions.

**Window caveat.** 2019–2024 reuses the null and contains the 2020 V and the 2022–23 round trip, but not 2025 (the
year that motivated this) and nothing before 2009. Escalation exists to cover both.

## How to run

```sh
PREREG=<this commit> sh dev/experiments/floor-nearest-2026-10-25/chain.sh launch   # reuses .claude/worktrees/sweep-ps @ 3db869d32
tail -f /tmp/fn-run/chain.log
sh dev/experiments/floor-nearest-2026-10-25/chain.sh summary /tmp/fn-run/results   # S rows from NULL_DIR (default /tmp/ps-run/results)
sh dev/scripts/perf_long_cells.sh update /tmp/fn-run/chain.log
```

`chain.sh` is `../path-stability-2026-10-23/chain.sh` cut down to one arm. Its header lists the changes: the null's
build, names and lists are asserted at launch, there are separate stage, work, fixtures and output dirs, and the
summary reads S from `NULL_DIR` and applies the rule above. It was checked with `sh -n`, `dash -n` and
`posix_sh_check.sh`. `summary` was also run on the null's own SC cells relabelled as SN, which exercises the arithmetic
only: it read "NO-BUILD", as SC's numbers imply.

## Arm SM (second stage, blocked): a monthly universe refresh

The yearly May 31 list freezes the universe for 12 months. Live trading screens whatever is liquid now. In the same
screen, a monthly top-3000 (same 60-day dollar-volume rule) had 13 % of members outside the yearly list in force. These
entrants have a lower median 12-month forward return (−0.5 % vs +6.1 %) but hold 29 % of all > +300 % 12-month moves
(AXTI enters at 2025-09; the yearly lists never admit it). Pre-registered here so that the rule predates any SM run:

- **Arm SM** = S with `universe_schedule` holding a dated top-3000 list at every month end (1999-05-31 → 2025-12-31),
  built by the same builder and post-processing as pit-v12 (the dollar-volume rank, the equity filter, the #3391
  twin-drops). Everything else is S's.
- **Prerequisites (each a PR, before any SM run):**
  1. A dates option on the list builder (`build_composition_universes_runner` anchors at May 31 today, though
     `Build_from_individuals.build ~date` takes any date).
  2. A reproduction check: the builder's May 31 output must equal the committed pit-v12 yearly lists byte for byte, so
     the monthly lists differ from the yearly ones only by date.
  3. A warehouse whose manifest covers the union of the monthly lists, with the chain's set-equality check.
- **Perturbations:** the same five names, cut from every monthly list; same seeds.
- **Rule:** the same as SN's (liveness, then Δ against spread(S), do-no-harm, the same caveats). Liveness for SM: at
  least one SM p0 trade in a symbol outside the yearly list in force on its entry date.

## Results

_Placeholder: filled by the results PR (results-analyst read, `summary.txt`, review-pack look, `Verifies` line)._
