Reviewed SHA: 4d079a5424a9ab8d3508dbdcd96118c6b6504e3c

## Structural QC — feat(strategy): promote entry_order_max_rest_weeks 0 → 26

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | Exit code 0 |
| H2 | dune build | PASS | Exit code 0 |
| H3 | dune runtest | PASS | All tests passed (42 tests in 5.03s); linters all OK (fn_length, nesting, file_length, mli_coverage, formatting) |
| P1 | Functions ≤ 50 lines (linter) | PASS | H3 passes; fn_length_linter passed as part of test suite |
| P2 | No magic numbers (linter) | PASS | H3 passes; linter_magic_numbers.sh passed as part of test suite |
| P3 | Config completeness | PASS | Tunable value (26) is a config field `[@sexp.default 26]` in `weinstein_strategy_config.ml` — not a hardcoded literal |
| P4 | Public-symbol export hygiene (linter) | PASS | H3 passes; mli-coverage linter passed as part of test suite |
| P5 | Internal helpers prefixed per convention | PASS | No violations |
| P6 | Tests conform to test-patterns rules | PASS | Changed test file opens `Matchers` and uses `assert_that` with matchers; no violations of the three sub-rules |
| A1 | Core module modifications | FLAG | Modifies `weinstein_strategy_config.ml/.mli` (strategy-config default promotion affecting behaviour). Flagged for qc-behavioral to evaluate generalizability and process compliance (documented as user-directed, deviating from `experiment-flag-discipline.md` R3: no ledger ACCEPT, no confirmation grid) |
| A2 | No new analysis imports | PASS | No dune files modified |
| A3 | No unnecessary existing module modifications | PASS | All three changed files are part of the feature; no cross-feature drift |

### Verified the dispatcher's four numbered claims

1. **Blast radius** — ✓ Confirmed. Exactly one golden spec arms StopLimit: `sp500-2019-2023-armed-stoplimit.sexp`. Re-derived by grepping the whole scenario tree; no others found.
2. **The affected spec's CI gate** — ✓ Confirmed. It carries `;; perf-tier: 3`, so `golden_sp500_postsubmit.sh` picks it up; `golden-runs-sp500-5y.yml` is POSTSUBMIT (`on: push` to main only, so it did **not** run on this PR) and `continue-on-error: true`. The script counts *execution failure*, not numeric drift — there is no committed golden baseline next to the spec, so **no golden re-pin is required by this PR**.
3. **`goldens-small` byte-identical** — ✓ Structurally consistent. The clock is reachable only under StopLimit entries; `goldens-small` uses Market entries and cannot be affected.
4. **PR-body arithmetic** — ✓ Consistent across all three locations (PR body, `.mli`, test docstrings): salts {513.42, 434.06, 377.73} vs null {265.44, 281.71, 397.95}, mean +126.7pp, 8-of-9 pairwise, p = 0.100; test asserts `(false, 26)`; axis values {0, 13, 26, 52}.

### Note (dispatcher-supplied, not attributable to this PR)

`test_runner_hypothesis_overrides.ml:814` carries five `Invalid documentation comment` odoc warnings — pre-existing on `main`, in a docstring this PR does not touch (the `{13, 26, 52}` literal, which odoc reads as a section heading). `dune build @fmt` still exits 0. Recorded so it is not mistaken for a regression from this PR. Full population measured in `dev/health/2026-08-19-fast.md`.

## Quality Score

4 — All gates pass, the code is clean, and the mechanism is well documented; behavioral QC must adjudicate the user-directed process deviation.

## Verdict

APPROVED

**Routing for behavioral review:** A1 flagged — qc-behavioral should verify (1) whether the documented evidence mitigates the generalizability concern, and (2) whether the two process deviations (no confirmation grid, no ledger ACCEPT) are acceptable under a user-directed rationale.

