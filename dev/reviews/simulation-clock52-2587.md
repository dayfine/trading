Reviewed SHA: 5044eb5f1c451e4636b63766284881d20d117d88

## Structural QC — PR #2587

**Reviewed SHA:** `5044eb5f1c451e4636b63766284881d20d117d88`

_Posted by the GHA orchestrator on behalf of `qc-structural` (the agent has no `gh`/API access in this runtime). The checklist and verdict are the agent's. The **Orchestrator correction** at the end is mine, not the reviewer's — flagged so provenance is not misread._

### Hard gates

| Gate | Result |
|---|---|
| H1 `dune build @fmt` | **PASS** |
| H2 `dune build` | **PASS** |
| H3 `dune runtest` | **PASS** |

### Structural checklist

| # | Check | Status | Notes |
|---|---|---|---|
| P1 | Functions ≤ 50 lines | PASS | via H3 |
| P2 | No magic numbers | PASS | via H3 |
| P3 | Config completeness | PASS | `entry_order_max_rest_weeks` is a config field with `[@sexp.default 52]` and appears in the `default_config` literal |
| P4 | Public-symbol export hygiene | PASS | `mli_coverage` via H3 |
| P5 | Internal helper naming | PASS | |
| P6 | Test patterns | PASS | `assert_that` + matchers; no `List.exists … equal_to (true\|false)`, no bare `let _ = … .run`, no unasserted match arms |
| A1 | Core module modification | NA | Portfolio/Orders/Position/Engine/Strategy untouched at the API level |
| A2 | tier boundary | PASS | Only Tier-2 Weinstein strategy config touched; no new `analysis/` import into a core module |
| A3 | No unnecessary modifications | PASS | File list from the PR diff, not a git-ancestry walk |

### Defaults consistency — all three declaration sites agree

- `weinstein_strategy_config.ml` type: `entry_order_max_rest_weeks : int; [@sexp.default 52]`
- `weinstein_strategy_config.ml` `default_config` literal: `= 52;`
- `weinstein_strategy_config.mli`: `[@sexp.default 52]`

`test_strategy_mli_redeclares_clock_default_consistently` pins this and passes. Worth noting that the **first** push of this branch updated one pin and missed a sibling (`test_strategy_config_parses_with_lifecycle_fields_absent`), which is what turned `build-and-test` red; both are now consistent.

### R3 (`experiment-flag-discipline.md`) — verified, not taken from the PR body

`dev/experiments/_ledger/2026-08-27-entry-rest-weeks-surface.sexp` exists in the tree and contains `(verdict Accept)`. The `.mli` docstring cites the ledger entry and the promotion date, as R3 requires.

### `goldens-affected` (red) — expected, not a code defect

