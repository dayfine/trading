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

(* Every check is a condition plus the finding to raise when it fails. These
   two combinators keep that shape flat, so each check reads as a list
   concatenation of independent single-condition helpers rather than as a
   nested literal of option-typed branches. *)
let _if_err cond ~symbol ~check detail =
  if cond then [ _err ~symbol check detail ] else []

let _if_warn cond ~symbol ~check detail =
  if cond then [ _warn ~symbol check detail ] else []

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

(* ---- Price / side checks ---------------------------------------------- *)

let _positive_price_finding ~symbol ~name v =
  let detail = Printf.sprintf "%s = %f must be positive and finite" name v in
  let bad = Float.is_nan v || Float.( <= ) v 0.0 in
  _if_err bad ~symbol ~check:"positive_prices" detail

let _stop_side_finding ~side (c : Weekly_snapshot.candidate) =
  let fill = Weekly_snapshot.expected_fill_price c in
  let detail =
    Printf.sprintf
      "stop %.2f is not on the protective side of the expected fill %.2f" c.stop
      fill
  in
  let wrong_side = Float.( >= ) (_side_sign side *. (c.stop -. fill)) 0.0 in
  _if_err wrong_side ~symbol:c.symbol ~check:"stop_side" detail

let _check_prices ~side (c : Weekly_snapshot.candidate) =
  _positive_price_finding ~symbol:c.symbol ~name:"entry" c.entry
  @ _positive_price_finding ~symbol:c.symbol ~name:"stop" c.stop
  @ _stop_side_finding ~side c

(* ---- Reconciliation checks -------------------------------------------- *)

let _class_matches ~through_band_pct ~extension_max_pct ~class_name stored =
  match class_name with
  | `Valid -> Float.( <= ) stored through_band_pct
  | `Through ->
      Float.( > ) stored through_band_pct
      && Float.( <= ) stored extension_max_pct
  | `Extended -> Float.( > ) stored extension_max_pct

let _overshoot_finding ~side (c : Weekly_snapshot.candidate)
    ~(levels : Entry_reconciliation.levels) =
  let recomputed = _overshoot_pct ~side ~entry:c.entry ~close:levels.close in
  let stored = levels.overshoot_pct in
  let detail =
    Printf.sprintf
      "stored overshoot %.4f%% disagrees with (close %.2f vs entry %.2f) = \
       %.4f%%"
      stored levels.close c.entry recomputed
  in
  let disagrees = not (_rel_close recomputed stored) in
  _if_err disagrees ~symbol:c.symbol ~check:"reconciliation_overshoot" detail

let _class_finding ~through_band_pct ~extension_max_pct
    (c : Weekly_snapshot.candidate) ~class_name ~stored =
  let detail =
    Printf.sprintf
      "class does not match overshoot %.2f%% under thresholds (band %.2f, max \
       %.2f)"
      stored through_band_pct extension_max_pct
  in
  let ok =
    _class_matches ~through_band_pct ~extension_max_pct ~class_name stored
  in
  _if_err (not ok) ~symbol:c.symbol ~check:"reconciliation_class" detail

let _reconciliation_class_finding ~side ~through_band_pct ~extension_max_pct
    (c : Weekly_snapshot.candidate) ~(levels : Entry_reconciliation.levels)
    ~class_name =
  _overshoot_finding ~side c ~levels
  @ _class_finding ~through_band_pct ~extension_max_pct c ~class_name
      ~stored:levels.overshoot_pct

let _check_reconciliation ~side ~through_band_pct ~extension_max_pct
    (c : Weekly_snapshot.candidate) =
  let cls ~levels ~class_name =
    _reconciliation_class_finding ~side ~through_band_pct ~extension_max_pct c
      ~levels ~class_name
  in
  match c.reconciliation with
  | Entry_reconciliation.Not_reconciled -> []
  | Valid_stop levels -> cls ~levels ~class_name:`Valid
  | Through_entry levels -> cls ~levels ~class_name:`Through
  | Extended levels -> cls ~levels ~class_name:`Extended

(* ---- Sizing checks ----------------------------------------------------- *)

let _risk_consistency_finding (c : Weekly_snapshot.candidate) ~fill
    ~expected_risk =
  let detail =
    Printf.sprintf
      "sized_risk_amount %.2f disagrees with shares x |fill - stop| = %d x \
       |%.4f - %.4f| = %.2f"
      c.sized_risk_amount c.sized_shares fill c.stop expected_risk
  in
  let disagrees = not (_rel_close expected_risk c.sized_risk_amount) in
  _if_err disagrees ~symbol:c.symbol ~check:"risk_consistency" detail

let _risk_budget_finding (c : Weekly_snapshot.candidate) ~budget =
  let detail =
    Printf.sprintf "sized risk %.2f exceeds budget %.2f" c.sized_risk_amount
      budget
  in
  let over = Float.( > ) c.sized_risk_amount budget in
  _if_warn over ~symbol:c.symbol ~check:"risk_budget" detail

