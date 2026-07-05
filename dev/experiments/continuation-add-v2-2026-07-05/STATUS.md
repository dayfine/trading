# Continuation-add v2 surface — STATUS

- **Mechanism:** merged default-off (#1855; plan #1852). REJECT of scale-in v1
  and its WHYs unaffected — this is the untested full-size+continuation-add
  shape with the book's actual trigger.
- **State: READY TO RUN, launch BLOCKED on Docker.raw recompact** (55 GB >
  30 GB sweep-hygiene preflight; user GUI action). Est. runtime ~8–12 h
  (13 folds × 4 variants, top-3000 snapshot mode, fork-per-fold).
- **Launch:** `walk_forward` runner with `spec_top3000.sexp`, snapshot dir
  `wfcv-top3000-1998`, `--parallel 1`, out-dir under `/tmp/sweeps/` per
  sweep-hygiene. Nothing else on the container.
- **First-fold sanity before the full run:** instrument or audit-diff one
  fold to confirm continuation adds actually emit AND fill (the #1846
  measurement lesson); verify trades.csv sibling rows look sane (post-#1847
  pairing).
- **Verdict:** to the ledger either way, with WHYs (mechanism-validation
  rigor). No promotion without ACCEPT + confirmation grid.
