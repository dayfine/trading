open Core

type level = Error | Warning [@@deriving sexp, eq, show]

type finding = {
  level : level;
  symbol : string option;
  check : string;
  detail : string;
}
[@@deriving sexp, eq, show]

let _err ?symbol check detail = { level = Error; symbol; check; detail }
let _warn ?symbol check detail = { level = Warning; symbol; check; detail }

(* Relative tolerance for recomputed-vs-stored dollar/percent comparisons:
   generous enough for float round-tripping through sexp, far below any
   economically meaningful discrepancy. *)
let _rel_tolerance = 1e-6

(* Split detection threshold: a day-over-day jump in the raw/adjusted ratio
   beyond this fraction indicates a split (or a corporate action of the same
   magnitude class) inside the bar window. Ordinary dividends move the ratio
   by well under 5%. *)
let _split_ratio_jump = 0.20

let _rel_close a b =
  let denom = Float.max (Float.abs a) (Float.abs b) in
  Float.(denom = 0.0) || Float.(abs (a -. b) /. denom <= _rel_tolerance)

let _side_sign = function `Long -> 1.0 | `Short -> -1.0

let _overshoot_pct ~side ~entry ~close =
  _side_sign side *. (close -. entry) /. entry *. 100.0

(* ---- Per-candidate checks -------------------------------------------- *)

let _check_prices ~side (c : Weekly_snapshot.candidate) =
  let bad name v =
    if Float.is_nan v || Float.( <= ) v 0.0 then
      Some
        (_err ~symbol:c.symbol "positive_prices"
           (Printf.sprintf "%s = %f must be positive and finite" name v))
    else None
  in
  List.filter_opt
    [
      bad "entry" c.entry;
      bad "stop" c.stop;
      (let fill = Weekly_snapshot.expected_fill_price c in
       let sign = _side_sign side in
       if Float.( >= ) (sign *. (c.stop -. fill)) 0.0 then
         Some
           (_err ~symbol:c.symbol "stop_side"
              (Printf.sprintf
                 "stop %.2f is not on the protective side of the expected fill \
                  %.2f"
                 c.stop fill))
       else None);
    ]

let _reconciliation_class_finding ~side ~through_band_pct ~extension_max_pct
    (c : Weekly_snapshot.candidate) ~(levels : Entry_reconciliation.levels)
    ~class_name =
  let recomputed = _overshoot_pct ~side ~entry:c.entry ~close:levels.close in
  let stored = levels.overshoot_pct in
  let class_ok =
    match class_name with
    | `Valid -> Float.( <= ) stored through_band_pct
    | `Through ->
        Float.( > ) stored through_band_pct
        && Float.( <= ) stored extension_max_pct
    | `Extended -> Float.( > ) stored extension_max_pct
  in
  List.filter_opt
    [
      (if _rel_close recomputed stored then None
       else
         Some
           (_err ~symbol:c.symbol "reconciliation_overshoot"
              (Printf.sprintf
                 "stored overshoot %.4f%% disagrees with (close %.2f vs entry \
                  %.2f) = %.4f%%"
                 stored levels.close c.entry recomputed)));
      (if class_ok then None
       else
         Some
           (_err ~symbol:c.symbol "reconciliation_class"
              (Printf.sprintf
                 "class does not match overshoot %.2f%% under thresholds (band \
                  %.2f, max %.2f)"
                 stored through_band_pct extension_max_pct)));
    ]

let _check_reconciliation ~side ~through_band_pct ~extension_max_pct
    (c : Weekly_snapshot.candidate) =
  match c.reconciliation with
  | Entry_reconciliation.Not_reconciled -> []
  | Valid_stop levels ->
      _reconciliation_class_finding ~side ~through_band_pct ~extension_max_pct c
        ~levels ~class_name:`Valid
  | Through_entry levels ->
      _reconciliation_class_finding ~side ~through_band_pct ~extension_max_pct c
        ~levels ~class_name:`Through
  | Extended levels ->
      _reconciliation_class_finding ~side ~through_band_pct ~extension_max_pct c
        ~levels ~class_name:`Extended
      @
      if c.sized_shares = 0 && Float.( = ) c.sized_risk_amount 0.0 then []
      else
        [
          _err ~symbol:c.symbol "extended_not_suppressed"
            (Printf.sprintf
               "EXTENDED candidate carries a sized ticket (%d sh, risk %.2f)"
               c.sized_shares c.sized_risk_amount);
        ]

