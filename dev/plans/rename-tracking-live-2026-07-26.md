# Live rename tracking (issue #2083 Finding 2) — 2026-07-26

Track: `weekly-snapshot`. Branch: `feat/universe-rename-tracking`.

## 1. Context

The 2026-07-17 weekly report's rank-1 pick **SNSE** did not exist at the
broker. Sensei Biotherapeutics renamed to Faeth Therapeutics, **SNSE -> FTH,
effective 2026-06-16**. Three compounding failures were filed as issue #2083:

| # | Failure | Status |
|---|---|---|
| F1 | Feed served a sparse "zombie" tail under the dead ticker | SHIPPED — `Sparse_tail_gate` (#2090) |
| F3 | The screener's breakout came off a single +58% spike bar | SHIPPED — `Spike_bar_gate` (#2097) |
| F2 | **Nothing knew the rename had happened** | this plan |

F1 and F3 are *backstops*: they refuse or annotate a candidate whose data
smells bad. F2 is the only finding that attacks the root cause — knowing that
`SNSE` was superseded by `FTH` on a specific date.

Issue #2083 proposes two mechanisms for F2:

> **Rename tracking on fetch:** EODHD symbol-change feed (or detect via the
> existing returns-basis twin matcher run live: new symbol whose returns match
> a going-stale one) -> update universe mapping, carry the history under the
> new ticker.

`EODHD_API_KEY` is **not available** in this environment, so the vendor
symbol-change feed cannot be built or tested here. This plan builds the
parenthetical — the **returns-basis succession detector run over the local bar
store** — which is fully testable offline and needs no vendor feed at all.

### What already exists

`trading/trading/backtest/snapshot_warehouse/twin_detector.{ml,mli}` (library
`twin_detector`, depends only on `core`) implements returns-basis similarity
scoring for the *warehouse builder*. Its docstring carries calibration we must
not re-derive:

> On the real top-3000 warehouse `Levels` found 15 exact-feed groups yet missed
> 9 of the 10 known rename twins (e.g. BLL/BALL, BKR/BHI, TXNM/PNM); those 9 all
> score 0.95-0.99 under `Returns` while genuine different-company controls
> (BALL/TAP, ASB_old/CDX_old) score below 0.06.

`Twin_detector.detect` answers a *different* question: "which series in this
set are near-duplicates of each other, concurrently?" It union-finds all
matching pairs into groups and keeps the latest-`data_end` leg. A **rename
succession** is strictly more specific:

- the predecessor is dense up to ~`D` and then goes sparse/silent,
- the successor has no history before ~`D` and is dense after it,
- over whatever window they *do* overlap, daily returns match closely.

A concurrent twin (two dense series over the same span) is **not** a rename
event, and `Twin_detector` cannot tell the two apart.

## 2. Approach

### 2.1 New pure module `Rename_detector`

Location: `trading/trading/weinstein/snapshot/gen/lib/rename_detector.{ml,mli}`,
beside its `Sparse_tail_gate` / `Spike_bar_gate` siblings from the same issue.

Pure function of `Config.t` + `as_of` + a list of `series` (symbol + ascending
`(date, adjusted_close)` array). No filesystem, no bar loading — the caller
owns loading, exactly as `Twin_detector` does.

**Reuse, not reimplementation.** The returns-similarity score is obtained by
calling `Twin_detector.detect` on the two-series pair with
`basis = Returns` and `min_overlap_days = 2` (so the anchor stride is 1 and
the prefilter is exhaustive over the pair — no false negatives from anchor
sampling), then reading `overlap_days` / `match_fraction` off the resulting
`pair_match`. The overlap and match thresholds are then applied by *this*
module. No line of similarity arithmetic is duplicated, and no existing module
is modified.

**Succession criteria** — all must hold for an ordered pair
`(old = a, new = b)`:

| id | criterion | knob |
|---|---|---|
| S1 | `D = b`'s first bar date; `a` has `>= min_predecessor_bars` bars strictly before `D` (the old ticker had real history, the new one starts at `D`) | `min_predecessor_bars` |
| S2 | `D <= a`'s last bar date (they overlap at all) and `b`'s last bar date `>= a`'s last bar date (the successor is the surviving leg) | — |
| S3 | over the trailing `tail_window_trading_days` **union** dates `<= as_of`: `a`'s bar density `<= max_predecessor_tail_density` and `b`'s `>= min_successor_tail_density` — the *handover* signature that separates a succession from a concurrent twin | `tail_window_trading_days`, `max_predecessor_tail_density`, `min_successor_tail_density` |
| S4 | shared dates `>= min_overlap_days` and the `Returns` match fraction `> match_fraction` | `min_overlap_days`, `match_fraction`, `ret_epsilon` |

S1/S2 are cheap and run first as a prefilter; S3 is cheap; only surviving
pairs pay for S4's `Twin_detector.detect` call.

**Trading-day calendar.** The module derives its calendar from the input
itself: the sorted union of every date appearing in any input series. Over a
whole universe this *is* the trading calendar; it needs no `Bar_reader` and
keeps the module pure. Documented as such in the `.mli`.

Output:

```ocaml
type rename = {
  old_symbol : string;
  new_symbol : string;
  changeover : Date.t;      (* successor's first bar date *)
  overlap_days : int;
  match_fraction : float;
  old_tail_bars : int;
  new_tail_bars : int;
  tail_window_trading_days : int;
}

type report = { config : Config.t; renames : rename list }

val detect     : Config.t -> as_of:Date.t -> series list -> report
val mapping    : report -> (string * string) list   (* old -> new *)
val survivors  : report -> all_symbols:string list -> string list
val warnings   : report -> string list
val render     : report -> string
```

**Plan revision (during implementation).** `weinstein_snapshot_gen` is a
*public* dune library and `twin_detector` was *private*, so dune refuses the
dependency ("Library "twin_detector" is private, it cannot be a dependency of a
public library"). Resolved with a one-line addition of
`(public_name trading.backtest.twin_detector)` to the existing
`trading/trading/backtest/snapshot_warehouse/dune`. This is a packaging-only
change under an already-declared package — no code, no behaviour, no opam
package added — and is the minimal alternative to the extraction this plan
explicitly declined to do unilaterally. Recorded here rather than done silently.

### 2.2 Wiring — `Weekly_snapshot_generator`, default-off

`generate` currently does:

```
all tickers -> Sparse_tail_gate.partition -> eligible, sparse_warnings
```

It becomes:

```
all tickers -> _rename_partition -> survivors, rename_warnings
             -> Sparse_tail_gate.partition -> eligible, sparse_warnings
```

Rename detection runs **first**, on the full ticker list: the sparse-tail gate
is armed in production and would otherwise have already removed the zombie
predecessor whose bars are the evidence.

Effect when armed: a detected predecessor is dropped from candidate
consideration and a warning line naming `OLD -> NEW (changeover, overlap,
match)` is appended to `Weekly_snapshot.t.warnings`, so the pick disappears
*with an explanation and an actionable successor ticker* rather than silently.

**Plan revision (during implementation).** The adapter was first written inline
in `weekly_snapshot_generator.ml`, which pushed that file to 303 lines — past
the 300-line hard limit. Per `code-health-discipline.md` the fix is extraction,
not a limit bump: the adapter now lives in its own small module
`Rename_gate` (`series_for` + `partition`), whose `partition` returns the same
`(eligible, warnings)` shape as `Sparse_tail_gate.partition`, so the two #2083
eligibility stages compose uniformly. The generator is back to 276 lines and
`Rename_detector` stays filesystem-free.

### 2.3 Config — R1/R2

Two new flat fields on `Weinstein_strategy_config.config`, mirroring the
`sparse_tail_min_bars` / `sparse_tail_window_trading_days` pair exactly:

```ocaml
rename_detect_min_overlap_days : int;   [@sexp.default 0]
rename_detect_match_fraction   : float; [@sexp.default 0.0]
```

`Rename_detector.Config.armed ~min_overlap_days ~match_fraction` sets
`enabled = (min_overlap_days > 0 && match_fraction > 0.0)`; anything else is
disabled, and `detect` on a disabled config returns an empty report without
touching the series. The generator additionally short-circuits before building
series, so an unarmed run does not even pay the load cost — **bit-identical**
to today.

Remaining five detector knobs (`ret_epsilon`, `min_predecessor_bars`,
`tail_window_trading_days`, `max_predecessor_tail_density`,
`min_successor_tail_density`) live in `Rename_detector.Config.t` with
documented defaults, so there are no magic numbers; the two fields that
actually need per-run calibration are the ones lifted to the strategy config.
Defaults for `match_fraction` (0.95) and `ret_epsilon` (1e-3) are taken from
`Twin_detector.Config.default` so the two detectors agree on what "the same
series" means.

**Not armed.** The default is not flipped and nothing is added to
`dev/weekly-picks/live-config-overrides.sexp` — that needs a ledger ACCEPT
(`experiment-flag-discipline.md` R3).

### 2.4 Rejected alternatives

- **Put the module under `analysis/data/universe/lib/`.** Conceptually the
  better home, and the A2 direction (`analysis/` -> `trading/trading/`) is
  allowed. But `analysis/data/universe` is its own dune-project scope and
  `twin_detector` is a *private* library in the `trading/` project, so
  `universe` cannot depend on it without giving `twin_detector` a
  `public_name` + opam package — i.e. modifying an existing module's packaging
  unilaterally. Co-locating with the other two #2083 gates costs nothing and
  keeps the family together. Flagged as a decision item in the status file.
- **Extract `_returns_match_fraction` out of `Twin_detector` into a shared
  scoring lib.** Cleanest long-term, but it modifies an existing module used by
  the warehouse builder. Per CLAUDE.md, *propose* rather than execute: recorded
  as a decision item; this session takes the non-invasive
  `Twin_detector.detect`-on-a-pair path.
- **Reuse `Twin_detector.detect` wholesale over the universe.** Rejected: its
  union-find groups *concurrent* duplicates, has no notion of a changeover
  date, and would report a dual-listing as a rename.
- **Build the EODHD symbol-change feed client.** Out of scope — no API key in
  this environment, so it could not be exercised even once.

### 2.5 Weinstein-faithfulness

This is an **engineering data-hygiene mechanism, not a Weinstein book rule.**
No section of `docs/design/weinstein-book-reference.md` is cited because none
supports it. The spine is untouched: no change to stage classification, the
Stage-2-only buy rule, volume confirmation, macro/sector gating, entry, stop or
sizing. The mechanism only decides *whether a ticker's price series is
trustworthy enough to screen at all*.

## 3. Files to change

| File | Change |
|---|---|
| `dev/plans/rename-tracking-live-2026-07-26.md` | this plan (commit 1) |
| `trading/trading/weinstein/snapshot/gen/lib/rename_detector.mli` | new — full doc surface |
| `trading/trading/weinstein/snapshot/gen/lib/rename_detector.ml` | new — implementation |
| `trading/trading/weinstein/snapshot/gen/lib/dune` | add `twin_detector` to `libraries` |
| `trading/trading/backtest/snapshot_warehouse/dune` | give `twin_detector` a `public_name` (packaging only, see §2.1) |
| `trading/trading/weinstein/snapshot/gen/lib/rename_gate.{ml,mli}` | new — the `Bar_reader` adapter (see §2.2) |
| `trading/trading/weinstein/snapshot/gen/test/test_rename_gate.ml` | new — adapter/seam tests |
| `trading/trading/weinstein/snapshot/gen/test/test_rename_detector.ml` | new — unit tests |
| `trading/trading/weinstein/snapshot/gen/test/dune` | register the test |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.ml` | two new fields + defaults |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy_config.mli` | field docs |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy.mli` | mirror field docs |
| `trading/trading/weinstein/snapshot/gen/lib/weekly_snapshot_generator.ml` | `_rename_series` / `_rename_partition` + call in `generate` |
| `trading/trading/weinstein/snapshot/gen/lib/weekly_snapshot_generator.mli` | document the new stage |
| `trading/trading/weinstein/snapshot/gen/test/test_weekly_snapshot_generator.ml` | generate-seam tests |
| `dev/status/weekly-snapshot.md` | status entry |

## 4. Risks / unknowns

1. **Coverage limit.** The generator can only see symbols in its own universe +
   held book. In the actual incident **FTH was absent from the bar store
   entirely**, so a live run over the 2026-07-17 pinned universe would *not*
   have caught SNSE->FTH. Full coverage needs a scan of the whole bar store,
   which is the maintainer-local re-pin task (out of scope, see §6). This
   limitation is stated in the `.mli` and the status file — the module must not
   be oversold as having prevented the incident on its own.
2. **False positives from spin-offs / dual listings.** A spin-off whose first
   weeks track the parent closely could trip S4. S3's handover requirement
   (parent must go *sparse*) is the main guard; a spun-off parent stays dense
   and is therefore not reported.
3. **Cost when armed.** Detection needs a full daily history per ticker, a
   second pass over the bar store. Mitigated by short-circuiting before series
   construction when disabled (the default) and by the cheap S1-S3 prefilter.
4. **Short overlaps.** A rename with a 1-day overlap cannot be scored on
   returns (a return needs two consecutive bars). `min_overlap_days >= 2` is
   enforced; renames with a clean cut-over and zero overlap are undetectable by
   this mechanism and need the vendor feed.
5. **`weekly_snapshot_generator.ml` is at 261/300 lines.** The wiring must stay
   ~20 lines or an extraction is required (no limit bump, no `@large-module`
   marker — `code-health-discipline.md`).

## 5. Acceptance criteria

- `Rename_detector` is pure: no filesystem, no `Bar_reader`, same input -> same
  output.
- Every public value in `rename_detector.ml` is exported in the `.mli` with a
  doc comment; no function over 50 lines; file under 300 lines.
- Tests (OUnit2 + `Matchers`, one `assert_that` per value) cover **at least**:
  1. **True positive** — a synthetic SNSE->FTH-shaped succession (predecessor
     dense then sparse after `D`, successor starting at `D`, matching returns
     over the overlap) is detected, with the right `old_symbol`/`new_symbol`
     *direction*, changeover date, overlap and score.
  2. **True negative, level-similar** — two different companies whose price
     *levels* coincide but whose *returns* differ are not flagged (pins that
     the `Returns` basis is what does the work).
  3. **Near-miss negative** — two fully-overlapping series that both stay dense
     (a *concurrent* twin, the thing `Twin_detector` reports) is **not** a
     rename.
  4. **Default-off** — a default config yields an empty report; at the
     `generate` seam, the default-config run on a rename-shaped fixture is
     byte-identical to the armed-detector-absent run.
  5. **Both directions pinned at the seam** — the predecessor is dropped *and*
     the successor is retained, each asserted separately, plus a warning naming
     both. (The recurring defect on this track is one side of a two-sided path
     being unpinned.)
- Every new production line is mutation-checked: break it, confirm exactly one
  test goes red, restore. Lines that no test pins are named explicitly in the
  status file and the PR body.
- `dev/lib/run-in-env.sh dune build @fmt`, `dune build`, `dune runtest` all
  exit 0 (modulo the pre-existing maintainer-owned `Tuner.Bayesian_opt` LAPACKE
  failure, PR #2009, which touches no code in this diff).

## 6. Out of scope

- **EODHD symbol-change feed / any live API call.** `EODHD_API_KEY` is not set
  in this environment; a vendor-feed client could not be exercised even once.
  Filed as the follow-up half of F2.
- **Re-pinning the production universe / rewriting the bar store.** Needs real
  data and maintainer judgement; the module produces the *mapping*, applying it
  to a pinned snapshot is a maintainer-local task.
- **Merging or renaming history files on disk** (carrying the predecessor's
  bars forward under the successor ticker).
- **Arming the flag.** Ships default-off; arming needs a ledger ACCEPT (R3) and
  a false-positive dry run over the live universe.
- **Modifying `Twin_detector`** (extraction of its scoring core, or giving it a
  `public_name`) — proposed as a decision item, not executed.
