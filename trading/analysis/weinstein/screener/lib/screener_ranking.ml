open Core
open Weinstein_types

type candidate_ranking =
  | Alphabetical
  | Quality
  | Quality_earliness
  | Reverse_alphabetical
  | Symbol_length
  | Hash_order
[@@deriving sexp, eq]

type rankable = { score : int; ticker : string; analysis : Stock_analysis.t }

(** Continuous relative-strength magnitude for the [Quality] tiebreak.

    Uses the Mansfield zero-line position ([current_normalized]) the RS analysis
    already carries — Weinstein selects by RS strength vs the market, and a
    higher-RS leader is preferred (weinstein-book-reference.md §Relative
    Strength; spine item 7). [None] RS (insufficient history) sorts last via
    [Float.neg_infinity]. *)
let _rs_magnitude (r : rankable) =
  match r.analysis.rs with
  | Some rs -> rs.current_normalized
  | None -> Float.neg_infinity

(** Earliness key for the [Quality] tiebreak: [weeks_advancing] for a Stage-2
    candidate. {e Smaller is earlier} and preferred — Weinstein warns against
    buying an extended Stage 2 (weinstein-book-reference.md §Stage 2:
    Advancing). Non-Stage-2 candidates (rare at this point in the cascade) sort
    last via [Int.max_value]. *)
let _weeks_advancing_key (r : rankable) =
  match r.analysis.stage.stage with
  | Stage2 { weeks_advancing; _ } -> weeks_advancing
  | _ -> Int.max_value

(** Volume-expansion magnitude for the [Quality] tiebreak: [volume_ratio]
    (event-volume / avg-volume). Higher expansion is a stronger breakout
    confirmation (weinstein-book-reference.md §4.2 Volume Confirmation). [None]
    volume sorts last via [Float.neg_infinity]. *)
let _volume_ratio_key (r : rankable) =
  match r.analysis.volume with
  | Some v -> v.volume_ratio
  | None -> Float.neg_infinity

(** The ordered [Quality]-tiebreak keys, as a lexicographic comparator chain.
    Each entry compares so the {e preferred} candidate sorts first: RS magnitude
    descending, then [weeks_advancing] ascending (earlier Stage 2), then volume
    ratio descending, then ticker ascending as the final deterministic fallback.
    {!List.find_map} returns the first non-zero comparison — equivalent to the
    nested if-chain but flat. *)
let _quality_keys =
  [
    (fun a b -> Float.compare (_rs_magnitude b) (_rs_magnitude a));
    (fun a b -> Int.compare (_weeks_advancing_key a) (_weeks_advancing_key b));
    (fun a b -> Float.compare (_volume_ratio_key b) (_volume_ratio_key a));
    (fun a b -> String.compare a.ticker b.ticker);
  ]

(** The [Quality_earliness]-tiebreak keys: same primitives as {!_quality_keys}
    but with {b earliness primary}. [weeks_advancing] ascending (prefer the
    FRESHEST Stage-2 breakout) leads, then RS magnitude descending, then volume
    ratio descending, then ticker ascending as the deterministic fallback.

    This is the most faithful reading of "do not buy an extended Stage 2"
    (weinstein-book-reference.md §Stage 2: Advancing): among equal-score ties it
    picks the earliest setup rather than the highest-RS (= most extended) one.
    Contrast {!_quality_keys}, which leads with RS and so preferentially selects
    already-run-up names — the behaviour the 2026-06-29 breadth grid rejected
    (ledger [2026-06-29-candidate-ranking-tiebreak-grid]). *)
let _quality_earliness_keys =
  [
    (fun a b -> Int.compare (_weeks_advancing_key a) (_weeks_advancing_key b));
    (fun a b -> Float.compare (_rs_magnitude b) (_rs_magnitude a));
    (fun a b -> Float.compare (_volume_ratio_key b) (_volume_ratio_key a));
    (fun a b -> String.compare a.ticker b.ticker);
  ]

(** First non-zero comparison in a lexicographic key chain; [0] (equal) when all
    keys tie. *)
let _lex keys a b =
  List.find_map keys ~f:(fun cmp ->
      match cmp a b with 0 -> None | c -> Some c)
  |> Option.value ~default:0

(** Cross-platform-stable pseudo-random hash of a ticker — the 32-bit FNV-1a
    (offset basis [0x811c9dc5], prime [0x01000193], masked to 32 bits each
    step).

    FNV-1a is used deliberately over a plain rolling [h = h*31 + byte]: the
    latter is {b monotonic in string length} (each extra byte multiplies by 31,
    so a 1-char ticker always hashes below any 2-char ticker), which collapses
    "hash order" into "length order" — observed 2026-06-30 when [Hash_order]
    produced bit-identical results to [Symbol_length]. FNV-1a's
    XOR-before-multiply diffuses bits so the value is uniform w.r.t. length,
    giving a genuine (but reproducible) pseudo-random order. The 32-bit mask
    keeps it [Core]-polymorphic- hash-free and identical across the macOS/Linux
    toolchain (the determinism hazard that motivated [Alphabetical], see
    {!_top_n}); intermediate products stay well under 2^63 (≈2^56) so there is
    no OCaml-int overflow. Hash collisions fall back to [ticker]. *)
let _ticker_hash s =
  String.fold s ~init:0x811c9dc5 ~f:(fun h c ->
      h lxor Char.to_int c * 0x01000193 land 0xffffffff)

(** Diagnostic {b control} tiebreaks — NOT return-seeking, NOT intended for
    default use. They are deliberately {e uninformative} sorts (reverse-ticker,
    symbol length, deterministic pseudo-random hash) used to bracket the
    {e noise floor} of the equal-score tiebreak: if every uninformative sort
    performs alike and the informative ones ([Quality] / [Quality_earliness])
    sit inside that band, then no sort beats unbiased sampling
    (project_edge_is_the_fat_tail). All deterministic (ticker as final fallback)
    for reproducible backtests. *)
let _reverse_alphabetical_cmp a b = String.compare b.ticker a.ticker

let _symbol_length_cmp a b =
  match Int.compare (String.length a.ticker) (String.length b.ticker) with
  | 0 -> String.compare a.ticker b.ticker
  | c -> c

let _hash_order_cmp a b =
  match Int.compare (_ticker_hash a.ticker) (_ticker_hash b.ticker) with
  | 0 -> String.compare a.ticker b.ticker
  | c -> c

(** Tiebreak comparator among equal-score candidates, parameterised by the
    ranking mode. [Alphabetical] is bit-identical to the historical ticker-only
    tiebreak; [Quality] leads with RS magnitude; [Quality_earliness] leads with
    earliness; the rest are uninformative {!_reverse_alphabetical_cmp} /
    {!_symbol_length_cmp} / {!_hash_order_cmp} controls. *)
let _tiebreak ranking a b =
  match ranking with
  | Alphabetical -> String.compare a.ticker b.ticker
  | Quality -> _lex _quality_keys a b
  | Quality_earliness -> _lex _quality_earliness_keys a b
  | Reverse_alphabetical -> _reverse_alphabetical_cmp a b
  | Symbol_length -> _symbol_length_cmp a b
  | Hash_order -> _hash_order_cmp a b

let compare_rankable ranking a b =
  let by_score = Int.compare b.score a.score in
  if by_score <> 0 then by_score else _tiebreak ranking a b
