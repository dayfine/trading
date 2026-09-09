# Warehouse dedupe rebuild — `_v10dedup` (2026-09-08, #2730 ask 3)

Rebuild of the three vintage warehouses (`top-3000` 2000 / 2009 / 2019, the `_v7mark` supersets from `warehouse-rebuild-2026-09-06`) with two changes:

1. **Rename-twin pass armed** (`-dedupe-rename-twins -twin-basis returns`, PR #2733): the `_v7mark` warehouses carried twin pairs (NLS/BFX, BB/BBRY, AABA/YHOO, DOC/HCP_old, AORT/CRY_old, AZN/AZN_old, LANC/MZTI, HPT/SVC …) and every wider-stop arm funded both legs — up to +$890k of a single arm's "edge" was one instrument counted twice (`stop-width-by-state-2026-09-08`).
2. **MEL quarantined** (#2732): a ~$170k/share mis-scaled series with a few $8–12 bars; the map arms bought 1–2 "shares" at $175k and lost $172k–$343k on the 12.2 bar.

Script: `rebuild4.sh` (pinned worktree `sweep-dedup`, container-exclusive, sequential; per-vintage `rename_twin_report_<v>_v10.txt` + `terminal_runs_<v>_v10.csv` land in `results/`).

Then: re-run the item-3 null + map (salts 0–2) on `_v10dedup` 2000, gated by `validator_diff.exe` on V6 (ask 2), and re-base the record band on it (V6 must read 0 on every cell).

## Run log

(pending — launch only when no cell and no agent is live; each vintage is a full 3,000-symbol build.)
