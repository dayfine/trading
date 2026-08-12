# Plan — asynchronous faithful entry ticket (faithful-v2), 2026-08-10

Supersedes/extends `dev/plans/entry-ticket-right-basis-2026-08-08.md` (built
and A/B'd as ladder v3 — results + trade dissection:
`dev/notes/ladder-v3-faithful-stoplimit-2026-08-09.md`). **Nothing here is
built** — this is the next-session engineering brief for feat-agents.

Produced by a plan-writer pass reconciled against an adversarial book review
(both 2026-08-10). Review verdict: SOUND-WITH-AMENDMENTS; all amendments are
folded in below. Governing rules:
`.claude/rules/experiment-flag-discipline.md` (R1/R2/R3),
`.claude/rules/weinstein-faithful-core.md` (spine vs dials, argued per flag),
`.claude/rules/promotion-confirmation.md` (WF-CV + grid before promotion).

## 1. Motivation + evidence

Ladder v3 (top-3000, 26y): faithful-StopLimit arms w4 **+318%** / Sharpe 0.46,
w13 **+262%** / 0.42 vs record-nextopen **+7,321%** and book-honest +310%.
Dissection: the ~23× gap is **structural exclusion of crash-recovery
monsters** (AXTI +$56.2M in record, 0 trades in faithful arms, 22–28×
`Stop_too_wide` on the exact record entry Fridays; same SKYW 2023-03-17, BPT
2022-01-21). Trade counts nearly equal (1,139 vs 1,121): the walk **backfills**
dropped wide-range names with calm-base names — adverse selection against the
fat tail, not selectivity.

