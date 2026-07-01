(** Per-screen decision-audit records. See [screen_record.mli]. *)

open Core
module TA = Backtest.Trade_audit

type funded_entry = {
  symbol : string;
  score : int;
  grade : Weinstein_types.grade;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
  rs_value : float option;
  volume_ratio : float option;
  sector_name : string;
}
[@@deriving sexp]

type near_miss = {
  symbol : string;
  score : int;
  grade : Weinstein_types.grade;
  reason_skipped : TA.skip_reason;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
  rs_value : float option;
  volume_ratio : float option;
  sector_name : string;
}
[@@deriving sexp]

type summary = {
  n_funded : int;
  n_near_miss : int;
  min_funded_score : int option;
  max_nearmiss_score : int option;
  inversion : bool;
}
[@@deriving sexp]

type t = {
  screen_date : Date.t;
  funded : funded_entry list;
  near_misses : near_miss list;
  summary : summary;
}
[@@deriving sexp]

let _funded_of_entry (e : TA.entry_decision) : funded_entry =
  {
    symbol = e.symbol;
    score = e.cascade_score;
    grade = e.cascade_grade;
    stage = e.stage;
    weeks_advancing =
      (match e.stage with
      | Stage2 { weeks_advancing; _ } -> Some weeks_advancing
      | _ -> None);
    rs_value = e.rs_value;
    volume_ratio = e.volume_ratio;
    sector_name = e.sector_name;
  }

let _near_miss_of_alt (a : TA.alternative_candidate) : near_miss =
  {
    symbol = a.symbol;
    score = a.score;
    grade = a.grade;
    reason_skipped = a.reason_skipped;
    stage = a.stage;
    weeks_advancing = a.weeks_advancing;
    rs_value = a.rs_value;
    volume_ratio = a.volume_ratio;
    sector_name = a.sector_name;
  }

(** Deduplicate near-misses by symbol (keep the first, i.e. highest-scored after
    the score-desc sort), then re-sort score-desc so the report reads top-down.
*)
let _dedup_near_misses (alts : near_miss list) : near_miss list =
  let sorted =
    List.stable_sort alts ~compare:(fun a b -> Int.compare b.score a.score)
  in
  List.remove_consecutive_duplicates
    (List.sort sorted ~compare:(fun a b -> String.compare a.symbol b.symbol))
    ~equal:(fun a b -> String.equal a.symbol b.symbol)
  |> List.sort ~compare:(fun a b -> Int.compare b.score a.score)

let _summary_of ~(funded : funded_entry list) ~(near_misses : near_miss list) :
    summary =
  let min_funded_score =
    List.min_elt funded ~compare:(fun (a : funded_entry) b ->
        Int.compare a.score b.score)
    |> Option.map ~f:(fun (e : funded_entry) -> e.score)
  in
  let max_nearmiss_score =
    List.max_elt near_misses ~compare:(fun (a : near_miss) b ->
        Int.compare a.score b.score)
    |> Option.map ~f:(fun (n : near_miss) -> n.score)
  in
  let inversion =
    match min_funded_score with
    | None -> false
    | Some min_f ->
        List.exists near_misses ~f:(fun (n : near_miss) -> n.score > min_f)
  in
  {
    n_funded = List.length funded;
    n_near_miss = List.length near_misses;
    min_funded_score;
    max_nearmiss_score;
    inversion;
  }

let _record_of_screen ~screen_date ~(entries : TA.entry_decision list) : t =
  let funded = List.map entries ~f:_funded_of_entry in
  let raw_near_misses =
    List.concat_map entries ~f:(fun e ->
        List.map e.alternatives_considered ~f:_near_miss_of_alt)
  in
  let near_misses = _dedup_near_misses raw_near_misses in
  {
    screen_date;
    funded;
    near_misses;
    summary = _summary_of ~funded ~near_misses;
  }

let of_audit_records (records : TA.audit_record list) : t list =
  let by_date = Hashtbl.create (module Date) in
  List.iter records ~f:(fun (r : TA.audit_record) ->
      Hashtbl.add_multi by_date ~key:r.entry.entry_date ~data:r.entry);
  Hashtbl.to_alist by_date
  |> List.sort ~compare:(fun (d1, _) (d2, _) -> Date.compare d1 d2)
  |> List.map ~f:(fun (screen_date, entries_rev) ->
      _record_of_screen ~screen_date ~entries:(List.rev entries_rev))
