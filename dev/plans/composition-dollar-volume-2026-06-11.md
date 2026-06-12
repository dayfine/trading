# Wire per-symbol dollar volume through Snapshot → composition-policy adapter

**Date:** 2026-06-11
**Track:** data-foundations (P1'.1)
**Branch:** feat/composition-dollar-volume

## Context

The just-merged universe-composition-policy stack (#1537/#1540/#1539) added a
config-driven composition policy with an ADR liquidity floor
(`adr_min_dollar_volume`). The floor drops ADR/GDR candidates whose
`avg_dollar_volume` is below a configured threshold — but it is currently
**inert** on real snapshots, because `Snapshot.entry` does not carry per-symbol
dollar volume. The CLI adapter (`Composition_policy_report.candidates_of_snapshot`)
sources volume only from an optional `?dollar_volume` map, defaulting absent
volumes to `Float.infinity` (floor never fires).

The builder (`Build_from_individuals`) already computes the trailing-60-day
avg `close × volume` per symbol (`_dollar_volume_score` → `scored.score`), uses
it to rank, then **discards** it in `_make_entry`. This task plumbs that value
into the snapshot and through the adapter so the floor can fire on a real
snapshot.

## Approach

Purely additive schema change + builder population + adapter precedence.

1. **`snapshot.{ml,mli}`** — add `avg_dollar_volume : float option [@sexp.option]`
   to `entry`. `[@sexp.option]` (ppx_sexp_conv) means an entry sexp *without*
   the field decodes to `None`, and an entry with `avg_dollar_volume = None`
   serializes *without* the field — so existing 4-field goldens load unchanged
   and round-trip byte-identically.

2. **`build_from_individuals.ml`** — `_make_entry` sets
   `avg_dollar_volume = Some scored.score`. Decomposition (`Build_from_index`)
   keeps emitting `None` (no real volume) — verified it constructs entries
   without this field, which `[@sexp.option]` makes legal.

3. **`composition_policy_report.{ml,mli}`** — `candidates_of_snapshot`
   precedence for `avg_dollar_volume`:
   `?dollar_volume` map override (if symbol present) → else `entry.avg_dollar_volume`
   (if `Some`) → else `Float.infinity` (unchanged conservative default).

4. **Tests** (`test/`):
   - `test_snapshot.ml`: a 4-field entry sexp (no `avg_dollar_volume`) loads
     with `avg_dollar_volume = None`; and a `Some` entry round-trips.
   - `test_build_from_individuals.ml`: emitted entries carry
     `avg_dollar_volume = Some <close*volume>` (AAA = 100M, BBB = 50M, CCC = 20M).
   - `test_composition_policy_report.ml`: ADR floor fires using the entry's own
     volume (drop below floor, keep above); explicit `?dollar_volume` map still
     overrides the entry value.

## Backward-compat risk + verification

The load-bearing risk: 297 checked-in goldens under
`trading/test_data/goldens-custom-universe/` use the 4-field entry shape. A
non-optional field, or `[@sexp.default]` on a non-option, would break their
decode (`Of_sexp_error`) and fail the full `dune runtest`.

`[@sexp.option]` is the correct ppx for a `_ option` field that should be
omitted entirely when `None`:
- absent field → `None` (old goldens load)
- `Some v` → field present (new emissions carry it)
- `None` → field omitted (decomposition / synthetic snapshots round-trip clean)

**Verification:** run the *full* `dune runtest` (not just the universe dir) —
the golden-loading paths decode all 297 goldens; a sexp regression surfaces
there. Also a dedicated `test_snapshot` case pins the 4-field-decode-to-None
behaviour directly.

## Acceptance criteria

- `dune build @fmt` clean; `dune build && dune runtest` exit 0.
- 297 goldens load unchanged (full runtest green; dedicated decode test green).
- Builder-emitted entries carry `Some score`; decomposition emits `None`.
- ADR floor fires on a snapshot built from entry volumes; `?dollar_volume`
  override still wins.
- Default (`adr_min_dollar_volume = None`) behaviour bit-identical to today.

## Out of scope

- Regenerating the 297 goldens with volumes populated.
- Running `apply_composition_policy.exe` bulk → `goldens-custom-universe/composition/`
  (P1'.2, data-gated on the maintainer-local bar store).
- Any `trading/trading/` change (A2 boundary).