**The elephant (book review, load-bearing):** on the book's own text,
Weinstein would likely PASS on AXTI at 2.71 — §4.3 grades the 2.71→4.03 crash
range immediately overhead as C/Heavy ("stock will use up buying power getting
through this zone"), the near-term ceiling caps un-fought upside at ~+49%
against a 36% structural stop (~1:1 reward/risk), and §5.1 says >15% risk →
"prefer other candidates." **A faithful process may legitimately exclude the
monsters. AXTI-capture is NOT the success criterion of this plan.** The
success criteria are: (a) process fidelity (asynchronous ticket = the book's
actual mechanics), (b) capture of *book-qualified* wide-range names (§4.5
triple-confirmation cohort, see F6), (c) elimination of the backfill
anti-selection. Each ladder-v4 arm must state whether overhead grading gates
it; SKYW/BPT overhead profiles must be re-checked before citing them as
expected wins.

## 2. The three timing mis-mappings

### M1 — the stage clock starts at the wrong event
Book §1: "Stage 2 **begins when** the stock breaks out above the top of the
resistance zone AND above the 30-week MA" — and Stage 1 explicitly has price
tossing above/below the MA for months. Our classifier starts `weeks_advancing`
at the MA cross, so AXTI (10 weeks above its MA, below its 2.71 range top —
still *basing*, by the book) aged out of `early_stage2_max_weeks ≤ 4` before
its actual breakout, the book's Stage-2 week one. Freshness for the ticket
family must be measured from the **range-top breakout**, not the MA cross.

### M2 — synchronous Friday screen vs the book's asynchronous place-then-wait
Book §4.7: spot the setup → write a **GTC buy-stop** above the range top
("Buy 1,000 XYZ at 12⅛ stop – 12⅜ limit – GTC … you may be surprised two or
three weeks later") → **the fill is the breakout** → volume is judged AT the
breakout, not at placement (breakout-week volume cannot be known when the
order is written — the current screen-time volume requirement is the
unfaithful one; §1 even notes base volume "dries up", so demanding screen-week
volume selects against textbook bases). Our cascade requires stage + volume +
breakout-candidacy + risk gate at one Friday instant *before* placing. GTC
persistence already works (`test_gtc_entry_persistence.ml`); **placement is
the bottleneck.**

### M3 — gate semantics don't transfer across entry models
`early_stage2_max_weeks ≤ 4` and the 15% `max_stop_distance_pct` drop-filter
were WF-CV-validated under the MARKET-entry model, where they are load-bearing
(a stale market entry = mid-run buy without structure). Under a resting
breakout ticket **the ticket itself is the discipline** — it fills only on a
fresh cross — so the screen-time freshness gate is redundant-to-harmful (M1)
and the hard drop at 15% amputates (fixed-risk sizing already scales shares
~1/stop_distance; a 36% stop buys ~2.4× fewer shares, never zero).

## 3. Design — mechanisms (all default-off no-op `Weinstein_strategy_config`
fields, single-component `Variant_matrix` axes on landing; F2/F3/F5/F6
activate only when the StopLimit family — `enable_sim_entry_stoplimit` +
`sim_entry_trigger_at_suggested` — is armed; `stop_anchor_at_entry_base` is
retired from this family's armed set)

Base composition: StopLimit family + `entry_anchor_local_range_weeks` +
`freeze_entry_at_first_breakout` + `sim_entry_fill_next_open`, stop = support
floor.

### F1 — `entry_freshness_basis : Ma_cross | Range_top_breakout [@sexp.default Ma_cross]`
- No-op `Ma_cross` = today's clock, bit-identical.
- Armed: admission freshness measured from the breakout above the ticket
  anchor. Admit iff close ≥ (1 − 5%) × anchor top (setup live, breakout
  pending). The MA-cross age is not consulted, **but the §4.1 conditions
  remain explicit in the admit rule: MA flat-or-rising AND trigger above the
  MA** ("breakout below a declining MA is a trap, not a buy" — Western Union;
  interaction with the #1775 `reject_declining_ma_long_entry` gate documented
  in the PR). The already-broken-out disjunct is **dropped** (its book shape
  is the pullback second-chance / continuation buy — out of scope, and #1366
  fenced; F1 must not become a stealth re-run of the rejected
  continuation/early-admission axes: the ≤4-week *value* stays frozen in v4,
  only the basis changes).
- Anchor caveat (book review): the book's anchor is "the top of the CURRENT
  trading range", and bases "can last months or years" — a 4–8-week local
  high can be an intra-base swing high. v4 adds a **base-extent anchor**
  variant (max high since the 30-wk MA flattened, capped at
  `base_lookback`) alongside `{4,8}`; treat the short windows as the
  aggressive cells, not the definition.
- Touches: `Stock_analysis.config` + `is_breakout_candidate`, threaded via
  `_stock_analysis_config_for` (same route as `entry_anchor_local_range_weeks`).
- Faithfulness: BOOK-SUPPORTED (§1 Stage-2 definition); moves the clock to the
  book's own Stage-2 start event. Spine intact; the crossing requirement is
  *enforced better* (ticket cannot fill without the cross).

### F2 — `entry_order_ttl_weeks : int [@sexp.default 0]` + re-screen cancel
- No-op `0` = today's behaviour (weekly re-issue; GTC-forever persistence).
- Armed: the **primary** cancellation is condition-based — a resting ticket
  whose symbol fails the next weekly re-screen (base broken down, MA rolls
  declining, sector/macro gate flips) is cancelled; the clock TTL (N weeks
  unfilled) is the **backstop**. This is what §4.7's "until you either cancel
  the orders or they are actually executed" plus the §7 weekend-homework loop
  actually imply; the book gives cancel authority but no number (dial).
  Cancel releases the `Entering` position and the `Entry_freeze` pin (the
  symbol may re-qualify later with a fresh E).
- Touches: strategy screening tick (age + requalification tracking),
  simulator cancel path (`cancel_handler.ml`), `Entering → released`.
- Faithfulness: BOOK-NEUTRAL dial (order-level staleness = "the setup
  expired"); 13-weeks-no-revalidation is the least book-like cell.

### F3 — `stop_width_mode : Drop_over_max | Size_down [@sexp.default Drop_over_max]`
- No-op = today's G15 step-3 drop, bit-identical.
- Armed `Size_down`: candidate admitted; fixed-risk sizing scales shares
  ~1/stop_distance; `max_stop_distance_pct` becomes the sanity ceiling; audit
  tag `Sized_down_wide_stop`.
- **Honest citation (book review): NOT a documented book mechanism.** §5.1's
  "prefer other candidates" is comparative, not an absolute ban, but the
  book's remedies for a wide stop are (i) anchor at the nearest prior
  correction low, (ii) the trader 4–6% stop, (iii) pass — never risk-parity
  size-down. F3 is a tolerated-participation *reading*, labeled as such.
- **Competing faithful arm (added per review):** `stop_anchor_nearest_floor`
  — anchor the initial stop at the **nearest qualifying prior correction
  low** (not the deepest/crash floor), which shrinks stop distance the book's
  own way instead of shrinking shares. Field:
  `support_floor_anchor_mode` already has an anchor-mode surface in
  `Weinstein_stops` — extend with a `Nearest` variant if absent (verify at
  build time; default unchanged).
- Touches: G15 gate in `entry_audit_capture.ml`, sizing in `entry_walk.ml`.

### F4 — `max_stop_distance_pct` sweep `{0.15, 0.25, 0.35, 0.50}` — pure axis
No code. **0.35/0.50 are pre-registered as diagnostic-only cells**: promoting
either would be an explicit, documented deviation from §5.1 (15%) — and §5.3's
trader preset is 4–6%, so wide values are defensible under *no* book reading.
They exist to measure where the exclusion binds, not to become defaults.

### F5 — `volume_confirm_at_fill : bool [@sexp.default false]`
- No-op = today's screen-time volume requirement, bit-identical.
- Armed (StopLimit family only): placement no longer requires the screen-week
  volume signal (stage/base/RS/resistance/macro/sector gates still apply);
  on fill, confirm the breakout volume; unconfirmed ⇒ **eject** at next fresh
  open (`Volume_eject` audit tag), confirmed ⇒ hold. Evaluated on the first
  tick after the fill week completes (no partial-week lookahead).
- **Amendments folded in (review):** (i) the eject is **inseparable from the
  flag** — no eject-off cell exists (a held volume-unconfirmed breakout is a
  W1 spine FAIL); (ii) implement BOTH §4.2 confirmation branches — fill-week
  ≥2× prior-4-week average OR 3–4-week volume build-up ≥2× with some increase
  on breakout week — fill-week-only would eject book-valid breakouts;
  (iii) **pre-build TODO:** verify the source book's low-volume-breakout sell
  passage and add it to `weinstein-book-reference.md` §4.2/§4.7 with a
  chapter cite (the distilled doc currently lacks the explicit sentence);
  (iv) a later trader/investor variant (`eject | hold_with_stop_at_breakout`)
  is noted but NOT in v4.
- Faithfulness: BOOK-SUPPORTED structurally — §4.7's GTC ticket precedes the
  breakout, §4.2's confirmation is defined on the breakout week; spine item 3
  is preserved and relocated to the correct event.

### F6 — §4.5 triple-confirmation tag (audit feature, no gate)
Capture on every placed ticket: breakout-volume multiple, RS zero-cross
flag, pre-breakout in-base advance % (book: ≥40% = accumulation signature —
National Semiconductor, Blocker Energy). This is the book's **native
discriminator for exactly the wide-range population** and its sanctioned
reason to tolerate imperfect overhead. v4 reads it as a captured feature
(does the triple-confirmed cohort contain the monsters?); a later plan may
promote it to a gate — the faithful alternative to F3.

### Preset statement (W3, per review)
The v4 arms run **full-size tickets (trader sizing dial) on the investor
stop/exit base** — a deliberate choice: scale-in (½ + ½) was built and
REJECTED (#1855 arc, fat-tail tax). One sentence in each scenario header
acknowledges the mix.

## 4. Build order — small PRs, TDD, each <500 lines

| PR | content | tests (write first) |
|---|---|---|
| PR-1 | F1 basis variant + threading + §4.1 conditions explicit | synthetic AXTI shape (10 wks above MA below range top): `Ma_cross` rejects at wk 5+, `Range_top_breakout` admits; declining-MA variant rejects under BOTH; breakout week admits under both; default bit-identical |
| PR-2 | F3 `stop_width_mode` + `Sized_down_wide_stop` + nearest-floor anchor arm | 36% floor: `Drop_over_max` skips (pin current), `Size_down` admits at ~risk_budget/stop_distance shares; ceiling still drops above swept max; nearest-floor mode picks the shallower qualifying low; default bit-identical |
| PR-3 | F2 TTL + re-screen cancel + pin release | unfilled ticket cancelled on requalification failure and on week N+1; `Entry_freeze` pin released and re-pinnable; `0` never clock-cancels (extends, does not weaken, `test_gtc_entry_persistence`); fill at week N−1 unaffected |
| PR-4 | F5 both-branch volume confirm + `Volume_eject` runner | fill-week 2× confirms; 3–4-wk build-up branch confirms; neither ⇒ eject at next fresh open; unfilled ⇒ no check; default bit-identical. **Blocked on the §4.2 source-verification TODO** |
| PR-5 | audit fields: placement date, ticket age at fill/cancel, fill-week volume ratio, freshness basis, F6 triple-confirmation tag | sexp-shape golden only; no behaviour change |
| PR-6 | ladder v4 scenario specs + overlays; commit the v3 scenario sexps (w4/w8/w13) for reproducibility | `Overlay_validator` round-trip of every axis |

PR-1/PR-2 independent; PR-3 before PR-4. Every PR cites this plan + book
section and states R1/R2 compliance.

## 5. Experiment design — ladder v4

Comparators (fixed): record-nextopen +7,321%; book-honest +310%; faithful w4
+318% / w13 +262%. Same window/universe as v3.

Axes over the v2 base: anchor ∈ {4, 8, base-extent} × freshness basis ×
TTL {0, 4, 8} × (Drop_over_max×{0.25, 0.35ᵈ, 0.50ᵈ} | Size_down×{0.50ᵈ} |
nearest-floor×{0.15}) × volume_confirm {f, t}  (ᵈ = diagnostic-only cells).
Prune to ~24 cells: one-axis-at-a-time deltas off a single v2-core cell
first, then the best-composed cell. **Each arm's header states whether
overhead grading gates it.**

Predictions (recorded before running; falsifiable):
1. Fewer fills than w13's 1,139 (no backfill churn; TTL + placement-only
   discipline); composition shifts back toward wide-range names.
2. **Conditional tail participation:** in cells without an overhead gate,
   AXTI's ticket (placed ~Jun 2025 above 2.71) fills late Aug 2025 at reduced
   size under Size_down / wide-max; SKYW 2023-03 and BPT 2022-01 enter
   *subject to their overhead re-check*. In overhead-gated cells the monsters
   may stay excluded — **that outcome is book-legitimate, not a failure**;
   the informative read is the F6 tag: does triple-confirmation separate
   book-qualified monsters from junk?
3. `Range_top_breakout` freshness moves more than TTL (M1 is the binding
   exclusion for AXTI-class bases).
4. `volume_confirm_at_fill` cuts false-breakout stop-outs at small return
   cost (eject class ≈ the whipsaw class).

If (1) fails or the composition does not shift, the mis-mapping model is
wrong — stop and re-dissect; no knob-search. Any surviving cell family goes
through `experiment-gap-closing` WF-CV (Deflated Sharpe) → ledger → the
promotion-confirmation grid (≥3 period×universe cells, one spanning
2000-02+2008). No default flips in this plan's scope.

## 6. Risks / open questions

- Size-down × portfolio caps: tiny positions may round to zero via
  min-notional/liquidity gates — audit `Sized_down_wide_stop` share counts.
- TTL × freeze: cancel must release the pin; re-placement must not ratchet E
  weekly. Pin-lifecycle test in PR-3 is load-bearing.
- Resting-ticket capacity: does the entry walk treat unfilled `Entering` as
  committed cash? If yes, resting tickets crowd live entries and TTL is
  capital-recycling-critical — quantify (resting count per week in audit).
- Gap-over-band no-fills: crash-recovery names gap; measure the gap-skip rate
  on the monster cohort (the pullback second-chance ticket — out of scope —
  is the book's recovery path for these; its absence makes v4 under-capture
  relative to the book and inflates the measured eject/whipsaw cost).
- Volume confirm waits to week-end; eject executes at next fresh open — the
  eject cost is part of the measured arm.
- `virgin_crossing_readmission` (default-on) overlap: AXTI-class names are
  NOT virgin (heavy overhead) — F1 must compose without double-counting;
  PR-1 tests state this.
- F5 widens the placed-ticket population (volume no longer required at
  placement); macro/sector/RS/stage still bound it — watch placed counts.
- F1's admit-rule anchor and the ticket anchor must be the SAME level or the
  freshness test and the ticket drift apart.

## 7. Explicitly out of scope

Default flips or preset changes (R3); live order-gen arming; short-side
mirrors; pullback second-chance tickets (noted as the book's paired mechanism
— candidate for v5 if v4's gap-skip/eject costs are material); scale-in
re-litigation; `stop_anchor_at_entry_base`; GTC semantics for non-entry
orders; intraday fill-model changes beyond what `test_gtc_entry_persistence`
pins.
