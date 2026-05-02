open Core

type score_change = {
  symbol : string;
  v1_score : float;
  v2_score : float;
  delta : float;
}
[@@deriving sexp, eq, show]

type rank_change = {
  symbol : string;
  v1_rank : int;
  v2_rank : int;
  delta : int;
}
[@@deriving sexp, eq, show]

type macro_change = { v1_regime : string; v2_regime : string }
[@@deriving sexp, eq, show]

type t = {
  date : Date.t;
  v1_version : string;
  v2_version : string;
  added_in_v2 : string list;
  removed_in_v2 : string list;
  score_changes : score_change list;
  rank_changes : rank_change list;
  macro_change : macro_change option;
}
[@@deriving sexp, eq, show]

(** Build a map from symbol → (1-based rank, candidate). The rank is the
    position in the input list, which the screener emits score-descending. *)
let _index_candidates (candidates : Weekly_snapshot.candidate list) :
    (int * Weekly_snapshot.candidate) String.Map.t =
  List.foldi candidates ~init:String.Map.empty ~f:(fun i acc c ->
      Map.set acc ~key:c.symbol ~data:(i + 1, c))

let _symbols (candidates : Weekly_snapshot.candidate list) : String.Set.t =
  List.map candidates ~f:(fun (c : Weekly_snapshot.candidate) -> c.symbol)
  |> String.Set.of_list

let _macro_change_of ~(v1 : Weekly_snapshot.macro_context)
    ~(v2 : Weekly_snapshot.macro_context) : macro_change option =
  if String.equal v1.regime v2.regime then None
  else Some { v1_regime = v1.regime; v2_regime = v2.regime }

(** Score deltas for overlapping symbols, only nonzero. Sorted by symbol. *)
let _score_changes_of ~v1_index ~v2_index ~overlap : score_change list =
  Set.to_list overlap
  |> List.filter_map ~f:(fun symbol ->
      let _, (c1 : Weekly_snapshot.candidate) = Map.find_exn v1_index symbol in
      let _, (c2 : Weekly_snapshot.candidate) = Map.find_exn v2_index symbol in
      let delta = c2.score -. c1.score in
      if Float.equal delta 0.0 then None
      else Some { symbol; v1_score = c1.score; v2_score = c2.score; delta })

(** Rank deltas for overlapping symbols, only nonzero. Sorted by symbol. *)
let _rank_changes_of ~v1_index ~v2_index ~overlap : rank_change list =
  Set.to_list overlap
  |> List.filter_map ~f:(fun symbol ->
      let r1, _ = Map.find_exn v1_index symbol in
      let r2, _ = Map.find_exn v2_index symbol in
      let delta = r2 - r1 in
      if delta = 0 then None
      else Some { symbol; v1_rank = r1; v2_rank = r2; delta })

let diff ~(v1 : Weekly_snapshot.t) ~(v2 : Weekly_snapshot.t) :
    t Status.status_or =
  if not (Date.equal v1.date v2.date) then
    Error
      (Status.invalid_argument_error
         (Printf.sprintf
            "Cannot diff snapshots from different dates: v1=%s v2=%s"
            (Date.to_string v1.date) (Date.to_string v2.date)))
  else
    let v1_index = _index_candidates v1.long_candidates in
    let v2_index = _index_candidates v2.long_candidates in
    let v1_set = _symbols v1.long_candidates in
    let v2_set = _symbols v2.long_candidates in
    let overlap = Set.inter v1_set v2_set in
    Ok
      {
        date = v1.date;
        v1_version = v1.system_version;
        v2_version = v2.system_version;
        added_in_v2 = Set.to_list (Set.diff v2_set v1_set);
        removed_in_v2 = Set.to_list (Set.diff v1_set v2_set);
        score_changes = _score_changes_of ~v1_index ~v2_index ~overlap;
        rank_changes = _rank_changes_of ~v1_index ~v2_index ~overlap;
        macro_change = _macro_change_of ~v1:v1.macro ~v2:v2.macro;
      }
