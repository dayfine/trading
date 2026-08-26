# Representative-trade audit — three populations vs the book archetype (#2489)

**2026-08-26.** Read-mostly. No backtest was run; every number below is
recomputed from committed artifacts by the four scripts in this directory.

Supersedes the first-pass tables in issue #2489's 08-24 comments **on the
executed-trade half**. Those were computed on `instr-null`, which #2503 and
#2530 retired as the record basis on 2026-08-24 — the stops-basis flip
(`initial_stop_buffer` 1.02→1.0, `reset_anchor_on_stalled_cycle` off→on)
moved exactly the distributions the verdict rested on. The entry-side half
(fill-week volume, base length) is re-verified here and survives unchanged.

---

## 1. Estimand, and what this is not

**Estimand:** the joint distribution, over decision-time and outcome features,
of the trades the strategy actually takes — compared against Weinstein's
archetype (Stage-2 entry on a volume-confirmed breakout above a
months-long base, held through a ratcheting trailing stop until the Stage 3/4
rollover; `docs/design/weinstein-book-reference.md`).

This is a **description**, not a P&L claim. Nothing here says a more
book-representative population would earn more. Per
`mechanism-validation-rigor`, the §2.2 read in §7 is stated as a **decision
input**, not a data verdict.

## 2. The three populations — and what each is conditioned on

| # | population | n | source | conditioned on |
|---|---|---:|---|---|
| **P1** | executed round-trips, **pinned basis** | **780** | `record-baseline-2026-08-24/results/record-baseline-trades.csv` | surviving screening **and** funding **and** fill **and** closing before 2026-06-26 |
| P1′ | executed round-trips, **retired** pre-flip basis | 1,182 | `instrumented-record-2026-08-23/results/instr-null-trades.csv` | same, one config basis earlier — carried only as the flip contrast |
| **P2** | §4.2 fill-week ejections / kept | **2,190 / 834** | `instrumented-record-2026-08-23/results/feat-p2{eject,kept}.csv` | the **arc faithful bundle's** config, not the record convention |
| **P3** | funding-death tickets | **397** | `.../feat-p3.csv` | ticket **placement** — names rejected for cash *before* placement never appear |

⚠ **Three non-poolability warnings, all load-bearing:**

1. **P2 is a different config basis** (the arc faithful bundle). P2-ejected vs
   P2-kept is a valid *within-P2* contrast; P2 vs P1 is not a controlled
   comparison.
2. **P3 is conditioned on placement.** It is the cohort whose ticket was placed
   and then failed to fund — not "every trade we couldn't afford."
   Pre-placement cash rejects are recorded only as a `skip_reason`
   (`project_ticket_dies_on_cash_shortfall`).
3. **P2/P3 are keyed to the retired basis's entry set.** Their entry-side
   features remain valid (see §3) but their counts do not scale to the 780.

`position_id` is the only join key used anywhere here; symbols repeat across
26 years (`feedback_position_id_is_the_only_join_key`).

## 3. Entry side — book-conformant at PLACEMENT, not at FILL

`vol_ratio_at_date` and `base_weeks_at_date` come from `monster_scan -pairs` on
the book's own basis (4wk × 2.0). They are **pure functions of the weekly
bars**, so they are comparable across arms even though the entry *sets* differ.

| dim (p10/p25/**med**/p75/p90) | P1 pinned subset (502) | P1′ retired (1182) | P2 ejected (2190) | P2 kept (834) | P3 funding-death (397) |
|---|---|---|---|---|---|
| **fill-week vol ratio** | 0.70/0.90/**1.24**/1.78/2.72 | 0.67/0.89/**1.20**/1.69/2.42 | 0.60/0.77/**0.99**/1.26/1.55 | 0.70/0.96/**1.46**/2.34/3.09 | 0.56/0.70/**0.89**/1.24/2.07 |
| **clears the book's 2× at fill** | **20.1%** | 17.0% | **0.0%** | 36.1% | 11.3% |
| **base_weeks** | 0/0/**27**/51/75 | 0/0/**28**/48/70 | 0/13/**35**/55/77 | 0/0/**24**/42/64 | 0/12/**30**/45/70 |
| stage at fill | — | 96.1% St2 | 97.1% St2 | **89.8% St2**, 8.5% St1 | 100% St2 |

Meanwhile the **placement-week** volume ratio (recorded in `trades.csv` as
`entry_volume_ratio`) is med **2.27×** on the pinned basis — essentially
identical to the retired basis's 2.26×, and comfortably over the book's 2× bar.
Entry stage at placement is **99.9% Stage 2** on both bases.

