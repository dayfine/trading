open Core
open Weinstein_types

type candidate_ranking = Alphabetical | Quality [@@deriving sexp, eq]
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

(** Tiebreak comparator among equal-score candidates, parameterised by the
    ranking mode. [Alphabetical] is bit-identical to the historical ticker-only
    tiebreak; [Quality] applies {!_quality_keys} lexicographically. *)
let _tiebreak ranking a b =
  match ranking with
  | Alphabetical -> String.compare a.ticker b.ticker
  | Quality ->
      List.find_map _quality_keys ~f:(fun cmp ->
          match cmp a b with 0 -> None | c -> Some c)
      |> Option.value ~default:0

let compare_rankable ranking a b =
  let by_score = Int.compare b.score a.score in
  if by_score <> 0 then by_score else _tiebreak ranking a b