let _sized_findings ?risk_budget (c : Weekly_snapshot.candidate) =
  (* Issue #2158: sizing is on the worst admissible fill (the do-not-chase cap),
     so the risk identity is checked against that basis, not the expected fill.
     [sizing_basis_price] falls back to the expected fill when no cap is carried
     (disarmed default / pre-#2158 snapshot), so historical artifacts still
     validate against the basis they were actually sized on. *)
  let fill = Weekly_snapshot.sizing_basis_price c in
  let expected_risk =
    Float.of_int c.sized_shares *. Float.abs (fill -. c.stop)
  in
  let budget_findings =
    match risk_budget with
    | None -> []
    | Some budget -> _risk_budget_finding c ~budget
  in
  _risk_consistency_finding c ~fill ~expected_risk @ budget_findings

let _check_sizing ?risk_budget (c : Weekly_snapshot.candidate) =
  if c.sized_shares <= 0 then [] else _sized_findings ?risk_budget c

(* ---- Bar-dependent checks (optional bar source) ----------------------- *)

let _ratio (b : Types.Daily_price.t) =
  if Float.is_nan b.close_price || Float.( <= ) b.close_price 0.0 then None
  else Some (b.adjusted_close /. b.close_price)

let _is_ratio_jump a b =
  let step = Float.abs (b -. a) /. Float.max a Float.epsilon_float in
  Float.( > ) step _split_ratio_jump

let rec _any_adjacent_jump = function
  | a :: (b :: _ as rest) -> _is_ratio_jump a b || _any_adjacent_jump rest
  | _ -> false

(* A step change in raw/adjusted ratio between consecutive bars = a split (or
   equivalent corporate action) inside the window. Such a candidate's
   resistance grade and structural floor were computed on a series whose raw
   scale changes mid-window — flag them basis-suspect (issue #2133). *)
let _split_inside_window bars =
  _any_adjacent_jump (List.filter_map bars ~f:_ratio)

let _chart_coverage_finding (c : Weekly_snapshot.candidate) ~bars =
  _if_warn
    (List.length bars < 2)
    ~symbol:c.symbol ~check:"chart_coverage"
    "fewer than 2 bars from the configured bar source — the report chart \
     degrades to 'no chart data'"

let _split_window_finding (c : Weekly_snapshot.candidate) ~bars =
  _if_warn
    (_split_inside_window bars)
    ~symbol:c.symbol ~check:"split_in_window"
    "raw/adjusted ratio steps inside the bar window (split or equivalent) — \
     resistance grade and structural floor are basis-suspect until the grading \
     is verified split-safe (issue #2133)"

let _check_bars ~bars_for (c : Weekly_snapshot.candidate) =
  let bars = bars_for ~symbol:c.symbol in
  _chart_coverage_finding c ~bars @ _split_window_finding c ~bars

(* ---- Snapshot-level checks -------------------------------------------- *)

(* [seen] is threaded left-to-right, so the SECOND occurrence is the one
   flagged and candidate order is preserved. *)
let _duplicate_finding seen ~list_name (c : Weekly_snapshot.candidate) =
  let detail = Printf.sprintf "appears more than once in %s" list_name in
  let dup = Hash_set.mem seen c.symbol in
  Hash_set.add seen c.symbol;
  _if_err dup ~symbol:c.symbol ~check:"duplicate_symbol" detail

let _check_duplicates (candidates : Weekly_snapshot.candidate list) ~list_name =
  let seen = String.Hash_set.create () in
  List.concat_map candidates ~f:(_duplicate_finding seen ~list_name)

let _check_macro (m : Weekly_snapshot.macro_context) =
  if String.is_empty m.regime then
    [ _err "macro_regime" "macro regime is empty" ]
  else []

(* ---- Entry point ------------------------------------------------------ *)

let _candidate_findings ~side ~through_band_pct ~extension_max_pct ?risk_budget
    ?bars_for (c : Weekly_snapshot.candidate) =
  let bar_findings =
    match bars_for with None -> [] | Some bf -> _check_bars ~bars_for:bf c
  in
  _check_prices ~side c
  @ _check_reconciliation ~side ~through_band_pct ~extension_max_pct c
  @ _check_sizing ?risk_budget c
  @ bar_findings

let validate ?(through_band_pct = 1.0) ?(extension_max_pct = 15.0) ?risk_budget
    ?bars_for (t : Weekly_snapshot.t) : finding list =
  let per_side ~side cs =
    let f =
      _candidate_findings ~side ~through_band_pct ~extension_max_pct
        ?risk_budget ?bars_for
    in
    List.concat_map cs ~f
  in
  _check_macro t.macro
  @ _check_duplicates t.long_candidates ~list_name:"long_candidates"
  @ _check_duplicates t.short_candidates ~list_name:"short_candidates"
  @ per_side ~side:`Long t.long_candidates
  @ per_side ~side:`Short t.short_candidates

let has_errors findings =
  List.exists findings ~f:(fun f -> equal_level f.level Error)

let _level_tag (l : level) = match l with Error -> "ERROR" | Warning -> "WARN"
let _symbol_tag = function Some s -> s ^ " " | None -> ""

let _format_finding f =
  Printf.sprintf "%s %s%s: %s\n" (_level_tag f.level) (_symbol_tag f.symbol)
    f.check f.detail

let to_report findings =
  match findings with
  | [] -> "OK: no findings\n"
  | _ -> String.concat (List.map findings ~f:_format_finding)
