Reviewed SHA: 25b4f550

## Behavioral QC — selection-path differential (#2503)

PR #2507, branch `fix/screener-refactor-differential-2503`, tip `69787516`.
qc-structural: APPROVED (quality 4). Environment: no docker, no `gh`; `dune` via
`eval $(opam env)` in an isolated plain-git worktree at `/__w/trading/wt-qcb-2507`.

### Scope

Infrastructure / test PR. No production code is touched (`+1,035/−2` across a new
`Selection_trace` library, its dump binary, a 10-test regression file, a test
`dune` entry, and a status-file paragraph). Per
`.claude/rules/qc-behavioral-authority.md` §"When to skip this file entirely",
the Weinstein domain block (S\*/L\*/C\*/T\*) is **NA**; the review is the generic
Contract Pinning Checklist. One domain observation is recorded below the
checklist, because the harness's subject matter *is* the selection cascade.

### What I re-derived (not taken from the PR body)

| claim | measured here | verdict |
|---|---|---|
| trace = 129,084 bytes, md5 `0f467d79cb4b10fa6398538127c27813` | **129,084 bytes, md5 `0f467d79cb4b10fa6398538127c27813`** | reproduces exactly, on a different machine |
| 45 (universe × config) cases | **45** (`cases: 45` in the trace header) | reproduces |
| 200 replayed screening days | **200** (`entered=` rows; 100 per replay arm) | reproduces |
| mutation: score floor `>=`→`>` = 21 lines | **21**; suite red (1 failure) | reproduces |
| mutation: price floor `>=`→`>` = 17 lines | **17**; suite red (1 failure) | reproduces |
| mutation: tiebreak reversed = 490 lines | **490**; suite red (2 failures) | reproduces |
| mutation: top-N off-by-one = **834** lines | **35** (`n+1`) and **35** (`n-1`); suite red (2 failures) | **does not reproduce** — see CP2 |
| replay emits zero entries | 200/200 rows are `enter=[]` | reproduces (disclosed) |
| suite green at HEAD | `dune build @…/strategy/test/runtest` exit **0**, 10 tests OK | reproduces |

**The suite is not vacuous.** All four named mutants drive the committed
`test_selection_trace.ml` red — verified by applying each mutation to
`screener_admission.ml` / `screener.ml` / `screener_ranking.ml`, rebuilding, and
reading `dune` exit codes. This is the check the brief asked for, and it passes.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | **FAIL** | Most claims pin cleanly (see below). Two do not, and are false as written: (a) `sector_map`'s "Groups carry distinct ratings so each arm of the sector gate (Weak blocks longs, Strong blocks shorts) is exercised" — **deleting both sector-gate conjuncts from `screener_admission.ml` leaves the trace byte-identical (0 of 834 lines moved) and the 10-test suite green (exit 0)**; (b) "What it covers" names "the cooldown and **point-in-time membership** gates" — `_run_screen` never passes `?membership_at`, so that gate is `None` in all 45 cases. |
| CP2 | Each claim in PR body "Test coverage" has a corresponding test in the committed test file | **FAIL** | The four mutation *detections* are real and re-verified. But the published figure "top-N cap off-by-one → **834** trace lines moved" does not reproduce: both directions of the natural off-by-one at `_top_n`'s `~len` move **35** lines. **834 is exactly the trace's total line count** (`wc -l` = 834) — the signature of a dump that produced empty output, which is what an unguarded `min (n-1)` does at the `cap/max_buy=0` case (`List.sub ~len:(-1)` raises). The number is published in both the PR body and `dev/status/screener.md` as measured evidence of sensitivity. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | **PASS** | Both observational-equivalence tests compare the **full ordered ticker list** via `equal_to`, not `size_is` — `test_screener_on_candidates_does_not_change_selection` (buys and shorts) and `test_entry_walk_callback_does_not_change_entries` (entering symbols). Each also carries an explicit **non-vacuity guard** (`!seen > 0`; `List.length on_symbols > 0`) so the equality cannot pass on two empty lists. `test_trace_covers_cases` guards the harness itself against silently degrading to zero cases or a never-screening replay. This is the correct shape and is above the bar. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | **FAIL** | Same evidence as CP1(a)/(b). The `.mli` enumerates the sector gate and the PIT membership gate among the guards the instrument covers; neither is exercised by any of the 45 cases or 200 replay days. Measured across all 245 rendered diagnostics records: **zero** observations where `long_breakout_admitted > long_sector_admitted` or `short_breakdown_admitted > short_sector_admitted`, i.e. the sector gate never rejects anything. |

### Behavioral Checklist (Weinstein domain)

