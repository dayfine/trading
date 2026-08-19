---
name: project-stale-order-fills-are-not-an-edge
description: "Fills from tickets resting >26wk are 7.8% of fills and -15.1% of total P&L on the 26y record base (-3,923/trade vs +2,518 for the rest). Net-losing but tail-heavy — which is why one 5y cell showed -40.91pp for cutting them."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-19T18:43:49.056Z
---

**A fill from a long-frozen `E` is order persistence being harvested, not signal.**
User verdict 2026-08-19: *"that's not an edge"* — and the largest sample we have
agrees.

`dev/experiments/ttl-retest-2026-08-16/README.md`, `position_id`-keyed rest-time
table, 26-year record base, 1,147 fills, `clock=0`:

| cohort | fills | P&L | per trade |
|---|---:|---:|---:|
| rest ≤ 26wk | 1,058 | +2,664,085 | **+2,518** |
| **rest > 26wk** | **89** | **−349,132** | **−3,923** |

**7.8% of fills, −15.1% of total P&L**, losing at roughly the rate the healthy
population earns. The profit engine is the **5–13wk band** (+1,021,434 on 136
fills); ≤1wk carries the bulk (+1,710,291 on 698).

## Why the two clock measurements never conflicted

Long-rest fills are **negative in expectation but tail-heavy**. Cutting them is
right on average; on any given short window you may cut a monster and look
catastrophic.

- **26y × 3000: +126.7pp** for the clock — inside that base's 132.5pp noise, but
  the correct sign.
- **5y sp500 golden: −40.91pp**, complete separation — but the removed cohort
  contained **SMCI +258,902 (+240%)**, alone exceeding the cohort's net.

I explained the −40.91pp three ways overnight (regime, window-length,
tail-lottery) and never consulted the table above, which was committed 08-16 and
settles it. The tail-lottery framing was closest but drew the wrong conclusion:
**a coin flip on a net-losing class should still be cut.**

## But age is the wrong discriminator

A base can legitimately take months — a stock in Stage 1 for eight months that
breaks through the *same* resistance is textbook, and its old `E` is correct.
The illegitimate case is a stock that broke out, failed, drifted, and later
re-approached a level describing nothing current.

**Age cannot separate those; whether the base held can.** All three existing
policies discriminate on the wrong variable:

| policy | cuts on | failure |
|---|---|---|
| none | — | keeps the −349,132 |
| clock | age | cuts held-base and broken-base alike |
| re-screen | stage flicker | −137pp: kills pullback-then-resume, which *is* base-building |

The missing one — **cancel when the base that defined `E` is broken** — is
[[project-base-broken-cancel]] / issue #2407.

## Consequences

- The clock at 26 is probably **right on the merits**; #2397's revert was
  procedurally correct (don't ship a measured golden regression silently) but
  the mechanism has the larger sample behind it. Issue #2405 reframed.
- **26 was never derived.** The sign flips between the 14–26wk band (+82,266)
  and 27–52wk (−148,226), so the boundary is inside that span — surface
  {13, 26, 52} rather than assume.
- **The record baseline may be overstated** by whatever fraction of its return
  comes from fills whose base no longer held. Unmeasured; the companion
  measurement in #2407.

Related: [[project-ttl-is-a-tail-lever]],
[[project-condition-vs-time-cancellation]], [[project-edge-is-the-fat-tail]],
[[project-clock26-is-a-tail-lottery]] (superseded in its conclusion by this).
