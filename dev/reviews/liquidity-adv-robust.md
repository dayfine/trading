Reviewed SHA: 4c03944db308065749e00dcad7390bd2a69ae154

## Behavioral QC — liquidity-adv-robust (PR #2081, issue #2060)

Authority documents consulted: `liquidity_metric.mli` / `liquidity_config.mli` /
`entry_liquidity_gate.mli` / `liquidity_exit_runner.mli` / `short_borrow_gate.mli`
docstrings (primary contract for a realism-overlay change),
PR #2081 body §"What changed" / §"R1" / §"R2" / §"R3" / §"Test plan",
`.claude/rules/experiment-flag-discipline.md` (R1/R2/R3),
`.claude/rules/weinstein-faithful-core.md` (W1/W2),
`.claude/rules/qc-behavioral-authority.md` (domain rows).

## Behavioral Checklist

| # | Check | Status | Notes |
|---|-------|--------|-------|
| CP1 | Each non-trivial claim in new .mli docstrings has an identified test that pins it | **FAIL** | **Metric layer: fully pinned.** `liquidity_metric.mli` claims → tests: "`Mean` … reproduces the pre-#2060 behaviour bit-for-bit" → `test_default_aggregation_is_bit_identical_to_mean` (`test_liquidity_metric.ml:157`); "`Median` … middle observation for odd, mean of the two central for even" → `test_median_odd_window` / `test_median_even_window` (:180, :186); "spoofable: one block print moves the mean by spike/n" + "`Median` and `Trimmed_mean` are robust to that single spike; `Mean` is not" → `test_spoof_mean_clears_entry_floor` / `test_spoof_robust_aggregations_stay_below_floor` (:124, :133); "`floor (n *. trim_pct)` clamped so at least one observation always survives" → `test_trim_always_leaves_one_observation` (:220); "non-finite or non-positive `trim_pct` trims nothing" → `test_trim_pct_nonfinite_trims_nothing` (:204); "`trim_pct` at or above 0.5 trims maximally" → `test_trim_pct_at_half_degenerates_to_median` (:214); "Returns `None` when bars empty or `lookback_days <= 0`" → `test_empty_bars_none_for_every_aggregation` / `test_nonpositive_lookback_none_for_every_aggregation` (:236, :241); "never a padded count" → `test_window_longer_than_bars_uses_all` (:65) + `test_single_bar_same_for_every_aggregation` (:246). `liquidity_config.mli` "Default `Mean`" → `test_config_default_aggregation_is_mean` (:174); "expressible as a `Variant_matrix` axis" → `test_adv_aggregation_axes_expand` (`test_variant_matrix.ml:751`, which runs `Overlay_validator.apply_overrides` via `_validate_override`). **Consumer layer: three new .mli contracts unpinned** — see CP1 finding below. |
| CP2 | Each claim in PR body "Test plan"/"Test coverage" has a corresponding committed test | PASS | Every advertised test exists at this SHA. "5 → 20 cases" → suite list `test_liquidity_metric.ml:262-303` has exactly 20 entries. LINK spoof fixture (60 bars, $250k honest, one $15.4M print at index 50, inside the trailing 20) → `spoof_bars` :103; arithmetic verified: mean = (19·250 000 + 15 400 000)/20 = **1 007 500** matches the pinned `spoof_mean`, median of 20 obs = 250 000, trimmed(k=floor(20·0.1)=2) = 250 000. "Median: odd, even, lookback truncation" → :180/:186/:193. "Trimmed mean: `trim_pct=0` → Mean; non-finite/negative trims nothing; ≥0.5 trims maximally; at-least-one floor" → :198/:204/:214/:220. "Degenerate inputs for every aggregation" → :236/:241/:246/:252. "R2 axis expansion test" → `test_variant_matrix.ml:751`. "`test_liquidity_exit_runner.ml` config literal now builds from `default_config with`" → diff confirms. The Test plan makes **no** consumer-level test claim, so nothing is over-advertised. |
| CP3 | Pass-through / identity / invariant tests pin identity, not just size | PASS | `test_default_aggregation_is_bit_identical_to_mean` (:157) uses `elements_are [equal_to …]` on `float option` — exact structural equality, not `float_equal`/epsilon — across six inputs including both degenerate cases (`[]`, `lookback_days = 0`). Crucially it does **not** degenerate into "Mean equals Mean": the retained legacy pins with literal expected values (`test_uniform_mean` 10 000.0 :56, `test_window_takes_trailing` 15 000.0 :60, `test_window_longer_than_bars_uses_all` :65, `test_empty_bars_none` :72, `test_nonpositive_lookback_none` :75) independently anchor the default path, so a broken `Mean` fails there. Backward-compat of `[@sexp.default]` on the two new fields is exercised by the existing on-disk corpus (11 `*.sexp` scenario/golden files carry `liquidity_config` blocks lacking the new fields; CI green at this SHA). |
| CP4 | Each guard called out in code docstrings has a test exercising the guarded-against scenario | PASS | Guards → tests: `None` on empty/`lookback_days<=0` and the "a missing reading must never force a spurious exit/drop" rationale → per-aggregation `None` tests (:236, :241); "at least one observation always survives" (division-by-zero guard) → `test_trim_always_leaves_one_observation` (:220, n=2 @ `trim_pct=0.49`); non-finite `trim_pct` → NaN + infinity + negative all covered (:204); "never pads" → :65, :246; chronological ≠ sorted → `bars_ascending` fixture is deliberately unsorted (:29) and is the basis of the median tests. Two doc nits, non-blocking: (a) `liquidity_metric.ml:41` `_trim_count` docstring sentence is garbled ("Total on a non-finite or non-positive `trim_pct` …" — a word is missing); (b) the `.mli` says `trim_pct >= 0.5` degenerates "to `Median` on an odd-length window" — it also degenerates to the median on an **even**-length window (`n - 2k = 2`, mean of the two central), so the qualifier under-claims; only the odd case is tested. Neither is a contract violation. |
| A1 | Core module modification is strategy-agnostic | PASS | qc-structural recorded PASS-not-FLAG and handed the generalizability judgment here. Exercising that discretion: no file under the authority's core watch-list (`trading/trading/portfolio/`, `orders/`, `position/`, `strategy/`, `engine/`) is touched. All nine implementation files are under `trading/trading/weinstein/strategy/lib/` — the Weinstein overlay subtree; `Liquidity_metric` and `Liquidity_config` are themselves Weinstein-local. The one file outside that subtree, `trading/trading/backtest/walk_forward/test/test_variant_matrix.ml`, is a test-only addition that exercises the existing generic `Overlay_validator` path with no production change. Even under the broad name-matching reading structural flagged as possible, no strategy-specific logic leaks into a shared module. |
| W1 | Weinstein spine intact | PASS | `weinstein-faithful-core.md` spine items 1–7 untouched: no change to stage classification, the Stage-2-only buy rule, breakout/volume confirmation, Stage-3/4 exit, initial stop placement, macro/sector gating, or RS selection. This is an execution-realism dial on the pre-existing liquidity overlay — it changes only *how a dollar-ADV window is reduced to one number*, never a stage or signal rule. |
| W2 | Adaptation is config-expressed and searchable | PASS | `experiment-flag-discipline.md` R1: `adv_aggregation` defaults to `Mean` with `[@sexp.default default_adv_aggregation]` (`liquidity_config.ml:31`), and `Mean` is the same in-order left-fold sum as the pre-#2060 code, so the no-op equals prior behaviour bit-for-bit (pinned, CP3). R2: both are real `Liquidity_config.t` fields reached through the nested `liquidity_config` path in `Overlay_validator`. R3: no default flipped, and `liquidity_config.mli:56` states explicitly there is no ledger ACCEPT for a non-`Mean` aggregation. **Caveat feeding the CP1 finding:** R2 "searchable" is currently pinned only as far as *the override parses into the config* — no test shows that flipping the axis changes any gate's decision. |
| S1–S6 | Stage definitions / buy criteria | NA | Liquidity/execution-realism change. No stage classification, entry-signal, or buy-criteria logic is touched; per `qc-behavioral-authority.md` §"When to skip this file entirely" the domain block is not applicable to a measurement-basis dial. Same note applies to L1–L4 (stop-loss / stop state machine), C1–C3 (screener cascade / macro gate / sector RS) and T1–T3 (stage-transition, bearish-macro and stop-trailing test coverage). |
| L1–L4 | Stop-loss rules / state machine | NA | See S1–S6 note. |
| C1–C3 | Screener cascade / macro gate / sector RS | NA | See S1–S6 note. The entry liquidity gate and short-borrow gate sit *after* the cascade in `entry_assembly.ml` and their ordering is unchanged by this PR. |
| T1–T3 | Stage-transition / bearish-macro / stop-trailing test coverage | NA | See S1–S6 note. |
| T4 | Tests assert domain outcomes, not just "no error" | PASS | Every metric test asserts an exact dollar figure and, for the spoof cases, the *decision-relevant* comparison against the $1M floor (`ge (module Float_ord) entry_floor` for `Mean`, `lt` for `Median`/`Trimmed_mean`, `test_liquidity_metric.ml:124-153`) rather than merely "returns Some". No `assert_bool`-style or existence-only assertions in the diff. |