let _check_sizing ?risk_budget (c : Weekly_snapshot.candidate) =
  if c.sized_shares <= 0 then []
  else
    let fill = Weekly_snapshot.expected_fill_price c in
    let expected_risk =
      Float.of_int c.sized_shares *. Float.abs (fill -. c.stop)
    in
    List.filter_opt
      [
        (if _rel_close expected_risk c.sized_risk_amount then None
         else
           Some
             (_err ~symbol:c.symbol "risk_consistency"
                (Printf.sprintf
                   "sized_risk_amount %.2f disagrees with shares x |fill - \
                    stop| = %d x |%.4f - %.4f| = %.2f"
                   c.sized_risk_amount c.sized_shares fill c.stop expected_risk)));
        Option.bind risk_budget ~f:(fun budget ->
            if Float.( <= ) c.sized_risk_amount budget then None
            else
              Some
                (_warn ~symbol:c.symbol "risk_budget"
                   (Printf.sprintf "sized risk %.2f exceeds budget %.2f"
                      c.sized_risk_amount budget)));
      ]

(* ---- Bar-dependent checks (optional bar source) ----------------------- *)

let _ratio (b : Types.Daily_price.t) =
  if Float.is_nan b.close_price || Float.( <= ) b.close_price 0.0 then None
  else Some (b.adjusted_close /. b.close_price)

(* A step change in raw/adjusted ratio between consecutive bars = a split (or
   equivalent corporate action) inside the window. Such a candidate's
   resistance grade and structural floor were computed on a series whose raw
   scale changes mid-window — flag them basis-suspect (issue #2133). *)
let _split_inside_window bars =
  let ratios = List.filter_map bars ~f:_ratio in
  let rec scan = function
    | a :: (b :: _ as rest) ->
        if
          Float.( > )
            (Float.abs (b -. a) /. Float.max a Float.epsilon_float)
            _split_ratio_jump
        then true
        else scan rest
    | _ -> false
  in
  scan ratios

let _check_bars ~bars_for (c : Weekly_snapshot.candidate) =
  let bars = bars_for ~symbol:c.symbol in
  List.filter_opt
    [
      (if List.length bars >= 2 then None
       else
         Some
           (_warn ~symbol:c.symbol "chart_coverage"
              "fewer than 2 bars from the configured bar source — the report \
               chart degrades to 'no chart data'"));
      (if _split_inside_window bars then
         Some
           (_warn ~symbol:c.symbol "split_in_window"
              "raw/adjusted ratio steps inside the bar window (split or \
               equivalent) — resistance grade and structural floor are \
               basis-suspect until the grading is verified split-safe (issue \
               #2133)")
       else None);
    ]

(* ---- Snapshot-level checks -------------------------------------------- *)

let _check_duplicates (candidates : Weekly_snapshot.candidate list) ~list_name =
  let seen = String.Hash_set.create () in
  List.filter_map candidates ~f:(fun c ->
      if Hash_set.mem seen c.symbol then
        Some
          (_err ~symbol:c.symbol "duplicate_symbol"
             (Printf.sprintf "appears more than once in %s" list_name))
      else (
        Hash_set.add seen c.symbol;
        None))

let _check_macro (m : Weekly_snapshot.macro_context) =
  if String.is_empty m.regime then
    [ _err "macro_regime" "macro regime is empty" ]
  else []

(* ---- Entry point ------------------------------------------------------ *)

let _candidate_findings ~side ~through_band_pct ~extension_max_pct ?risk_budget
    ?bars_for (c : Weekly_snapshot.candidate) =
  _check_prices ~side c
  @ _check_reconciliation ~side ~through_band_pct ~extension_max_pct c
  @ _check_sizing ?risk_budget c
  @ match bars_for with None -> [] | Some bf -> _check_bars ~bars_for:bf c

let validate ?(through_band_pct = 1.0) ?(extension_max_pct = 15.0) ?risk_budget
    ?bars_for (t : Weekly_snapshot.t) : finding list =
  let per_side ~side cs =
    List.concat_map cs
      ~f:
        (_candidate_findings ~side ~through_band_pct ~extension_max_pct
           ?risk_budget ?bars_for)
  in
  _check_macro t.macro
  @ _check_duplicates t.long_candidates ~list_name:"long_candidates"
  @ _check_duplicates t.short_candidates ~list_name:"short_candidates"
  @ per_side ~side:`Long t.long_candidates
  @ per_side ~side:`Short t.short_candidates

let has_errors findings =
  List.exists findings ~f:(fun f -> equal_level f.level Error)

let to_report findings =
  match findings with
  | [] -> "OK: no findings\n"
  | _ ->
      String.concat
        (List.map findings ~f:(fun f ->
             Printf.sprintf "%s %s%s: %s\n"
               (match f.level with Error -> "ERROR" | Warning -> "WARN")
               (match f.symbol with Some s -> s ^ " " | None -> "")
               f.check f.detail))
