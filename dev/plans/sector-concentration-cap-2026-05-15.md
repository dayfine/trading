# Sector concentration cap (P1) — 2026-05-15

## Context

Cell E caps `max_long_exposure_pct = 0.70` (long-side) but has **no
per-sector exposure limit**. On 16y long-only, axis-2's catastrophic
result (MaxDD 19.9%→60.1%, 0→26 force-liqs) coincided with 26
force-liquidations — likely positions clustered in same-sector losers
during bear regimes. A `max_sector_exposure_pct = 0.30` cap could
decorrelate that failure mode.

Authority:
- `dev/notes/next-session-priorities-2026-05-15.md` §P1 — strategic pivot
  to this work today (demoted from P4).
- `dev/notes/next-session-priorities-2026-05-14.md` §P4 — original
  technical sketch.

The current `Portfolio_risk` module has:
- `max_sector_concentration : int` — counts positions per named sector.
- `sector_counts : (string * int) list` — per-sector position counts in
  `portfolio_snapshot`.
- `Sector_concentration of string * int` limit-violation variant.

What's missing: a per-sector **exposure-percent** cap (dollar notional
fraction of portfolio_value), parallel to the count-based cap that
already exists.

## Approach

Add a new optional config field `max_sector_exposure_pct : float option`
to `Portfolio_risk.config`:

- `None` (default) → no exposure cap (preserves all goldens bit-equal).
- `Some pct` → enforce that, when admitting a new position to sector S,
  `(existing_sector_exposure_S + proposed_value) / total_value <= pct`.

Touch surface, in order:

1. **`portfolio_snapshot`** — add a new field `sector_exposures :
   (string * float) list` alongside `sector_counts`. Computed by an
   internal `_compute_sector_exposures` mirroring
   `_compute_sector_counts`. Empty-string sector represents
   "unknown" — bucketed the same way as `sector_counts`.

2. **`limit_violation`** — add a new variant `Sector_exposure_exceeded
   of string * float` (sector_name, projected_pct).

3. **`config`** — add `max_sector_exposure_pct : float option`
   `[@sexp.default None]`. The `[@sexp.default]` preserves backwards
   compatibility with any existing scenario sexps that don't mention the
   field.

4. **`check_limits`** — add a `_check_sector_exposure` helper that:
   - returns `[]` when `config.max_sector_exposure_pct = None` (the
     default path; default-off bit-equality).
   - looks up `proposed_sector` in `snapshot.sector_exposures` (default
     0.0 if absent).
   - computes `(existing + proposed_value) / snapshot.total_value`.
   - emits `Sector_exposure_exceeded (sector, projected_pct)` if over
     limit.
   - **Empty-string sector**: skip the cap. Rationale: the unknown
     bucket already has its own count-cap
     (`max_unknown_sector_positions`); adding a second exposure cap on
     the same bucket compounds gates without a clear win. The named
     sector exposure cap is the intent — keep behaviour scoped to it.

5. **Strategy wiring**: extend `entry_audit_capture.classify_candidate`
   pipeline with one new gate. Add a primitive
   `check_sector_exposure_cap` (parallels `check_short_notional_cap`)
   that consults a per-sector exposure accumulator. Wire it in
   `weinstein_strategy_screening.entries_from_candidates`, seeded from
   the current portfolio state.

   - New skip reason: `Sector_exposure_cap` in
     `Audit_recorder.skip_reason`.
   - The strategy passes the sector→exposure accumulator + cap config
     into `classify_candidate`. When `None`, gate is a no-op
     pass-through (the strategy passes `Float.infinity` or wires the
     gate off entirely — see implementation note below).

   **Implementation note**: pass `~max_sector_exposure_pct :
   float option` to `classify_candidate`. When `None`, the gate is
   skipped entirely (no allocation, no accumulator updates). When
   `Some pct`, the gate accumulates and enforces.

6. **Tests**: unit tests on `check_limits` for the new violation, plus
   one integration test for the strategy gate.

### Rejected alternatives

- **Compute sector_exposures inline in `_check_sector_exposure`**
  (not store in snapshot): rejected because `check_limits` is meant to
  be a pure function over a pre-computed snapshot. Storing it in the
  snapshot is consistent with `sector_counts`.

- **Single combined `max_sector_concentration_pct` field (replacing or
  unifying with `max_sector_concentration : int`)**: rejected. The
  count-cap and the exposure-cap have different semantics: a small
  position contributes 1 to count but ~0% to exposure. Keep them
  separate; the two compose.

