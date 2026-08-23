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

(* Mirrors [Trade_audit_recorder]'s near-miss extraction, on the same source
   fields, so a cascade row and an entry-walk row describe a candidate
   identically. *)
let signals_of_analysis ~(analysis : Stock_analysis.t) ~sector_name ~score
    ~grade =
  {
    score;
    grade;
    stage = analysis.stage.stage;
    weeks_advancing =
      (match analysis.stage.stage with
      | Stage2 { weeks_advancing; _ } -> Some weeks_advancing
      | Stage1 _ | Stage3 _ | Stage4 _ -> None);
    rs_value =
      Option.map analysis.rs ~f:(fun (r : Rs.result) -> r.current_normalized);
    volume_ratio =
      Option.map analysis.volume ~f:(fun (v : Volume.result) -> v.volume_ratio);
    sector_name;
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

(* Total mapping from the screener's cascade phase onto the artefact's outcome.
   The two enums are deliberately separate types — this module owns the on-disk
   schema, exactly as [Trade_audit] owns [stop_floor_kind] — so this function is
   the single seam where they meet, and a phase added upstream forces a compile
   error here rather than a silent schema gap. *)
let _outcome_of_phase : Screener.cascade_phase -> cascade_outcome = function
  | Admitted -> Admitted
  | Dropped_at_macro -> Dropped_at_macro
  | Dropped_at_breakout -> Dropped_at_breakout
  | Dropped_at_sector -> Dropped_at_sector
  | Dropped_at_rs -> Dropped_at_rs
  | Dropped_at_grade -> Dropped_at_grade
  | Dropped_at_top_n -> Dropped_at_top_n

(* A G2 cascade row: its candidate never reached the entry walk, so the signals
   come off the analysis plus the screener's own trace rather than an
   [alternative_candidate]. *)
let _candidate_of_drop (d : Weinstein_strategy.Audit_recorder.cascade_drop) =
  {
    symbol = d.outcome.ticker;
    side = d.side;
    outcome = _outcome_of_phase d.outcome.phase;
    signals =
      signals_of_analysis ~analysis:d.analysis ~sector_name:d.sector.sector_name
        ~score:d.outcome.score ~grade:d.outcome.grade;
  }

let week_of ~date ~alternatives ~drops =
  let candidates =
    match drops with
    | [] -> List.map alternatives ~f:_candidate_of_alternative
    | drops -> List.map drops ~f:_candidate_of_drop
  in
  { date; candidates }

let _candidates_path ~scenario_dir =
  Filename.concat scenario_dir "candidates.sexp"

let emit ~enabled ~scenario_dir (t : t) =
  if enabled then
    try Sexp.save_hum (_candidates_path ~scenario_dir) (sexp_of_t t)
    with e ->
      eprintf "candidates: failed to write %s: %s\n%!"
        (_candidates_path ~scenario_dir)
        (Exn.to_string e)
