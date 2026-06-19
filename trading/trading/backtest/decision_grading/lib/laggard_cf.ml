(** Laggard-rotation paired counterfactual. See [laggard_cf.mli]. *)

open Core

type event = {
  dumped_symbol : string;
  dumped_date : Date.t;
  dumped_forward_pct : float;
  funded_forward_pcts : float list;
}
[@@deriving show, eq, sexp]

type summary = {
  n_events : int;
  n_with_redeploy : int;
  mean_dumped_forward_pct : float;
  mean_funded_forward_pct : float;
  mean_paired_diff_pct : float;
  pct_rotation_paid : float;
  diff_p10 : float;
  diff_p50 : float;
  diff_p90 : float;
}
[@@deriving show, eq, sexp]

(** Forward returns of the [entries] opened in [(dumped_date, dumped_date +
    alloc_window_days]] — the redeployment cohort the freed cash plausibly
    funded. Lifted out of {!build_events} to keep its pipeline flat (nesting). *)
let _funded_in_window ~alloc_window_days ~dumped_date entries =
  List.filter_map entries ~f:(fun (entry_date, fwd) ->
      let gap = Date.diff entry_date dumped_date in
      if gap > 0 && gap <= alloc_window_days then Some fwd else None)

(** One {!event} from a [(symbol, exit_date, forward)] laggard exit, pairing it
    with the redeployment cohort in its allocation window. *)
let _event_of ~alloc_window_days ~entries
    (dumped_symbol, dumped_date, dumped_forward_pct) =
  {
    dumped_symbol;
    dumped_date;
    dumped_forward_pct;
    funded_forward_pcts =
      _funded_in_window ~alloc_window_days ~dumped_date entries;
  }

let build_events ~alloc_window_days ~laggard_exits ~entries =
  List.map laggard_exits ~f:(_event_of ~alloc_window_days ~entries)

(** Arithmetic mean of [xs], or [0.0] for an empty list. *)
let _mean xs =
  match xs with
  | [] -> 0.0
  | _ -> List.sum (module Float) xs ~f:Fn.id /. Float.of_int (List.length xs)

(** Nearest-rank [p]-th percentile of [xs], or [0.0] when empty. *)
let _percentile ~p xs =
  match List.sort xs ~compare:Float.compare with
  | [] -> 0.0
  | sorted ->
      let n = List.length sorted in
      let idx =
        Float.round_nearest (p *. Float.of_int (n - 1)) |> Float.to_int
      in
      List.nth_exn sorted (Int.max 0 (Int.min (n - 1) idx))

let _p10 = 0.10
let _p50 = 0.50
let _p90 = 0.90

let summarize events =
  let with_redeploy =
    List.filter events ~f:(fun e -> not (List.is_empty e.funded_forward_pcts))
  in
  let diffs =
    List.map with_redeploy ~f:(fun e ->
        _mean e.funded_forward_pcts -. e.dumped_forward_pct)
  in
  let n_with_redeploy = List.length with_redeploy in
  let pct_rotation_paid =
    if n_with_redeploy = 0 then 0.0
    else
      let paid = List.count diffs ~f:(fun d -> Float.( > ) d 0.0) in
      Float.of_int paid /. Float.of_int n_with_redeploy
  in
  {
    n_events = List.length events;
    n_with_redeploy;
    mean_dumped_forward_pct =
      _mean (List.map with_redeploy ~f:(fun e -> e.dumped_forward_pct));
    mean_funded_forward_pct =
      _mean (List.map with_redeploy ~f:(fun e -> _mean e.funded_forward_pcts));
    mean_paired_diff_pct = _mean diffs;
    pct_rotation_paid;
    diff_p10 = _percentile ~p:_p10 diffs;
    diff_p50 = _percentile ~p:_p50 diffs;
    diff_p90 = _percentile ~p:_p90 diffs;
  }

let _pct1 x = Printf.sprintf "%+.1f%%" (x *. 100.0)

let to_markdown ~horizon_weeks s =
  Printf.sprintf
    "### Did laggard-rotation pay? (paired counterfactual, %dw forward)\n\n\
     Per rotation event: forward return of the new entries the freed cash \
     funded vs the laggard sold. Positive paired diff / >50%% paid = rotation \
     beat holding the laggard.\n\n\
     | metric | value |\n\
     |---|---|\n\
     | rotation events | %d |\n\
     | with redeployment | %d |\n\
     | mean dumped-laggard forward | %s |\n\
     | mean funded-cohort forward | %s |\n\
     | mean paired diff (funded − dumped) | %s |\n\
     | %% events rotation paid | %.0f%% |\n\
     | paired diff p10 / p50 / p90 | %s / %s / %s |\n"
    horizon_weeks s.n_events s.n_with_redeploy
    (_pct1 s.mean_dumped_forward_pct)
    (_pct1 s.mean_funded_forward_pct)
    (_pct1 s.mean_paired_diff_pct)
    (s.pct_rotation_paid *. 100.0)
    (_pct1 s.diff_p10) (_pct1 s.diff_p50) (_pct1 s.diff_p90)
