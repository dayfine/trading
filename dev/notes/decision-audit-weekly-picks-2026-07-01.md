# Decision-audit on the 2026 live weekly picks — pipeline + first run (2026-07-01)

Applies the decision-audit faithfulness lens to the **live** 2026 weekly
recommendations (not a backtest). Two pieces landed this session:
- **(a)** `Weekly_adapter` (PR #1811) — `Weekly_snapshot.t list → Screen_record.t list`,
  so the same Phase-1 report + Phase-2 counterfactual run on live picks. "Funded" =
  the displayed top-`displayed_k` (default 3); "near-miss" = the rest of the ranked
  cohort (`reason_skipped = Top_n_cutoff`) — the synthetic analog of the backtest
  cash line.
- **(b)** fetched 2026 forward bars + built a snapshot warehouse for the counterfactual.

## The setup

- **Picks:** `dev/weekly-picks/89c2ee2a8/` — 5 weekly snapshots, 2026-05-29 → 06-26.
  Each is **20 candidates, all grade A / score 70** (the tie), alphabetically ordered.
- **Data (b):** the 50 unique pick symbols are small-caps NOT in `test_data`; fetched
  fresh from EODHD (Phase-1 verified: clean daily bars incl. tiny names AIXI/AGPU,
  floor 2026-06-30 = latest EOD). Fetch window 2025-01-01→2026-06-30 (indicator
  lead-in + the elapsed forward window). Built a 50-symbol snapshot warehouse via
  `build_snapshots.exe`.

## Reproduce

```bash
# (b) fetch — host (needs $EODHD_API_KEY); writes CSV store layout <f>/<l>/<SYM>/data.csv
#   symbols = union of candidates across dev/weekly-picks/89c2ee2a8/*.sexp (50)
#   window 2025-01-01..2026-06-30, into trading/dev/experiments/weekly-cf/data
# build the 50-symbol Pinned universe.sexp, then in the container:
build_snapshots.exe -universe-path <universe.sexp> \
  -csv-data-dir <.../weekly-cf/data> -output-dir <.../weekly-cf/warehouse> \
  -start-date 2025-01-01 -end-date 2026-06-30
# (a) run the lens (after #1811 merges; repo-root path for the picks dir):
decision_audit_bin.exe \
  --weekly-picks-dir /workspaces/trading-1/dev/weekly-picks/89c2ee2a8 \
  --snapshot-dir <.../weekly-cf/warehouse> --displayed-k 3 --horizon-weeks 4 --out r.md
```

⚠ **jj-wipe gotcha:** `dev/experiments/` + `dev/weekly-picks/` are NOT gitignored,
so any `jj new`/branch-switch snapshots then **wipes** uncommitted warehouse/data
from disk. Regenerate from the fetch command above (fetch ~1 min, warehouse 0.4s);
don't expect the warehouse to survive a working-copy switch.

## First run — PIPELINE VALIDATION, not signal

5 screens, 15 funded (alphabetical top-3), 85 near-misses. 4-week horizon.

**Phase-1 (captured features):**
| feature | funded | near-miss |
|---|---|---|
| score | 70.00 | 70.00 (all tied — the tie, confirmed) |
| rs_value | **1.46** | **1.50** |
| volume_ratio / weeks_advancing | — | — (not carried in snapshot; the documented ceiling) |

The displayed (alphabetical) top-3 sit *marginally below* the cut cohort on RS
(1.46 vs 1.50) — i.e. alphabetical display is mildly RS-anti-selective, consistent
with the earlier "alphabetical buries the high-RS names (AIXI rs6.5)" finding.

**Phase-2 (4-week forward return):**
| group | mean | median | n |
|---|---|---|---|
| funded | +0.12 | +0.04 | 15 |
| near-miss | +0.04 | −0.01 | 85 |

**This is NOISE, not a result.** Only ~1–5 weeks have elapsed (picks 05-29→06-26,
today 07-01) vs the horizon; n=15 funded across 5 screens; one small universe. The
funded>near-miss direction here is within-noise and even contradicts the RS gap
above — exactly what you'd expect from an unmatured window. **What it proves:** the
(a)+(b) pipeline runs end-to-end on live picks and emits the faithfulness +
counterfactual output. Re-run the same command as 2026 progresses (or extend
`--horizon-weeks`) and the counterfactual matures into a real "did the alphabetical
display leave return on the table" test.

## Standing interpretation (unchanged)

RS as a *funding/return* tiebreak was WF-CV **rejected** (#1788) — so this is a
**display/UX** lever (#1782: show the human the strongest-RS names first), not a
return claim. The matured counterfactual will test the return side directly; until
the window elapses, treat the live-picks numbers as pipeline validation only.
