# Next-session priorities — 2026-07-02

**Supersedes** `next-session-priorities-2026-07-01.md`. Main is green
(tip `0f2858f4` #1824). This session resolved the "why are all the weekly picks
score-70" question end-to-end: root-caused a live-generator bug, fixed it, refreshed
the committed 2026-H1 series, and validated the corrected picks are coherent.

## What this session delivered (all merged)

**Decision-audit / faithfulness thread (the original P0):**
- **#1799** `decision_audit` lib+bin — per-screen faithfulness report (funded vs
  cash-rejected near-misses on captured features). **#1806** Phase-2 forward-return
  counterfactual. **#1811** weekly-snapshot adapter (lens runs on live picks too).
- Verdict (writeups `dev/notes/decision-audit-*`): **selection is FAITHFUL** — no
  captured feature separates funded from near-miss in an exploitable way; the only
  entry-side lever the data points to is explicit **capacity**, not a better sort.
  Memory: `project_decision_audit_faithful`.

**The prior_stage bug + live-picks refresh (this session's deep dive):**
- Root cause: the live weekly-snapshot generator passed `prior_stage:None`, resetting
  the stage classifier's `weeks_advancing` to ~1 for **every** Stage-2 stock →
  grades collapsed to a flat 70/A and the `≤4`-week admission gate never bit, so the
  live picks were ~55% extended advancers (up to ~45 weeks into Stage 2). Full
  writeup: `dev/notes/live-generator-prior-stage-bug-2026-07-01.md`. Memory:
  `project_live_generator_prior_stage_bug`.
- **#1816** finding doc + `stage_dump` diagnostic (prior-chained stage-timeline
  inspector, `analysis/scripts/stage_dump/`). **#1818** the fix (chain the classifier;
  qc-structural + qc-behavioral APPROVED 5/5; backtest-parity confirmed — no golden
  re-pin). **#1821** refreshed the committed 2026-H1 series
  (`dev/weekly-picks/5a2689cb4/`, 26 weeks) with the fix, superseding the buggy
  `89c2ee2a8` (removed). **#1824** coherence + follow-up analysis.

**The refreshed picks now carry signal:** grades track regime (dense A+ fresh
breakouts in the strong Jan–Feb tape → 0 A+ / weak B in the March pullback → recover
Apr–Jun); ranked by score not alphabetical; ~62% of picks confirm (stay Stage 2, 6wk
fwd), failures are clean regime-driven rollovers (not choppy), early-S2 confirms
(75%) > fresh breakouts (60%). Analysis: `dev/notes/weekly-picks-refresh-analysis-2026-07-01.md`.

## Update — 2026-07-02 (later session): P0 SHIPPED

**P0 is done — merged as #1826** (main `3e067fed`). Display-only tightening of the
human weekly-pick report (`Report_renderer`): display limits are now configurable
(`?long_limit`/`?short_limit`, default long **10→7**, short 5), section headers echo
the effective limit, the render CLI gained `-long-limit`/`-short-limit` flags, and a
**tie-honesty note** now appends below a truncated table ("N more not shown; M tie the
cutoff score S — treat the tied set as interchangeable"). The note encodes the
project's own insight (score is anti-predictive at the top grade; the alphabetical
tie-break is not a ranking) so a reader funding ~5 of a large tied A+ block knows the
cut is arbitrary. **No strategy/backtest/schema change** — the `.sexp` still holds the
screener's full capped list. The committed 26-week 2026-H1 series
(`dev/weekly-picks/5a2689cb4/`) was re-rendered from the existing `.sexp` (e.g.
2026-01-16 now shows top-7 + "13 more not shown; 4 tie the cutoff 85.00"). Both QC
gates APPROVED (behavioral score 5); CI green (one BO-tuner test flaked, passed on
rerun — unrelated to this PR).

**The frontier is now P1 (capacity/concentration) — the one remaining entry-side
lever.** Items P2–P6 below are unchanged.

