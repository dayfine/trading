open Core

type metrics = {
  total_return_pct : float;
  sharpe : float;
  max_drawdown_pct : float;
  calmar : float;
  ulcer_pct : float;
  n_points : int;
}
[@@deriving sexp, eq, show]

type t = { nav_curve : (Date.t * float) list; metrics : metrics }

let _trading_days_per_year = 252.0

let _zero_metrics n =
  {
    total_return_pct = 0.0;
    sharpe = 0.0;
    max_drawdown_pct = 0.0;
    calmar = 0.0;
    ulcer_pct = 0.0;
    n_points = n;
  }

(* Join the two legs on common dates, preserving engine-curve order — the same
   inner-join [blend.awk] does with [if (d in f)]. Returns aligned
   [(date, floor_value, engine_value)] triples. *)
let _join floor_curve engine_curve =
  let floor_tbl = Date.Table.create () in
  List.iter floor_curve ~f:(fun (d, v) -> Hashtbl.set floor_tbl ~key:d ~data:v);
  List.filter_map engine_curve ~f:(fun (d, ev) ->
      Option.map (Hashtbl.find floor_tbl d) ~f:(fun fv -> (d, fv, ev)))

let _daily_return prev cur =
  if Float.( <= ) prev 0.0 then 0.0 else (cur -. prev) /. prev

(* Reset the two sleeves to the target split, keeping total NAV unchanged — the
   modelled effect of a cash-only rebalance transfer between sleeves. *)
let _rebalance ~floor_weight ~nav_f ~nav_e =
  let total = nav_f +. nav_e in
  (floor_weight *. total, (1.0 -. floor_weight) *. total)

(* Mutable per-step state for the two-sleeve walk: current sleeve NAVs, the
   previous leg values (None until the second step), and the date of the last
   rebalance. *)
type sleeve_state = {
  mutable nav_f : float;
  mutable nav_e : float;
  mutable prev_f : float option;
  mutable prev_e : float option;
  mutable last_rebalance : Date.t;
}

(* Compound both sleeves by this step's per-leg daily returns. No-op on the
   first step, when there is no previous value to compound against. *)
let _compound_step st ~fv ~ev =
  match (st.prev_f, st.prev_e) with
  | Some pf, Some pe ->
      st.nav_f <- st.nav_f *. (1.0 +. _daily_return pf fv);
      st.nav_e <- st.nav_e *. (1.0 +. _daily_return pe ev)
  | _ -> ()

(* Reset the sleeves to the target split once [stride_days] have elapsed since
   the last rebalance. *)
let _maybe_rebalance st ~floor_weight ~stride_days ~date =
  if Date.diff date st.last_rebalance >= stride_days then begin
    let f, e = _rebalance ~floor_weight ~nav_f:st.nav_f ~nav_e:st.nav_e in
    st.nav_f <- f;
    st.nav_e <- e;
    st.last_rebalance <- date
  end

(* Advance the state by one aligned triple and emit the combined-NAV point. *)
let _step st ~floor_weight ~stride_days (date, fv, ev) =
  _compound_step st ~fv ~ev;
  _maybe_rebalance st ~floor_weight ~stride_days ~date;
  st.prev_f <- Some fv;
  st.prev_e <- Some ev;
  (date, st.nav_f +. st.nav_e)

(* Fresh sleeve state at the target split, last rebalanced on the first date. *)
let _init_state ~floor_weight ~start_date =
  {
    nav_f = floor_weight;
    nav_e = 1.0 -. floor_weight;
    prev_f = None;
    prev_e = None;
    last_rebalance = start_date;
  }

(* Walk the aligned triples, compounding each sleeve by its leg's daily return
   and rebalancing once at least [stride_days] calendar days have elapsed since
   the last rebalance. Emits one combined-NAV point per date (normalised to
   start at 1.0). A [stride_days] of [1] rebalances on every step (the daily
   limit that reproduces [blend.awk]). *)
