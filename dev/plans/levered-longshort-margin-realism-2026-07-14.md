# Levered long-short realism — proper margin management + squeeze robustness

**Status: PLANNED** (user-directed 2026-07-14). Design-only; no build dispatched.
**Owner:** unassigned. **Prereq reading:** `dev/notes/rune-capped-2026-07-14.md`
(the E-capped decomposition), `dev/notes/long-short-margin-mechanics-2026-06-12.md`
(sub-$17 maintenance tiers), memory `project_short_realism_p0`.

## Why (user-aligned framing, 2026-07-14 discussion)

Long-short with leverage is a legitimate configuration to test — the short
leg does NOT need standalone edge (P1a showed hedge-shaped value: pays in
early bears at ≈$0 direct PnL). The bar is **honest costs**: old Run E's
+22,097% used free leverage (no borrow fee, no long margin interest, no
maintenance risk) and is fiction; E-capped (#1965, cap 1.0) is honest but
UNLEVERED. The missing piece is a margin model that prices leverage and
survives squeezes.

**Current state — the two mechanisms are orthogonal complements, neither
subsumes the other:**

- `Trading_portfolio.Margin_config` (#859/#1266, default-off): SHORT-side
  only — initial collateral (default 50% extra), maintenance force-cover
  (25%), borrow fee (50bps/yr flat). No long-side concept.
- `max_long_exposure_pct_entry` (#1965, default-off): LONG-side only —
  entry-walk bound on committed-at-entry long notional vs marked NAV.
  Currently the ONLY thing stopping short proceeds from levering the long
  book.

## Design principle

**Generalize the #1965 cap seam into long buying power; do not build a
parallel mechanism.** "Committed long ≤ 1.0 × NAV" is the degenerate case of
"long buying power at 100% initial margin requirement." The gate,
accumulator, audit skip-reason, and exit-safety scope (#1553: never blocks
exits) all carry over unchanged.

## Work items

### M1 — Long buying power (generalize #1965)
- New field `initial_long_margin_req : float [@sexp.default 1.0]` (1.0 =
  cash account = exact current cap-1.0 semantics; 0.5 = Reg-T 2× buying
  power). Entry-walk limit becomes `equity / initial_long_margin_req`.
  Keep `max_long_exposure_pct_entry` as-is for back-compat (min of the two
  applies; flag-discipline R1: defaults change nothing).
- Track a `borrowed_balance` when committed > cash: daily long margin
  interest (new config: `long_margin_rate_annual_pct`, default 0 = R1).
  Old-E-style leverage becomes PRICED.

### M2 — Long-side maintenance
- Marked-basis maintenance check for the LONG book (margin loans get called):
  `equity / marked_long_exposure < maintenance_long_pct` → force-reduce
  (sell weakest holdings first — needs an explicit, documented ordering; the
  Portfolio_floor bottom-tick lesson says the ORDER is where these mechanisms
  go wrong). Weekly-close cadence to match the strategy spine.
- This is the piece the entry cap deliberately ignores (it never force-trims)
  — under real leverage that is no longer safe.

### M3 — Short-side squeeze robustness (gaps in the existing model)
- **Borrow availability**: per-symbol shortable flag / borrow-supply proxy
  (float, ADV-based heuristic on our data; we have no locate feed).
  Unavailable → entry skipped (audit reason).
- **Hard-to-borrow rates**: replace flat 50bps with a tiered rate (e.g.
  price- and size-tiered per long-short-margin-mechanics-2026-06-12:
  sub-$17 names carry 83-362% maintenance — encode the maintenance tier
  table too, superseding the flat 25%).
- **Buy-in risk**: probabilistic forced cover on HTB names (config-gated,
  default off) OR at minimum a stress-path mode for the promotion grid.
- Cadence caveat documented: bar-cadence marks cannot see intraweek gap
  squeezes; stress paths must include gap-through-maintenance scenarios.

### M4 — Validation protocol (before any levered number is quoted)
1. Parity gates: M1 at (1.0, rate 0) bit-identical to E-capped; margin-off
   bit-identical to baseline (R1 each step).
2. GME-window + 2008 + dot-com stress cells for the short book (the
   squeeze-shaped windows); force-cover ordering audited per event.
3. Then the leverage surface via experiment-gap-closing: initial_long_margin
   ∈ {1.0, 0.75, 0.5} × short sleeve on/off, WF-CV + Deflated Sharpe;
   promotion-confirmation grid with a bear-regime cell. Expectation
   management: leverage amplifies BOTH tails; the honest question is whether
   priced leverage + hedge value clears the unlevered frontier, not whether
   MTM goes up.

## Sizing
M1 ≈ #1965-sized (small); M2 medium (force-reduce ordering + tests); M3
medium-large (data heuristics + tier tables); M4 = runs. Each lands
default-off behind its own field (R1/R2 per item).

## Explicitly NOT in scope
- Arming any of this in the record convention (Run D long-only remains the
  record basis).
- Intraday margin simulation (cadence is a documented limitation, not a work
  item).
- Reversal-timing or short-alpha claims (NO-reversal-timing directive
  stands; the short leg is priced as hedge/financing, not alpha).
