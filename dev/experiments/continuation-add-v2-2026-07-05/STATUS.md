# Continuation-add v2 surface — STATUS: DONE, verdict REJECT

- **Mechanism:** merged default-off (#1855; plan #1852); stays a default-off
  axis. **Verdict: REJECT for promotion** — ledger
  `2026-07-05-continuation-add-v2-surface`; writeup
  `dev/notes/continuation-add-v2-wfcv-2026-07-05.md`.
- Run 2026-07-05: 13 folds × 4 variants, 9h06m, zero failures. Gate FAIL all
  variants (4/13, 3/13, 4/13 Sharpe wins). Docker.raw preflight resolved
  non-destructively pre-launch (55→21 GB container /tmp scratch).
- Pre-run sanity passed: continuation adds emit AND fill (COHU sibling add
  verified in `sanity/`; trades.csv trustworthy post-#1847).
- **Scale-in program CLOSED** — both halves tested and rejected (v1
  ½-sizing tax; v2 flat redistribution). See writeup §Program closure for
  the forward guidance (no more intra-envelope reallocation variants;
  revisit only paired with an envelope change).
- Artifacts: `out_top3000/` (aggregate, fold_actuals, report).