---
🤖 qc-structural via GHA orchestrator run [32228074121](https://github.com/dayfine/trading/actions/runs/32228074121)
Reviewed SHA: 4d079a5424a9ab8d3508dbdcd96118c6b6504e3c

## Behavioral QC — promote entry_order_max_rest_weeks default 0 → 26

Reviewed as a **domain-config default flip**, so both the generic Contract Pinning rows and the project rows apply, plus the promotion-gate rows from `experiment-flag-discipline.md`, `promotion-confirmation.md` and `weinstein-faithful-core.md`.

Environment note: `gh` and `docker` are absent on this runner. dune was not re-run — qc-structural ran all three gates green at this exact SHA. Review is by reading code, tests, ledger, book reference and the golden specs in a detached worktree at `4d079a54`.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new/edited .mli docstrings has an identified test that pins it | **FAIL** | The *edited* docstring's claims are all pinned — `default = 26` → `test_default_entry_ticket_lifecycle_is_rescreen_off_clock_26` (`(false, 26)`); "survives week N, cancelled at N+1" → `test_clock_backstop_fires_one_week_after_ttl` (bound 4, weeks 3/4/5 → empty/empty/`ttl`); "cancelled regardless of whether it still qualifies" → `test_config_arms_clock_backstop_end_to_end` arm 4; "`[0]` = unbounded" → `test_ttl_zero_never_cancels`; omitted-field back-compat → `test_strategy_config_parses_with_lifecycle_fields_absent` (26). FAIL is for the docstrings the PR did **not** edit, which now assert a **false** default and are pinned by nothing — see B1. |
| CP2 | Each claim in the PR body has a corresponding committed test or verified artifact | PASS | Blast-radius table independently verified: goldens-broad 7, custom-universe 2, hybrid-tier 2, small 3, sp500 5, sp500-historical 8 = **27**; exactly one spec arms StopLimit (`goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp`); **no golden spec anywhere pins `entry_order_max_rest_weeks`**. |
| CP3 | Identity / invariant claims pin identity, not just a count | PASS | The "26 of 27 unaffected" claim rests on the goldens themselves, which are byte-level pins. All unit tests set both lifecycle fields explicitly via `_ttl_config`, so none silently inherits the new default. |
| CP4 | Each guard called out in docstrings has a test exercising the guarded-against scenario | PASS | Partial-fill exemption → `test_filled_and_partially_filled_tickets_are_never_cancelled`. Off-by-one guard → the 3/4/5 triple asserted together. `<= 0` short-circuit → `test_config_arms_rescreen_cancel_end_to_end` arm 1. |

## Promotion-gate Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | Mechanism lands default-off | NA | This PR *is* the promotion; R1 governed the original landing (#2349). |
| R2 | Knob is a real `config` field routed through `Overlay_validator`, axis-expressible | PASS | `test_entry_ticket_lifecycle_axes_resolve_via_overlay_validator` still pins `[0; 13; 26; 52]` through the real validator. |
| R3 | Default flip cites a ledger ACCEPT | **FAIL** | Declared unmet by the PR. `dev/experiments/_ledger/` holds exactly one related entry, `2026-08-18-entry-ticket-rescreen.sexp`, verdict `Reject`, about the *re-screen*. See B2 — the fix is a ledger record of the override, not a reversal of the flip. |
| PC | `promotion-confirmation.md` grid | **FAIL (declared; accepted as user-directed)** | One window, one universe, three salts, entirely post-2009. Filed as residual R-1, not blocking. |
| W1 | Weinstein spine intact | PASS | Stage classification, Stage-2-only entry, breakout+volume confirmation, Stage 3/4 exit, initial stop, macro/sector gates and RS selection all untouched. The clock ends the life of an **order that never became a position**; it cannot alter admission, grading or stops. |
| W2 | Adaptation is a documented dial, config-expressed, with cited book authority | PASS | The docstring's operative classification is **"BOOK-NEUTRAL dial"**, citing §4.7 ("a standing order with the specialist until you either cancel the orders or they are actually executed") and §7. Both verified directly in `docs/design/weinstein-book-reference.md` (lines 238–275, 419–425). The book grants cancel authority and names no expiry, so the number is a free parameter — which W2's "numeric thresholds tuned for the modern regime" permits. §4.7's own named case is the "surprised two or three weeks later" slow fill, comfortably inside a 26-week bound, so the promoted value does not cut the behaviour the book celebrates. The header's "the invented half" is scoped to the **number**, not the mechanism. **Caveat feeding B1:** the same paragraph closes "Prefer arming `enable_entry_ticket_rescreen` alone", which the promotion reverses and #2376 rejected at −137pp. |
| W3 | Experiments are Weinstein-faithful presets | NA | No experiment arm added here. |

## Behavioral Checklist (project rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core-module modification is strategy-agnostic (structural FLAGged) | PASS | The touched modules are Weinstein-specific by construction, not shared infrastructure. No Weinstein logic leaks into `portfolio/`, `orders/`, `position/`, `strategy/` or `engine/` — the diff does not touch them. |
| S1–S4 | Stage definitions | NA | No stage-classification logic in this diff. |
| S5 | Buy only in Stage 2, on breakout with volume confirmation | PASS | The clock can only *remove* a resting ticket; it cannot create an entry or relax any gate. |
| S6 | No buy signals in Stage 1/3/4 | PASS | Strictly subtractive on the entry side. |
| L1–L4 | Stop rules and state machine | NA | Stops untouched. `Entering` → `CancelEntry` never produces or moves a stop. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | Ordering and gate semantics unchanged. |
| T1–T3 | Stage / macro / stop-trailing coverage | NA | Not a stage, screener or stop feature. |
| T4 | Tests assert domain outcomes, not "no error" | PASS | Asserts the concrete shipped pair `(false, 26)` and parsed value `26`, not `is_ok`. The pre-existing TTL suite asserts cancellation *reasons* (`"ttl"` vs `"requalification"`), distinguishing the mechanism firing from the tick always cancelling. |

## Evidence calibration (`mechanism-validation-rigor.md`)

Every figure re-derived and correct: null mean **315.03** / spread **132.51**; clock mean **441.74** / spread **135.69**; gap **+126.70pp**; **8 of 9** pairwise; exact one-sided **p = 2/20 = 0.100** against a 1/20 = 0.050 floor at 3-vs-3; "worst clock draw 377.73 below best null draw 397.95" correct.

Two specific traps, both cleared:

1. **The spread is not used as a bound.** The two spreads sit in a descriptive column; significance is carried entirely by the separate pairwise/rank statement, and the PR volunteers that the distributions touch. This does **not** repeat the withdrawn "4–13× below the 132.5pp null" framing.
2. **No revival of a withdrawn claim.** The claim withdrawn at `58562044` compared clock-26-alone's 513.42 against a *different arm's* 282.20. This PR compares the clock-26 draws against the **null's own three draws** at the same base/window/universe/warehouse/salts — precisely the single-knob clock-only spec the ledger's forward guidance asked for.

Directionally consistent with the ledger's own note that "on the same null arm every clock bound {13,26,52,156} cuts a NET-LOSING cohort."

## Verdict rationale — what I am and am not blocking

I am **not** blocking the flip, the missing grid, or the `/tmp`-only draws. Those are disclosed, user-directed, and the disclosure is unusually candid: the PR states p = 0.100, states the distributions touch, states both gate deviations, and states its own evidence is not repo-reproducible. The repo's handoff grades it "**Promising, not established**" and the PR does not claim otherwise. A disclosed user-directed deviation is legitimate.

What I am blocking is the **record** — because the record is this PR's entire justification ("Both are recorded verbatim in the `.mli` rather than glossed"), and it is incomplete in two ways that mislead readers and confound future work. Both fixes are mechanical.

## Quality Score

**2** — Below standard: the measurement, statistics and disclosure are careful and verified correct, but the promotion ships with sites still asserting the old default (one a machine-readable `[@sexp.default 0]` in a public signature) and no ledger record, so the promotion is discoverable only from one docstring in a ~1,450-line `.mli`. Both defects are small and fixable.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### B1 (CP1): Four doc sites still describe the pre-promotion default

**Finding.** `weinstein_strategy.ml:49` does `include Weinstein_strategy_config` and `weinstein_strategy.mli:294` **re-declares the entire `config` record**. The PR updated the field in `weinstein_strategy_config.{ml,mli}` but not in the re-declaration, so the public signature of the module consumers actually open now contradicts the implementation. This **compiles green** — sexp attributes do not participate in signature matching — so no linter, no test and no CI gate can catch it.

**Locations.**
1. `weinstein_strategy.mli:880` — `entry_order_max_rest_weeks : int; [@sexp.default 0]`, docstring "`[0]` (default) = unbounded … ~156 is the candidate value". *(most serious — a machine-readable attribute disagreeing with the implementation)*
2. `weinstein_strategy.mli:231` — "armed independently by … (defaults `[false]` / `[0]` = off)".
3. `weinstein_strategy_screening.ml:296` — "No-op at the defaults (`[entry_order_max_rest_weeks = 0]`)". **False as of this PR**: at the defaults the guard at line 305 no longer short-circuits, the predicate is built, and tickets are cancelled. A false behavioural claim in the implementing module, ten lines above the guard it describes.
4. `weinstein_strategy_config.mli:1496` — "Prefer arming `{!enable_entry_ticket_rescreen}` alone", retained in the very W2 paragraph this PR rewrote. Contradicts the promoted default and contradicts #2376 / ledger `2026-08-18-entry-ticket-rescreen`, which rejected the re-screen at −137pp.

**Authority.** qc-behavioral CP1 — an `.mli` docstring is the primary contract; an unpinned claim is a defect and a **false** one more so. `experiment-flag-discipline.md` R3/R5. `weinstein-faithful-core.md` W2.

**Required fix.** (a) `weinstein_strategy.mli:880` → `[@sexp.default 26]`, docstring rewritten to state the promoted default and point at `Weinstein_strategy_config.entry_order_max_rest_weeks` for the evidence; (b) `:231` → "defaults `[false]` / `[26]`"; (c) `weinstein_strategy_screening.ml:296` → state the pass is **armed at the defaults** via the clock, and is a no-op only when the clock is pinned to `0` with the re-screen off; (d) delete or invert `weinstein_strategy_config.mli:1496`. Consider a one-line assertion in the F2 default test that the two `config` declarations agree, so a future divergence fails a test rather than compiling.

**harness_gap:** LINTER_CANDIDATE — a deterministic check that every `[@sexp.default …]` in `weinstein_strategy.mli`'s re-declared record matches the corresponding `weinstein_strategy_config.ml` literal would close this class permanently. This is the second declaration of a ~200-field record; divergence is structurally inevitable without a check.

### B2 (R3): The promotion is invisible from the experiment ledger

**Finding.** No ledger entry records this default flip. The one related entry, `2026-08-18-entry-ticket-rescreen.sexp`, describes its baseline as "the invented clock held at its no-op 0" and labels it `null`. **After this merge, `null` no longer denotes the default**, and every future arm that does not pin `entry_order_max_rest_weeks` silently carries 26. The ledger is what the next experiment session reads; a default flip invisible to it is a confound generator, not a bookkeeping nit.

**Authority.** `experiment-flag-discipline.md` R3. The house precedent for a legitimate R3 override is **#2047** (resistance-v2 BUNDLE, 2026-07-23), recorded with three artifacts: ledger `2026-07-20-bundle-promotion-studies` (verdict **`Inconclusive-pending-human`** — note it is *not* an ACCEPT either), promotion memo `dev/notes/resistance-supply-promotion-memo-2026-07-19.md`, and a status record in `dev/status/resistance-v2.md` naming the options and which the user approved. This PR has none of the three. **Requiring a ledger entry therefore invents no new standard** — it is the established form of a human-gated R3 override in this repo.

**Required fix.** Add `dev/experiments/_ledger/2026-08-18-entry-ticket-clock26-promotion.sexp` with a verdict such as `Promoted-by-user-override`, carrying: the three clock-only draws and the three null draws; the mean gap, 8-of-9 pairwise and p = 0.100; both declared gate deviations; the spec path `dev/experiments/ttl-retest-2026-08-16/specs/ttl-retest-06-clock26-only.sexp` and the salts; and the pending confirmation grid as the follow-up. Add a durable owner for that grid in a `dev/status/` file — the priorities doc is a session handoff, not a tracked obligation.

**harness_gap:** ONGOING_REVIEW (a weaker mechanical backstop is possible: a check that any diff changing a `[@sexp.default …]` in `weinstein_strategy_config.ml` also touches `dev/experiments/_ledger/` — that would be a LINTER_CANDIDATE).

## Non-blocking residuals (routed to a status file; not gating this PR)

- **R-1 — the confirmation grid.** ≥3 cells with **≥1 spanning a pre-2009 macro regime**. `promotion-confirmation.md`'s own worked example (early-admission, 2026-05-30) is precisely a case where four agreeing post-2009 cells were reversed by a 27y window covering the dot-com bust and the GFC.
- **R-2 — commit the per-arm outputs.** The PR says this itself. The spec is committed and the null tripwire reproduces to 15 digits, so this is weak rather than absent.
- **R-3 — cite the within-run cohort evidence.** Ledger `2026-08-18-entry-ticket-rescreen` already records: *"On the null arm a 26w bound cuts 89 fills worth −349,132, the largest net-losing cohort of the four bounds tested."* That is a **within-run** cohort figure supporting **26 specifically**, and the priorities doc says in bold to read within-run per-bucket P&L rather than the top line. This PR's evidence is entirely between-run. Citing it would materially strengthen the record at zero cost.
- **R-4 — stale line** at `dev/experiments/ttl-retest-2026-08-16/README.md:135`: "`entry_order_max_rest_weeks` still shipping at `0` remains correct".
- **R-5 — golden exposure.** `goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp` is the single affected golden and does not pin the clock. The PR's plan (let postsubmit measure it, re-pin with real numbers) is right — pinning `0` there would freeze the one armed-StopLimit golden to the retired default, defeating its purpose.

---
🤖 qc-behavioral via GHA orchestrator run [32228074121](https://github.com/dayfine/trading/actions/runs/32228074121)
Reviewed SHA: 4558e55d1f1424e9d938b9541dacd8116c900dd1

## Structural QC (re-review at 4558e55d)

Re-review. The prior APPROVED verdict was at `4d079a54`, **two commits ago**, when this PR was 3 files. It is now **25**, so that verdict is stale and this re-establishes it.

### Gates (measured in a detached worktree at this SHA)

| Gate | Exit | Notes |
|---|---|---|
| H1 `dune build @fmt` | **0** | doc-comment formatting warnings present but non-fatal (pre-existing population; see `dev/health/2026-08-19-fast.md`) |
| H2 `dune build` | **0** | |
| H3 `dune runtest` | **0** | **0** `^FAIL:` lines; all linters clean |

### Structural Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| H1 | dune build @fmt | PASS | exit 0 |
| H2 | dune build | PASS | exit 0 |
| H3 | dune runtest | PASS | exit 0, 0 `^FAIL:` |
| P1 | Functions ≤ 50 lines | PASS | fn_length linter clean under H3 |
| P2 | No magic numbers | PASS | magic_numbers linter clean under H3 |
| P3 | Config completeness | PASS | `entry_order_max_rest_weeks` declared `[@sexp.default 26]` in **both** `config.ml` and `config.mli` |
| P4 | Public-symbol export hygiene | PASS | mli_coverage clean under H3 |
| P5 | Internal helpers prefixed | PASS | drift-guard helpers underscore-prefixed |
| P6 | Tests conform to test-patterns | PASS | new drift-guard test composes `assert_that` + `is_some_and` + `equal_to` correctly; none of the three greppable sub-rule violations present |
| A1 | Core module modifications | PASS | no Portfolio/Orders/Position/Engine/Simulation changes; all code confined to `trading/trading/weinstein/strategy/lib/` |
| A2 | No new `analysis/` imports | PASS | zero cross-layer imports introduced; no dune files touched |
| A3 | No unnecessary modifications | PASS | 5 ml/mli (all strategy), 13 archived-spec sexp pins, 2 ledger files, 2 status/migration docs. No cross-feature drift. |

### Focus areas

**1. The archived-spec pins are complete.** Verified all 13 rather than accepting the count: 7 `staging-record-convention/`, 3 `ladder-v3-faithful-stoplimit-2026-08-09/`, 1 `armed-stoplimit-repro-2026-08-11/`, 1 `walk_forward/sim_entry_stoplimit_31fold_2026_08_04.sexp` — each now pins `entry_order_max_rest_weeks 0`. **Completeness re-derived**: grepped `trading/test_data/backtest_scenarios/` for StopLimit-armed specs lacking a pin; **zero** remain unpinned apart from the one deliberate exclusion.

**Deliberate exclusion confirmed correct:** `goldens-sp500/sp500-2019-2023-armed-stoplimit.sexp` stays unpinned. Pinning `0` there would freeze the sole armed-StopLimit golden to the retired default, defeating its purpose — the PR distinguishes "deliberately unpinned" from "missed", which was the thing to check.

**2. `entry_ticket_ttl.mli` (+10/−5) is docs-only.** Both `val` signatures (`cancellations`, `run`) are unchanged; only docstrings move. New text correctly states that since 2026-08-18 the config field ships at **26**.

**3. The drift guard is mechanically sound, and correctly scoped.** It reads the `.mli` **from disk** (not a compiled value — which is the only way to catch a divergence that compiles green), extracts the `[@sexp.default N]` attribute on the `entry_order_max_rest_weeks` line, and compares against the runtime `(_default_config ()).entry_order_max_rest_weeks`. A future divergence therefore **fails a test instead of compiling**.

Scope limit, stated rather than implied away: it guards **one field**, not the ~200-field record. The general case remains open.

**4. The ledger entry parses and conforms.** `verdict` uses the closed variant **`Inconclusive`**, verified against `trading/trading/backtest/experiment_ledger/lib/experiment_ledger.mli` — an invented label such as `Promoted-by-user-override` would **not** have parsed, so declining that suggestion was correct, and `Inconclusive` matches the #2047 house precedent. Structure `(date) (slug) (hypothesis) (verdict) (notes)` is well-formed and `index.sexp`'s appended row agrees on both slug and verdict.

**5. Issue #2388 unaffected.** The pre-existing `stale_exit_after_days` documented-`None` / ships-`Some 5` drift is neither fixed nor worsened here, as intended.

## Quality Score

4 — Good. All gates green; the drift guard is mechanically sound and honestly scoped; the spec pinning is complete and independently re-derived; the ledger conforms to a closed schema with an honest non-ACCEPT verdict. Held at 4 rather than 5 because the drift guard covers one field of a record whose second declaration has already produced a second known instance (#2388), so the class is contained here but not closed.

## Verdict

APPROVED

---
🤖 qc-structural (re-review) via GHA orchestrator run [32228074121](https://github.com/dayfine/trading/actions/runs/32228074121)
Reviewed SHA: 4558e55d1f1424e9d938b9541dacd8116c900dd1

## Behavioral QC (re-review at 4558e55d)

Re-adjudication of my NEEDS_REWORK (2) at `4d079a54`. Two rework commits landed (`3cdc1328`, `4558e55d`). All CP rows re-derived at this tip; none carried forward.

Environment: `gh`/`docker` absent. qc-structural ran all three gates green at this exact SHA, so I scoped my own build to the single test target needed to falsify the new drift guard.

## What I verified myself (not inherited)

- **All four B1 sites read at HEAD**, plus a fifth the rework fixed unasked.
- **The drift guard falsified in both directions** — a guard that cannot fail is the vacuity defect this run has been chasing.
- **Blast-radius table re-counted** from the tree: 7/2/2/3/5/8 = 27 goldens, exactly one arming StopLimit. Exact match to the PR body.
- **Every path cited by the diff swept** for dangling references.

## Contract Pinning Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new/edited `.mli` docstrings has an identified test that pins it | **PASS** (was FAIL) | All five sites now assert the shipped default, and the drift guard makes the machine-readable one fail loud on divergence. Pins: `default = 26` → `test_default_entry_ticket_lifecycle_is_rescreen_off_clock_26`; `.mli` re-declaration agrees with runtime → `test_strategy_mli_redeclares_clock_default_consistently`; omitted-field back-compat → `test_strategy_config_parses_with_lifecycle_fields_absent`; `[0]` = unbounded → `test_ttl_zero_never_cancels`; N/N+1 boundary → `test_clock_backstop_fires_one_week_after_ttl`; "regardless of whether it still qualifies" → `test_config_arms_clock_backstop_end_to_end`. |
| CP2 | Each claim in the PR body has a corresponding committed test or verified artifact | **PASS** | Re-derived, not inherited. Golden table re-counted from the tree: broad 7/0, custom-universe 2/0, hybrid-tier 2/0, small 3/0, sp500 **5/1**, sp500-historical 8/0 = 27, one armed. Nothing advertised is missing. The body is *under*-descriptive rather than over-claiming — filed as **R-7**, not a CP2 FAIL. |
| CP3 | Identity / invariant claims pin identity, not just a count | **PASS** | Checked the mechanism, not the intent: `weinstein_strategy_config.ml` carries **no** `sexp_drop_default`, so an explicit `((entry_order_max_rest_weeks 0))` override onto the new default yields a config **bit-identical** to the pre-flip effective config — preserving `Experiment_ledger.config_hash` exactly for every pinned arm. That is identity. One arm is exempt: **R-6**. |
| CP4 | Each guard called out in docstrings has a test exercising the guarded-against scenario | **PASS** | Partial-fill exemption → `test_filled_and_partially_filled_tickets_are_never_cancelled`. Off-by-one → weeks 3/4/5 asserted together. `<= 0` short-circuit → `test_ttl_zero_never_cancels`. The one *new* guard claim is pinned compositionally (default 26 pinned by test; `26 > 0` against a literal `<= 0` one line below) — acceptable, as the guard is a single readable expression adjacent to its own docstring. |

## B1 closure — each site read at HEAD

| # | Site | State at `4558e55d` | Verdict |
|---|---|---|---|
| 1 | `weinstein_strategy.mli:880` | `[@sexp.default 26]`; docstring delegates evidence to `Weinstein_strategy_config.entry_order_max_rest_weeks` instead of duplicating it | **closed** |
| 2 | `weinstein_strategy.mli:231` | `(defaults [false] = off / {b [26]} = armed, promoted 2026-08-18)` | **closed** |
| 3 | `weinstein_strategy_screening.ml:296` | `{b No longer a no-op at the defaults}`, naming `entry_order_max_rest_weeks = 0` as the only value restoring the old skip-everything path | **closed** — this was the false *behavioural* claim, the most serious of the four |
| 4 | `weinstein_strategy_config.mli:1531` | "Prefer arming the re-screen alone" inverted into an explicit **"Do not prefer the re-screen instead"** block citing the −137pp REJECT, its ledger path, and why the two rules select opposite populations | **closed** |
| 5 | `entry_ticket_ttl.mli:45` | **Not in my original finding.** Retitled "The no-op configuration"; states the config defaults no longer produce it while correctly noting the *function's* contract is unchanged — only which arguments the shipped config passes it | **closed (unasked)** |

Site 5 is the one I missed. Fixing it unprompted, and drawing the contract/caller distinction correctly rather than mangling the function's contract, is the right instinct.

## The drift guard — falsified, twice

`test_strategy_mli_redeclares_clock_default_consistently`. I built the single target and ran the single case.

| state of `weinstein_strategy.mli:880` | result |
|---|---|
| `[@sexp.default 26]` (as shipped) | **OK** — 1 case ran, 49 skipped |
| reverted to `[@sexp.default 0]` | **FAILED** — `Values should be equal / not equal` |
| attribute deleted entirely | **FAILED** |

Both preconditions are **asserted**, not assumed — file-not-found raises `assert_failure` with the cwd in the message; field-not-found returns `None` into `is_some_and`, which fails. It cannot pass vacuously by having its input silently disappear — the opposite of the shape a sibling reviewer found in #2390 today. The `.mli` is a compilation input to the library the test links, so any future edit forces a rebuild and re-run; the guard cannot go stale either. Worktree restored clean after falsification.

**Scope honestly stated, not implied away:** it guards *one* field, not the ~200-field record. That remains open as **R-8**. A narrow guard that demonstrably fails is worth more than a broad one that does not.

## B2 closure — the ledger record

Three things checked rather than assumed:

1. **The declined label was the right call.** `experiment_ledger.mli:20` — `type verdict = Accept | Reject | Inconclusive`. Closed variant; the suggested `Promoted-by-user-override` would not have parsed. `Inconclusive` is also what the cited precedent (`2026-07-20-bundle-promotion-studies`, the #2047 override) uses, and `notes` opens by stating in capitals that this is **not** an Accept. **I was wrong to propose the label.**
2. **The `null` confound is repaired at the right end.** The new entry states explicitly that `null` in both 2026-08-18 entries means `(rescreen=false, clock=0)` and that after this merge that is no longer the shipped default. **The old entry correctly was not amended** — `experiment_ledger.mli:1` and `experiment-gap-closing/SKILL.md:90` both specify the ledger is *append-only, never overwrite*. So my question "does the old entry need a note?" resolves to **no**.
3. **Every figure re-derived and still correct** — null mean 315.03/spread 132.51; clock mean 441.74/spread 135.69; gap +126.70pp; 8-of-9 pairwise; p = 2/20 = 0.100. The entry also volunteers what the PR body does not: the clock arm's salt→draw mapping is not independently verifiable, so only the *set* of three draws is load-bearing (hence `draw-a/b/c`, not `s0/s1/s2`). A self-imposed weakening of its own evidence, and the correct call.

**R-3 and R-4 also closed, unasked.** R-1/R-2/R-5 now have a durable owner in `dev/status/simulation.md`.

## New-scope checklist (13 pinned specs + `entry_ticket_ttl.mli`)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| N1 | Pinning `0` is correct preservation semantics per spec | **PASS with one exception** | For the 12 single-config scenario specs, pinning is *complete* preservation — one config, one pin, and with no `sexp_drop_default` the effective config (and thus the `config_hash` dedup key) is bit-identical to pre-flip. Each carries an explicit "Do not drop this pin" comment. |
| N2 | Pinning in a **walk-forward** spec means the same as in a single scenario | **FAIL as applied → R-6, non-blocking** | It does not. `walk_forward_runner.ml:20` composes `base.config_overrides @ variant.overrides`, so preservation requires pinning **every variant**, including the empty-override baseline. In `sim_entry_stoplimit_31fold_2026_08_04.sexp` the three `cap*` arms are pinned; the `market` baseline (`(overrides ())`) is not, and its base scenario does not pin it either. |
| N3 | Referencing ledger entries stay coherent | **PASS** | `2026-08-04-sim-entry-stoplimit-surface.sexp` carries real MD5 `config_hash`es; the three cap rows remain matchable exactly *because* of the pins — the strongest available argument that pinning was right. The `market` row is the R-6 exception. This invalidation class is global to any default flip and not something this PR created or could fix. |
| N4 | `entry_ticket_ttl.mli` docstring claims true and pinned | **PASS** | Docs-only; the only hunk is the header block above `open Core`. "Ships at 26" → pinned by the default test. "The function's contract is unchanged" → true and pinned by the untouched TTL suite, every test of which passes both args explicitly and so is immune to the default. |

## Promotion-gate Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| R1 | Mechanism lands default-off | NA | This PR *is* the promotion. |
| R2 | Real config field, axis-expressible | PASS | `[0; 13; 26; 52]` still pinned through the real validator. |
| R3 | Default flip cites a ledger record | **PASS** (was FAIL) | `2026-08-18-entry-ticket-clock26-promotion.sexp`, verdict `Inconclusive`, indexed. Not an ACCEPT and it says so — the honest record of a declared user-directed override, matching the #2047 precedent. **B2 closed.** |
| PC | `promotion-confirmation.md` grid | **FAIL (declared; accepted as user-directed)** | Unchanged in substance and in position: one window, one universe, three salts, post-2009 only. Now *owned* in `dev/status/simulation.md` with the pre-2009 macro cell called out. Not blocking — same as last time. |
| W1 | Weinstein spine intact | PASS | Re-stated given `entry_ticket_ttl.mli` moved: docs-only, so nothing about the spine moved with it. The clock ends the life of an **order that never became a position**. |
| W2 | Documented dial, config-expressed, book authority cited | PASS | Still **BOOK-NEUTRAL dial** per §4.7/§7. **The caveat that fed B1 is now resolved in the right direction** — the closing "prefer the re-screen alone" is inverted into an explicit prohibition citing the REJECT, so the docstring no longer recommends what the repo measured at −137pp. |
| W3 | Experiments are faithful presets | NA | No experiment arm added. |

## Behavioral Checklist (project rows)

| # | Check | Status | Notes |
|---|-------|--------|-------|
| A1 | Core-module modification is strategy-agnostic | PASS | Touched modules are Weinstein-specific by construction; `portfolio/`, `orders/`, `position/`, `strategy/`, `engine/` not in the diff. |
| S1–S4 | Stage definitions | NA | |
| S5 / S6 | Stage-2-only entry, no signals in 1/3/4 | PASS | The clock is strictly subtractive on the entry side. |
| L1–L4 | Stop rules | NA | `Entering` → `CancelEntry` never produces or moves a stop. |
| C1–C3 | Cascade / macro / sector RS | NA | |
| T1–T3 | Stage / macro / stop-trailing coverage | NA | |
| T4 | Tests assert domain outcomes | PASS | Asserts `(false, 26)`, the parsed `26`, and now the *source-level* declared default — none of them `is_ok`. |

## Verdict rationale

My position from the first review is unchanged and has not drifted: **the flip, the missing grid, and the `/tmp`-only draws were never blocking.** I blocked the **record**, in two specific ways. Both are now closed on directly verified evidence.

Of the process, one detail is worth recording: the rework agent **declined** my suggested verdict label and cited the closed variant at `experiment_ledger.mli:20`. That was correct and I was wrong.

**Why R-6 is a residual and not a second blocker.** It is a real defect in new scope and I nearly escalated it. Three things held me back, stated so the reasoning is auditable rather than deferential: (1) under the PR's own verified structural claim — the clock is meaningful only under the StopLimit entry family, evidenced by goldens-small returning byte-identical results and the 26-of-27 count I re-derived exactly — the `market` arm uses Market fills, so clock 0 vs 26 is inert for it; (2) the protected artifact is an *archived REJECT* nobody re-runs; (3) the fix is one line. That is a materially different magnitude from B1, whose sites were false claims about the shipped default in a public interface. Blocking on R-6 would be manufacturing a second pass. **Caveat, plainly:** R-6's inertness is inherited from that structural claim, which I could not independently re-run. If it is ever falsified, R-6 becomes a genuine two-knob confound and should be re-opened.

## Quality Score

4 — Good: both blocking findings closed on directly verified evidence, the drift guard demonstrably fails on divergence rather than passing vacuously, and the rework correctly declined an invalid suggestion of mine with a schema citation. Short of exemplary because one of the 13 pinned specs is pinned incompletely (R-6) and the drift guard covers one field of a ~200-field re-declared record (R-8).

## Verdict

APPROVED

## Prior findings — closure status

| finding | status | evidence |
|---|---|---|
| **B1** — four doc sites asserting the pre-promotion default | **CLOSED** | All four read at HEAD; a fifth fixed unasked; the machine-readable site backed by a guard falsified in two directions |
| **B2** — promotion invisible from the ledger | **CLOSED** | New entry + `index.sexp` row; verdict `Inconclusive` verified schema-valid; `null` confound repaired append-only |
| R-3 — cite the within-run cohort figure | **CLOSED (unasked)** | Now the docstring's load-bearing argument, with its own limit stated (static bucket subtraction ignores capital recycling) |
| R-4 — stale README line | **CLOSED (unasked)** | "⚠ Superseded 2026-08-18" block at `README.md:135` |
| R-1 / R-2 / R-5 | **OWNED** | `dev/status/simulation.md` — "CONFIRMATION GRID OWED" |

## Non-blocking residuals

**R-6 — the walk-forward baseline arm is not pinned.** `sim_entry_stoplimit_31fold_2026_08_04.sexp` pins `cap10`/`cap15`/`cap20` but leaves the `market` baseline at `(overrides ())`; the base scenario does not pin it either. Consequences: (a) the recorded baseline hash `e79b8f802399c30e3e163a07d142aeea` is no longer matchable by `Experiment_ledger.lookup`, while the three cap hashes are; (b) the spec's own inline comment — *"matches every existing baseline (defaults; both arming knobs off)"* — is now **false** about the clock knob, which is precisely the B1 class of defect, in a file this PR edited, two lines above three lines it changed. It is also the only one of the 13 with **no** explanatory pin comment. *Fix:* add the override and correct the comment — or, if the omission is deliberate because the arm is inert, say so, so a future reader can tell oversight from intent. *harness_gap:* LINTER_CANDIDATE — a check that within one walk-forward spec either all variants pin a field or none do.

**R-7 — the PR body still describes the 3-file version.** It documents neither the 13 pinned specs, nor the drift guard, nor the ledger entry. Nothing is *over*-claimed, so not a CP2 FAIL — but for a PR whose thesis is that the record is the justification, the body is the one artifact still carrying the pre-rework story. Also over-broad by one: `dev/status/simulation.md` says the 13 specs were pinned "to keep their recorded results reproducible", which holds for 12 of 13 (R-6).

**R-8 — the drift guard covers one field of ~200.** Generalising `_declared_sexp_default` to fold over all fields would close the class permanently. This is the second declaration of a ~200-field record and divergence is structurally inevitable. *harness_gap:* LINTER_CANDIDATE.

**R-9 — hand-written ledger entries do not round-trip through the schema.** The new entry's `aggregate` uses `(total_return_pct … max_drawdown_pct … rejected_fills …)`, not `Experiment_ledger.fold_aggregate`. Pre-existing house practice — its companion does the same and nothing parses `_ledger/` — so this PR is *consistent* with what it companions and I am not charging it here. But these two entries are human-readable only, unlike `2026-08-04-sim-entry-stoplimit-surface.sexp`, which is machine-usable. *harness_gap:* LINTER_CANDIDATE — a `dune runtest` check that every `_ledger/*.sexp` parses as `Experiment_ledger.entry_of_sexp` would prevent the ledger silently splitting into machine-usable and prose-only halves.

**Citation check (requested).** The `.mli` and ledger entry cite `ttl-retest-06-clock26-only.sexp`, absent on this branch. Confirmed it landed on `main` via `b3d339fd` (#2377), post-dating the branch point; `git cat-file -e origin/main:<path>` succeeds, so the citation resolves post-merge. I swept **every** path added anywhere in the diff for the same hazard — exactly one other dangles on-branch (`dev/notes/next-session-priorities-2026-08-19.md`), also present on `origin/main`. Nothing else.

---
🤖 qc-behavioral (re-review) via GHA orchestrator run [32228074121](https://github.com/dayfine/trading/actions/runs/32228074121)
