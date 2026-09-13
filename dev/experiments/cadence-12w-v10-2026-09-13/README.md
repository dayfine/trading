# Item 4 — 12% initial stop × weekly trail cadence, re-measured on `_v10dedup` (2026-09-13)

**Status: PRE-REGISTERED.** The 09-05 surface's both-window survivor (`sw26y-w12-W`: 761% / maxDD 29.7 at
salt 0 on the OLD exit basis and the twin-carrying `_v7mark` warehouse — `project_stop_width_cadence_surface_2026_09_05`)
must clear the re-based band before it is anything but an axis. Every pre-09-03 exit-lever read is suspect
(`project_lever_reads_invert_on_fixed_sim`) and every `_v7mark` maxDD read is suspect (twin double-funding,
`project_stop_buffer_by_macro_state_axis`).

| | |
|---|---|
| arm | `specs/a4-cadence-12w.sexp` = a0-breadth-on-null + `((initial_stop_buffer 0.9167)) ((stop_update_cadence Weekly))` |
| null | `stop-width-by-state-2026-09-08/results/a0-breadth-on-null-s{0,1,2}-v10-*`: 382.74 / 311.75 / 639.74 %, maxDD 37.60 / 32.75 / 42.96 |
| build / warehouse / lanes | same as `deteriorating-gate-2026-09-13/` (31e4bb9c3, `sweep-detgate`, `_v10dedup` 2000); runs through that experiment's `chain.sh` as lanes B2 (salts 0, 1) and A2 (salt 2) once the gate cells free each lane; artifacts land in `/tmp/sweeps/detgate/a4-cadence-12w-s<salt>-v10-*` and are copied here |
| decision rule (pre-registered, same as item 3's) | clears only if realised P&L AND maxDD both beat the a0-v10 null at ≥ 2 of 3 salts, `validator_diff -check V6` exit 0 per salt, open MTM decomposed by name. Otherwise retire as an axis (`project_stop_width_regime_dependent` already records width as regime-dependent). |

Read with `ARM=a4-cadence-12w sh dev/experiments/deteriorating-gate-2026-09-13/read.sh <salt> <artifact-dir>`.

## Log
