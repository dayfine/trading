open Core

module Config = struct
  type t = { act : bool; max_findings_keep : int; misscale_close : float }

  let default = { act = true; max_findings_keep = 20; misscale_close = 1000.0 }
end

module Exceptions = struct
  type rule = Keep of string | Drop of string | Cut_at of string * Date.t
  [@@deriving sexp, equal]

  (* The [splice] section is optional and unknown sections are ignored, so this
     one file carries both this module's rules and [Series_tail]'s [keep_tail]
     list without either parser tripping over the other's section. *)
  type file = { splice : rule list [@sexp.default []] }
  [@@deriving sexp] [@@sexp.allow_extra_fields]

  type t = rule Map.M(String).t

  let _symbol = function Keep s | Drop s | Cut_at (s, _) -> s
  let empty = Map.empty (module String)

  (* Last rule for a symbol wins, so appending a correction does not require
     deleting the line above it. *)
  let of_rules rules =
    List.fold rules ~init:empty ~f:(fun acc r ->
        Map.set acc ~key:(_symbol r) ~data:r)

  let of_file (f : file) = of_rules f.splice
  let find t ~symbol = Map.find t symbol
end

module Class = struct
  type t = Clean | Interleaved | Reuse | Prefix_misscale
  [@@deriving sexp_of, compare, equal]

  let to_string = function
    | Clean -> "clean"
    | Interleaved -> "interleaved"
    | Reuse -> "reuse"
    | Prefix_misscale -> "prefix_misscale"
end

module Action = struct
  type t =
    | Dropped
    | Cut_at
    | Kept
    | Kept_by_exception
    | Dropped_by_exception
    | Cut_by_exception
  [@@deriving sexp_of, compare, equal]

  let to_string = function
    | Dropped -> "dropped"
    | Cut_at -> "cut_at"
    | Kept -> "kept"
    | Kept_by_exception -> "kept_by_exception"
    | Dropped_by_exception -> "dropped_by_exception"
    | Cut_by_exception -> "cut_by_exception"
end

type finding = {
  symbol : string;
  klass : Class.t;
  n_findings : int;
  cut_after : Date.t option;
  cut_from : Date.t option;
  n_dropped : int;
  action : Action.t;
}
[@@deriving sexp_of, compare, equal]

(* What the build does with a series. Kept private: callers read the resulting
   bars and [Action], never this. *)
type decision = Keep_all | Drop_all | Cut of Date.t

let keep_from date bars =
  List.filter bars ~f:(fun (b : Types.Daily_price.t) -> Date.( >= ) b.date date)

let _bars_before ~date bars =
  List.filter bars ~f:(fun (b : Types.Daily_price.t) -> Date.( < ) b.date date)

let _last_date_before ~date bars =
  _bars_before ~date bars |> List.last
  |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.date)

(* Reference close for the mis-scale gate: the close on the last bar strictly
   BEFORE the cut — the direct analogue of [Series_tail]'s [last_real_close],
   and read on the same RAW basis, so the two modules' 1,000 thresholds mean the
   same thing. (The detector works on adjusted closes; the mis-scale it is
   distinguishing is a raw-price artefact.) *)
let _boundary_close ~cut_from bars =
  _bars_before ~date:cut_from bars
  |> List.last
  |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.close_price)

(* Findings count first, because no series legitimately jumps out of band
   [max_findings_keep] times: that shape is two issuers shuffled together and no
   date separates them. Only below the cut is a boundary meaningful, and only
   there does the mis-scale gate get to rename the class. *)
let _classify (cfg : Config.t) ~n_findings ~boundary_close =
  if n_findings = 0 then Class.Clean
  else if n_findings >= cfg.max_findings_keep then Class.Interleaved
  else
    match boundary_close with
    | Some c when Float.( >= ) c cfg.misscale_close -> Class.Prefix_misscale
    | Some _ | None -> Class.Reuse

let _rule_decision ~klass ~cut_from =
  match klass with
  | Class.Clean -> Keep_all
  | Class.Interleaved -> Drop_all
  | Class.Reuse | Class.Prefix_misscale -> (
      match cut_from with Some d -> Cut d | None -> Keep_all)

let _exception_decision = function
  | Exceptions.Keep _ -> (Keep_all, Action.Kept_by_exception)
  | Exceptions.Drop _ -> (Drop_all, Action.Dropped_by_exception)
  | Exceptions.Cut_at (_, d) -> (Cut d, Action.Cut_by_exception)

let _rule_action = function
  | Keep_all -> Action.Kept
  | Drop_all -> Action.Dropped
  | Cut _ -> Action.Cut_at