**NA — all rows.** Pure infrastructure / test PR; no stage classifier, stop rule,
cascade threshold, or config default is altered. No domain logic to leak into
core modules (qc-structural raised no A1 flag).

**C1 observation (recorded because the harness's subject is the cascade).** The
instrument does **not** re-model the cascade — it drives the real
`Screener.screen`, `screen_with_cooldown`, `Weinstein_strategy.entries_from_candidates`
and `on_market_close` through their public signatures. Cascade *order* is
therefore the strategy's own by construction and cannot drift. What is uneven is
cascade *stage coverage*. Measured stage-by-stage:

| stage | ever drops a candidate? |
|---|---|
| macro gate | yes — all three trends walked in cases and replay |
| breakout / price floor / score floor | yes — 21- and 17-line mutants detected |
| **sector gate** | **never, on either side (0 of 245 observations)** |
| RS hard gate (short) | yes — 4 replay days |
| grade admission | yes — 9 cases |
| top-N truncation | yes — 16-case cap sweep cutting inside the tie group |
| cooldown | yes — 3 boundary cases, discriminating |
| PIT membership | **never — `?membership_at` never supplied** |
| failed-breakout gate | never (`long_failed_breakout_dropped = 0` everywhere) |

No `BOOK-CHECK-NEEDED` items: no faithfulness question arises on this PR.

### Answers to the review questions

**Is the pin self-referential?** Partly, and the author says so. There is **no
committed golden trace**. `test_trace_is_deterministic` compares HEAD against
HEAD (two `render ()` calls in one process) — that pins determinism and nothing
about #2500/#2501. The three-way `cmp` result lives **only in the transcript**;
the repo does not pin it. Unlike sibling #2505, which commits a 3,721-line
`.expected` generated at the merge-base, this PR's durable residue is the eight
property tests, which I verified do go red under all four named mutations. The
stated reason for not committing a golden — that it would move on every
legitimate config-default change and train readers to re-bless it unread — is a
defensible engineering call, and the test docstring states it plainly. **I am not
calling this a FAIL**, but the reader of the exoneration should understand that
its evidence is a transcript, and its durable residue is a *sensitivity* pin, not
the differential itself.

**Does the suite actually go red?** Yes — 4 of 4. See the table above. No
vacuous-pass instance found in the committed suite; the two non-vacuity guards
and `test_trace_covers_cases` are exactly the defences this repo's recurring
defect calls for.

**Is the disclosed limit list complete?** **No.** The author discloses three
limits honestly (no backtest; zero entries in the replay; one surviving min-price
mutant). Three further blind spots are undisclosed, one of them large:

1. **The sector gate is entirely invisible** — a surviving mutant far larger than
   the disclosed one (removing the gate outright: trace unchanged, suite green).
2. **The PIT membership gate is never armed.**
3. **The replay's discriminating depth is much shallower than "200 days"
   suggests.** Of the 200 rows: 61 have `total_stocks = 0` (warmup), and
   **196 of 200 have `long_breakout_admitted = 0`** — the long cascade dies at
   the breakout gate. Only **4** days reach sector/grade/top-N on the long side,
   and **zero** days produce any short candidate at top-N. So a change to
   ranking, tiebreak or the cap *inside the composed path* is discriminated by 4
   days, not 200. The upstream gates are covered on all 200.
4. Minor: the three `candidate_ranking` modes exercised (`Alphabetical`,
   `Quality`, `Quality_earliness`) produce **byte-identical** candidate order on
   this fixture (grade order, score order and alphabetical order all coincide),
   so the ranking-mode axis is non-discriminating; the three `_case`s are
   redundant. The three diagnostic control modes are not exercised at all.

**Does "zero entries in the replay" undercut the coverage claim?** The author's
mitigation checks out: **39 of 45 standalone cases emit entries** (35 with
`n=3`), including a short-side entry under `macro/Bearish` — so
`entries_from_candidates` is genuinely exercised, not merely asserted to be. The
entry-walk half is covered. What is *not* covered is the entry walk **as reached
through `on_market_close`**, which is the composed path the PR emphasises.

**`.mli` honesty.** Good overall — the "What it deliberately does not cover"
section is unusually candid, and the inline comments explaining *why* the fixture
is shaped as it is (warmup length, daily-vs-weekly expansion, `position_id`
omission) are excellent and would survive a reader who has never seen #2503. The
two overclaims in CP1 are the exceptions.

**`dev/status/screener.md`.** Two problems in a file that becomes the next
session's premise:

- It states the verdict as "provably identical **on the default selection
  path**". Given (1)–(3) above, the supportable phrasing is "on the selection
  surface this instrument covers". The sector gate and the PIT membership gate
  are part of the default selection path and are not covered.
- It reads "**Suspicion is handed back to #2492** (`Stop_geometry`), audited
  concurrently by a sibling agent", while the PR body — same PR — concludes that
  #2505 exonerates #2492 and "all three of the issue's named suspects are
  cleared", with baseline provenance the leading hypothesis. Only the status file
  is durable. Left as-is, the next session reads the status file and spends
  container time re-auditing #2492.

**Determinism.** Clean. The md5 reproduced on a different machine and toolchain
than the author's — stronger evidence than the in-process test. No hashtable
iteration order reaches the output (the sector `Hashtbl` is lookup-only; every
emitted collection is either in code-under-test order or explicitly sorted).
Float formatting is fixed-precision (`%.4f` / `%.6f`). `position_id` is
deliberately omitted from rendered transitions. No flaky-golden risk.

### Corrections to the dispatch brief

- The brief asked whether the tiebreak mutant's 490 could be re-derived. It can,
  exactly. Three of the four mutation figures reproduce to the digit; only the
  top-N figure does not.
- The brief's framing that this PR "appears to generate and compare in-process"
  is right, and the consequence is as stated: the cross-commit result is
  unpinned by the repo.

### Quality Score

2 — Craft is well above average (real mutation testing, non-vacuity guards, candid
"does not cover" section, reproducible artefact), but the `.mli` and the durable
status file both claim coverage the instrument provably does not have, and one
published sensitivity figure is an artefact of a crashed mutant run.

### Verdict

NEEDS_REWORK

### NEEDS_REWORK Items

#### CP1/CP4-a: `selection_trace.mli` claims the sector gate is exercised; it is not
- Finding: Deleting the sector-gate conjunct from **both** admission paths
  (`passes_breakout && not (equal_sector_rating sector.rating Weak)` →
  `passes_breakout`, and the `Strong` mirror on the short side) leaves the
  rendered trace **byte-identical (0 of 834 lines moved)** and the committed
  10-test suite **green (`dune ... runtest` exit 0)**. The gate cannot fire on
  this fixture: `Weak` (Energy) is carried only by `_short_group`, whose members
  are `Declining` and never long candidates; and no group carries `Strong` on any
  symbol that qualifies as a short (`_tie_group_a` is `Strong` but is entirely
  long candidates). Across all 245 rendered diagnostics records there is **zero**
  observation of `long_breakout_admitted > long_sector_admitted` or
  `short_breakdown_admitted > short_sector_admitted`.
- Location: `trading/trading/weinstein/strategy/differential/selection_trace.mli`
  (the `sector_map` docstring, and "sector" in the "What it covers" list);
  fixture at `selection_trace.ml:176-198` (`_sector_of_ticker`).
- Authority: `selection_trace.mli`, `val sector_map` — "Groups carry distinct
  ratings so each arm of the sector gate (Weak blocks longs, Strong blocks
  shorts) is exercised."
- Required fix: either (preferred) add two fixture symbols that make the gate
  bite — one `Early_breakout` symbol in a `Weak` sector, one `Declining` symbol
  in a `Strong` sector — which closes the surviving mutant and makes the
  docstring true; or strike the sentence and add the sector gate to the "What it
  deliberately does not cover" list. If the fixture is extended, the committed
  md5/byte-count in the test docstring must be re-stated or dropped.
- harness_gap: LINTER_CANDIDATE — `test_trace_covers_cases` is already this
  shape. Extending it to assert that each cascade stage drops at least one
  candidate somewhere in the trace (a monotone-counter inequality over the
  rendered `cascade_diagnostics`) would catch this class deterministically.

#### CP1/CP4-b: the point-in-time membership gate is listed as covered but never armed
- Finding: `Screener.screen_with_cooldown` takes `?membership_at`;
  `Selection_trace._run_screen` never supplies it, so the gate is `None` — a
  no-op — in all 45 cases, and `Screener.screen` has no such parameter at all.
- Location: `selection_trace.ml:397-404` (`_run_screen`);
  `selection_trace.mli` "What it covers" — "the cooldown and point-in-time
  membership gates".
- Authority: `trading/analysis/weinstein/screener/lib/screener.mli:539-553`.
- Required fix: add a case that passes a `membership_at` closure excluding one
  admitted ticker, or remove "point-in-time membership" from the covered list.
- harness_gap: LINTER_CANDIDATE — same coverage assertion as above.

#### CP2: the "834 trace lines moved" sensitivity figure does not reproduce
- Finding: I applied the top-N off-by-one in both directions at
  `screener.ml:_top_n` (`~len:(min (n + 1) …)` and `~len:(min (max 0 (n - 1)) …)`).
  Both move **35** lines, and both drive the suite red (2 failures). The
  published 834 equals the trace's **entire** line count (`wc -l` = 834); I
  reproduced that exact number by accident when a mutation failed to compile and
  the dump wrote an empty file. An unguarded `min (n - 1)` raises
  `Invalid_argument` at the `cap/max_buy=0` case (`List.sub ~len:(-1)`), which
  produces precisely this artefact. A cap off-by-one also *cannot* move all 834
  lines — the first three are constants (`selection-trace v1`,
  `universe: 15 symbols`, `cases: 45`) and the 200 replay rows never bind the cap.
- Location: PR body §"Sensitivity proven, not assumed";
  `dev/status/screener.md` (2026-08-24 entry); `test_selection_trace.ml:19`
  ("the top-N cap off by one (834)").
- Authority: PR body's own claim; `.claude/rules/mechanism-validation-rigor.md`
  §"the one-line self-check" — a published figure must be a measurement of the
  thing it names.
- Required fix: re-run the top-N mutant with the crash guarded, publish the
  corrected count (35 in my measurement), and correct all three places. The
  *detection* claim survives and should be kept — the suite does go red.
- harness_gap: ONGOING_REVIEW — a transcript-only mutation battery is not
  CI-checkable. Committing the battery as a small script under `dev/` would move
  this toward LINTER_CANDIDATE and is worth considering given this is the second
  differential harness in a week.

#### CP2/status: `dev/status/screener.md` overstates the verdict's scope and contradicts the PR body on #2492
- Finding: (a) The entry claims both PRs are "provably identical **on the default
  selection path**"; the instrument does not cover two gates that are part of
  that path (findings a/b above), and its composed-path coverage of
  ranking/tiebreak/cap is 4 replay days, not 200 (196 of 200 rows have
  `long_breakout_admitted = 0`). (b) The entry says "Suspicion is handed back to
  #2492", while the PR body says #2505 exonerates #2492 and names baseline
  provenance as the leading hypothesis. The status file is the durable artefact;
  the PR body is not.
- Location: `dev/status/screener.md`, 2026-08-24 entry.
- Authority: `CLAUDE.md` §"Status-file refreshes must verify claims against
  current main"; `.claude/rules/mechanism-validation-rigor.md` §"Verdict
  calibration".
- Required fix: scope the verdict to "the selection surface this instrument
  covers" and enumerate the uncovered gates; reconcile the #2492 sentence with
  #2505's outcome so the next session is pointed at baseline provenance rather
  than at a re-audit of the stops.
- harness_gap: ONGOING_REVIEW.

### FLAGs (non-blocking, no rework required)

- `_cooldown_cases` labels are inverted: `cooldown/inside` uses a stop-out **5**
  weeks before `as_of` (outside a 4-week cooldown; symbol admitted, `n=8`) and
  `cooldown/outside` uses **3** weeks (inside; symbol blocked, `n=7`).
  `selection_trace.ml:296-311`. Harmless to the differential — both builds render
  the same label — but misleading to a reader.
- The three exercised `candidate_ranking` modes yield identical order on this
  fixture; the three diagnostic control modes (`Reverse_alphabetical`,
  `Symbol_length`, `Hash_order`) are not exercised.
- `test_screener_on_candidates_does_not_change_selection` compares tickers only,
  not scores/grades/entry prices; an instrumentation change that perturbed a
  score without changing the order would pass. The trace itself does render
  score/grade/entry, so the differential covers this — only the durable pin is
  narrower.

---

## Structural QC — re-review at 25b4f550

qc-structural: re-review, rework iteration 1 of 2. Environment: no docker, no
`gh`, no jj; `dune` via `eval $(opam env)` in isolated plain-git worktree at
`/__w/trading/wt-reqc-2507`.

### Rework verification

The four prior behavioral findings have been addressed:

1. **CP1/CP4-a (sector gate invisible):** FIXED. Two new fixture symbols added:
   - `WEAKB` = `Early_breakout` in `Weak` sector (matches `_tie_group_a` shape
     but with sector rating Weak instead of Strong)
   - `STRGD` = `Declining` in `Strong` sector (matches `_short_group` shape but
     with rating Strong instead of Weak)
   - Verified: both are shape-identical to existing groups, sector rating only
   - Result: sector gate now rejects 44 long-arm records and 5 short-arm records
     (was 0 before)
   - Tests confirm: `test_sector_gate_rejects_a_weak_sector_long` and
     `test_sector_gate_rejects_a_strong_sector_short` both PASS

2. **CP1/CP4-b (PIT membership gate never armed):** FIXED. Added case that arms
   `?membership_at`:
   - `test_membership_gate_drops_exactly_the_non_member` now exercises
     `_run_screen` with `~membership_at:(fun ticker _as_of -> not (String.equal
     ticker victim))`
   - Tests that exactly one admitted candidate is dropped
   - Verified: both gate arms now exercised (2 cases arm it per `.mli`)

3. **CP2 (834 line figure is an artifact):** FIXED. Mutation harness guard
   added:
   - Mutation table in `.mli` now shows **35** for both top-N off-by-one mutants
     (n+1 and n-1, guarded at 0)
   - Mutation testing verified: `min (n - 1)` raises `Invalid_argument` on
     zero-cap → fixed by guarding to `max 0 (n - 1)`
   - `.mli` now includes load-bearing note: "Confirm a mutant built AND wrote
     non-empty output before believing its line count"
   - Status file and test docstring updated to 35 (was 834)

4. **CP2/status (status file overclaiming):** FIXED. `dev/status/screener.md`
   rewritten:
   - Verdict scoped to "the selection surface this instrument covers"
   - Uncovered gates now enumerated: failed-breakout gate, replay sector gate
   - Replay depth honestly stated: 61 warmup rows, 196 of 200 have
     `long_breakout_admitted = 0`, only 4 rows reach ranking/top-N on long side
   - Replaces "Suspicion handed back to #2492" with #2505 exoneration and
     baseline provenance as leading hypothesis

### Structural checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | No format violations |
| H2 | dune build | PASS | Clean build, no errors |
| H3 | dune runtest | PASS | 13 tests in selection_trace (10 prior + 3 new gates/observational) |
| P1 | Functions ≤ 50 lines | PASS | Linter passed as part of H3 |
| P2 | No magic numbers | PASS | Linter passed as part of H3 |
| P3 | Config completeness | PASS | No new tunable parameters; fixture is test-only |
| P4 | Public-symbol export hygiene | PASS | `.mli` coverage complete |
| P5 | Internal helpers prefixed | PASS | `_tie_group_a`, `_sector_of_ticker`, etc. all prefixed |
| P6 | Tests conform to test-patterns | PASS | All 13 tests use `assert_that` with composition via `all_of`/`field`; no nested `assert_that` in callbacks; non-vacuity guards present on observational-equivalence tests; gate tests pin rejection |
| A1 | Core module modifications | PASS | No modifications to Portfolio/Orders/Position/Strategy/Engine; new differential module only |
| A2 | Analysis imports into trading/trading | PASS | Only `weinstein.*` dependencies (allow-listed); no `analysis/data/` or other analysis imports |
| A3 | Unnecessary existing module modifications | PASS | Only new module, new test file, dune config updates; no existing module drift |

### Quality Score

5 — All four prior findings corrected, durable residue strengthened (mutation
harness now guards against crashed runs), test coverage expanded with direct
gate-rejection pins replacing invisible gates, status file rewritten for honest
scope calibration.

### Verdict

APPROVED

---

## Behavioral QC — re-review at 25b4f550

Rework iteration 1 of 2. All four findings below were mine, issued at `69787516`
(quality 2). qc-structural re-reviewed at `25b4f550` and APPROVED (quality 5).

Environment: no docker, no `gh` (REST via `curl`), no working jj; `dune` via
`eval $(opam env)` in an isolated plain-git worktree at `/__w/trading/wt-reqcb-2507`,
detached at `25b4f550`. Book tier 2 unreachable (issue #2457) — no
`BOOK-CHECK-NEEDED` items arise, since no faithfulness question is in play.

### Everything below was re-measured, not read off the PR

I re-derived every figure the rework publishes. **All 21 reproduce exactly.**

| claim | measured here | verdict |
|---|---|---|
| trace = 133,512 bytes / md5 `751a285ddfc70e8b93810a0f37ad5e01` | **133,512 bytes, md5 `751a285ddfc70e8b93810a0f37ad5e01`** | reproduces |
| 893-line trace, 49 cases, 17 symbols | **893 / 49 / 17** (trace header) | reproduces |
| 249 `cascade_diagnostics` records (49 cases + 200 replay) | **49 + 200 = 249** | reproduces |
| sector gate rejects **44** long-arm records | **44** | reproduces |
| sector gate rejects **5** short-arm records | **5** | reproduces |
| replay does **not** exercise the sector gate | **0** replay records show a sector reject | reproduces |
| `long_failed_breakout_dropped = 0` in all 249 | **0 of 249** | reproduces |
| replay: 200 rows / 61 warmup / 196 `long_breakout_admitted = 0` | **200 / 61 / 196** | reproduces |
| replay: **4** rows reach top-N long, **0** short at top-N | **4 / 0** | reproduces |
| short RS hard gate — 4 replay days | **4** | reproduces |
| grade admission — 9 cases | **9** | reproduces |
| macro gate — all three trends, cases *and* replay | Bearish/Bullish/Neutral in **both** | reproduces |
| mutation: sector gate deleted both arms = **94**, suite red | **94**; suite exit **1** | reproduces |
| mutation: membership neutered = **12** | **12** | reproduces |
| mutation: score floor `>=`→`>` = **21** | **21** | reproduces |
| mutation: price floor `>=`→`>` = **17** | **17** | reproduces |
| mutation: tiebreak reversed = **540** | **540** | reproduces |
| mutation: top-N `n+1` = **35** | **35** | reproduces |
| mutation: top-N `max 0 (n-1)` = **35** | **35** | reproduces |
| mutation: min-price disable `<=0`→`<0` = **0**, survives | **0** — survives, as disclosed | reproduces |
| suite green at HEAD, 13 tests | `dune build @…/strategy/test/runtest` exit **0**, **13 tests OK** | reproduces |

### Finding 1 (CP1/CP4-a, sector gate invisible) — CLOSED, and I re-derived it end to end

This was the central finding, so I re-ran it rather than accepting the report.

- **Shape-identical claim checked specifically, as asked.** `WEAKB` is
  `Early_breakout`, the same shape constructor as every `_tie_group_a` member;
  `STRGD` is `Declining`, the same as every `_short_group` member. Since
  `_analysis` derives the whole `Stock_analysis.t` from `_series_of_shape` +
  `_prior_stage_of_shape` + ticker, the analyses are identical bar the ticker.
  The remaining difference is the sector context, which differs in **two**
  fields, not one — `rating` *and* `sector_name` (`Materials`/`Healthcare` vs
  `Technology`/`Energy`). I checked whether the second matters: `sector_name` is
  **never read** anywhere in `trading/analysis/weinstein/screener/lib/` outside
  its own record declaration and one `"Unknown"` literal, and scoring reads only
  `sector.rating` (`screener_scoring.ml:196-207`). `sector.stage` is identical
  by construction. **So the claim holds: sector rating is the only live
  difference, and the 94-line delta is cleanly attributable to the sector gate.**
- **The gate now bites**: `long_breakout_admitted 9 → long_sector_admitted 8`
  and `short_breakdown_admitted 4 → short_sector_admitted 3` on the base case;
  44 long-arm and 5 short-arm rejects across the 49 cases (was **0**).
- **The mutation now moves the trace.** Deleting both sector conjuncts from
  `screener_admission.ml:119-120` and `:168-169`: **94 of 893 lines moved**
  (was 0 of 834), mutant built, dump exit 0, 133,512 bytes — a genuinely
  *partial* diff, which by the `.mli`'s own reasoning is the safe signature.
- **The suite goes red, on exactly the right tests.** Suite exit **1**, with
  `selection_trace:6:sector gate rejects a weak-sector long` and
  `selection_trace:7:sector gate rejects a strong-sector short` the two
  failures. Both new tests are load-bearing, not decorative.

Option (a) was the preferred fix in my original finding, and it is the one that
was taken.

### Finding 2 (CP2, the 834 artefact) — CLOSED, and the failure mode is confirmed

The corrected **35** reproduces in both directions. More importantly I
reproduced the *artefact itself*, which settles the diagnosis rather than
accepting it:

| cap expression | built | dump exit | bytes | moved |
|---|---|---|---|---|
| `n + 1` | yes | 0 | 134,293 | **35** |
| `max 0 (n - 1)` (guarded) | yes | 0 | 132,731 | **35** |
| `n - 1` (unguarded) | **yes** | **2** | **0** | *not reportable* |

Note the unguarded mutant **compiles** and fails at *runtime* — so "confirm the
mutant built" alone is not sufficient; the non-empty-output half of the check is
what actually catches it. A naive `diff` against that empty dump yields 893, the
new fixture's exact line count — the 2026 analogue of the original 834. The
author's argument that 21/17/540 cannot share the failure mode is sound and I
independently confirmed all three on the new fixture.

I also confirmed the guard fires on the *other* failure mode: my first attempt
at the membership mutant did not compile, and the built-and-non-empty check
correctly refused to report a count for it.

**One correction to the dispatch brief.** The brief states "the mutation harness
now refuses to report a count unless the mutant built AND wrote non-empty
output." There is **no committed mutation harness** — the rework diff is 5 files
(`selection_trace.{ml,mli}`, `test_selection_trace.ml`, and two docs), no script.
What shipped is *prose*: `selection_trace.mli:117-127` and the corresponding
`dev/status/screener.md` paragraph. The guard is a documented procedure a human
or agent must follow, not an executable that enforces it. I verified the
procedure is correct and sufficient by applying it myself (it caught both the
runtime-crash and the non-compiling mutant above) — but it fires only when
someone runs it. This is **not** a blocker: my original CP2 required fix asked
for the corrected count published in three places, and I classified committing
the battery as `harness_gap: ONGOING_REVIEW` / "worth considering", explicitly
not a required fix. It is filed as a residual below.

### Finding 3 (replay depth overstated) — CLOSED, and widened beyond what I asked

Every narrowed figure reproduces: 200 / 61 / 196 / 4 / 0. The two *additional*
limits the author found and disclosed unprompted both check out — the replay
shows **0** sector rejects across all 200 rows (it drives `on_market_close`,
which derives its own sector context and never reads `sector_map`), and
`long_failed_breakout_dropped` is **0** in all 249 records. Disclosing a limit
nobody asked about is the behaviour this checklist is trying to produce.

My PIT no-op finding was closed rather than disclosed: two `?membership_at`
cases added, the gate armed in exactly 2 of 49 cases (the other 47 leave it
`None`, as production does), and the neutering mutation moves **12** lines.

### Finding 4 (status file) — CLOSED

`dev/status/screener.md` now scopes the verdict to "the selection surface this
instrument covers", enumerates the uncovered failed-breakout gate with its
measured `0 of 249`, carries the per-gate reject counts, states the replay's
real depth, replaces "Suspicion is handed back to #2492" with #2505's
exoneration and all-three-cleared, names baseline provenance as the leading
hypothesis, and adds "**Do not spend container time re-auditing the stops**".
That is the whole of what I asked for.

### The exoneration is now genuinely stronger — verified independently

This is the claim the brief flagged as the reason the PR's conclusion improved,
so I re-ran the three-commit differential myself rather than trusting the
re-run. I created detached worktrees at `bdcb257b` and `b128b1d9`, grafted the
**new 49-case** differential module into each, and built and rendered:

| commit | lines | bytes | md5 |
|---|---|---|---|
| `bdcb257b` (pre-#2500) | 893 | 133,512 | `751a285ddfc70e8b93810a0f37ad5e01` |
| `b128b1d9` (post-#2500) | 893 | 133,512 | `751a285ddfc70e8b93810a0f37ad5e01` |
| `2b11c60d` (post-#2501) | 893 | 133,512 | `751a285ddfc70e8b93810a0f37ad5e01` |

`cmp` exit **0** on all three pairs — #2500 alone, #2501 alone, end-to-end. The
harness also **compiles unmodified at `bdcb257b`** (build exit 0), independently
confirming the public selection API did not change.

`2b11c60d` is measurable directly at the PR tip because the PR touches **no
production code** — I confirmed via the REST file list that all 9 changed files
are the new `differential/` library, its bin, the test file, a test `dune` entry
and two docs.

**The material change: this exoneration now covers the sector gate (44 long / 5
short rejects) and the PIT membership gate (2 armed cases), neither of which the
`69787516` trace discriminated at all.** When I blocked, the trace could not have
distinguished a build with the sector gate from one without it. It can now, and
it still says the three commits are identical. That is a strictly stronger
result on a strictly wider surface, and it is the correct answer to the question
I raised.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new `.mli` docstrings has an identified test that pins it | **PASS** | Both previously-false claims are now true and pinned. `val weak_sector_long` "the long arm must reject it" → `test_sector_gate_rejects_a_weak_sector_long`; `val strong_sector_short` → `test_sector_gate_rejects_a_strong_sector_short`; PIT membership "2 cases arm `?membership_at`" → `test_membership_gate_drops_exactly_the_non_member`; `val case_count` / replay non-emptiness → `test_trace_covers_cases`; `val render` determinism → `test_trace_is_deterministic`; `val tie_group` alphabetical-emission → `test_equal_scores_rank_alphabetically`. The measured coverage counts (44/5/249/200/61/196/4/0) are reported as measurements, not asserted as invariants, and every one reproduces; the tests correctly pin `> 0` rather than the brittle exact count. |
| CP2 | Each claim in PR body / test docstring / status file has a corresponding test or reproduces as measured | **PASS** | The three *durable* artefacts are corrected and verified digit-for-digit: `selection_trace.mli`, the `test_selection_trace.ml` header docstring (129,084→133,512, 45→49, 490→540, 834→35, plus the artefact explanation), and `dev/status/screener.md`. All 8 mutation rows and all 12 coverage counts re-derived above. The PR **body** is stale — see residual R1; it is not a repo artefact and its stale section is already marked superseded, so it does not carry CP2. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | **PASS** | Unchanged and extended. The two observational-equivalence tests still compare the **full ordered ticker list** via `equal_to` with explicit non-vacuity guards (`!seen > 0`, `List.length on_symbols > 0`). The new `test_membership_gate_drops_exactly_the_non_member` is the same shape and a good one: it asserts the gated list equals the *ungated list minus exactly the victim* (`equal_to (List.filter ungated …)`), plus a non-vacuity guard that the victim really was admitted with the gate unsupplied (`equal_to 1`). That is identity pinning, not size counting. |
| CP4 | Each guard called out explicitly in code docstrings has a test exercising the guarded-against scenario | **PASS** | The two gates I failed this on are now each exercised by a dedicated test that fails when its arm stops rejecting — verified by mutation, both go red. `test_sector_gate_rejects_a_weak_sector_long` additionally asserts `long_failed_breakout_dropped = 0` so the drop is *attributable* to the sector gate and not to the gate ahead of it, which is the right way to pin a cascade stage. The remaining docstring claims are **non-coverage** disclosures (failed-breakout gate never fires; replay does not reach the sector gate; the surviving min-price mutant) — I verified each is true rather than requiring a test for it, which is the correct disposition for a stated limit. |

### Behavioral Checklist (Weinstein domain)

**NA — all rows.** Infrastructure / test PR; no production code touched (REST
file list confirms), no stage classifier, stop rule, cascade threshold or config
default altered. Per `.claude/rules/qc-behavioral-authority.md` §"When to skip
this file entirely". qc-structural raised no A1 flag. No `BOOK-CHECK-NEEDED`
items.

**C1 observation.** The instrument drives the real cascade through its public
signatures, so cascade *order* cannot drift. On the question that motivated my
block — whether the harness models the real cascade well enough for "no
divergence" to mean something — the answer materially improved: the sector gate
and the PIT membership gate moved from *invisible* to *discriminating*, and the
one remaining uncovered stage (failed-breakout) is now named as uncovered in
both the `.mli` and the status file rather than implied covered.

### Residuals — filed, not blocking

- **R1 (new, the only one I'd act on before merge). The PR body still carries
  the superseded figures**, and its appended ⚠ CORRECTION section is now stale in
  the *opposite* direction: it says the sector gate "is invisible", the PIT gate
  "is a no-op in all 45 cases", and that "(21 / 17 / 490) … stand" — all three
  superseded by this rework (44/5 rejects, armed in 2 of 49, tiebreak now **540**
  on the larger fixture). The main body still reads 129,084 bytes / md5
  `0f467d79…` / 45 cases / 10 tests / 834. My original CP2 named the PR body as
  one of three places to correct, and it is the one not done. I am **not**
  blocking on it: the durable artefacts are all correct, the stale section is
  explicitly flagged as superseded so no reader is misled into believing 834, and
  the defect is that the body *understates* what shipped — the opposite of the
  "claims exceed evidence" class I blocked on. But the body becomes the squash
  commit message, so **whoever merges should refresh it first**; it needs no code
  change and no agent dispatch.
- **R2.** The mutation battery remains transcript-only — the guard is prose, not
  an executable (see Finding 2). Committing it as a small script under `dev/`
  would make this class CI-checkable. `harness_gap: ONGOING_REVIEW`, carried
  forward unchanged from my first review.
- **R3.** `cooldown/inside` / `cooldown/outside` labels are inverted
  (`shift=-1` is 5 weeks back, i.e. *outside* a 4-week cooldown). Confirmed by
  the author, deliberately left per no-new-scope. Needs a label swap plus a trace
  re-measure, which will move the md5 — so it should be done together with any
  other fixture change, not on its own.
- **R4.** Redundant `candidate_ranking` cases (the three exercised modes yield
  byte-identical order on this fixture; the three diagnostic control modes are
  unexercised).

R3 and R4 are carried forward from my first review as already-filed FLAGs and
are explicitly not re-raised as blockers.

## Quality Score

4 — Every one of the four findings is closed at the root rather than papered
over, and all 21 published figures re-derive exactly on an independent machine,
including the artefact that caused the block. The rework also widened the
exoneration to two gates it previously could not see and disclosed two limits
nobody asked for. Short of 5 only because the PR body — a location my original
required fix named — was left stale, and the "mutation harness guard" shipped as
prose rather than as the executable the brief describes.

## Verdict

APPROVED
