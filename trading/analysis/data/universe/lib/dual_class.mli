(** Dual-class share detection: map a ticker to the economic entity it belongs
    to, so the composition policy can keep at most one class per company.

    Today the PIT compositions can contain GOOG {i and} GOOGL, or BRK-A {i and}
    BRK-B — two share classes of one economic entity ranked as two separate
    universe members. A portfolio built on such a universe can hold both classes
    as two positions, doubling the intended exposure to one company. This module
    provides the detection used by {!Composition_policy} to collapse those.

    {1 Detection strategy}

    Two layers, checked in order:

    1. {b Known-pairs table} — a hand-maintained list grouping the tickers of
    one entity under a canonical key (e.g. [GOOG] / [GOOGL] -> ["GOOGL"]). This
    is the authoritative override: anything in the table is grouped exactly as
    the table says, regardless of the heuristic.

    2. {b Root-symbol heuristic} — strip a trailing class suffix ([-A] / [-B] /
    [.A] / [.B], etc., see {!entity_key} for the full set) and treat the
    remaining root as the entity key. Catches the common [BRK-A] / [BRK-B] ->
    [BRK] shape without an explicit table entry.

    {1 Known limits}

    The heuristic has false positives: two genuinely-distinct companies whose
    tickers differ only by a trailing [-A] / [-B] would be wrongly merged. It
    also has false negatives: dual-class pairs that share no common root and are
    not in the table (e.g. an entity using two unrelated tickers) are not
    detected. The known-pairs table is the escape hatch for both — add an entry
    to force-group or (by giving each ticker a distinct key) force-split. The
    table is intentionally small and curated, not exhaustive. *)

val known_pairs : (string * string list) list
(** [known_pairs] is [(canonical_key, members)] for the curated dual-class
    entities. Every ticker in [members] maps to [canonical_key] via
    {!entity_key}. Exposed for inspection / test pinning. *)

val entity_key : string -> string
(** [entity_key symbol] returns a stable identifier for the economic entity
    [symbol] belongs to. Two symbols return the same key iff this module
    considers them share classes of the same company.

    Resolution order:
    - If [symbol] (case-insensitively) appears in {!known_pairs}, returns that
      entity's canonical key.
    - Otherwise applies the root-symbol heuristic: uppercases, then strips a
      single trailing class marker — one of [-A] [-B] [-C] [.A] [.B] [.C] or a
      bare trailing [.] segment of length 1 — and returns the root. A symbol
      with no recognised suffix returns itself (uppercased).

    Pure: same input -> same output. *)