let _run_sleeves ~floor_weight ~stride_days aligned =
  match aligned with
  | [] -> []
  | (start_date, _, _) :: _ ->
      let st = _init_state ~floor_weight ~start_date in
      List.map aligned ~f:(_step st ~floor_weight ~stride_days)

(* Per-step blended returns from the combined-NAV path. *)
let _returns nav_curve =
  match nav_curve with
  | [] | [ _ ] -> []
  | (_, first) :: rest ->
      let prev = ref first in
      List.map rest ~f:(fun (_, v) ->
          let r = _daily_return !prev v in
          prev := v;
          r)

(* Population mean and standard deviation of [returns]. Both are 0.0 for an
   empty list. *)
let _mean_and_sd returns =
  let n = List.length returns in
  if n = 0 then (0.0, 0.0)
  else begin
    let nf = Float.of_int n in
    let mean = List.sum (module Float) returns ~f:Fn.id /. nf in
    let var =
      List.sum (module Float) returns ~f:(fun r -> (r -. mean) ** 2.0) /. nf
    in
    (mean, Float.sqrt (Float.max var 0.0))
  end

let _sharpe returns =
  let mean, sd = _mean_and_sd returns in
  if Float.( <= ) sd 0.0 then 0.0
  else mean /. sd *. Float.sqrt _trading_days_per_year

(* Worst peak-to-trough drawdown (fraction >= 0) and Ulcer index over the NAV
   path, in one pass — both as in [blend.awk]'s END block. *)
let _drawdown_and_ulcer nav_curve =
  let peak = ref Float.neg_infinity and maxdd = ref 0.0 and usum = ref 0.0 in
  let m = ref 0 in
  List.iteri nav_curve ~f:(fun i (_, nav) ->
      if Float.( > ) nav !peak then peak := nav;
      let dd =
        if Float.( <= ) !peak 0.0 then 0.0 else (!peak -. nav) /. !peak
      in
      if Float.( > ) dd !maxdd then maxdd := dd;
      (* blend.awk accumulates dd from the second point onward (i>=2). *)
      if i >= 1 then begin
        usum := !usum +. ((dd *. 100.0) ** 2.0);
        incr m
      end);
  let ulcer = if !m = 0 then 0.0 else Float.sqrt (!usum /. Float.of_int !m) in
  (!maxdd, ulcer)

let _metrics nav_curve =
  let n = List.length nav_curve in
  if n < 2 then _zero_metrics n
  else begin
    let final_nav = snd (List.last_exn nav_curve) in
    let returns = _returns nav_curve in
    let m = List.length returns in
    let maxdd, ulcer = _drawdown_and_ulcer nav_curve in
    let ann_return =
      if Float.( > ) final_nav 0.0 then
        Float.exp
          (Float.log final_nav *. (_trading_days_per_year /. Float.of_int m))
        -. 1.0
      else -1.0
    in
    let calmar = if Float.( > ) maxdd 0.0 then ann_return /. maxdd else 0.0 in
    {
      total_return_pct = (final_nav -. 1.0) *. 100.0;
      sharpe = _sharpe returns;
      max_drawdown_pct = maxdd *. 100.0;
      calmar;
      ulcer_pct = ulcer;
      n_points = n;
    }
  end

let blend_with_stride_days ~floor_weight ~rebalance_stride_days ~floor_curve
    ~engine_curve =
  let aligned = _join floor_curve engine_curve in
  let stride_days = Int.max 1 rebalance_stride_days in
  let nav_curve = _run_sleeves ~floor_weight ~stride_days aligned in
  { nav_curve; metrics = _metrics nav_curve }

let blend ~(config : Barbell_config.t) ~floor_curve ~engine_curve =
  blend_with_stride_days ~floor_weight:config.floor_weight
    ~rebalance_stride_days:(Barbell_config.rebalance_stride_days config)
    ~floor_curve ~engine_curve
