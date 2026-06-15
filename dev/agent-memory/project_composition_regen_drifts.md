---
name: project-composition-regen-drifts
description: "A full build_composition_universes_runner rebuild drifts ~3% of symbols vs committed goldens — NOT a tie-break (builder is deterministic, verified); it's a provenance gap because inventory.sexp is UNTRACKED. Add volume via enrichment-in-place, not a rebuild; and track inventory.sexp"
metadata: 
  node_type: memory
  type: project
  originSessionId: ba7d98f1-b3d9-44de-a8f0-f78e1b02d084
---

2026-06-14: to get `avg_dollar_volume` into the 84 composition goldens
(`goldens-custom-universe/composition/top-{500,1000,3000}-{1998..2025}.sexp`) for
the policy-universe artifact (P1'.2), the obvious move is to re-run
`build_composition_universes_runner.exe` (it now populates
`avg_dollar_volume = Some scored.score` via `build_from_individuals._make_entry`).
**The builder works and writes volumes — BUT a full rebuild is NOT
behavior-neutral.** vs main, top-3000-2011 drifts **87/3000 symbols (2.9%)**:
2913 identical, the 87 turnover is ~68 delisted `_old`↔`_old2` tie-break swaps +
~10 warrant (AIG-WS) ↔ ~9 preferred (BAC-PL, GS-PD) swaps. Economically marginal
(tail names, 0.0003 weight) but **NOT bit-equal → re-pins any backtest reading the
goldens.** The `composition-dollar-volume-2026-06-11` plan's assumption that regen
is a clean `[@sexp.option]` add is WRONG for a full rebuild — the add is clean, the
re-ranking is not.

**VERIFIED CAUSE (2026-06-14 — corrects the "tie-break" wording above):** the
builder is **deterministic** — rebuilding top-3000-2011 twice ~5h apart gave a
byte-identical symbol set (0 diff). Ranking is `List.sort` (stable) over a
list-ordered inventory; no RNG / hashtable-iteration. #1542 only ADDED the
`avg_dollar_volume` field (didn't touch scoring). Inventory mtime stable (May 18),
bars not re-fetched, symbol_types only cosmetic (#1235). So the drift vs the
committed golden is a **provenance mismatch**, not a tie-break: the committed
golden (#1190, May 18) was built from a different inputs snapshot than the current
local store, biting only at the rank-3000 tail. **ROOT HOLE: `inventory.sexp` is
UNTRACKED** (only `symbol_types.sexp` is in git) → committed goldens are NOT
reproducible from version control; drift is silent + unauditable.

**DECISION 2026-06-14 (user):** (1) add volume via a **volume-only enrichment**
(freeze committed composition, recompute `avg_dollar_volume` per committed symbol
from current bars, inject the field — no backtest re-pin); (2) **commit
`inventory.sexp` to git** to close the reproducibility hole. Do NOT adopt the full
rebuild.

⚠ **Tension to resolve first** ([[project-trade-realism-liquidity]]): the user's
2026-06-10 finding says liquidity is a non-issue at our scale — so the ADR
liquidity FILTER the volume feeds may not earn its place vs plain REIT/preferred
exclusion (which needs no volume). If the filter is dropped/token, the enrichment's
value is reproducibility + future analysis, not the immediate policy artifact.

**Two gotchas for next time:**
1. **Path bug:** the builder's CLI usage says `--out-dir trading/test_data/...`
   but `dune exec` runs from the dune root `/workspaces/trading-1/trading`, so
   `trading/test_data` resolves to `…/trading/trading/test_data/` (DOUBLE trading,
   a junk dir). Correct `--out-dir` is **`test_data/goldens-custom-universe/composition/`**
   (no leading `trading/`). Symptom: real goldens untouched, junk appears under
   `trading/trading/test_data/`.
2. **Behavior-neutral path:** to add volume WITHOUT composition drift, build a
   volume-only **enrichment-in-place** tool (recompute `avg_dollar_volume` for the
   goldens' EXACT existing symbol set + inject the field), not a full rebuild.
   This is the recommended path if backtest continuity matters.

Regenerated-with-volume output (full rebuild) was preserved at container
`/tmp/regen-goldens-with-volume/` (84 files) and main was left untouched pending a
user decision (accept drift vs enrichment). Downstream `apply_composition_policy`
is anyway gated on the **ADR $-volume threshold value** (from the weekly >1%-ADV
gate spec) which only the user can supply. See
`next-session-priorities-2026-06-14.md` §2.
