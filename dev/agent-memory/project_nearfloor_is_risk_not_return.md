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
| small-302 / 6y (3 salts) | 235 < 291 | 37.9 > 31.4 | 15.2 < 19.1 | **25.0 < 45.6** |

**The return advantage appears in exactly one context** — the 26y *single draw*,
which is the measurement most exposed to the monster lottery and whose noise
floor is ~278pp ([[project-ladder-v4-null-278pp]]). At 302/6y across three path
salts, core beats nearfloor by ~20pp every draw against a ≤6.6pp draw-spread;
nearfloor itself is strikingly stable (25.2 / 24.9 / 24.9).

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
