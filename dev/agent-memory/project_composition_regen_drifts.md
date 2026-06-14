---
name: project-composition-regen-drifts
description: "A full build_composition_universes_runner rebuild is NOT behavior-neutral — it drifts ~3% of symbols (delisted-variant tie-breaks); volume-add needs an enrichment-in-place, not a rebuild"
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
