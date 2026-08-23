(** Per-week candidate emission. See [candidate_log.mli] for the contract. *)

open Core

type cascade_outcome =
  | Admitted
  | Dropped_at_macro
  | Dropped_at_breakout
  | Dropped_at_sector
  | Dropped_at_rs
  | Dropped_at_grade
  | Dropped_at_top_n
[@@deriving sexp, eq, show]

type signals = {
  score : int;
  grade : Weinstein_types.grade;
  stage : Weinstein_types.stage;
  weeks_advancing : int option;
  rs_value : float option;
  volume_ratio : float option;
  sector_name : string;
}
[@@deriving sexp, eq]

type candidate = {
  symbol : string;
  side : Trading_base.Types.position_side;
  outcome : cascade_outcome;
  signals : signals;
}
[@@deriving sexp, eq]

type week = { date : Date.t; candidates : candidate list } [@@deriving sexp, eq]
type t = week list [@@deriving sexp]

(* Field-for-field. Deliberately exhaustive on the source record's decision-time
   subset rather than a partial copy: if [Trade_audit.alternative_candidate]
   gains or renames one of these, this projection stops compiling, which is the
   drift alarm. *)
let signals_of_alternative (a : Trade_audit.alternative_candidate) : signals =
  {
    score = a.score;
    grade = a.grade;
    stage = a.stage;
    weeks_advancing = a.weeks_advancing;
    rs_value = a.rs_value;
    volume_ratio = a.volume_ratio;
    sector_name = a.sector_name;
  }

type collector = { weeks : week Queue.t }

let create () = { weeks = Queue.create () }
let record t week = Queue.enqueue t.weeks week
let weeks t = Queue.to_list t.weeks
let create_if enabled = if enabled then Some (create ()) else None

let filter_from t ~start_date =
  List.filter t ~f:(fun (w : week) -> Date.( >= ) w.date start_date)

let weeks_in_window collector ~start_date =
  match collector with
  | None -> []
  | Some c -> filter_from (weeks c) ~start_date

let _candidate_of_alternative (a : Trade_audit.alternative_candidate) =
  {
    symbol = a.symbol;
    side = a.side;
    (* Reaching the entry walk means the cascade admitted it — naming the
       pre-top-N drops is a separate concern. *)
    outcome = Admitted;
    signals = signals_of_alternative a;
  }

let week_of ~date ~alternatives =
  { date; candidates = List.map alternatives ~f:_candidate_of_alternative }

let _candidates_path ~scenario_dir =
  Filename.concat scenario_dir "candidates.sexp"

let emit ~enabled ~scenario_dir (t : t) =
  if enabled then
    try Sexp.save_hum (_candidates_path ~scenario_dir) (sexp_of_t t)
    with e ->
      eprintf "candidates: failed to write %s: %s\n%!"
        (_candidates_path ~scenario_dir)
        (Exn.to_string e)