**So the breakout the strategy acts on is book-conformant; the fill is not.**
The resting StopLimit ticket decouples confirmation from execution — the
breakout week confirms, the ticket rests, and the fill lands on a quieter week.
Only ~1 executed fill in 5 clears 2× at the moment it actually transacts.

⚠ **The P2 ejected/kept contrast carries almost no independent information.**
Ejected clears the book's 2× bar **0.0%** of the time — the §4.2 gate's own
criterion and the comparison dimension are near-identical, so "ejected 0.99 vs
kept 1.46" is close to a tautology. The 08-24 comment read this as "the gate
discriminates on exactly the dimension it claims," which is true and is
precisely why it cannot also be evidence *about* the ejected population.

The **independent** dimensions say the opposite of "we eject the unrepresentative
ones": ejected entries have **longer** bases (med 35wk vs 24wk kept) and are
**more** often still in Stage 2 at fill (97.1% vs 89.8%).

## 4. Holding and exit — the flip moved this a lot, and the verdict survives

| dim | **P1 pinned (780)** | P1′ retired (1182) | book archetype |
|---|---|---|---|
| days held (p10/p25/**med**/p75/p90) | 1/5/**25**/93/157 | 1/1/**7**/40/110 | months to years |
| dead ≤ 7 days | **28.7%** | 51.3% | — |
| held ≥ 13 weeks | **25.8%** | 14.5% | the normal case |
| held ≥ 52 weeks | 1.0% | 0.5% | common |
| exit = `stop_loss` | **64.5%** | 78.6% | — |
| exit = `laggard_rotation` | 34.5% | 20.3% | not a book exit |
| exit = `stage3_force_exit` | **3 trades (0.4%)** | 3 (0.3%) | **the primary exit** |
| ≥1 stop raise | **5.4%** | 3.3% | continuous ratcheting |
| pnl% (p10/**med**/p90) | −7.5/**−2.1**/+16.1 | −5.7/**−1.4**/+8.3 | — |

The stops-basis flip is a large, correctly-signed improvement — median holding
3.6×, ≥13wk survival +11.3pp, early deaths −22.6pp. **The verdict does not
change:** the median position still lives 25 days, and Weinstein's own exit
fires **3 times in 26 years**.

## 5. Attribution — it is stop PROVENANCE, and it is a lower bound

Splitting P1 by whether the initial stop came from a real support level or from
the fallback formula (`entry × buffer × (1 − max_stop_pct)`):

| basis | bucket | n | ≤7d | ≥13wk | stop_loss | ≥1 raise | mean pnl% |
|---|---|---:|---:|---:|---:|---:|---:|
| **pinned** (width proxy) | structural | 322 | 18.9% | 31.1% | 54.3% | 7.8% | +3.17 |
| **pinned** (width proxy) | fallback | 458 | 35.6% | 22.1% | 71.6% | 3.7% | +1.54 |
| retired (width proxy) | structural | 392 | 35.2% | 22.7% | 64.5% | 8.2% | +2.62 |
| retired (width proxy) | fallback | 790 | 59.2% | 10.4% | 85.6% | 0.9% | +0.37 |
| **retired (GROUND TRUTH)** | structural | **164** | **8.5%** | **33.5%** | 41.5% | **17.1%** | **+3.50** |
| **retired (GROUND TRUTH)** | fallback | **1018** | **58.2%** | **11.4%** | 84.6% | **1.1%** | +0.73 |

**The width proxy understates the gap, and by a lot.** Validated against the
committed `stop_floor_kind` on the retired basis (`proxy-validation.txt`,
n=1182, join on `position_id`): the *fallback* bucket is 99.5% precise, but the
*structural* bucket is only 41% precise — 232 of its 392 members are really
`Buffer_fallback`. True structural share is **13.9%**, not 33%. So **the pinned
row's structural-vs-fallback gap is a floor, not an estimate.**

The ground-truth split reproduces `project_ratchet_freeze_real_data` from a
different artifact: fallback stops ratchet on **1.1%** of round-trips vs 17.1%
for structural.

## 6. The why

The realized population is **not** the book's population, and the divergence is
**not selection** — it is produced downstream of the pick, by two mechanisms:

1. **Execution decay (entry side).** Placement is book-conformant (2.27× volume,
   99.9% Stage 2). The resting ticket then fills on a quieter week — median
   fill-week ratio 1.24×, only 20% over the book's bar. The *decision* is
   faithful; the *transaction* is not.
