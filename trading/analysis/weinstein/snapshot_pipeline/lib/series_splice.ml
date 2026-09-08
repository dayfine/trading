open Core

(* One trading year: the shortest later segment a 30-week MA and a stage
   classification survive, and the length below which "keep the later segment"
   keeps a stub rather than a company (#2711). See [Config.min_kept_bars]. *)
let _default_min_kept_bars = 250

module Config = struct
  type t = {
    act : bool;
    max_findings_keep : int;
    misscale_close : float;
    min_kept_bars : int;
  }

  let default =
    {
      act = true;
      max_findings_keep = 20;
      misscale_close = 1000.0;
      min_kept_bars = _default_min_kept_bars;
    }
end

module Exceptions = struct
  type rule = Keep of string | Drop of string | Cut_at of string * Date.t
  [@@deriving sexp, equal]

  type t = rule Map.M(String).t

  let _symbol = function Keep s | Drop s | Cut_at (s, _) -> s
  let empty = Map.empty (module String)

  (* Last rule for a symbol wins, so appending a correction does not require
     deleting the line above it. *)
  let of_rules rules =
    List.fold rules ~init:empty ~f:(fun acc r ->
        Map.set acc ~key:(_symbol r) ~data:r)

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
    | Cut_refused_short_tail
  [@@deriving sexp_of, compare, equal]

  let to_string = function
    | Dropped -> "dropped"
    | Cut_at -> "cut_at"
    | Kept -> "kept"
    | Kept_by_exception -> "kept_by_exception"
    | Dropped_by_exception -> "dropped_by_exception"
    | Cut_by_exception -> "cut_by_exception"
    | Cut_refused_short_tail -> "cut_refused_short_tail"
end

type finding = {
  symbol : string;
  klass : Class.t;
  n_findings : int;
  cut_after : Date.t option;
  cut_from : Date.t option;
  n_dropped : int;
  n_kept : int;
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
   BEFORE the cut — the analogue of [Series_tail]'s [last_real_close], read on
   the same RAW basis so the two modules' 1,000 thresholds mean the same thing.
   (The detector works on adjusted closes; the mis-scale is a raw artefact.) *)
let _boundary_close ~cut_from bars =
  _bars_before ~date:cut_from bars
  |> List.last
  |> Option.map ~f:(fun (b : Types.Daily_price.t) -> b.close_price)

(* Findings count first, because no series legitimately jumps out of band
   [max_findings_keep] times: that shape is two issuers shuffled together, with
   no date between them. Only below the cut may the mis-scale gate rename. *)
let _classify (cfg : Config.t) ~n_findings ~boundary_close =
  if n_findings = 0 then Class.Clean
  else if n_findings >= cfg.max_findings_keep then Class.Interleaved
  else
    match boundary_close with
    | Some c when Float.( >= ) c cfg.misscale_close -> Class.Prefix_misscale
    | Some _ | None -> Class.Reuse

(* [Reuse] keeps the whole series (#2711): the blanket cut read a terminal
   corporate event as a ticker recycle and kept the stub instead of the company
   (247 of 518 lost 90%+ of their bars), so a reuse cuts only where a reviewer
   named one. [Prefix_misscale] still cuts by rule — there the earlier segment
   is a known artefact, not a company. *)
let _rule_decision ~klass ~cut_from =
  match klass with
  | Class.Clean | Class.Reuse -> Keep_all
  | Class.Interleaved -> Drop_all
  | Class.Prefix_misscale -> (
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

(* The structural guard on every cut, rule- or reviewer-driven: a cut leaving
   fewer than [min_kept_bars] bars keeps a stub, and a terminal jump with a
   short tail is [Series_tail]'s domain. It is a SAFETY NET for an exceptions
   entry a reviewer got wrong, not the protection #2711 turns on — that is
   [Reuse] defaulting to [Kept]; see the .mli. A cut leaving NOTHING is refused
   with the rest; it degenerates to a drop only with the guard off, where a
   zero-bar manifest entry is what a drop exists to avoid. *)
let _guard_short_tail (cfg : Config.t) ~decision ~action bars =
  match decision with
  | Keep_all | Drop_all -> (decision, action)
  | Cut d ->
      let n_kept = List.length (keep_from d bars) in
      if n_kept < cfg.min_kept_bars then
        (Keep_all, Action.Cut_refused_short_tail)
      else if n_kept = 0 then (Drop_all, Action.Dropped)
      else (decision, action)

let _resolve decision bars =
  match decision with
  | Drop_all -> None
  | Keep_all -> Some bars
  | Cut d -> Some (keep_from d bars)

(* The date the report names, acted on or not: the cut that happened or was
   refused, else the splice the series turns on. Naming it even for a kept
   [Reuse] is what makes report-only reviewable (#2711 item 3). *)
let _reported_cut ~klass ~cut_from ~attempted =
  match attempted with
  | Some _ -> attempted
  | None -> (
      match klass with
      | Class.Reuse | Class.Prefix_misscale -> cut_from
      | Class.Clean | Class.Interleaved -> None)

(* Depth read off the BARS, not off the action, so a report-only row says how
   deep the cut would have been. A dropped symbol loses all of them. *)
let _counts ~reported ~dropped bars =
  let total = List.length bars in
  match (dropped, reported) with
  | true, _ -> (total, 0)
  | false, None -> (0, total)
  | false, Some d ->
      let n_kept = List.length (keep_from d bars) in
      (total - n_kept, n_kept)

(* A [Clean] symbol nobody vetoed has nothing to say: the report lists real
   splices and real reviewer decisions, not every symbol in the warehouse. *)
let _reportable ~klass ~exceptions ~symbol =
  (not (Class.equal klass Class.Clean))
  || Option.is_some (Exceptions.find exceptions ~symbol)

let _finding ~symbol ~klass ~n_findings ~reported ~dropped ~action bars =
  let n_dropped, n_kept = _counts ~reported ~dropped bars in
  {
    symbol;
    klass;
    n_findings;
    cut_after =
      Option.bind reported ~f:(fun d -> _last_date_before ~date:d bars);
    cut_from = reported;
    n_dropped;
    n_kept;
    action;
  }

let _attempted_cut = function Cut d -> Some d | Keep_all | Drop_all -> None
let _is_drop = function Drop_all -> true | Keep_all | Cut _ -> false

let apply (config : Config.t) ~exceptions ~symbol ~splices bars =
  let splices = List.dedup_and_sort splices ~compare:Date.compare in
  let n_findings = List.length splices in
  let cut_from = List.last splices in
  let boundary_close =
    Option.bind cut_from ~f:(fun d -> _boundary_close ~cut_from:d bars)
  in
  let klass = _classify config ~n_findings ~boundary_close in
  let rule = _rule_decision ~klass ~cut_from in
  let decided, decided_action = _decide config ~exceptions ~symbol ~rule in
  let effective, action =
    _guard_short_tail config ~decision:decided ~action:decided_action bars
  in
  let reported =
    _reported_cut ~klass ~cut_from ~attempted:(_attempted_cut decided)
  in
  let out_bars = _resolve effective bars in
  let finding =
    if not (_reportable ~klass ~exceptions ~symbol) then None
    else
      Some
        (_finding ~symbol ~klass ~n_findings ~reported
           ~dropped:(_is_drop effective) ~action bars)
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

let csv_header = "symbol,class,n_findings,cut_after,n_dropped,n_kept,action"
let _date_or_blank = function None -> "" | Some d -> Date.to_string d

let _csv_row f =
  String.concat ~sep:","
    [
      f.symbol;
      Class.to_string f.klass;
      Int.to_string f.n_findings;
      _date_or_blank f.cut_after;
      Int.to_string f.n_dropped;
      Int.to_string f.n_kept;
      Action.to_string f.action;
    ]

let to_csv findings =
  String.concat ~sep:"\n" (csv_header :: List.map findings ~f:_csv_row) ^ "\n"

let _count findings ~f = List.count findings ~f:(fun x -> f x.action)

let _is_by_exception = function
  | Action.Kept_by_exception | Action.Dropped_by_exception
  | Action.Cut_by_exception ->
      true
  | Action.Dropped | Action.Cut_at | Action.Kept | Action.Cut_refused_short_tail
    ->
      false

let summary findings =
  Printf.sprintf
    "series_splice: %d findings (%d dropped, %d cut_at, %d kept, %d refused, \
     %d by_exception)"
    (List.length findings)
    (_count findings ~f:(Action.equal Action.Dropped))
    (_count findings ~f:(Action.equal Action.Cut_at))
    (_count findings ~f:(Action.equal Action.Kept))
    (_count findings ~f:(Action.equal Action.Cut_refused_short_tail))
    (_count findings ~f:_is_by_exception)
