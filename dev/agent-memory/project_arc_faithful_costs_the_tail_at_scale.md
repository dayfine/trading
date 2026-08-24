---
name: project-arc-faithful-costs-the-tail-at-scale
description: "Corrected arc bundle 26y = −62.4% (pre-correction −40.1%; the 22pp delta is INSIDE the 132.5pp null — no stop-fix claim). Structural finding: the faithful §4.2 fill-week gate ejects 72% of all entries over 26y (+$162/trade leg) while stops pay −$2.19M; negative P&L 19 of 27 years. 2019H1's ≈0 eject cost was the regime exception. laggard_rotation is the only big profit channel."
metadata:
  type: project
  originSessionId: 7959dddf-3101-4cab-8f02-c90b77a7d8fd
  modified: 2026-08-21T11:32:37.611Z
---

**"Faithful and profitable diverge" is now quantified at 26y scale.** The
four-override arc-faithful bundle (#2452: rt + anchor 4 + E-anchored StopLimit
2pp + volume-at-fill + `initial_stop_buffer 1.0`) on top-3000-2000, 2000→2026:

| | pre-correction | corrected |
|---|---:|---:|
| return | −40.1% | **−62.4%** |
| trades | 3,172 | 3,029 |
| mean hold | 7.6d | 9.3d |

**Null discipline:** the 22pp intra-bundle delta is inside the 132.5pp 26y
noise floor — the stop correction's 26y effect is NOT measurable from these
two runs, even though the 6-month `bookstop` arm showed −4.17%→+4.83%
([[project-entry-cap-horizon-reversal]] horizon trap, again).

**The robust structural claim:** exit mix = volume_eject 2,192 (72%, +$355k ≈
+$162/trade), stop_loss 668 (−$2.19M), laggard_rotation 154 (+$1.29M — the
only real profit channel, [[project-trade-forensics-2026-06-12]]). Negative
yearly P&L in 19 of 27 years. The gate is behaving exactly as §4.2 commands
([[project-fallback-stop-half-book-band]] session resolved it faithful) — the
book's "sell it for a fast profit when it advances (which it will usually do)"
premise does not pay on a broad modern universe; the `bothfix` 2019H1 ≈0 cost
was the exception, and the whole bundle sits ~350pp below `fullbook-graded`'s
+287% (far outside any null).

**Licensed forward dials (recorded, not proposed):** volume
`strong_threshold` (2×) era-tuning {1.2, 1.5, 2.0} under the W2 license — but
it is **NOT sweepable today**: it lives in `Volume.config`, unreachable from
`Weinstein_strategy.config` / `Overlay_validator` (QC catch, the
[[project-rt-needs-its-anchor-knob]] shape); plumbing required first. Also the
eject-timing nuance (book sells into the advance, runner sells next open).
Caveat on the pair: the two 26y runs also differed in `data_dir` (worktree
test_data vs live store) — snapshot bars same warehouse, but AD-breadth reads
moved (sector map comes from the spec's universe_path, NOT data_dir); one more
axis making the intra-pair delta non-claimable.

Record: `dev/notes/arc26y-corrected-writeup-2026-08-21.md`, artifacts
`dev/experiments/inspect-6mo-2026-08-21/results/arc26y-{precorrection,corrected}-*`
(PR #2459).