## The load-bearing behavioral finding

The metric layer is excellent and the spoof reproduction is genuinely
discriminating: the fixture reproduces the LINK shape with the correct arithmetic
(`Mean` = $1 007 500, clears the armed floor by 0.75%; `Median` and
`Trimmed_mean` = $250 000, 4× below it), and the bit-identity test is a real
structural pin rather than an epsilon compare.

The gap is one layer up. The PR's chosen direction is justified in its own body
by the multi-consumer property — *"A metric-level fix repairs all three from one
place; a k-of-N gate … would leave the other two reading a spoofable number,
which is a latent inconsistency"* — and `short_borrow_gate.mli:57-61` promotes
that to an explicit contract: *"measures dollar-ADV on **exactly the same
basis** as the entry gate and the held-position exit."* That property, the
load-bearing argument of the whole PR, has zero test coverage.

I verified by reading that all three consumers are in fact correctly rewired
(`entry_liquidity_gate.ml:3-4`, `liquidity_exit_runner.ml:49-51`,
`short_borrow_gate.ml:19-24`, plus the `entry_assembly.ml:19` call-site update).
The problem is that **nothing discriminates it**: because the default is `Mean`,
deleting `~aggregation:config.adv_aggregation` from any one of the three leaves
the entire suite green — no unit test, golden, or scenario would change. That is
exactly the "test that would still pass if the behaviour regressed" defect class,
and it is the highest-consequence one here, because the first consumer of these
axes is a WF-CV promotion surface: a silently de-threaded consumer would make the
experiment measure the wrong thing and record a wrong verdict in the ledger.

