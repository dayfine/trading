# Candidate-universe payoff run — top-3000, 2026-08-13/14

The 2026-08-13 acceptance run validated the *mechanism* and said so plainly:
302 → 291 symbols, 188s → 185s. The source universe was already small, so almost
every symbol became a candidate and there was nothing to drop. This run tests
the claim that motivated the builder — that over a broad universe the fixture is
an order of magnitude smaller and the re-run correspondingly cheaper, which is
what would make per-mechanism scenarios affordable.

**One variable changed** from the acceptance run: universe breadth, 302 → 3000.
Same window (2018-01-02..2023-12-29), same config (ladder-v4 cell-00 "core-w4"),
same comparison. Window length deliberately not varied — the 26y capture is a
separate, far more expensive follow-up, and mixing the two would leave a ratio
attributable to neither.

Run at `e6b28d302` (main incl. #2317), pinned worktree, snapshot warehouse
`/tmp/snap_top3000_dedup_v5thin_adj`, `--parallel 1`.

## Result — correctness: PASS, unambiguously

| | baseline | fixture |
|---|---|---|
| universe | `broad-3000-2010-01-01.sexp`, **3000** | `broad3000-candidates-2018-2023.sexp`, **277** |
| wall | 1020s | 808s |

```
actual.sexp        IDENTICAL
trades.csv         IDENTICAL
equity_curve.csv   IDENTICAL
trade_audit.sexp   IDENTICAL
macro_trend.sexp   IDENTICAL
open_positions.csv IDENTICAL
```

**2,723 dropped symbols changed nothing** — not one trade, not one point of the
equity curve, not one digit of the return. The soundness argument ("dropping a
symbol that never became a candidate cannot change the run, provided the capture
was taken at the lowest gate") now holds at a compression ratio of **10.8×**,
where the acceptance run could only demonstrate it at 1.04×.

Capture: 17,589 scored candidates → 4,123 grade-F rows → **277 distinct
symbols**, 0 unresolved sectors.

## The payoff is real but far smaller than the compression ratio suggests

**10.8× fewer symbols bought 1.26× less wall time** — 1020s → 808s, a 21%
saving. That gap is the actual finding of this run, and it is the opposite of
what the builder's motivation assumed.

Universe size is evidently not what dominates a scenario's cost at this window.
Whatever the remaining 808s is spent on — simulation over 313 weeks, position
management, warehouse access — it is nearly invariant to how many symbols the
universe holds. Dropping 91% of the universe removed only 21% of the work.

### Break-even makes this concrete

The capture that produces the fixture took **3h09m** (11,340s), against a saving
of **212s per re-run**:

```
11,340 / 212  ≈  54 runs
```

**A fixture must be re-used ~54 times on the same (window × config family)
before it has paid for its own capture.** For a one-off scenario it is a large
net loss. It only wins for something like a full ladder sweep — 24 cells × 3
salts ≈ 72 runs — and even then the win is ~25%, not the order of magnitude that
would change what is affordable.

Note also that the baseline itself is 17 minutes, not hours. Scenarios at this
window were not obviously unaffordable to begin with; the affordability problem
lives at 26y, which this run did not test.

### What this does not say

- It does not invalidate the builder. Correctness is established at a real
  compression ratio, which is what the acceptance run could not do, and the
  fixture remains a legitimate way to turn a broad-universe window into a
  *reproducible, small, committed* scenario. That value is independent of wall
  time.
- It does not generalise to 26y. Cost scales with both window length and
  universe size, and this run varied only the latter. A 26y capture would cost
  proportionally more to produce, but the per-run saving might also be larger.
  Unknown until measured — **do not assume the 21% carries.**
- **It does not say per-mechanism scenarios are now affordable.** That was the
  stated motivation, and on this evidence the fixture alone does not deliver it.
  If per-mechanism scenarios are the goal, the 808s floor is the thing to attack,
  not the universe size.

## Not a result

`total_return_pct` was **-4.25%** (331 trades). This pair exists only to be
compared against itself; the config was not tuned for top-3000 and the figure
must not be quoted as a strategy result.

## Files

- `run.sh` — the full chain, re-runnable.
- `base.sexp` / `fixture.sexp` — the two specs, differing only in name and
  universe. `fixture.resolved.sexp` is the fixture spec as actually run, with
  `universe_size` filled in at 277.
- `broad3000-candidates-2018-2023.sexp` — the emitted fixture universe, with its
  provenance header.
- `results.txt` — the raw byte-compare and capture output.

## One operational note

The chain's final `docker cp` back to the host failed: the experiment directory
was deleted out from under the running script by an unrelated `jj new` in the
parent workspace, three hours in. The container-side artefacts were intact and
everything was recovered, but this is the hazard in
`feedback_jj_new_wipes_long_running_outputs`, in a shape the existing rule does
not cover — it warns about *outputs* written into the repo, whereas here the
script's own directory vanished while it was executing. A long chain's host-side
paths should resolve outside the repo, or be captured into variables before the
first long step.
