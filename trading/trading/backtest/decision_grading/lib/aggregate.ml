(** Aggregation by exit reason. See [aggregate.mli]. *)

open Core

type graded_trade = {
  exit_reason : string;
  realized_pnl_pct : float;
  continuation_pct : float;
  exit_grade : Grade.exit_grade;
  entry_capture_ratio : float option;
  post_exit_max_adverse_pct : float;
  post_exit_max_favorable_pct : float;
}
[@@deriving show, eq, sexp]

type group_stats = {
  exit_reason : string;
  n : int;
  mean_realized_pnl_pct : float;
  mean_continuation_pct : float;
  pct_premature : float;
  pct_good_exit : float;
  mean_net_value_add_pct : float;
  mean_entry_capture_ratio : float option;
  mean_post_exit_max_adverse_pct : float;
  mean_post_exit_max_favorable_pct : float;
  continuation_p10 : float;
  continuation_p90 : float;
  disaster_dodge_rate : float;
}
[@@deriving show, eq, sexp]

let default_disaster_threshold_pct = -0.20

(** Lower-tail quantile for the post-exit continuation distribution. *)
let _continuation_p10_quantile = 0.10

(** Upper-tail quantile for the post-exit continuation distribution. *)
let _continuation_p90_quantile = 0.90

(** Arithmetic mean of [xs], or [0.0] for an empty list. *)
let _mean xs =
  match xs with
  | [] -> 0.0
  | _ -> List.sum (module Float) xs ~f:Fn.id /. Float.of_int (List.length xs)

(** Mean of the [Some] values in [xs], or [None] when every element is [None].
*)
let _mean_opt xs =
  match List.filter_opt xs with [] -> None | ys -> Some (_mean ys)

(** Fraction of [trades] whose [exit_grade] equals [grade]. *)
let _fraction_graded trades ~grade =
  let n = List.length trades in
  if n = 0 then 0.0
  else
    let matching =
      List.count trades ~f:(fun t -> Grade.equal_exit_grade t.exit_grade grade)
    in
    Float.of_int matching /. Float.of_int n

(** Nearest-rank [p]-th percentile (p in [[0,1]]) of [xs], or [0.0] when empty.
    Sorts ascending and reads index [round (p *. (n-1))]. *)
let _percentile ~p xs =
  match List.sort xs ~compare:Float.compare with
  | [] -> 0.0
  | sorted ->
      let n = List.length sorted in
      let idx =
        Float.round_nearest (p *. Float.of_int (n - 1)) |> Float.to_int
      in
      let idx = Int.max 0 (Int.min (n - 1) idx) in
      List.nth_exn sorted idx

(** Aggregate one non-empty group sharing [exit_reason]. *)
let _stats_of_group ~exit_reason ~disaster_threshold_pct trades =
  let mean_continuation_pct =
    _mean (List.map trades ~f:(fun t -> t.continuation_pct))
  in
  let continuations = List.map trades ~f:(fun t -> t.continuation_pct) in
  let n = List.length trades in
  let n_dodged =
    List.count trades ~f:(fun t ->
        Float.( <= ) t.post_exit_max_adverse_pct disaster_threshold_pct)
  in
  {
    exit_reason;
    n;
    mean_realized_pnl_pct =
      _mean (List.map trades ~f:(fun t -> t.realized_pnl_pct));
    mean_continuation_pct;
    pct_premature = _fraction_graded trades ~grade:Grade.Premature;
    pct_good_exit = _fraction_graded trades ~grade:Grade.Good_exit;
    (* Holding through the horizon would have added [continuation] on top of the
       realized return, so the value-add of having exited is its negation. *)
    mean_net_value_add_pct = -.mean_continuation_pct;
    mean_entry_capture_ratio =
      _mean_opt (List.map trades ~f:(fun t -> t.entry_capture_ratio));
    mean_post_exit_max_adverse_pct =
      _mean (List.map trades ~f:(fun t -> t.post_exit_max_adverse_pct));
    mean_post_exit_max_favorable_pct =
      _mean (List.map trades ~f:(fun t -> t.post_exit_max_favorable_pct));
    continuation_p10 = _percentile ~p:_continuation_p10_quantile continuations;
    continuation_p90 = _percentile ~p:_continuation_p90_quantile continuations;
    disaster_dodge_rate = Float.of_int n_dodged /. Float.of_int n;
  }

(** Reduce one same-[exit_reason] group to its [group_stats], skipping empties.
*)
let _group_to_stats ~disaster_threshold_pct = function
  | [] -> None
  | (first : graded_trade) :: _ as group ->
      Some
        (_stats_of_group ~exit_reason:first.exit_reason ~disaster_threshold_pct
           group)

let aggregate_by_exit_reason
    ?(disaster_threshold_pct = default_disaster_threshold_pct) trades =
  trades
  |> List.sort_and_group ~compare:(fun (a : graded_trade) (b : graded_trade) ->
      String.compare a.exit_reason b.exit_reason)
  |> List.filter_map ~f:(_group_to_stats ~disaster_threshold_pct)

(** A float formatted as a signed percentage with one decimal, e.g. ["+12.3%"].
*)
let _pct1 x = Printf.sprintf "%+.1f%%" (x *. 100.0)

(** [entry_capture_ratio] rendered: a bare ratio with two decimals, or ["n/a"].
*)
let _ratio_cell = function None -> "n/a" | Some r -> Printf.sprintf "%.2f" r

(** Value/grade table: realized, net opportunity cost vs hold, grade split,
    capture. *)
let _value_table groups =
  let header =
    "### Exit value vs hold-counterfactual\n\n\
     | exit_reason | n | mean realized | mean post-exit cont. | % premature | \
     % good exit | mean net value-add | mean capture |\n\
     |---|---|---|---|---|---|---|---|\n"
  in
  let row g =
    Printf.sprintf "| %s | %d | %s | %s | %.0f%% | %.0f%% | %s | %s |\n"
      g.exit_reason g.n
      (_pct1 g.mean_realized_pnl_pct)
      (_pct1 g.mean_continuation_pct)
      (g.pct_premature *. 100.0) (g.pct_good_exit *. 100.0)
      (_pct1 g.mean_net_value_add_pct)
      (_ratio_cell g.mean_entry_capture_ratio)
  in
  header ^ String.concat (List.map groups ~f:row)

(** Insurance table: the benefit (disaster dodged) vs cost (upside foregone)
    decomposition the mean continuation hides, plus the continuation tails. *)
let _insurance_table groups =
  let header =
    "### Disaster-avoidance vs upside-foregone (the insurance decomposition)\n\n\
     | exit_reason | n | mean disaster dodged | mean upside foregone | cont \
     p10 | cont p90 | disaster-dodge rate |\n\
     |---|---|---|---|---|---|---|\n"
  in
  let row g =
    Printf.sprintf "| %s | %d | %s | %s | %s | %s | %.0f%% |\n" g.exit_reason
      g.n
      (_pct1 g.mean_post_exit_max_adverse_pct)
      (_pct1 g.mean_post_exit_max_favorable_pct)
      (_pct1 g.continuation_p10) (_pct1 g.continuation_p90)
      (g.disaster_dodge_rate *. 100.0)
  in
  header ^ String.concat (List.map groups ~f:row)

let to_markdown groups = _value_table groups ^ "\n" ^ _insurance_table groups
