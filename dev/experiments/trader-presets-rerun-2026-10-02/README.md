# Trader-preset rerun after the continuation-anchor fix (2026-10-02)

Follow-up to `../trader-presets-2026-09-29/` (#3038, writeup `results-2026-10-01.md`, PR #3061).
That matrix left two questions open:

1. **Continuation buys were never tested.** T1 was trade-for-trade identical to H in all 6 cells:
   the entry ticket was anchored at the old base top, which a continuation name has already left
   behind (#3056). #3067 anchors a continuation candidate's ticket at the detector's
   `consolidation_high`, behind `enable_continuation_buys` (flag-off path unchanged). This rerun
   is the T1 / T2 measurement the matrix could not make.
2. **T0's 5r "adds" was flagged, not adopted** (book prior: the 10-week MA is a *trader's* MA for
   timing, not a stage definition). T0 changed two things at once: the stage MA **and**, through
   the default `trailing_stop_ma_period = None`, the MA the stop machine trails. Its edge in the
   matrix came from profitable stop exits (21–28 per salt vs H's 7). Arm **T0S** pins the stop
   machine back to the 30-week MA (`((trailing_stop_ma_period (30)))`) while stages stay on 10
   weeks, to separate the two.

## Arms

| arm | spec | change vs H |
|---|---|---|
| H | `tp-h-<w>` | hybrid control, verbatim from the 09-29 matrix |
| T1 | `tp-t1-<w>` | `((enable_continuation_buys true))`, verbatim; now live through #3067 |
| T2 | `tp-t2-<w>` | T1 + `((trailing_stop_ma_period (10)))`, verbatim |
| T0S | `tp-t0s-5r` | `tp-t0-5r` + `((trailing_stop_ma_period (30)))` — 10-week stages, 30-week stop MA |

The six H / T1 / T2 specs are byte-copies of `../trader-presets-2026-09-29/specs/`. `tp-t0s-5r` is
hand-derived from `tp-t0-5r.sexp`; the diff is the header comment, the name/description and one
override line.

## Windows and salts

`5r` (2021-06-01 → 2026-06-26, PIT top-3000 2020 … 2025) and `5d` (2007-06-01 → 2012-06-29, PIT
top-3000 2006 … 2011), salts 0/1/2. T0S runs on `5r` only: the T0 `5d` read is blocked on the
CMN/CMD rename twin (#3057, root cause in its 10-01 comment), and T0S
shares T0's 10-week stage classification, so it would likely admit the same twin.

21 cells, one chain, one build (main after #3067), pinned worktree; ~40 min per cell → ~14 h.

## Same-build anchor

H is not touched by #3067 (the continuation arm is unreachable while `enable_continuation_buys` is
off). Each rerun H cell must therefore match its 09-29 counterpart (build 6bcefc0c8) on
`actual.sexp` metrics and `trades.csv` (all columns but `position_id`). A mismatch means the build
moved something else, and T0S-vs-T0 (the one cross-build read below) becomes descriptive only.

## Reading rule (pre-registered 2026-10-02, before any cell runs)

Rules 1–5 of `../trader-presets-2026-09-29/README.md` §"Reading rule" apply **verbatim** to the
T1-vs-H and T2-vs-T1 pairs: V6 gate per salt, valid-salt thresholds (2 of 3, 2 of 2, else "no
reading"), Calmar primary with the 5 pp max-DD guard, the four outcomes ("adds" / "mixed" /
"dilutes" / "no reading"), the per-entry-type split for T1 (continuation vs base-breakout:
count, realized P&L, win rate, median `pnl_percent`), and the (entry date, symbol) per-trade
join for any arm that "wins".

Additional rules for this rerun:

6. **Liveness first.** If T1 is again trade-for-trade identical to H in a window, the T1 and T2
   readings for that window are "not tested" (as in the 09-29 matrix), and the fix is reported as
   not reaching the run path.
7. **T0S vs H** — the same four outcomes as rule 3, at `5r`. Reported alongside the 09-29 T0 cells
   (same salts, same window):
   - T0S keeps T0's edge (Calmar ≥ T0's at 2 of 3 valid salts) → the edge is the **10-week stage
     classification / entry set**, not the stop.
   - T0S loses it (Calmar < H's at 2 of 3) → the edge was the **10-week trailing stop on T0's
     entries**; record it as an exit-side finding, and note that T2 (10-week stop on the 30-week
     entry set) dilutes.
   - Anything else → "not separable at n = 3".
   The book prior stands either way: no 10-week stage arm is promotable from this rerun. A T0S
   "adds" is flagged, as T0's was.
8. **Same-build anchor** (above) is checked before any cross-build sentence is written.
9. **Entry-type classifier (for rule 3's split).** No artifact tags an entry as continuation, so
   an entry counts as **continuation** when its `trade_audit.sexp` entry record has
   `(stage (Stage2 (weeks_advancing N) ...))` with N > 4, and as **base-breakout** otherwise. Basis:
   the hybrid only admits early Stage 2 (N ≤ 4) — the 09-29 `tp-h-5r-s0` audit has 361 entries, all
   N ≤ 4 (288 / 28 / 24 / 21 at N = 1–4). Check: every rerun H cell must also have zero N > 4
   entries, else the classifier is void and the split is not reported.

No ledger entry unless a dial reads "adds" in both windows at the required threshold; even then
the promotion path is the confirmation grid (`promotion-confirmation.md`), not this rerun.

## Files

- `specs/` — the seven specs.
- `results/chain-trader.sh` — copy of the 09-29 chain with run paths moved to `/tmp/trader-rerun`
  and `/tmp/sweeps/trader-presets-rerun`.
- `results/launch.sh` — `PREREG=<this commit> sh launch.sh`; pins a worktree at main, aborts unless
  #3067 is in it, stages specs from the pre-registration commit.
