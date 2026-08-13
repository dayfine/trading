---
name: project-nearfloor-is-risk-not-return
description: "Nearest-floor stop anchoring is a reproducible risk-reduction dial that costs return — its 26y \"670%\" return edge rests on a single draw and reverses in two independent contexts"
metadata: 
  node_type: memory
  type: project
  originSessionId: d7d8f2bb-6b58-4fde-8e01-c50e796e5faa
  modified: 2026-08-12T15:26:45.607Z
---

`stops_config.support_floor_anchor_scope = Nearest` (F3, PR #2258) anchors the
initial stop on the nearest qualifying prior correction low instead of the
window extremum. Ladder-v4 cell 09 made it look like the best lever in the
program (669.98 vs cell 00's 343.90 at 26y/top-3000). **That return claim does
not hold up.**

**The mechanism is real and reproduces everywhere** — fewer trades, higher win
rate, lower drawdown, in all three contexts tested:

| context | trades | win rate | maxDD | return |
|---|---|---|---|---|
| 26y / top-3000 | 967 < 1136 | 40.4 > 34.0 | 27.0 < 44.3 | **670 > 344** |
| sp500 / 5y | 207 < 240 | — | — | **38.6 < 112.3** |
| small-302 / 6y (3 salts) | 235 < 288 | 37.87 > 31.25 | 15.09 < 19.05 | **25.24 < 53.84** |

⚠ **Sourcing of the win-rate column.** The 302/6y row is sourced
(`dev/experiments/nearfloor-302-6y-2026-08-13/results.txt`). The **26y row's
`40.4 > 34.0` is NOT** — it has no committed artifact anywhere in the repo, and
a repo-wide grep for it comes back empty outside these two tables. Treat it as
unverified until a 26y run emits it. The trades / maxDD / return columns for
that row are sourced; the win rate alone is not. (So "reproduces everywhere"
above rests on two sourced rows plus one unverified cell, not three sourced
rows.)

**The return advantage appears in exactly one context** — the 26y *single draw*,
which is the measurement most exposed to the monster lottery and whose noise
floor is ~278pp ([[project-ladder-v4-null-278pp]]). At 302/6y across three path
salts, core beats nearfloor on every draw; nearfloor itself is strikingly stable
(25.2 / 24.9 / 24.9).

**Re-run + corrected 2026-08-13** (`dev/experiments/nearfloor-302-6y-2026-08-13/`,
committed after PR #2288's review found this cell had no artifact at all).
Nearfloor reproduces essentially exactly (24.98 / 25.42 / 25.32). The core arm's
"≤6.6pp draw-spread" does **not** — this run gave 65.91 / 47.33 / 48.27, spread
**18.58pp (~2.8x** the original figure). The separation still holds and is
stronger than claimed: worst core draw 47.33 > best nearfloor draw 25.42, by
21.9pp. Win rate also now sourced (37.87 vs 31.25–33.33) and holding period is
new: nearfloor holds **~62 days vs core's ~41**.

⚠ **Do NOT pool the two runs.** A draft of this correction quoted a pooled
six-draw 24.4pp — withdrawn. Both runs are salts 0/1/2 of one spec, so
post-#2279 they should be bit-identical and are not (old 47.3 aligns to new
**s1**; 48.1 ≠ 48.27). Different generative processes, and the pooled low
endpoint came from the run being retired as untraceable. That non-reproducibility
*even by salt* is the real argument for retiring the old numbers.

**The mechanism:** core's dispersion is structurally concentrated — across its
three draws the trade count moves by **one** (288/289/288) and maxDD by
**0.009pp**, while return moves 18.58pp. Nearly the whole draw-to-draw
difference sits in **a single trade's outcome** — §1b's "a cent re-runs the
lottery", seen directly. Nearfloor's trade count is exactly invariant
(235/235/235). So nearfloor does not merely earn less; it **collapses
path-variance**, clipping the path-dependence that makes the baseline a lottery
over which monsters get funded. (State it that way, not as a ~40x variance
ratio — that ratio's numerator is an n=3 range, which the rule below forbids
leaning on.)

**Method carry-forward:** never quote a range from n=3 as a noise floor. The
original error was measuring the *stable* arm's spread accurately and assuming it
characterised both arms; three draws of a fat-tailed quantity look tight by luck.
Prefer a duplicate-cell null ([[project-ladder-v4-null-278pp]]) over a small-n
range, and always report n.

**How to apply:** do not carry "nearfloor = the result" forward. The right
question is not "does it make more money" — two independent contexts say no — but
"is the risk reduction worth the return it costs". That is a Calmar/Sharpe
question; at 26y it showed Sharpe 0.582 vs 0.457 and maxDD 27.0 vs 44.3, which
is worth evaluating properly on distributions in the target regime. Also note
the mechanism verified in the audit: `stop_floor_kind` moves 867/558 →
108/1158 Buffer_fallback/Support_floor, i.e. `Window_extreme` was falling back
to an arbitrary buffer for most candidates.

Writeup: `dev/notes/ladder-v4-read-2026-08-12.md` §3c. Related:
[[project-edge-is-the-fat-tail]], [[project-backtest-nondeterminism-intraday-path]].
