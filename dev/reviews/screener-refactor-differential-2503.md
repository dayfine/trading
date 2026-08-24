Reviewed SHA: 69787516

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