The `AFFECTS-ALL` shape from `config-default-blast-radius.md`: a default **value** changed and **zero** of 15 goldens override the knob, so all 15 inherit it. This clears only via a human-reviewed paired table plus the `paired-run-done` label. It is the gate the −40.91pp episode (#2384 → #2397) installed, working as designed.

### Review of the orchestrator's own commit `5044eb5f`

Checked adversarially at my request, since I wrote it and had a throughput incentive to wave it through:

- **Ancestry verified independently**: branch point `cbac374f` is the direct parent of `b1f10412` (#2584), so this branch never contained that PR's odoc fixes.
- **Revert confirmed**: #2584 escaped `\{13, 26, 52\}` and `\{0, 4, 8\}`; this branch re-issued them unescaped.
- **Fix is byte-identical** to #2584's version of the hunk.
- **Doc-comment only**; no behaviour impact.

## Quality Score

**5** — All gates pass, defaults consistent across three sites, ledger ACCEPT verified in the tree, and the dispatcher-side odoc fix is correct and orthogonal to the domain change.

## Verdict

**APPROVED** — for *structural soundness of the code*. This is explicitly **not** a merge authorization; see below.

---

### ⚠ Orchestrator correction to the above (not the reviewer's finding)

The reviewer credited **B1/B2** of `config-default-blast-radius.md` as satisfied by the presence of `dev/experiments/clock-surface-2026-08-27/run-goldens-52.sh`, describing the paired comparison as *"implicit in the test names"*. **I do not think that is right, and I am recording the disagreement rather than letting it stand.**

- **B1** asks for a **paired table pasted in the PR body** — base arm and PR arm, side by side. A script that *would* produce one is not the artifact the rule names. The PR body currently says the paired sweep is "running dispatcher-side" and that the table "lands on this branch before merge", i.e. B1 is **pending**, not met.
- **B2** exists precisely to reject single-arm evidence. "Implicit" pairing is the shape it was written to catch.
- **B3** is red with no `paired-run-done` label.

None of this is a defect in the *code*, and none of it asks the author to do anything they have not already said they will do. But B1/B2/B3 are the three conditions that let a **−38.42pp** regression merge on fully green CI (#2384, issue #2393), so I would rather over-record them than let a review say they are met when the table is not yet there.

Also, a figure worth correcting before the paired run is sized off it: the PR body says **13 strategy cells**. The tree says **12** — `goldens-affected` lists 15 inheriting goldens and exactly three carry a `Bah_benchmark` stanza (`sp500-2011-2026-bah-brk-b`, `sp500-2019-2023-bah-brk-b`, `sp500-2019-2023-bah-spy`); the other 12 have no strategy stanza and default to Weinstein.

**This PR will not be auto-merged by the orchestrator.** It is handed back for the paired-golden table and the `paired-run-done` label.
## Behavioral QC — PR #2587 (`entry_order_max_rest_weeks` 0 → 52, #2405)

**Reviewed SHA:** `5044eb5f1c451e4636b63766284881d20d117d88`

_Posted by the GHA orchestrator on behalf of `qc-behavioral` (no `gh`/API in this runtime). Verdict and findings are the agent's._

Environment: GHA-class runner, no `docker`, book unreachable (`book-as-authority.md` branch 2). `dune build` **0**; `dune build @fmt` **0** with **zero** `Invalid documentation comment` warnings; `dune runtest --force trading/backtest/test/ trading/weinstein/strategy/test/` **0**, 0 `^FAIL:`. `PROJECT_ROOT` verified via `RUN_IN_ENV_PRINT_ROOT=1` as the reviewer's own worktree, so H-RUNENV-WORKTREE-BLIND does not apply. PR body unreadable without `gh`; body claims assessed against the equivalent claims committed in the diff.

### Contract Pinning Checklist

| # | Check | Status | Notes |
|---|---|---|---|
| CP1 | Changed `.mli` docstring claims pinned | PASS | default pair `false`/`52` → `test_default_entry_ticket_lifecycle`; `.mli` re-declaration → `test_strategy_mli_redeclares_clock_default_consistently`; omitting sexp → `test_strategy_config_parses_with_lifecycle_fields_absent`; boundary → `test_clock_backstop_fires_one_week_after_ttl`; end-to-end arming → `test_config_arms_clock_backstop_end_to_end`; axes → `test_entry_ticket_lifecycle_axes_resolve_via_overlay_validator`. The two tests that had to be updated are the drift guards doing their job — the one missed in the first push turning CI red is evidence **for** the pinning, not against it |
| CP2 | PR-body claims have committed tests | PASS | No advertised-but-absent test. The one body claim cross-checkable from the diff — the affected-cell count — is wrong; scored under B1, not here |
| CP3 | Identity tests pin identity, not size | PASS | The round-trip test asserts field-level values via `field` + `all_of`, not a count |
| CP4 | Guards named in docstrings have a test | PASS | Both-off no-op → `test_ttl_zero_never_cancels`; armed path and boundary covered. *Note (not a FAIL):* the newly asserted "the **default** path now builds the predicate" is pinned only compositionally; no test runs a default-config tick and observes a cancel. A one-line default-config case would close it |

### Weinstein domain checklist

**S5 PASS** — the clock is strictly *subtractive* on the entry side: it cancels an **unfilled** resting ticket, and a cancelled symbol must re-qualify through the full cascade at a fresh `E`. No path introduces a fill outside Stage 2. **S6 PASS** — same reasoning; the change can only remove a pending entry. **C1 PASS** — `_ticket_cancellations` runs before the entry walk and ahead of `Entry_freeze.apply`; no cascade gate reordered or bypassed. **T4 PASS** — both updated tests assert exact values, not absence of error. **A1, S1–S4, L1–L4, C2, C3, T1–T3 NA** — stage classifier, stops and macro/sector gating all untouched.

### Promotion-gate rows

| # | Check | Status | Notes |
|---|---|---|---|
| W1 | Spine intact | PASS | None of spine items 1–7 touched |
| W2 | Adaptation is a dial, config-expressed, authority cited | PASS | `weinstein-book-reference.md` §4.7 quotes *"a standing order with the specialist until you either cancel the orders or they are actually executed"* — cancel authority granted, **no duration named**. §4.7's load-bearing GTC property is *"the order rests for WEEKS"*; a 52-week floor is ~17× that horizon, so the book-supported property survives |
| R2 | Searchable as an axis | PASS | Real config field; `{13,26,52}` pinned resolving through the real `Overlay_validator` |
| R3 | Cites the ledger ACCEPT | PASS | Ledger entry exists in-tree with `(verdict Accept)`, cited in both `.mli`s |
| U1/U3/U4 | Broad measurement universe, correct PIT vintage | PASS | Verified **from the specs**: cell A `top-3000-2000` 2000→2026; B `top-3000-2019` 2019→2023; C `top-3000-2000` 2000→2012, all `universe_size 3000`. No index universe in any measurement cell. The sp500 goldens in the blast radius are regression pins, which `universe-discipline.md` explicitly permits |
| G1 | Ledger decision rule supports the value 52 | PASS | **Re-derived digit-for-digit from the committed `results/*-actual.sexp`, not read off the ledger prose.** 52 is top on return **and** sharpe **and** maxDD in all three cells: A 496.20/0.515/25.65 vs null 312.74/0.430/38.78; B 25.31/0.345/27.00 vs 18.02/0.271/34.12; C 97.99/0.448/25.65 vs 76.71/0.382/27.10. Never dominated. 156 is worse than null at A and digit-identical to null at B, so the docstring's supersession of the old 156 recommendation is correct |
| **G2** | **Promotion evidence complete per `promotion-confirmation.md` + the ledger's own preconditions** | **FAIL** | see below |
| **B1** | **Paired table present in the PR body** | **FAIL** | see below |
| **B2** | **Table is paired, not single-arm** | **FAIL** | see below |
| **B3** | `goldens-affected` green (plain or acknowledged) | **FAIL** | Re-ran `goldens_affected_check.sh cbac374f HEAD` → exit 1, `AFFECTS-ALL`, 15 inherit / 0 override. Red by design; no `paired-run-done` is possible until the table exists |

**BOOK-CHECK-NEEDED:** *The book grants cancel authority for a GTC buy-stop but names no criterion. Is a **blind time-based** cancel a faithful stand-in for the discretionary cancel Weinstein describes, given the **condition-based** half — the weekly re-screen, arguably the closer reading of "you cancel the orders" — was measured at −137pp and REJECTED (ledger `2026-08-18-entry-ticket-rescreen`)? Does the book anywhere tie pulling a resting buy-stop to the base going stale rather than to elapsed time?* Tier 1 is silent; §7's "weekend homework → enter GTC orders" hints tickets lapse and are re-entered weekly, which would make an unbounded rest a simulation artifact, but the reference does not say so. Queued for a local session.

## NEEDS_REWORK items

### B1 — no paired golden table; a script that *would* produce one is not the measurement

The PR adds `dev/experiments/clock-surface-2026-08-27/run-goldens-52.sh` and **zero** golden results. The script cannot have run on any shared runner: it hardcodes `REPO=/Users/difan/Projects/trading-1` and `docker exec trading-1-dev`, and pins `PIN=5dc61da07`, which is not this tip.

**I adjudicated against qc-structural here and agree with the dispatcher.** B1 requires "the paired table … in the PR body"; step 2 is "run each matching golden BY HAND, PAIRED"; step 3 is "paste the paired table in the PR body **before requesting merge**". A plan to measure is not a measurement, and "implicit in the test names" is the exact single-arm shape B2 rejects. The rule exists because #2384 merged fully green on an unmeasured default flip.

One point **in the script's favour**, on the record because it is correct: its header argument that "the current pinned expectations ARE the old arm, so one run per cell + compare-to-pin = the paired table" is sound methodology and halves the required runtime. It simply has not been executed.

**Count correction:** the blast radius is **12 strategy cells, not 13**. 15 goldens inherit; exactly 3 carry `Bah_benchmark`. The script's own loops enumerate **12** while its header comment says **13** — it contradicts itself. Also unaccounted: `dev/weekly-picks/live-config-overrides.sexp` does not pin this knob, so the **live weekly-picks pipeline inherits 52** as well; the body should say so even if the conclusion is "no material effect".

**Required fix:** run the 12 cells at the flipped default, paste the paired (pin-vs-52) table, correct 13 → 12, add the live-config statement, then have a maintainer apply `paired-run-done`.

### B2 — the comparison is single-arm; the base arm has no committed numbers

B2 rejects a table with only the new value's row. This is a step weaker: **neither** row exists. The base arm is recoverable from the current pins in principle, but no pin-vs-52 pair is written down for any of the 12 cells, so nothing shows the direction or size of the move on the surface where the last flip lost 38–41pp. `sp500-2019-2023-armed-stoplimit` — the exact golden that produced the −40.91pp reading on 2026-08-19 — is first in the script's queue and has no result.

### G2 — the flip PR does not supply the composition-independent cell the ledger deferred *to it*

The ledger's own `notes` say, verbatim: *"a composition-independent cell (different PIT vintage/breadth) **remains open for the flip PR**."* The README repeats it. **This is the flip PR**, and its entire `dev/` contribution is one unexecuted script. The precondition is self-declared and unmet. Three supporting observations, descending weight:

1. **The grid's universe axis is confounded with its period axis.** Cell B is the only different PIT vintage *and* the only different period among the non-A cells — nothing varies composition while holding the window fixed. `promotion-confirmation.md` asks for universe diversity as an axis **distinct** from period diversity. The ledger names this itself: only (B,C) is mutually disjoint, and C is a strict time-prefix of A on the same vintage — the identical 15-digit A-52/C-52 maxDD is that fingerprint.
2. **A path-dominated mechanism measured at one path salt.** The ledger's own dissection calls the effect *"path-dominated divergence — at 26y >50% of the book differs between arms"*, driven by *"the downstream reshuffle from freed cash/slots"*. Measured at `TRADING_PATH_SEED_SALT=0` only, with the sole cited noise floor a **26-year, old-basis 132.5pp** figure. **No null spread was measured for cell B or cell C at all.** Cell B's margin is +7.3pp on a 187-trade 5-year book — the smallest, noisiest cell, in the same regime shape where clock=26 previously measured −40.91pp with complete separation across three salts. The very docstring this PR edits states the lesson: *"Every base needs its own null; never import one base's noise floor to judge another's gap."*
3. **The pre-registered confirmatory test did not fire as written.** The README records it plainly: rule item 2 required the removed-fills cohort to be net-negative; in cell A at w26 it came out **net-positive (+$1.09M)**. The verdict was rebased onto portfolio-level outcomes plus the previously committed bucket table. Declared, not concealed — but the mechanism's causal story is not the one pre-registered, which is exactly when `mechanism-validation-rigor.md` checks 2 and 7 become load-bearing.

**To be precise about what is *not* being said:** `promotion-confirmation.md`'s decision rule — promotable value beats baseline in a strong majority of cells, never badly dominated — **is satisfied** on the committed numbers, independently re-derived. ACCEPT(mechanism) and "robust value = 52" are well-earned. The FAIL is that the promotion **executes** while a precondition the ledger wrote for this specific PR is still open, on the knob whose last unmeasured flip cost −40.91pp nine days ago.

**Required fix — either:** (a) add the deferred cell (a different broad composition vintage or breadth tier, e.g. `top-1000`, over a window already in the grid, so composition moves while period is held) **and** re-run cell B at ≥3 path salts so its +7.3pp margin has a measured null; **or** (b) if the decision is to promote on the evidence in hand, say so explicitly in the body as a user-gated exception, name the three deviations as accepted, and **amend the ledger** — it currently reads "DEFAULT FLIP NOT EXECUTED … USER DECISION REQUIRED", which this PR makes stale either way.

### Adversarial review of `5044eb5f` (the orchestrator's own commit) — verified, keep it

- **Ancestry exact.** `b1f10412`'s parent is `cbac374f`, this branch's merge-base. The branch never contained #2584's fix; it did not "revert" it in the git sense, but carrying the pre-#2584 docstring text forward has the same net effect on `main` after merge. The commit message's phrasing is accurate.
- **Byte-identical** to #2584's hunk; 3 lines, entirely inside a `(** … *)` block on a test file. Cannot alter behaviour; `dune runtest --force` green on both affected directories.
- **The stated failure mode reproduces:** `@fmt` now exits 0 with **zero** doc-comment warnings, and there is no odoc check in `trading/devtools/checks/` — so a re-broken `{13, 26, 52}` would indeed merge green, matching the #2588 class.
- **Did it belong here?** Strictly, scope creep. Keep it anyway: 3 comment lines on a file this PR already rewrites, splitting it would leave `main` silently reverted meanwhile, and the message states scope and reason without overclaiming. No throughput-motivated softening detected.

## Quality Score

**2** — The experimental record is exceptionally honest (the README declares its own pre-registration failure and every gate deviation) and every number re-derived from the committed artifacts reconciled exactly. But the promotion ships without the paired-golden table the blast-radius rule hard-requires, without the composition-independent cell the ledger deferred *to this PR*, and with a miscounted blast radius — below the bar for a default flip on the one knob that caused a −40.91pp regression nine days ago.

## Verdict

**NEEDS_REWORK**
