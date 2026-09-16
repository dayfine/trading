---
name: pit-chunked-twin-miss
description: ⭐ A chunked -incremental build_snapshots run misses every CROSS-chunk rename twin (233 legs on the 9.6k PIT union, 09-15); fix = pairwise chunk-union twin scans (report is written before the per-symbol loop; kill after it) + one small -incremental dedupe rebuild of the pairs; hubs (CISXF/BWLP/LNSPF/IBDRY/BCAL, >4 legs) are the false-twin class; a full-union scan OOMs.
metadata:
  type: project
---

**Cross-chunk twins are invisible to a chunked build.** The 3b `_v11pit` warehouse was built in four
first-letter chunks (`-incremental`, 10.5k names OOM in one pass at 7.75 GB). The twin pass sees one chunk
at a time, so every rename whose legs sort into different chunks (ELV/ANTM, DXC/CSC, CPAY/FLT, EXE/CHK,
AABA/YHOO, TFC/BBT_old, ALTM/LTHM, GTM/ZI, GEAR/VSTO …) stayed double-indexed. V6 on the first null
caught only the 3 pairs that were HELD simultaneously; the true count was **233 legs / 239 edges**.

**Method that works (2026-09-15, `dev/experiments/pit-universe-2026-09-14/step4/twin-scan/`):**
- A full-union twin scan OOMs (exit 137, ~5 min) — `Twin_pass.run` loads every symbol's bars first.
- Six chunk-PAIR unions (~5.2k names, peak ~4.3 GB, ~35 min each) fit; `rename_twin_report.txt` is
  written BEFORE the per-symbol build loop, so `pkill build_snapshots` once it exists (`pair-scan.sh`).
- Keep only DIRECT edges: overlap ≥ 200, match ≥ 0.95, survivor not a hub (> 4 legs — CISXF alone had 65,
  the degenerate flat/zero-return series class of #2823), leg not in the restored false-legs list, both legs
  still in the manifest (`analyze-pair.sh`).
- One `-incremental -dedupe-rename-twins` rebuild whose universe is survivor+dropped legs together (460 names,
  40 s) removes the losers from the manifest (`Build_runner`: dropped legs leave the carry set). Check the
  report for collateral (EMBT was dropped via test tickers ZAZZT/ZBZZT → rebuilt alone, no dedupe).
- Then alias the dropped legs into the yearly lists (`alias-lists.pl`, balanced-paren entry matcher,
  per-list dedupe): manifest 9,597 → 9,364; union 10,133 → 9,900; per-year effective breadth 2,79x–2,99x.

**Why:** a held twin double-funds one instrument (~$764k on one arm, #2730); the record band demands V6 = 0.

**How to apply:** any warehouse built in chunks needs the pairwise scan before its first measured cell;
budget ~3.5 h for a 4-chunk union. Better: a `-twin-only` mode in `build_snapshots` (closes-only load) —
not built. Related: [[delisting-guards-2672]], [[splice-reuse-cut-is-terminal-events]],
[[pit-universe-migration]].
