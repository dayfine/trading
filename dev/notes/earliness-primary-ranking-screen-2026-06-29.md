# Earliness-primary candidate-ranking — read-only screen (2026-06-29)

> **RESOLVED 2026-06-30 — the user chose to build+grid it; the grid REJECTED it
> (harder than this screen's "no-build-now" lean).** `Quality_earliness` was built
> (default-off) and run on the 3-cell breadth WF-CV grid: it is **Pareto-dominated
> by baseline in all 3 cells** (worse Sharpe AND Calmar AND return everywhere), and
> *worse than even RS-primary `Quality`*. The directive's hypothesis — "earliness
> underperforms in `Quality` only because it's behind RS; lead with it" — is
> **refuted**: leading with earliness is worse. The freshest breakout is the
> least-confirmed → tilting toward it adds risk without return. See
> `dev/experiments/earliness-ranking-wfcv-2026-06-29/FINDINGS.md` + ledger
> `2026-06-30-earliness-ranking-tiebreak-grid`. Mechanism stays a default-off axis.
> Net: a third confirmation that no equal-score tiebreak on any entry feature adds
> return. Screen below retained for the record.

---


**Mode:** screen-before-build (`screen-rigor`, `mechanism-validation-rigor`). This
is an **evidence-synthesis screen producing a build/no-build *decision*** on the
06-29 handoff's #1 forward directive — **NOT** a fresh backtest, NOT a build, NOT a
WF-CV, NOT a goldens change. Honest about its proxy nature (§Estimand).

**The forward directive** (ledger `2026-06-29-candidate-ranking-tiebreak-grid`,
verbatim): *"if revisited, test an EARLINESS-PRIMARY ordering (prefer FRESH
breakouts over extended ones — the more faithful reading of 'don't buy extended');
the current Quality key relegates earliness to secondary behind RS, which is likely
why it underperforms."*

So the candidate mechanism is a 3rd `candidate_ranking` mode (alongside
`Alphabetical` default and the rejected RS-primary `Quality`): break equal-score
ties by **earliness first** — `weeks_advancing` ascending — then RS / volume /
ticker. The hypothesis: fresh-first does-no-harm or helps where RS-first (which
preferred *extended* names) failed the #1788 grid.

---

## What a fresh broad-3000 audit run would cost (why this is a synthesis, not a run)

The clean test of "does earliness-at-entry predict realized outcome" wants a broad
top-3000 long-only trade audit (`weeks_advancing` per entry joined to realized
P&L + MFE). That artifact is **not turnkey**: the snapshot-mode `scenario_runner`
(the only broad-N runner) does **not** emit `trade_audit.sexp`; the audit writer is
the CSV-mode simulator path (`simulation/lib/simulator.ml`, via `panel_runner`),
which OOMs at N=3000. Producing it needs either audit-emission wiring into the
snapshot runner or the new mode itself — i.e. the build this screen is meant to
gate. Per `screen-rigor`, a cheap synthesis of strong existing evidence is the
correct first pass before paying that cost.

## Evidence

**E1 — the #1788 grid (direct, this-week, the thing being extended).** RS-primary
`Quality` *failed* do-no-harm: lower Calmar in all 3 breadth cells
(0.850→0.676, 0.690→0.669, 0.861→0.761), lower Sharpe in 2/3, dominated in narrow
top-500. **Why:** RS-magnitude-primary preferentially picks the highest-RS = most
**extended / already-run-up** names among ties — the exact "don't buy extended
Stage-2" setups — mildly taxing the fat tail. Its *only* consistent benefit was
**lower dispersion** (Deflated Sharpe ~0.997 vs ~0.99) + lower MaxDD in 2/3.

**E2 — `project_cascade_selection_inversion` (validated, directional support).**
Stage1→2 breakout (more extended) **underperforms** early-Stage2 (fresher) on
**win-rate** across top-3000/1000/500 and both eras; the A+ grade is the *worst*
bucket. So fresher entries win *more often* → this **directionally supports
earliness-primary** (it tilts toward the higher-win-rate cross-section, the
opposite tilt to the rejected RS-primary). **Caveat:** that return edge is
**non-stationary** (gone 2019-26), and higher win-rate ≠ higher return.

**E3 — `project_edge_is_the_fat_tail` + `project_accuracy_is_unreachable`.**
Broad-universe return is a few right-tail monsters; winners ≈ losers at entry on
every measured feature (score, vol-ratio flat across buckets); you cannot pre-pick
winners. **Consequence: no equal-score tiebreak can add return** — its ceiling is
consistency / dispersion / Calmar-via-avoiding-extended, not CAGR.

**E4 — estimand bound (verified in code).** The tiebreak acts **only among
identical-score candidates** at the cap / cash boundary. `screener_scoring.ml`
already scores stage-progression: `w_stage2_breakout = 30` (Stage1→2 breakout) vs
`w_early_stage2 ≈ 15` (`Stage2 weeks_advancing ≤ 4`). So the gross fresh-vs-extended
distinction is **already in the primary score** — among *equal-score* ties the
residual `weeks_advancing` spread the tiebreak can still act on is small. The
mechanism's reach is bounded by construction.

## Estimand & rigor caveats (screen-rigor)

- **Proxy, not the estimand.** This synthesizes population-level entry-feature
  results (E2/E3) and the RS-primary grid (E1); it does **not** measure the
  realized P&L of the earliness-first *rule* among ties (E4 says that residual is
  small and unmeasured here). A fresh audit run would tighten it.
- **Direction vs magnitude.** E2 gives the *sign* (fresh > extended on win-rate);
  it does not give the *return* magnitude, and E3 caps that magnitude at ~0 for a
  tiebreak. No distribution of the rule's per-decision effect is computed here.
- **Non-stationarity (E2 caveat) is unhandled** — the win-rate tilt weakened
  2019-26.

## Calibrated verdict — **NO-BUILD-NOW (lean-on-prior decision)**, not a rejection

Per `screen-rigor` verdict calibration, a proxy screen may render a no-build
*decision* leaning on standing priors; it may **not** declare the mechanism
"doesn't work." So:

- **Earliness-primary is the *correctly-motivated* variant** — strictly better
  motivated than the rejected RS-primary, because it tilts toward **fresh** (E2:
  higher win-rate; the faithful "don't buy extended" reading) instead of
  **extended** (E1: exactly why RS-primary taxed the tail). If candidate ranking
  is *ever* revisited, this is the variant to test, RS-primary is dead.
- **But its realistic ceiling is do-no-harm + marginally lower dispersion / better
  Calmar — NOT added return** (E3), and the effect is **bounded to equal-score
  ties whose gross stage-gap the score already neutralizes** (E4). Expected value
  is marginal-consistency-only.
- **Therefore: do not prioritize the build+grid cycle now.** The cheap real test
  (add a `Quality_earliness` reorder — `weeks_advancing` asc primary — and re-run
  the existing 3-cell breadth grid; warehouses `wfcv-top{500,1000,3000}-1998` are
  on disk) remains the sanctioned next step **if** the user wants to convert this
  lean into hard evidence. It is not "rejected"; it is "not worth the cycle ahead
  of higher-certainty work, on current priors."

## The transferable WHY (capitalize-findings)

**The entire candidate-ranking lever class is a tiebreak among equal-score ties →
bounded by construction (E4) → cannot add return (E3) → its best case is a
dispersion/Calmar do-no-harm play.** RS-primary even gave back Calmar by selecting
*against* the fat tail (E1). Stop expecting *return* from candidate-ranking. The
one orthogonal place candidate-ordering still has standalone value is the **live
weekly-pick UX** (#1782) — de-dup / RS-led *display* ordering so the user doesn't
see the same alphabetical-first 20 grade-A names every week (AIT 12/26 H1 weeks).
That is a presentation change that does **not** touch backtest selection, so none
of E1–E4 constrains it — and it has clear, measured user value the backtest lever
lacks.

## Provenance
- Ledger: `dev/experiments/_ledger/2026-06-29-candidate-ranking-tiebreak-grid.sexp`
  (RS-primary REJECT + the forward directive being screened here).
- Code: `screener_ranking.mli` (modes), `screener_scoring.ml:18,40,65,83-84`
  (the 30/15 stage-progression weights → E4).
- Memories: `project_cascade_selection_inversion`, `project_edge_is_the_fat_tail`,
  `project_accuracy_is_unreachable_diversify_instead`,
  `project_screener_alphabetical_tiebreak`.
