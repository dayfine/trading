# Next-session priorities — 2026-07-28

**Supersedes** `next-session-priorities-2026-07-27.md`. That doc's P0
(Phase C + #2103) and everything that grew out of it SHIPPED across
07-27/07-28 — the session closed the entire live-picks defect arc:

- **Reports**: #2105/#2107 (HTML + entry reconciliation), #2129 (watch
  section, full 20-pick list, warehouse charts, `-html-out` both formats),
  #2134 (split-adjusted charts).
- **Validation**: #2139 — `Snapshot_validator` + `validate_weekly_snapshot.exe`
  (#2122 v1); full-history sweep found zero errors + ~30 `split_in_window`
  basis-suspect picks.
- **Split-safe grading**: #2145 — resistance sketches on the adjusted basis,
  hash-gated (`Weekly_sidetable.format_hash` new = `128e4c1e…`, old kept as
  `format_hash_raw_basis`; old-hash warehouses bit-identical by design).
  Weekly-review warehouse rebuilt (3,173/3,173).
- **Record of record for 07-24 = v4** (`dev/weekly-picks/790d23a06/`,
  PR #2150): **CLMB (rank 2) dropped on honest grading** — its "Clean (0.12)"
  was a 4:1-split artifact hiding a $25–34 supply wall — PH entered; 19
  others bit-identical; validator "OK: no findings".
- Also: baseline-drift root-caused (#2108/#2109/#2119, P1b REJECT
  re-certified clean); pinned-worktree sweep rule; picks v1/v2/v3 records.
- Memories: `project_split_safe_resistance_basis`,
  `project_leverage_dawn_drift_root_cause`.

**Friday's live run is on fully honest machinery.** Recipe: fetch → full
(non-incremental) `build_snapshots.exe` rebuild of weekly-review (superset
Pinned universe = picks + 15 context syms; grammar
`(Pinned ( ((symbol X) (sector "S")) … ))`) → generate with live overrides →
`validate_weekly_snapshot.exe -bars-snapshot-dir … -risk-budget 1000` →
render. Validation must be part of the record (v4 convention).

## P0 — #2133 backtest blast radius (task #12)

The promoted resistance-v2 bundle's evidence used split-blind sketches.
v5thin (and every backtest warehouse) still carries raw-basis/old-hash
side-tables — deliberately bit-identical until this deliberate re-measure.

Recommended first step (small tool, then compute):
1. **Build `rebuild_weekly_sidetables.exe`** — derive `SYMBOL.weekly` from an
   EXISTING warehouse's own `.snap` daily columns (bars are all there:
   O/H/L/C + Adjusted_close) into a **clone/overlay dir**, stamping the new
   format hash in a cloned manifest. Never mutate the certified warehouse
   in place. This also becomes the standard migration tool for every other
   warehouse.
2. Clone v5thin side-tables split-safe → re-run the record-convention
   scenario (pinned worktree per `sweep-hygiene.md` §Pinned-worktree builds;
   detached + marker-file + persistent Monitor — plain background watchers
   get reaped and wedge dune, see Ops notes) → compare vs the pinned record.
3. Ledger/memo the outcome. No golden/claim changes before the measurement.
   Disk was at ~53G free at session close — check before launching.

## P1

- **#13 floor anchoring (wick vs close)** — `support_floor` anchors stops on
  intraday capitulation wicks (CLMB's old $14.64 = Apr-30 wick 15.25 −4%);
  close-basis floor would read ~26% risk vs 42.5%. Domain-rule change: needs
  book authority + default-off knob per flag discipline. Also make
  support_floor split-safe (raw lows) — same Adjusted_basis helper.
- **#2122 slice (a)**: wire the validator into `generate_weekly_snapshot`
  warn-first so Friday runs self-check without a separate invocation.

## P2 — carried

- **#15 / #2083 remainder**: arm returns-basis rename detection in
  `dev/weekly-picks/live-config-overrides.sexp` + universe re-pin.
- #2122 slices (b) cross-artifact instruction identity, (c) reproducibility
  golden (v3 demonstrated it live: regenerated sexp bit-identical mod
  version stamp), (d) "N eligible beyond cap" visibility.
- Tax Phase 2; trader-preset audit; decision_audit Phase-2 (unchanged).

## Ops notes (hard-won this session)

- **Background docker-exec clients get reaped mid-run and wedge dune**
  (0% CPU holding the lock). Playbook: `pkill -9 dune`, rm `_build/.lock`
  (+ `.db` after kill -9), rerun. Reliable pattern: `docker exec -d` writing
  RC markers to `/tmp/sweeps/...` (bind-mount) + **persistent Monitor** on
  the host-side marker file. Foreground execs that finish within their
  client's life are also fine.
- The GHA orchestrator actively reworks open PRs with failing gates — check
  `git ls-remote` for a moved tip before pushing a local rework
  (double-rework collisions happened on #2139 AND #2145; adopt the remote,
  it usually includes extra QC-driven pins).
- CI's nesting linter (avg 3.0/max 5/file 2.5) rejects inline
  `if…Some…else None` inside list literals — hoist to `_`-prefixed
  option-returning helpers up front; verify with
  `dune runtest devtools/checks` reading dune's exit code, not grep.
