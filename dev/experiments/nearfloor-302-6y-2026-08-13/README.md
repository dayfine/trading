# Nearfloor at 302 symbols / 6y — the missing artifact, plus a corrected spread

**What this is.** The committed evidence for the 302/6y cell in
`dev/notes/ladder-v4-read-2026-08-12.md` §3c. That cell was reported with no
spec, no results file, and no run script — the one claim in the writeup framed
with the most statistical rigour ("3 salts, decisive at this scale") and the
least traceability. qc-behavioral flagged it on PR #2288; this directory is the
answer.

**Arms.** Identical configs except one knob:

| arm | `stops_config.support_floor_anchor_scope` |
|---|---|
| `nf-small-00-core` | `Window_extreme` (baseline) |
| `nf-small-09-nearfloor` | `Nearest` |

Both are the ladder-v4 cell-00 / cell-09 configs re-pointed at the 302-symbol
`universes/small.sexp` over 2018-01-02 → 2023-12-29. Three `TRADING_PATH_SEED_SALT`
draws each, run from the pinned `v4-fixed` worktree (post-#2279 seed fix), CSV
mode, `--parallel 1`. `run.sh` reproduces it; `results.txt` is the raw log.

## Results (this run, 2026-08-13)

| arm | salt 0 | salt 1 | salt 2 | mean | spread |
|---|---|---|---|---|---|
| 00 core | 65.91 | 47.33 | 48.27 | **53.84** | **18.58** |
| 09 nearfloor | 24.98 | 25.42 | 25.32 | **25.24** | **0.44** |

Full metrics per run are in `results.txt`:

| | trades | win rate | maxDD | holding days |
|---|---|---|---|---|
| 00 core | 288 / 289 / 288 | 33.33 / 31.83 / 31.25 | 19.055 / 19.049 / 19.046 | 42.3 / 41.0 / 41.2 |
| 09 nearfloor | 235 / 235 / 235 | 37.45 / 37.87 / 37.87 | 15.098 / 15.048 / 15.092 | 61.8 / 61.8 / 61.8 |

(The win-rate column was previously quoted in §3c with no source anywhere in the
repo. It reproduces: the claimed `37.9 > 31.4` matches nearfloor 37.87 against
core 31.25–33.33. Holding period is new and was never reported: nearfloor holds
**~62 days against core's ~41**.)

## What it confirms, and what it corrects

**Confirms — the mechanism signature.** Nearfloor trades less (235 vs ~288) and
draws down less (15.1 vs 19.05) in every draw. Same signature as the other two
contexts. The §3c reading that nearfloor is a *risk* mechanism stands.

**Confirms — nearfloor's stability.** The original reported 25.2 / 24.9 / 24.9;
this run gives 24.98 / 25.42 / 25.32. That reproduces essentially exactly, and
is the strongest single number in the whole §3c cell.

**Confirms — the direction, more strongly than claimed.** All six draws separate
cleanly: the worst core draw (47.33) still beats the best nearfloor draw (25.42)
by 21.9pp. "Decisive at this scale" survives.

**Corrects — the draw-spread.** §3c reported a core range of **6.6pp** and
concluded core wins "against a draw-spread of at most 6.6pp". This run's core
range is **18.58pp** — **~2.8x** the reported figure. The original measured the
*stable* arm's spread accurately and implicitly assumed it characterised both
arms; three draws of a fat-tailed quantity can look tight purely by luck, and a
range computed from them is itself a high-variance estimate.

**Do not pool the two runs.** An earlier draft of this file quoted a pooled
six-draw spread of 24.4pp (~4x). That figure is withdrawn. Both runs are salts
0/1/2 of the same spec, so under #2279's determinism they should be
bit-identical — and they are not: the old run's 47.3 aligns to this run's **s1**,
not s0, and its 48.1 is not this run's 48.27. They are therefore different
generative processes (different binary or data vintage), not six draws of one
distribution, and pooling them is not a legitimate range. It would also take its
low endpoint (41.5) from the very run being retired here as untraceable. The
in-run **18.58pp** is self-sourced and reaches the same conclusion.

That non-alignment is itself worth recording: the pre-fix numbers are not
reproducible *even by salt*, which is the strongest available argument for
retiring them rather than reconciling them.

## The finding this adds: nearfloor collapses path-variance

Across the three salts, nearfloor's outcome barely moves while core's swings:

| | return spread | maxDD spread | trades |
|---|---|---|---|
| 00 core | 18.58pp | 0.009pp | 288 / 289 / 288 |
| 09 nearfloor | 0.44pp | 0.050pp | **235 / 235 / 235** — exactly invariant |

The load-bearing evidence is not the return-spread ratio (that is a ratio of two
n=3 ranges, and this file's own closing rule says not to lean on such a thing).
It is the **structure** of core's dispersion: its trade count moves by *one*
and its drawdown by 0.009pp, while its return moves 18.58pp. Nearly the entire
outcome difference across draws sits in **the outcome of a single trade** —
which is §1b's "a cent re-runs the lottery" observed directly, at a scale small
enough to see. Nearfloor's trade count, by contrast, is bit-stable across all
three draws.

So the mechanism reading is: anchoring the stop at the nearest qualifying
correction low removes the path-dependence that makes the baseline's outcome a
lottery over which monsters get funded. The baseline keeps the fat right tail
(65.9) and pays for it in dispersion; nearfloor clips both ends — and holds far
longer when it does hold (~62 days vs ~41), which is what a stop that is not
being knocked out by intra-move noise looks like.

Which is the honest frame for the whole question: nearfloor is not "worse by
~28pp", it is **a different risk/return point** — roughly half the return, 4pp
less drawdown, a higher win rate (37.9 vs 31–33), a ~50% longer hold, and an
outcome that barely depends on the path draw. Whether that trade is worth taking
is a Calmar/Sharpe question on the target regime, not a return-ranking question,
exactly as §3c concludes.

## Methodological carry-forward

**Never quote a range from n=3 as a noise floor.** Both this cell and the
26y-null work now have the same lesson from opposite directions: the ladder-v4
duplicate cell measured a 278pp null at 26y, and here a 6.6pp "spread" was
really ~24pp. A small-sample range understates dispersion in exactly the
fat-tailed setting where dispersion matters most. Report n, and prefer a
duplicate-cell null over a range across a handful of draws.