(* [act = false] short-circuits ahead of the exceptions lookup, exactly as
   [Series_tail]'s disabled edit does: a report-only build changes nothing, so
   an exception has nothing to override and the honest action is [Kept]. *)
let _decide (cfg : Config.t) ~exceptions ~symbol ~rule =
  if not cfg.act then (Keep_all, Action.Kept)
  else
    match Exceptions.find exceptions ~symbol with
    | Some r -> _exception_decision r
    | None -> (rule, _rule_action rule)

(* A cut that would leave nothing behind degenerates to a drop: an entry with
   zero bars in the manifest is exactly the shape the drop rule exists to
   avoid. *)
let _resolve decision bars =
  match decision with
  | Keep_all -> (Some bars, 0)
  | Drop_all -> (None, List.length bars)
  | Cut d -> (
      match keep_from d bars with
      | [] -> (None, List.length bars)
      | kept -> (Some kept, List.length bars - List.length kept))

(* The date the report names, whether or not the build acted on it: the
   effective cut when there is one, otherwise the cut the rule would have made.
   This is what makes a [-no-splice-action] run reviewable. *)
let _reported_cut ~rule ~effective =
  match (effective, rule) with
  | Cut d, _ -> Some d
  | (Keep_all | Drop_all), Cut d -> Some d
  | (Keep_all | Drop_all), (Keep_all | Drop_all) -> None

(* A [Clean] symbol nobody vetoed has nothing to say: the report lists real
   splices and real reviewer decisions, not every symbol in the warehouse. *)
let _reportable ~klass ~exceptions ~symbol =
  (not (Class.equal klass Class.Clean))
  || Option.is_some (Exceptions.find exceptions ~symbol)

let _finding ~symbol ~klass ~n_findings ~reported ~n_dropped ~action bars =
  {
    symbol;
    klass;
    n_findings;
    cut_after =
      Option.bind reported ~f:(fun d -> _last_date_before ~date:d bars);
    cut_from = reported;
    n_dropped;
    action;
  }

let apply (config : Config.t) ~exceptions ~symbol ~splices bars =
  let splices = List.dedup_and_sort splices ~compare:Date.compare in
  let n_findings = List.length splices in
  let cut_from = List.last splices in
  let boundary_close =
    Option.bind cut_from ~f:(fun d -> _boundary_close ~cut_from:d bars)
  in
  let klass = _classify config ~n_findings ~boundary_close in
  let rule = _rule_decision ~klass ~cut_from in
  let effective, action = _decide config ~exceptions ~symbol ~rule in
  let out_bars, n_dropped = _resolve effective bars in
  let finding =
    if not (_reportable ~klass ~exceptions ~symbol) then None
    else
      Some
        (_finding ~symbol ~klass ~n_findings
           ~reported:(_reported_cut ~rule ~effective)
           ~n_dropped ~action bars)
  in
  (out_bars, finding)

let cut_plan findings =
  List.fold findings
    ~init:(Map.empty (module String))
    ~f:(fun acc f ->
      match (f.action, f.cut_from) with
      | (Action.Cut_at | Action.Cut_by_exception), Some d ->
          Map.set acc ~key:f.symbol ~data:d
      | _, _ -> acc)

let dropped_symbols findings =
  List.filter_map findings ~f:(fun f ->
      match f.action with
      | Action.Dropped | Action.Dropped_by_exception -> Some f.symbol
      | _ -> None)

let csv_header = "symbol,class,n_findings,cut_after,n_dropped,action"
let _date_or_blank = function None -> "" | Some d -> Date.to_string d

let _csv_row f =
  String.concat ~sep:","
    [
      f.symbol;
      Class.to_string f.klass;
      Int.to_string f.n_findings;
      _date_or_blank f.cut_after;
      Int.to_string f.n_dropped;
      Action.to_string f.action;
    ]

let to_csv findings =
  String.concat ~sep:"\n" (csv_header :: List.map findings ~f:_csv_row) ^ "\n"

let _count findings ~f = List.count findings ~f:(fun x -> f x.action)

let _is_by_exception = function
  | Action.Kept_by_exception | Action.Dropped_by_exception
  | Action.Cut_by_exception ->
      true
  | Action.Dropped | Action.Cut_at | Action.Kept -> false

let summary findings =
  Printf.sprintf
    "series_splice: %d findings (%d dropped, %d cut_at, %d kept, %d \
     by_exception)"
    (List.length findings)
    (_count findings ~f:(Action.equal Action.Dropped))
    (_count findings ~f:(Action.equal Action.Cut_at))
    (_count findings ~f:(Action.equal Action.Kept))
    (_count findings ~f:_is_by_exception)
