((date 2026-07-28) (slug split-basis-blast-radius)
 (hypothesis
  "Issue #2133 backtest blast radius: the promoted resistance-v2 bundle's evidence (and the 28y record-of-record row) was measured on SPLIT-BLIND side-tables (raw-basis weekly high/mid vs a raw Close anchor). Re-measure the contiguous 26.5y record-convention path on a split-safe clone of v5thin -- side-tables rebuilt on the adjusted basis by rebuild_weekly_sidetables.exe (PR #2153) with CSV deep-prefix re-feed re-pinned to the warehouse's adjusted basis -- against a same-binary raw control, to quantify how much of the record was basis-flattered.")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention (promoted-bundle defaults, pinned worktree @ 9f50de924, run 2026-07-28 21:22Z; control /tmp/snap_top3000_dedup_v5thin, treatment /tmp/snap_top3000_dedup_v5thin_adj)")
 (window_id contiguous-top3000-2000-2026)
 (baseline_label raw-control)
 (variants
  (((label raw-control) (config_hash "")
    (aggregate
     (((mean_sharpe 0.0) (mean_calmar 0.0) (mean_return_pct 8689.4)
       (mean_max_drawdown_pct 30.3)))))
   ((label adjusted-split-safe) (config_hash "")
    (aggregate
     (((mean_sharpe 0.0) (mean_calmar 0.0) (mean_return_pct 8366.8)
       (mean_max_drawdown_pct 37.1)))))))
 (verdict Inconclusive)
 (notes
  "MEASUREMENT entry, not a mechanism verdict (verdict field is n/a; kept Inconclusive). Control REPRODUCES the pinned record on current main (+8689.4% / MaxDD 30.3 / 1172 trades / win 38.5 vs recorded +8689 / 30.3 / 1170 / 38.4) -- the #2145 old-hash bit-compat claim holds at path level. Split-safe treatment: +8366.8% / MaxDD 37.1 / 1122 trades / win 37.7. BLAST RADIUS: -322pp return (-3.7% rel), -50 trades, and MaxDD DEGRADES 30.3 -> 37.1 (+6.8pp) -- the record's headline risk number was materially flattered by split-blind grading; the return flattering is mild. Trade-level: entry churn is broad (~190 symbols entered only under raw grades, ~140 only under adjusted -- the cap-20 screener boundary reshuffles when overhead grades change); the AXTI monster is intact ($64.1M vs $65.8M realized); largest per-symbol swings FARM +$2.1M, FDX +$1.3M, BKE +$1.1M (adj-favored), AXTI -$1.7M, PEGA -$0.9M (raw-favored). Migration provenance: 2894/2908 symbols rebuilt with exact week-skeleton parity; 14 refused deep re-pin (revision-class raw restatements since 06-26, e.g. HON post-window corporate action; snap-only fallback), LH/ONTO rebuilt with skeleton drift (CSV restatements) -- migration_report.sexp archived. CAVEATS: single contiguous path (no fold-level lens); the bundle's PROMOTION evidence (13x2y WF-CV surface, baseline .827) is NOT re-certified here -- fold-level re-run on the adjusted clone is the open follow-up; Run-D (+7914/32.3) is also split-blind-era and not directly comparable. Record-of-record re-pin to the honest numbers = user decision (R3). Artifacts /tmp/sweeps/basis-blast/{raw,adj}/ + migration_report.sexp; memo dev/notes/split-basis-blast-radius-2026-07-28.md."))