## Open / pick up here

The frontier for the weekly-picks/live product, in priority order:

1. ~~**P0 — tighten the surfaced list to actionable size.**~~ **DONE — #1826** (see
   the update block above). The tie-honesty note also lays groundwork for P1: it makes
   the "which ~5 of the tied A+ block to fund" question explicit, which is exactly the
   capacity decision.

2. **P1 — the capacity/concentration experiment (the real entry-side lever).** With a
   surplus of quality breakouts but ~5 slots: fund **more-smaller vs fewer-larger**,
   and should the **fresh (60% confirm, higher-variance) vs early-S2 (75% confirm)**
   tiers be sized differently? The tension: tilting to "safer" early-S2 could **tax
   the fat-tail edge** (`project_edge_is_the_fat_tail` — the monsters likely come from
   the fresh breakouts). Testable, and we now have the confirmation-rate data to
   design it. Ties to `project_capacity_concentration_surface` (the standing
   "one live lever", inconclusive so far — this gives it a concrete hypothesis).

3. **P2 — the `≤4`-week gate tuning (deferred from #1818).** Now that the
   early-breakout admission gate actually bites, is `≤4` right vs the 8-week
   breakout-event window? Default-off axis + WF-CV per `experiment-gap-closing`.

4. **Continuous-RS scoring (the remaining reason A-tier ties at 70).** The score
   buckets RS into a flat 10-pt "positive" bin, discarding the `rs_vs_spy` magnitude
   (which ranges 0.8–6.5). Folding in RS magnitude would spread the A-tier — but
   RS-as-a-return-tiebreak was WF-CV-**rejected** (#1788), so this is a display/UX
   sharpening, not an evidenced return lever. Scope carefully.

5. **Faithful per-week universes (M6.6).** The #1821 refresh used ONE composition
   universe (2026-06-26) across all 26 weeks — a point-in-time approximation for the
   earlier weeks (per-week eligible universes only exist for the last 5). A fully
   faithful series needs the eligibility builder run per week. Deferred.

6. **Decision-audit follow-ups** (from `project_decision_audit_faithful`): the
   RS-coverage harness gap (~77% `rs_value=None` in sp500 audits); re-run the
   weekly-picks Phase-2 counterfactual once a 2026 forward window matures.

## Strategic context

Entry-*selection* is exhausted (decision-audit: faithful; score anti-predictive at
top; tiebreak dead). The live directions are (a) **display/product** (tighten the
list — P0) and (b) **explicit capacity** (P1 — the one entry-side lever, now with a
concrete fresh-vs-early sizing hypothesis). The `prior_stage` fix was the
highest-value thing this session: it turned an uninformative flat-70 live feed into
picks that behave like real Weinstein Stage-2 breakouts.

## Process note (bit me repeatedly this session)

`jj new main@origin` / branch switches **wipe uncommitted working-copy edits** that
aren't gitignored — I lost a warehouse, a universe file, and an analysis note (empty
PR #1823) this way. **Rule:** write files AFTER positioning `@` (never `jj new`
between the Write and the commit); route regenerable scratch to a gitignored path
(`trading/dev/experiments/weekly-cf/` is now ignored). See
`.claude/rules/worktree-isolation.md`.

## State at handoff

- Main green (tip `0f2858f4` #1824). Fix + refreshed series + all analyses merged.
- Scratch (gitignored, regenerable): `trading/dev/experiments/weekly-cf/` (368 pick
  symbols' bars + universe). Reproduce the refresh:
  `generate_weekly_snapshot --as-of <Fri> --universe dev/weekly-picks/universe-2026-06-26.sexp
  --bars-snapshot-dir dev/data/snapshots/weekly-review --snapshot-dir <out> --system-version <sha>`.
- New memories: `project_live_generator_prior_stage_bug`, `project_decision_audit_faithful`.
- Tool: `analysis/scripts/stage_dump/` (prior-chained stage-timeline inspector).