- **Per-sector exposure cap in addition to overall long-exposure cap
  symmetrically across long/short**: rejected for scope. The cap is
  applied symmetrically (long + short positions to the same sector
  count toward the same bucket) — that matches the existing
  `sector_counts` semantics. The 30% number from the priorities note
  is a single number, not per-side.

## Files to change

| File | Change |
|---|---|
| `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.mli` | Add `sector_exposures` field to snapshot; new `Sector_exposure_exceeded` variant; new `max_sector_exposure_pct : float option` field on config |
| `trading/trading/weinstein/portfolio_risk/lib/portfolio_risk.ml` | Implement `_compute_sector_exposures`, plumb through `_make_snapshot` and `snapshot`/`snapshot_of_portfolio`; add `_check_sector_exposure`; default `max_sector_exposure_pct = None` |
| `trading/trading/weinstein/portfolio_risk/test/test_portfolio_risk.ml` | Update `make_snapshot` helper (new field); update existing `match_snapshot` calls to include the new field (set `__`); add 4-5 new tests for the exposure cap |
| `trading/trading/weinstein/strategy/lib/audit_recorder.{ml,mli}` | New `Sector_exposure_cap` skip reason |
| `trading/trading/weinstein/strategy/lib/entry_audit_capture.{ml,mli}` | New `check_sector_exposure_cap` primitive; thread accumulator + cap through `classify_candidate`; emit `Sector_exposure_cap` skip |
| `trading/trading/weinstein/strategy/lib/weinstein_strategy_screening.ml` | Seed sector-exposure accumulator from `portfolio` and `sector_map`; pass through into `classify_candidate` |

Maybe also touched (callers of `portfolio_snapshot`):
- Other tests or fixtures that pattern-match `portfolio_snapshot` —
  add explicit `sector_exposures` if any are exhaustive.

## Risks / unknowns

1. **Snapshot field addition is interface-widening**. All callers that
   pattern-match `portfolio_snapshot` exhaustively must add the new
   field. I'll grep for them and update in the same PR. The test file
   uses a re-declared record type via `[@@deriving test_matcher]` which
   raises a compile error if a field is added — exactly the pattern we
   want for safety.

2. **Default-off check** — the default `max_sector_exposure_pct = None`
   path **must** bit-equal current behaviour. Verify by running
   `dune runtest --force` after the wiring lands and confirming no
   golden diffs.

3. **Sector accumulator seeding**. The strategy must seed the
   accumulator from existing `Holding` positions, similar to the
   `_initial_short_notional` pattern. Long + short positions contribute
   the absolute value of their notional to the sector bucket.

4. **G15-flavor decision: should this gate fire before or after the
   cash gate?** The short-notional cap fires _after_ cash. I'll match
   that pattern — sector cap fires last. This keeps the cash-and-cap
   walk in a consistent order.

5. **Empty-string sector**: explicitly skipped in the gate (see
   approach §4). The count-cap `max_unknown_sector_positions` handles
   the unknown bucket separately.

## Acceptance criteria

- [ ] `Portfolio_risk.config` has a new `max_sector_exposure_pct :
      float option` field defaulting to `None`.
- [ ] `portfolio_snapshot` has a new `sector_exposures : (string *
      float) list` field, computed in parallel to `sector_counts`.
- [ ] New `Sector_exposure_exceeded of string * float` limit violation.
- [ ] `check_limits` enforces the cap on named sectors only (skips
      empty-string bucket).
- [ ] Unit tests:
  - Default `None` → cap doesn't fire even when concentration is high.
  - `Some 0.30` with sector at 28% → admit a 3% candidate fails
    (projected 31%).
  - `Some 0.30` with sector at 20% → admit a 5% candidate passes
    (projected 25%).
  - Empty-string sector is exempt from the exposure cap.
- [ ] Strategy gate `check_sector_exposure_cap` filters at entry-walk
      time; emits `Sector_exposure_cap` skip reason.
- [ ] Default-off → `dune runtest --force` passes bit-equal (no golden
      diffs).
- [ ] `dune build && dune fmt && dune runtest --force` passes clean.

## Out of scope

- **No 16y sp500 backtest experiment in this PR**. The maintainer's
  note explicitly defers that to a `feat-backtest` follow-up
  experiment.
- **Long-only and long-short symmetry beyond the natural one**: the
  cap is one number, applied to absolute position value summed per
  sector. No per-side splitting.
- **Big-winner override**: no escape hatch for high-conviction trades.
  If the maintainer wants it later, it can be added orthogonally.
- **Status-file index update** — the orchestrator owns that.
