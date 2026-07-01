(** Adapter: live weekly-picks snapshots → {!Screen_record.t}. See the [.mli].
*)

open Core
module WS = Weinstein_snapshot.Weekly_snapshot
module TA = Backtest.Trade_audit
module SR = Screen_record

(** Parse a displayed grade label (the inverse of
    [Weinstein_types.grade_to_string]) back to the variant. Exhaustive; raises
    [Invalid_argument] on an unknown label rather than silently defaulting, so a
    schema drift surfaces loudly. *)
let _grade_of_string (s : string) : Weinstein_types.grade =
  match s with
  | "A+" -> A_plus
  | "A" -> A
  | "B" -> B
  | "C" -> C
  | "D" -> D
  | "F" -> F
  | other ->
      invalid_arg
        (Printf.sprintf "Weekly_adapter: unknown grade label %S" other)

(* A live long pick is a Stage-2 breakout by the screener's construction; a live
   short pick is a Stage-4 decline. The count fields are unknown from a snapshot,
   so they default to 0 (surfaced as [None] in the record's [weeks_advancing]). *)
let _long_stage : Weinstein_types.stage =
  Stage2 { weeks_advancing = 0; late = false }

let _short_stage : Weinstein_types.stage = Stage4 { weeks_declining = 0 }
let _score_of (c : WS.candidate) : int = Float.iround_nearest_exn c.score

let _funded_of_candidate (c : WS.candidate) : SR.funded_entry =
  {
    symbol = c.symbol;
    score = _score_of c;
    grade = _grade_of_string c.grade;
    stage = _long_stage;
    weeks_advancing = None;
    rs_value = c.rs_vs_spy;
    volume_ratio = None;
    sector_name = c.sector;
  }

(** Map a below-the-cut candidate to a near-miss. [stage] and [side] differ for
    the long-overflow vs short cases; the caller supplies both. *)
let _near_miss_of_candidate ~(side : Trading_base.Types.position_side)
    ~(stage : Weinstein_types.stage) (c : WS.candidate) : SR.near_miss =
  {
    symbol = c.symbol;
    side;
    score = _score_of c;
    grade = _grade_of_string c.grade;
    reason_skipped = TA.Top_n_cutoff;
    stage;
    weeks_advancing = None;
    rs_value = c.rs_vs_spy;
    volume_ratio = None;
    sector_name = c.sector;
  }

let _record_of_snapshot ~displayed_k (snap : WS.t) : SR.t =
  let funded_cands, long_overflow =
    List.split_n snap.long_candidates displayed_k
  in
  let funded = List.map funded_cands ~f:_funded_of_candidate in
  let long_near =
    List.map long_overflow
      ~f:(_near_miss_of_candidate ~side:Long ~stage:_long_stage)
  in
  let short_near =
    List.map snap.short_candidates
      ~f:(_near_miss_of_candidate ~side:Short ~stage:_short_stage)
  in
  let near_misses = long_near @ short_near in
  {
    screen_date = snap.date;
    funded;
    near_misses;
    summary = SR.summary_of funded near_misses;
  }

let of_weekly_snapshots (snaps : WS.t list) ~displayed_k : SR.t list =
  if displayed_k < 0 then
    invalid_arg
      (Printf.sprintf "Weekly_adapter: displayed_k must be >= 0, got %d"
         displayed_k);
  List.map snaps ~f:(_record_of_snapshot ~displayed_k)
  |> List.sort ~compare:(fun (a : SR.t) b ->
      Date.compare a.screen_date b.screen_date)
