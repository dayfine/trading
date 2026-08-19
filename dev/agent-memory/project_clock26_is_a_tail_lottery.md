---
name: project-clock26-is-a-tail-lottery
description: "The clock-26 golden A/B: -40.91pp on sp500/2019-2023, driven by one trade (SMCI +240%). Measurement and dissection stand; the do-not-promote VERDICT is SUPERSEDED — the long-rest class is net-losing (see project-stale-order-fills-are-not-an-edge)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7b9bffd9-4afb-483a-9e22-50b6142eb14c
  modified: 2026-08-19T09:18:28.526Z
---

> **⚠ VERDICT SUPERSEDED 2026-08-19.** Everything below about the measurement
> and the trade-level dissection stands. The **conclusion does not.** The
> committed 26-year rest-time table shows fills resting >26wk are **7.8% of
> fills and −15.1% of total P&L** (−3,923/trade vs +2,518) — the class is
> **net-losing**, so a coin flip on it should still be cut. The −40.91pp below
> is the variance of a tail-heavy losing class, measured on the one 5y window
> whose cut cohort happened to contain SMCI. See
> [[project-stale-order-fills-are-not-an-edge]].

**The 26-week entry-ticket clock cuts the resting-ticket population blind, and
that population is where the fat-tail winners live.**

Supersedes `project_clock26_regime_dependent` (deleted — its title was the first
of two wrong mechanisms; see the retraction list below).

## The measurement

Paired single-knob A/B on `goldens-sp500/sp500-2019-2023-armed-stoplimit`, the
only one of 27 goldens that arms `enable_sim_entry_stoplimit` (the clock is
inert under Market entries):

| arm | return | trades | maxDD |
|---|---:|---:|---:|
| clock=0 | **108.23%** | 238 | 16.0% |
| clock=26 | **69.81%** | 227 | 14.5% |

Control lands within **2.55pp** of the golden's own 110.78 band floor, so the
run reproduces the golden and the **−38.42pp** is the knob.

## The mechanism — from the trades, not from the window

⚠ **`position_id` does NOT join across arms** — only 99 of 238 overlap, because
the global ticket counter shifts as soon as the clock cancels anything. It stays
the correct *within*-run key. Join cross-arm on `symbol|entry_date`.

| cohort | n | net P&L |
|---|---:|---:|
| control-only (what the clock removed) | **59** | **+248,545** |
| armed-only (what the freed cash bought) | 48 | **−84,172** |
| shared | 179 | +5,846 (noise) |

Not "11 trades removed" — **59 out, 48 in**; cancelling frees cash that funds
different later tickets.

**The removed cohort is mostly junk**: median **−2,840**, 40 losers / 19 winners.
Its positive total is one tail — top 5 = +442,821 = **178%** of the cohort net,
and **SMCI alone (+258,902, +240.0%, 292 days) exceeds the whole cohort's net**.

Across arms: MU and AZO are simply **absent** when armed; AXON and MPWR keep
their small early losers and **lose the later winner**; SMCI re-enters *earlier*
(2022-08-18), is stopped out at **−17.4%**, and never catches the real breakout.

## Why this settles it

The clock's effect in **both** directions is dominated by whether it happens to
cancel a monster. That also explains the promotion cell (+126.7pp on top3000 ×
2000-2026) with no new hypothesis — and is why that figure sits **below its own
base's 132.5pp seed-noise floor**. A coin flip on the tail is not a promotable
mechanism whatever its sign on one window.

12th+ confirmation of [[project-edge-is-the-fat-tail]]; joins harvest-rotate,
trim, re-time and cap in the graveyard.

**If a bound is wanted for correctness** (defect E: `FUL-wein-64` rested 21.7
years; 865-week max fill age), that argues for something like **156 weeks** that
only touches the genuinely absurd tail — not 26, which cuts into the live
distribution where the monsters are.

## Two wrong mechanisms I published first

1. ~~"Regime-dependent — pays in crash-spanning windows"~~ — refuted by the
   window dates: 2019-01-02 → 2023-12-29 **contains COVID and the 2022 bear**.
2. ~~"Window length — the multi-year pathology can't exist in 5 years"~~ —
   explains an absence of *gain*, not a **−38pp loss**.

Both were derived from window characteristics **before opening `trades.csv`
once**. The dissection that found the real answer took four commands. See
[[feedback-always-dissect-before-reporting]] — the rule existed; I didn't follow
it.

## Process finding

`golden-runs-sp500-5y.yml` runs **on push to main, not on PRs**, and is
`continue-on-error: true`. CI green on #2384 said nothing about the one golden
the change moves. ⇒ **when a PR changes a config default, find the goldens that
arm that knob and run them by hand.** Issue #2393.

Artifacts: `dev/experiments/clock26-golden-ab-2026-08-19/` (PR #2392); hold on
PR #2384.
