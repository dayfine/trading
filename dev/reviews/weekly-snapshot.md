Reviewed SHA: 3b919df1

# QC review — weekly-snapshot track

## PR #2100 — `feat/universe-rename-tracking` (issue #2083 Finding 2)

Live ticker-rename detection via returns-basis **succession**, default-off.

structural_qc: APPROVED
behavioral_qc: APPROVED
overall_qc: APPROVED

Rework iterations: 1 (of a cap of 2).

Full verdicts are PR review comments on #2100. Written here by the
**orchestrator**, not the QC agents: both were fenced read-only because the GHA
container shares a single git working tree. The `*_qc:` lines above sit at
column 0 with no list marker or backticks, and the `## Quality Score` heading
below is followed by a bare integer — `record_qc_audit.sh` greps
`^structural_qc: (APPROVED|NEEDS_REWORK)` and reads the first non-blank line
after a `## Quality Score` heading, and a prettier rendering parses to
**SKIPPED / null without erroring**.

### Round 1 — base tip `f40c033e`

- structural: **APPROVED**, quality 4/5. All rows PASS/NA, zero drift.
- behavioral: **NEEDS_REWORK**, quality 3/5. Three documented contracts
  unpinned and undisclosed:
  - **B1** — `.mli:201` claims "the highest `match_fraction` wins", but the only
    multi-successor fixture gave both successors *identical* series, so both
    scored 1.0, `Float.compare` returned 0, and only the tie-break arm ever ran.
    Mutating `| c -> c > 0` to `| c -> c < 0` left the whole suite green.
  - **B2** — the `as_of` truncation contract (stated twice in the `.mli`) was
    entirely unpinned: every fixture set `as_of` to the last calendar date, so
    deleting *both* truncation sites left the suite green.
  - **B3** — `rename_gate.mli:33`'s "(which the detector then ignores)" guard had
    no test; removing the `Array.is_empty` check makes `fst bars.(0)` raise, on a
    live production path (`partition` maps over every ticker in the universe).

### Round 2 — rework tip `3b919df1`

- structural: **APPROVED**, quality 4/5 (delta re-review). Lib delta confirmed
  comment-only; P6 clean on all new tests; the three orchestrator files
  accidentally swept into the author's first push were confirmed absent from
  branch history after the `--force-with-lease` cleanup.
- behavioral: **APPROVED**, quality 4/5. All three findings **CLOSED**, each
  verified *by construction* rather than on the author's word — the reviewer
  recomputed the fixture arithmetic (ZETACO 1.0000 vs ALPHACO 0.8000 with a 50×
  margin over `ret_epsilon`; the 11-date overlap; the 56-vs-6 overlap inflation
  under mutation; the trailing-window shift to a zero-density region) and
  confirmed the two `_better` arms are now *separately* pinned.
- **Regression check explicitly clean:** the rework is strictly additive — one
  removed line across both test files, and that a comment fragment. The shared
  calendar fixtures are unchanged *context* lines in the diff, so no pre-existing
  expected value could shift. This was the highest-risk side effect of adding new
  successions to a shared fixture calendar, and it is clean.

### Carried non-blocking flags

- **F7** (filed to `dev/status/cleanup.md`) — the `prefilter_rel_tol = infinity`
  correctness precondition is pinned only **incidentally**, by the B2 fixture
  whose anchor-key gaps happen to be 0.041–0.050 against the stock 2e-2. The
  pre-existing pair's min gap is 0.0057 and would leave it unpinned. A fixture
  edit could silently unpin a stated precondition.
- **F3–F6** — unpinned `Config.default` fields, directional-only threshold
  calibration, and single-rename ordering claims. Acknowledged non-blocking by
  both the reviewer and the author.

### Honest limitation carried into main

The `.mli` states it plainly and the PR body repeats it: **in the actual SNSE→FTH
incident, FTH was absent from the bar store**, so a run over the 07-17 pinned
universe would *not* have caught the rename. This is one layer of defence, not a
guarantee. The bar-store-wide scan and universe re-pin that would close that hole
need real data and are maintainer-local.

## Quality Score

4

## Verdict

APPROVED
