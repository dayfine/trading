# Ledger audit — which verdicts rest on an sp500 universe

**Date:** 2026-08-20
**Trigger:** `.claude/rules/universe-discipline.md` (PR #2444) — *never measure
performance on the sp500 universe; use it only for sanity check / rule
validation.*
**Scope:** all 59 entries in `dev/experiments/_ledger/`.

The rule is new; most of these entries are not. This audit does **not** claim
the entries were wrong when written. It identifies **which conclusions rest on
a basis the project no longer accepts**, so the worklist is explicit rather
than rediscovered one experiment at a time.

## Method

For every `*.sexp` in the ledger, extract the `base_scenario` field and read
the universe it names. Classify by the universe actually used, not by the
path it lives under.

**Verdict distribution across the 59 entries:** 36 Reject, 13 Inconclusive,
10 Accept.

### ⚠ The path name is not the universe

`goldens-sp500-historical/` contains **top-3000** scenarios. Two entries look
like violations by path and are not:

| entry | base_scenario | actual universe |
|---|---|---|
| `2026-06-25-capacity-concentration-BROAD` | `goldens-sp500-historical/top3000-2000-2026-catstop.sexp` | **top-3000** ✓ |
| `2026-07-10-liquidity-overlay-wfcv` | `goldens-sp500-historical/top3000-2000-2026-catstop.sexp` | **top-3000** ✓ |

A grep for `sp500` over the ledger returns both as hits. Any future automated
check must read the scenario's universe, not match the directory name.

## Finding 1 — 16 entries have a sole sp500 base

4 Accept, 10 Reject, 2 Inconclusive.

### The 4 Accepts (highest priority — these changed behaviour)

| entry | base | note |
|---|---|---|
| **`2026-06-23-ad-default-flip-confirmation-grid`** | **all 3 grid cells sp500** (2000 / 2010 / 2015 vintages) | **PROMOTE — flipped a default.** See Finding 2. |
| `2026-06-22-arming-speed-wfcv` | sp500-2000-2026-catstop | |
| `2026-06-22-neutral-blocks-shorts-wfcv` | sp500-2000-2026-longshort | |
| `2026-07-09-portfolio-floor-default-off` | sp500-2010-2026 | post-dates the 07-04 directive (Finding 3) |

### The 10 Rejects

`2026-05-14-continuation-combined-axis`, `2026-05-14-m5-5-single-lever-exhausted`,
`2026-05-29-laggard-disable-retracted`, `2026-05-29-stage3-hysteresis-wf-cv`,
`2026-06-22-fast-v-min-rate-surface`, `2026-06-22-neutral-blocks-shorts-grid`,
`2026-06-22-slow-grind-adlive-wfcv`, `2026-06-24-arming-speed-adlive-wfcv`,
`2026-07-09-catstop-deep-wfcv`, `2026-08-04-sim-entry-stoplimit-surface`.

**A Reject on sp500 is a different failure than an Accept on sp500.** An
Accept shipped something on evidence that may not transfer. A Reject means a
mechanism was **dismissed without a fair test** — a false negative is entirely
possible, and given how few levers this program has found, ten untested
mechanisms is arguably the larger cost. Neither is a claim that any specific
verdict flips; both are a claim that the evidence does not support the verdict
at the standard now in force.

### 2 Inconclusive

`2026-06-25-capacity-concentration-surface`,
`2026-06-25-laggard-cadence-surface`. Low priority — an Inconclusive on a
non-conforming basis is still Inconclusive.

## Finding 2 — the A-D default flip has zero conforming grid cells

`2026-06-23-ad-default-flip-confirmation-grid` is an **Accept marked
PROMOTE** that flipped a default, justified by a 3-cell confirmation grid.
Its `base_scenario`, verbatim:

> `GRID: sp500-2000 1999-2026 (deep dot-com+GFC+COVID) + sp500-2010 2010-2026 (post-GFC bull+COVID) + sp500-2015 2015-2026 (recent, diff universe)`

All three cells are the same large-cap index at three composition vintages.
Under `universe-discipline.md` **U3** ("a confirmation-grid cell on an index
universe is a FAIL regardless of its result") the grid has **no valid cells**,
and its universe-diversity axis — three sp500 vintages — is precisely the
substitution the rule now forbids.

Two further observations, both from the entry's own notes:

- Its stated cell-3 justification is *"recent, diff universe"* — the
  diversity claim is doing work, and it is sp500-2015 vs sp500-2010.
- It records a **contradicting** long-only spot-check (MaxDD 21.6 → 31.3,
  Calmar 0.46 → 0.26, i.e. risk-**worse**) and dismisses it as *"not a grid
  cell"*. That reasoning is correct under the old rule and is now the only
  broad-adjacent evidence in the entry pointing the other way.

The mechanism may well be fine. The point is that **nothing in the record
currently establishes it on a broad universe**, and it is live by default.

## Finding 3 — the directive is ~6.5 weeks old, not new

`2026-07-05-continuation-add-v2-surface.sexp` states, in its own
`base_scenario`:

> `BROAD-ONLY surface (top-3000 PIT-2000, the decisive cell; no sp500 per user directive 2026-07-04)`

So the instruction was given **2026-07-04**, honoured immediately in the
07-05 entry, and then lapsed. Three sp500-based verdicts were recorded after
it — `2026-07-09-catstop-deep-wfcv` (Reject),
`2026-07-09-portfolio-floor-default-off` (Accept),
`2026-08-04-sim-entry-stoplimit-surface` (Reject) — plus PR #2436 on
2026-08-20, which is what prompted the user to repeat the instruction and
prompted #2444.

**This reframes #2444.** It is not codification of a new preference; it is
re-codification of one that was stated, followed once, and decayed within a
week. The relevant lesson is the same shape as
`feedback_check_memory_before_claiming_about_code`: the knowledge existed and
did not bind. A rule file is only better than a directive if something
mechanical reads it — hence U1–U4 as greppable QC checks rather than prose.

## Mixed grids — contain an sp500 cell alongside broad cells

Not sole-sp500, so not in the 16, but one cell is non-conforming:

| entry | verdict | cells |
|---|---|---|
| `2026-06-09-stage3-force-exit-off-confirmation-grid` | Reject | A=top-3000-2011, **B=sp500-2000**, C=top-1000-2011 |
| `2026-06-28-declining-ma-gate-grid` | Reject | A=top-3000, **B=sp500-515**, C=top-1000 |
| `2026-07-03-scale-in-v1-surface` | Reject | **A=sp500-515**, B=top-3000 |

Each retains ≥1 broad cell, so each has *some* conforming evidence — but a
3-cell grid with one cell removed no longer meets the minimum grid size in
`promotion-confirmation.md`. Note also that in the first entry, cells A and C
share the identical window (2011-2026), so removing B leaves a grid with **no
period diversity at all**.

## What this audit does not establish

- That any verdict **flips**. Nothing here re-runs anything.
- Anything about the WF-CV entries' statistical power, which is a separate
  and still-unmeasured question (see the return-SNR finding in
  `project_rangetop_freshness_is_a_drawdown_lever`).
- That sp500 appearing anywhere in an entry is a defect. Determinism
  tripwires, liveness checks and goldens on sp500 are explicitly fine.

## Suggested worklist, by cost/value

1. **`ad-default-flip`** — a live default with no conforming cell. One broad
   cell would settle it. Highest value.
2. **The other 3 Accepts** — same shape, lower blast radius.
3. **The 10 Rejects** — cheapest source of untested mechanisms in the
   program. Not urgent individually; worth a pass when looking for levers.
4. **Mixed grids** — re-state their verdicts on the surviving broad cells and
   record the reduced grid size, rather than re-running.
