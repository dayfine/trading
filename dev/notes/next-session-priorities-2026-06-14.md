# Next-session priorities — 2026-06-14 (morning handoff)

**Supersedes** `next-session-priorities-2026-06-13-PM.md`. Written end of the
2026-06-13 PM session for a morning flip decision. Check main CI green first.

---

## ✅ DONE overnight (your "flip + regen" instruction)

- **Flip MERGED (#1582)** — `exempt_closing_trades_from_cash_floor` is now
  **default-ON** on main. Bit-equal (zero golden re-pins; the exemption only fires
  on a blocked cover, which no golden exercises), both QC gates APPROVED the R3-NA
  correctness framing, CI green. A `test_cash_floor_exemption_on_by_default` pin
  guards the default.
- **Regen RAN but needs your decision — NOT auto-committed (see §2).** The builder
  works (84/84 goldens regenerated with `avg_dollar_volume`), but a full rebuild
  also drifts composition ~2.9% (87/3000, mostly delisted `_old`↔`_old2` tie-break
  swaps + a few preferred↔warrant). That re-pins backtests — NOT the
  behavior-neutral add the queue doc assumed — so I preserved the output
  (`/tmp/regen-goldens-with-volume/`) and left main untouched.

---

## 🎯 RESOLVED PLAN (grill session 2026-06-14) — execute in this order

All open decisions resolved with the user. **Strategic frame:** finish the
long-only cluster first, *then* the profit-seeking long-short build.

### Long-only cluster — two semi-independent threads

**Thread 1 — data (unblock the universe):**
1. **Volume-only enrichment tool** — recompute `avg_dollar_volume` for each
   committed golden's *exact* symbol set, inject the field. No composition drift,
   no backtest re-pin. (NOT a full rebuild — see §2 for why; builder is
   deterministic, drift = untracked-inventory provenance gap.)
2. **Commit `inventory.sexp` to git** — closes the reproducibility hole (it's
   currently untracked, so committed goldens aren't regenerable from VC).
3. **Emit policy artifact** —
   `apply_composition_policy --exclude-reits --exclude-preferred --adr-min-dollar-volume 100000`
   (token floor: drops only zombie/untradeable tickers; liquidity is a non-issue
   at our scale per `project_trade_realism_liquidity`, so the floor is hygiene,
   not a real screen).
4. Matrix re-runs on the policy universe (lower value given the no-bull-edge
   finding, but completes the cluster).

**Thread 2 — understanding (higher-insight; runs NOW, no wait on Thread 1):**
5. **Factor-decomposition lens** on the existing honest matrix (top-3000-2011
   suppress-ON), **staged**: (a) cheap factors first — forward-index-drawdown
   ("did it dodge a correction?"), melt-up, realized-vs-MTM gap — to triage how
   much they explain; (b) **then** the screener-based factors that answer the
   user's actual questions — macro stage at start, sector-RS dispersion, Stage-2
   candidate count. Keyed on **realized** edge, not MTM. Design:
   `dev/notes/factor-decomposition-lens-design-2026-06-14.md`. Commit to both
   stages; cheap-first only orders by cost.

### After the cluster
6. **Initiative B (margin → long-short)** — local, P0-after-cluster, with
   oversight (core `Portfolio`, qc-structural A1 flag, 5 phases, re-pins shorts).
   The actual profit thesis (the matrix finding says profit is short/bear-side).
   Plan: `dev/plans/short-side-margin-2026-05-13.md`, start Phase 1.
7. **Initiative A (weekly trade-generation record)** — **dispatch to the GHA
   orchestrator** (now 8×/day) to build the `generate_weekly_snapshot` bin in
   parallel (self-contained, no core-module risk; M6.1–M6.5 libs already exist).

### Two immediate next actions (no further input needed)
- Factor-lens **cheap pass** (step 5a) — runs now on existing data.
- **Enrichment tool** (steps 1-2).

---

## (record) Original flip decision — cash-floor closing-trade exemption (NS1 #1567)

**What:** `exempt_closing_trades_from_cash_floor` (core `Portfolio`, default-off,
**merged #1567**, QC double-APPROVED, A1-generalizable). When on, the absolute
cash-floor solvency check no longer rejects the *reducing portion* of a closing
trade.

**Why it matters:** this flag is the fix for the **#1553 −240% zombie** — the
live cash floor (`portfolio.ml:338`) rejected a short **cover** (a trade that can
only *reduce* risk), stranding the position. Blocking a risk-reducing close is
arguably never correct.

**The decision is the same shape as the warmup flip (#1566):** is this a
**correctness invariant** or a **performance knob**?

- **(A) Correctness framing → flip ON now.** A closing/reducing trade improves
  solvency by construction, so a solvency floor should never block it. Under this
  framing it's an invariant, **R3-NA** (not an alpha promotion) — exactly how
  #1566 was reasoned. No NS4 experiment required.
- **(B) Performance framing → wait for NS4.** If treated as a strategy knob, the
  experiment-flag discipline (R3) wants an ACCEPT from the NS4 WF-CV experiment
  first — but NS4 is **data-gated** (needs the composition-policy universe, see
  the queued pipeline) and hasn't run.

**My recommendation: (A) flip ON as a correctness fix.** The zombie is concrete
evidence the current behaviour is wrong, not merely sub-optimal.

**⚠ Unlike NS1's merge (bit-equal, default-off), flipping ON is behaviour-affecting
→ a golden re-pin.** It only changes goldens where a cover was previously rejected
(likely few — it's an edge case), but the flip task must: (1) flip the default,
(2) run the goldens, (3) re-pin whichever move, (4) eyeball the diff is only
blocked-cover scenarios. That's a code PR (full 3-gate, not admin-merge).

**If you say "flip it," I'll do A end-to-end in the morning.** (NS3 CancelExit
already merged #1575, so it's now pure defense-in-depth; NS2/#1563 short-proceeds
is a separate margin item — see initiative B below.)

---

## 1. Matrix re-run result (warmup-flip re-measurement, P1 carried)

**✅ DONE (completed ~23:24 PDT 2026-06-13). Result is significant — the warmup
running-start was ~ALL of the apparent start-date edge.** Full writeup:
`dev/experiments/warmup-matrix-rerun-2026-06-13/ANALYSIS.md`.

| metric | STALE (OFF, what we'd been citing) | HONEST (ON, new default) |
|---|---|---|
| Median edge vs GSPC | +3.2 pp/yr | **−2.76 pp/yr** |
| Beat-rate | ~57% | **35.5%** (11/31) |
| Worst start | −28 pp | **−49.5 pp** |

Removing warmup-window trading swung the median ~6pp negative. Dividend-adjusted
(GSPC is price-only) honest edge vs total-return SPX ≈ **−4.8 pp/yr → no
bull-regime start-date return edge** (confirms `project_index_beating_structural_bar`
cleanly). The +107% max start (2025-01) is MTM-inflated (realized −21%); all
post-2020 starts have deeply negative *realized* despite positive MTM.

**Strategic takeaway (feeds initiative B):** long-only profit is NOT recoverable by
tuning bull-window long entries — the prior +3.2pp was contamination. The
strategy's case is bear-regime tail defense, not bull return-beating. The
"missing profit" you're after is on the **short/bear side** → the margin &
long-short build (§4) is the right place to look, *once shorts are measured
honestly* (Phase-1 margin accounting).

**Deep-understanding follow-up (your 2026-06-14 ask):** "beats 35% of the time" is
decomposed — first-pass WHEN/WHY in chat + a build design at
`dev/notes/factor-decomposition-lens-design-2026-06-14.md`. Key correction: the
honest beat-rate is **~23%** (7/31), not 35% — 4 of the 11 "beats" are MTM
artifacts (positive MTM-edge, deeply negative *realized*). The lens (join each
start to macro stage / forward index DD / Stage-2-supply, keyed on a **realized**
edge) is the prime analytical next task — built on OCaml extension of
`rolling_start_runner`. NOTE: eyeballing the raw table is unreliable (MTM
contamination muddies it); the lens must be built, not eyeballed.

---

## 2. ✅ RESOLVED — regen composition drift (decision → enrichment + track inventory; see roadmap)

**Resolution (grill 2026-06-14):** volume-only **enrichment** (freeze committed
composition, no re-pin) + **commit `inventory.sexp`** to git. NOT the full rebuild.
Verified root cause below for the record (the builder is deterministic; drift is an
untracked-inventory provenance gap, NOT a tie-break). Original decision write-up:

The goldens-regen ran successfully (all 84 now carry `avg_dollar_volume`), but
**a full `build_composition_universes_runner` rebuild is NOT behavior-neutral** —
it re-ranks the universe from the current bar store and drifts ~2.9% of symbols
vs main (87/3000). Breakdown for top-3000-2011: **2913/3000 identical**; the 87
turnover is **68 delisted `_old`↔`_old2` tie-break swaps**, ~10 warrant
(regen: AIG-WS) ↔ ~9 preferred (main: BAC-PL, GS-PD) swaps. Economically marginal
(tail names at 0.0003 weight) but **not bit-equal → re-pins any backtest reading
these goldens.** The queue doc assumed a clean volume-only add; it isn't.

**Output preserved:** `/tmp/regen-goldens-with-volume/` (container, 84 files with
volumes). main untouched.

**Your call — three options:**
- **(a) Accept the rebuild** — `cp /tmp/regen-goldens-with-volume/* → goldens dir`,
  commit, let golden-runs CI re-pin. Simplest; accepts the marginal tail drift as
  a (arguably more survivorship-complete) universe refresh.
- **(b) Volume-only enrichment** (behavior-neutral, the original intent) — a small
  tool that recomputes `avg_dollar_volume` for main's **exact** symbol set and
  injects the field, keeping composition bit-identical. Needs ~1 new bin; no
  backtest re-pin. **My recommendation** if you want backtest continuity.
- **(c) Defer** — the downstream policy artifact (Step 2) is **anyway blocked** on
  the **ADR $-volume threshold value** (from the weekly >1%-ADV gate spec) which
  only you can supply, so nothing downstream is unblocked tonight regardless.

Whichever: Step 2 (`apply_composition_policy`) still needs that **threshold value**
before the policy universe can be emitted — please supply it (or confirm the
>1%-ADV gate spec to read it from).

---

## 3. 🆕 Initiative A — weekly trade generation record (your ask, revived)

**Goal:** a durable weekly record of the trades/picks the strategy *would*
generate live, so future live runs can be reconciled against backtests.

**Good news — most of it is already built (M6.1–M6.5, `weekly-snapshot` track):**
- `Weekly_snapshot.t` type + `Snapshot_writer`/`Snapshot_reader` (round-trip stable)
- `Forward_trace` (trace picks forward N days), `Pick_diff` (cross-version diff),
  `Report_renderer` (snapshot → markdown)
- bins: `trace_picks`, `diff_picks`, `render_weekly_report`
- Designed format: `dev/weekly-picks/<system-version>/<date>.sexp` (macro context,
  sector strength, ranked candidates w/ score/grade/entry/stop/rationale, held positions)

**The gap (this is M6.6, deferred):** there is **no generator** that runs the
screener+strategy on current/latest-cached data, builds a `Weekly_snapshot.t`, and
writes it to `dev/weekly-picks/`. The dir doesn't exist yet. The consumers
(trace/diff/render) all read an existing pick file; nothing produces one from data.

**Concrete next step (small, self-contained):** a `generate_weekly_snapshot` bin
that takes `--as-of <date> --universe <path> --bars/--snapshot-dir`, runs the
existing screener + `entries_from_candidates` + stop placement, assembles
`Weekly_snapshot.t`, and `Snapshot_writer.write`s it to
`dev/weekly-picks/<version>/<date>.sexp`. Then a first record can be generated and
committed as the baseline to diff future weeks against. This is the
reconciliation seam the `trading-reconciler` (`project_trading_reconciler`) was
meant to consume. **Authority:** `docs/design/weinstein-trading-system-v2.md` §7
M6.1–M6.6; plan `dev/plans/m6-weekly-snapshot-verification-2026-05-02.md`.
**Owner:** feat-weinstein. Dispatchable once you green-light scope.

---

## 4. 🆕 Initiative B — margin & long/short (your ask: unlock the missing profit)

**Thesis (yours):** long-only leaves Weinstein's Stage-4 downside on the table;
a faithful long-short needs a real margin model, and doing it properly may unlock
profit. Agreed — and the spine permits it (short the Stage-4 decline is core
Weinstein, `weinstein-faithful-core.md`).

**State — well past zero, but the core accounting is unbuilt:**
- ✅ **Research done:** `dev/notes/long-short-margin-mechanics-2026-06-12.md` — the
  Reg-T/FINRA-4210 floor (short = 150% initial: proceeds locked + 50% extra;
  maintenance = max($5/sh, 30%) ≥$5, etc.), Schwab/IBKR specifics, borrow carry.
- ✅ **Plan done:** `dev/plans/short-side-margin-2026-05-13.md` — 5 phases with
  go/no-go gates: P1 margin accounting → P2 borrow fee → P3 Stage-A fixtures →
  P4 Stage-A short-only validation (PASS/FAIL gate) → P5 Stage-B long-short re-pin.
- ✅ **Short gates built:** `enable_short_side` (default true; Cell-E sets false),
  `short_min_price` axis (the sub-$17 economic-margin floor), `Short_side_gate`,
  `Short_min_price_gate` — all pinned (#1560/#1561).
- ✅ **#1563/NS2 design rec done:** `dev/notes/short-sale-proceeds-collateral-2026-06-13.md`
  — confirmed backtests run **margin-OFF**, short proceeds add to cash with **no
  collateral lock** → short sizing over-deploys. This is *the* correctness defect
  that makes today's short numbers untrustworthy.
- ⚠ **The gap:** `margin_config.{ml,mli}` exists but margin accounting is a **no-op
  by default** and **Phase 1 (lock short proceeds + Reg-T initial + maintenance +
  borrow fee) is unimplemented** — the plan is "design only, no code."

**Why this is the right order:** you can't trust *any* long-short backtest until
Phase 1 lands (§5.1 of the plan: "current accounting under-penalises shorts"). So
the profit question ("does shorting Stage-4 help?") is **unanswerable today** — it
would be measured on a free-money short model.

**Concrete next step:** dispatch Phase 1 (margin accounting) per the plan. It
**touches core `Portfolio`** → qc-structural **A1 will FLAG** (expected; the plan
has the generalizability argument ready). Default margin-off keeps every golden
bit-equal. Once Phase 1+2 land, run P3/P4 Stage-A short-only validation — the
go/no-go report answers your profit question with a *trustworthy* model. **Owner:**
feat-weinstein. This is multi-PR; sequence it deliberately, not in one shot.

---

## Done in the 2026-06-13 PM session (FYI, no action)

- **Orchestrator throughput #1573:** 4×→**8× daily** (every 3h) + cost cap
  $50→$200 (Max-20x is flat-rate; cap is now a runaway backstop, not a budget).
  Already producing — #1574 (sweep-perf Win #4) + #1575 (CancelExit NS3) landed on
  the new cadence. Real utilization bottleneck identified: ~5 tracks share one
  data-gated dependency (the §2 composition-policy artifact) — frequency alone
  won't fix 13%.
- **Budget orphans:** 4 orphan `ops/budget-*` branches (~$44.36) recovered to main
  (#1571) + deleted; recurrence root-cause filed **#1572** (no-op runs drop the
  budget bundle).
- **GHA cash-floor cluster self-driving:** NS1 #1567 + NS2 #1569 + NS3 #1575 merged
  untouched.

## Key references

`project_warmup_trading_running_start`, `project_rolling_start_matrix_first_run`
(both now flagged stale-semantics), `dev/plans/short-side-margin-2026-05-13.md`,
`dev/plans/m6-weekly-snapshot-verification-2026-05-02.md`,
`dev/notes/long-short-margin-mechanics-2026-06-12.md`,
`dev/status/cash-floor-correctness.md`.
