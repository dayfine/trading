(** Aggregation by exit reason. See [aggregate.mli]. *)

open Core

type graded_trade = {
  exit_reason : string;
  realized_pnl_pct : float;
  continuation_pct : float;
  exit_grade : Grade.exit_grade;
  entry_capture_ratio : float option;
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
}
[@@deriving show, eq, sexp]

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

(** Aggregate one non-empty group sharing [exit_reason]. *)
let _stats_of_group ~exit_reason trades =
  let mean_continuation_pct =
    _mean (List.map trades ~f:(fun t -> t.continuation_pct))
  in
  {
    exit_reason;
    n = List.length trades;
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
  }

let aggregate_by_exit_reason trades =
  trades
  |> List.sort_and_group ~compare:(fun (a : graded_trade) (b : graded_trade) ->
      String.compare a.exit_reason b.exit_reason)
  |> List.filter_map ~f:(function
    | [] -> None
    | (first : graded_trade) :: _ as group ->
        Some (_stats_of_group ~exit_reason:first.exit_reason group))

(** A float formatted as a signed percentage with one decimal, e.g. ["+12.3%"].
*)
let _pct1 x = Printf.sprintf "%+.1f%%" (x *. 100.0)

(** [entry_capture_ratio] rendered: a bare ratio with two decimals, or ["n/a"].
*)
let _ratio_cell = function None -> "n/a" | Some r -> Printf.sprintf "%.2f" r

let to_markdown groups =
  let header =
    "| exit_reason | n | mean realized | mean post-exit cont. | % premature | \
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