## Quality Score

2 — The metric layer alone would score 5 (exact-equality bit-identity pin, a
faithful LINK spoof reproduction with verified arithmetic, and every trim/median
edge case covered); the score reflects the single unpinned seam — the three
rewired consumers, whose contracts the .mli newly asserts and which no test can
distinguish from the old mean-only behaviour. The fix is ~25 lines.

## Verdict

NEEDS_REWORK

## NEEDS_REWORK Items

### CP1: Consumer rewiring to `config.adv_aggregation` is asserted in three .mli files but pinned by no test

- Finding: The PR threads `adv_aggregation` / `adv_trim_pct` into all three
  dollar-ADV consumers, and three `.mli` docstrings newly assert it —
  `entry_liquidity_gate.mli:25-27` ("over `config.adv_lookback_days` and reduced
  by `config.adv_aggregation` / `config.adv_trim_pct`"),
  `liquidity_exit_runner.mli:57-58` (same claim for the held-position exit), and
  `short_borrow_gate.mli:57-61` ("measures dollar-ADV on **exactly the same
  basis** as the entry gate and the held-position exit"). No test exercises any
  of the three adapters. `Entry_liquidity_gate` is referenced by **no** test file
  in the repo at this SHA; `test_short_borrow_gate.ml` tests only the pure
  `Short_borrow_gate.filter`, never the rewired `apply`;
  `test_liquidity_exit_runner.ml` exercises `update` only at the default `Mean`.
  A repo-wide grep confirms `Liquidity_metric.Median`, `Trimmed_mean` and
  `adv_aggregation` appear in **no** test outside `test_liquidity_metric.ml`.
  Because `Mean` is the default and is bit-identical, reverting the
  `~aggregation:` argument in any one consumer is invisible to the whole suite —
  the tests cannot discriminate the behaviour they document. This also leaves
  `experiment-flag-discipline.md` R2 only half-pinned:
  `test_adv_aggregation_axes_expand` proves the override *parses into the
  config*, not that flipping the axis changes any gate decision — a field that
  parsed but was ignored by every consumer would pass it unchanged.
- Location: `trading/trading/weinstein/strategy/lib/entry_liquidity_gate.ml:3-4`
  and `.mli:25-27`; `trading/trading/weinstein/strategy/lib/short_borrow_gate.ml:19-24`
  and `.mli:57-61`; `trading/trading/weinstein/strategy/lib/liquidity_exit_runner.ml:49-51`
  and `.mli:57-58`. Missing coverage in
  `trading/trading/weinstein/strategy/test/` (no `test_entry_liquidity_gate.ml`;
  `test_short_borrow_gate.ml:59-85` covers `filter` only;
  `test_liquidity_exit_runner.ml:91` `_armed_config` uses the default `Mean`).
- Authority: `.claude/agents/qc-behavioral.md` §Contract Pinning Checklist CP1 —
  "Each non-trivial claim in new .mli docstrings has an identified test that pins
  it." `short_borrow_gate.mli:57-61`: "Takes the whole `Liquidity_config.t`
  rather than a bare lookback so this gate measures dollar-ADV on **exactly the
  same basis** as the entry gate and the held-position exit … Measuring borrow
  supply with a different aggregation than the entry gate would be a latent
  inconsistency." `.claude/rules/experiment-flag-discipline.md` R2 — the flag
  must be genuinely searchable, i.e. setting it must change behaviour.
- Required fix: Add at least one consumer-level test that discriminates the
  aggregation threading end-to-end. The cheapest sufficient version is a single
  entry-gate test — the seam the PR's own damage narrative runs through:
  build the existing 60-bar LINK spoof shape via
  `Bar_reader.of_in_memory_bars` (the helper already used at
  `test_liquidity_exit_runner.ml:110`), call `Entry_liquidity_gate.apply` with
  `min_entry_dollar_adv = 1_000_000.0`, and assert with `elements_are` that the
  candidate is **kept** under `adv_aggregation = Mean` and **dropped** under
  `adv_aggregation = Median`. That one assertion pins the entry-gate threading,
  the R2 "the axis actually changes a decision" claim, and the PR's headline
  behavioural claim in one place. Strongly preferred, since the "same basis"
  contract is what justified the chosen direction: the analogous two-line
  additions for `Short_borrow_gate.apply` (`~liquidity_config` with `Mean` vs
  `Median`) and for `Liquidity_exit_runner.update` (a spoofed holding that
  survives under `Mean` and fires `liquidity_exit` under `Median`) — the latter
  reuses `_armed_config` and the existing bar-reader stub verbatim. If any
  consumer is deliberately left uncovered, weaken the corresponding `.mli`
  sentence so no untested contract is asserted.
- harness_gap: LINTER_CANDIDATE — "a config field that is threaded into a call
  site but whose non-default value is never exercised by any test" is
  mechanically detectable: for each new `Liquidity_config` field, grep the test
  tree for a non-default value of that field. More generally this is the
  default-off-mechanism blind spot flagged by `experiment-flag-discipline.md`
  R2, and a golden scenario parameterised on `adv_aggregation` would pin it
  deterministically.

### Non-blocking nits (not FAILs, no rework required)

- `liquidity_metric.ml:41` — the `_trim_count` docstring sentence "Total on a
  non-finite or non-positive `trim_pct` (trims nothing) and on a `trim_pct` at or
  above one half (trims maximally)" appears to be missing a word; it does not
  parse as written.
- `liquidity_metric.mli:78-80` — "a `trim_pct` at or above `0.5` trims maximally
  (degenerating to `Median` on an odd-length window)" under-claims: with
  `k = (n-1)/2` the survivor slice is the two central observations for even `n`,
  whose mean is also the median. The even case is untested; extending
  `test_trim_pct_at_half_degenerates_to_median` to a 4-bar window would cover it.
- `_trim_count`'s `Int.min max_trim (floor (n *. trim_pct))` clamp is
  mathematically unreachable in the `trim_pct < 0.5` branch (`floor (n·p) <=
  (n-1)/2` there for all `p < 0.5`), so it is defensive only. Correct as written;
  noted so a future reader does not hunt for the test that exercises it.