2. **Stop provenance (holding side).** ~59-86% of trades get a fallback stop,
   which is a flat percentage divorced from chart structure — exactly what book
   spine item 5 forbids. Those positions die early (58.2% within a week on
   ground truth), almost never ratchet (1.1%), and so never reach the Stage-3
   rollover that is the book's actual exit. Structural-stopped trades behave far
   more like the archetype on every dimension.

This re-derives the closed selection null (`project_entry_selection_closed_powered`,
`project_cascade_selection_inversion`: picks were never the problem) from a new
angle, and agrees with `project_monster_funnel_top_of_funnel` — the leak is
above the funding and stop layers, but the *shape* of what survives is set below
them.

**Forward guidance.** Levers that touch stop **provenance** and **width** move
this population toward the archetype and have now done so twice, measurably
(the #2530 flip is the second). Levers that re-screen or re-rank picks do not —
that surface is closed. The largest untouched divergence is the **ratchet**:
94.6% of round-trips never raise a stop once, against a book archetype defined
by continuous trailing. That is the next place to look, and it is a
*provenance* problem (fallback stops can't ratchet), not a new mechanism.

## 7. Read for decision-menu §2.2 (a decision input, not a verdict)

§2.2 was deferred on 2026-08-24 pending the stops flips (#2486 §2.1), the
re-basis (#2503) and the picks change (#2404). Two of the three have landed, so:

- The §4.2 fill-week gate **is not ejecting unrepresentative entries.** On every
  dimension independent of the gate's own criterion, ejected entries are equal
  or *more* book-conformant (longer bases, more Stage-2-at-fill).
- What the gate actually removes is the **normal consequence of resting
  tickets** — a fill on a quiet week. It is a symptom filter.
- Therefore §2.2 is not the "faithfulness vs performance" trade it was framed
  as. The faithfulness gap it points at is **real but mislocated**: it lives in
  the *execution* path (rest-then-fill decouples confirmation from transaction),
  not in entry quality.
- **Implied re-frame:** the book-faithful repair is to make the fill re-confirm
  (or to not rest), rather than to eject at fill. Ejecting at fill costs 72% of
  entries to fix a defect one layer up.

This is a framing input for the §2.2 decision. It is **not** an ACCEPT/REJECT on
the arc bundle, which would need the surface → WF-CV → grid pipeline.

## 8. Gaps — what could not be measured, and the cost to fix

| dimension | status | why |
|---|---|---|
| **RS at entry** | **GAP on the pinned basis** | lives in `trade_audit.sexp`, never committed (~13MB/arm) |
| **MFE / MAE shape** | **GAP on the pinned basis** | same |
| stop provenance on the pinned basis | **proxy only** (§5) | same — `floorkind.tsv` exists for the retired basis only |
| entry features on 278 of 780 pinned entries | 64.4% coverage | `feat-p1.csv` was keyed to the retired basis's entry set |

**Root cause worth recording:** `instrumented-record-2026-08-23/README.md` said
the pinned worktree `.claude/worktrees/sweep-instr-0823/` "**must be preserved
until #2489/#2490 analyses complete**". It has been reaped. The prose note was
human-vocabulary; nothing the sweeper reads expressed the hold — the same shape
as `feedback_draft_is_not_a_hold`. Large audit artifacts that a queued analysis
depends on need either a committed derived extract (as `floorkind.tsv` was — and
it is the only reason §5 has ground truth at all) or a machine-readable lock.

**Cost to close:** one 26y record-convention re-run at the pinned basis with
`--emit-candidates`, ~2-2.5h container-exclusive (`container-capacity-scheduling`),
committing derived per-`position_id` extracts for RS-at-entry, MFE/MAE and
`stop_floor_kind` — **not** the raw sexp. Not launched here per the read-mostly
scope. It is only worth paying if a decision actually turns on RS or MFE/MAE;
nothing in §6-7 does.

## 9. Reproduce

```sh
sh dev/experiments/rep-trade-audit-2026-08-26/run_tables.sh     "$PWD"
sh dev/experiments/rep-trade-audit-2026-08-26/run_dissection.sh "$PWD"
sh dev/experiments/rep-trade-audit-2026-08-26/validate_proxy.sh "$PWD"
sh dev/experiments/rep-trade-audit-2026-08-26/run_truth_split.sh "$PWD"
```

POSIX sh + awk only (`.claude/rules/no-python.md`). Outputs land in `results/`
and are committed, so every table above is checkable without re-running.
