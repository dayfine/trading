((date 2026-07-29) (slug split-basis-fold-recert)
 (hypothesis
  "Fold-level follow-up to 2026-07-28-split-basis-blast-radius: the promoted resistance-v2 bundle's WF-CV evidence basis (mean Sharpe .827 / return 36.17 / MaxDD 14.05 on the 13x2y broad grid) was measured on split-blind side-tables. Re-run the same 13x2y grid (promoted-bundle defaults, record-convention base scenario) on the split-safe v5thin clone, with a single no-op variant (bands 1/1/1/0 = the promoted default) doubling as an internal bit-consistency check of the adjusted arm.")
 (base_scenario
  "staging-record-convention/top3000-2000-2026-record-convention on /tmp/snap_top3000_dedup_v5thin_adj (promoted-bundle defaults, pinned worktree @ 9f50de924 + one added spec file, run 2026-07-28 23:10Z - 07-29 06:11Z)")
 (window_id margin-m4-broad-13x2y-2000-2026)
 (baseline_label baseline)
 (variants
  (((label "baseline (honest adjusted basis)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.765) (mean_calmar 0.897) (mean_return_pct 28.49)
       (mean_max_drawdown_pct 15.93)))))
   ((label "no-op default variant (internal parity check)") (config_hash "")
    (aggregate
     (((mean_sharpe 0.765) (mean_calmar 0.897) (mean_return_pct 28.49)
       (mean_max_drawdown_pct 15.93)))))))
 (verdict Inconclusive)
 (notes
  "MEASUREMENT entry (verdict n/a; kept Inconclusive). The HONEST fold-level baseline of record is now .765 Sharpe / 28.49 return / 15.93 MaxDD / .897 Calmar (sigma: Sharpe .462, return 26.49) vs the split-blind .827 / 36.17 / 14.05 / 1.309 -- the fold-level promotion evidence was flattered by -.062 Sharpe / -7.7pp mean fold return / +1.9pp MaxDD. Internal parity: the no-op variant is BIT-IDENTICAL to baseline on all 13 folds (0 wins, worst gap 0.0000) -- the adjusted read path is deterministic and Overlay_validator axis plumbing certifies clean on the new-hash warehouse. Per-fold honest profile: strong 2000-02 (.96-1.37), monster fold-010 2020-21 (1.635, +95.4%), weak fold-009 2018-19 (-4.5%, -.063) and fold-011 2022 (+5.4%, DD 31.5). CAUTION: cross-basis comparisons are invalid -- the honest .765 coincidentally equals the CONTAMINATED 07-26 baseline (.766, issue #2108); unrelated (that was environmental, raw-basis). What this does NOT settle: whether the bundle still beats its ALTERNATIVES honestly -- pre-bundle/floors/w15 arms were never run on the adjusted basis; if the R3 record re-pin wants a bundle-vs-pre-bundle honest margin, that comparison grid is a further (larger) run. All standing REJECT verdicts that cited baseline .827 (margin M4, leverage-dawn, leverf-age) remain qualitatively safe -- their losing margins dwarf the basis shift, but their baseline citations should be read as raw-basis numbers. FROM 2026-07-29 THE HONEST BASELINE OF RECORD FOR THE 13x2y BROAD GRID IS .765/28.49/15.93 ON THE ADJUSTED CLONE; new fold-level experiments should run on split-safe warehouses and compare against it, not .827. Artifacts /tmp/sweeps/basis-recert-broad/ (report+aggregate, mirrored into /tmp/sweeps/basis-blast/); spec basis-recert-BROAD-2000-2026.sexp (worktree-local, reproduced in the memo)."))
