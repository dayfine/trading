open Core
open Validator_types
open Validator_step
module Scm = Weinstein_strategy.Share_class_map

(* ---- source 1: rename twins -------------------------------------------- *)

(* Same-company ticker renames produce twin rows whose prices differ by feed
   adjustment noise (NLS 4.72 vs BFX 4.75 at the same dates/quantity) — exact
   price equality misses them, so twins match within a relative tolerance on
   price and quantity, keyed by the exact (entry, exit) date pair. *)
let _twin_tolerance = 0.05

let _twin_key (r : trade_row) =
  sprintf "%s|%s" (Date.to_string r.entry_date) (Date.to_string r.exit_date)

let _within_tolerance a b =
  let denom = Float.max (Float.abs a) (Float.abs b) in
  Float.(denom = 0.) || Float.(abs (a -. b) /. denom <= _twin_tolerance)

let _is_twin (a : trade_row) (b : trade_row) =
  (not (String.equal a.symbol b.symbol))
  && _within_tolerance a.entry_price b.entry_price
  && _within_tolerance a.exit_price b.exit_price
  && _within_tolerance a.quantity b.quantity

(* The pair the rename-twin pass evaluates: same (entry, exit) key + twin. *)
let _is_rename_twin (a : trade_row) (b : trade_row) =
  String.equal (_twin_key a) (_twin_key b) && _is_twin a b

let _add_twin groups (row : trade_row) =
  let key = _twin_key row in
  let cur = Hashtbl.find groups key |> Option.value ~default:[] in
  Hashtbl.set groups ~key ~data:(row :: cur)

let _group_twins trades =
  let groups = Hashtbl.create (module String) in
  List.iter trades ~f:(_add_twin groups);
  groups

let _twin_partners rows row = List.filter rows ~f:(_is_twin row)

let _twin_spec (rep : trade_row) partners =
  let syms =
    rep.symbol :: List.map partners ~f:(fun (r : trade_row) -> r.symbol)
    |> List.dedup_and_sort ~compare:String.compare
  in
  spec rep ("twin positions: " ^ String.concat ~sep:"/" syms)

let _rename_group_violation data =
  let has_partner r = not (List.is_empty (_twin_partners data r)) in
  List.find data ~f:has_partner
  |> Option.map ~f:(fun rep -> _twin_spec rep (_twin_partners data rep))

let _rename_twin_violations trades =
  Hashtbl.data (_group_twins trades)
  |> List.filter_map ~f:_rename_group_violation

(* ---- source 2: share-class groups -------------------------------------- *)

let share_class_source_path ~data_dir =
  Filename.concat data_dir Scm.default_file_name

let load_share_classes ~data_dir =
  let path = share_class_source_path ~data_dir in
  Or_error.try_with (fun () -> Scm.load path)
  |> Result.map_error ~f:Error.to_string_hum

(* One held position, closed or still open, normalised for the overlap test.
   [closed] is the trades.csv row (for rename-twin dedup); [None] for an
   open_positions.csv row, whose [exit] is [far_future]. *)
type holding = {
  symbol : string;
  side : string;
  entry : Date.t;
  exit : Date.t;
  closed : trade_row option;
  to_spec : string -> specimen;
}

let _of_trade (r : trade_row) =
  {
    symbol = r.symbol;
    side = r.side;
    entry = r.entry_date;
    exit = r.exit_date;
    closed = Some r;
    to_spec = spec r;
  }

let _of_open (r : open_row) =
  {
    symbol = r.symbol;
    side = r.side;
    entry = r.entry_date;
    exit = far_future;
    closed = None;
    to_spec = open_spec r;
  }

let _overlaps a b = Date.(a.entry < b.exit && b.entry < a.exit)

let _already_rename_twin a b =
  match (a.closed, b.closed) with
  | Some ra, Some rb -> _is_rename_twin ra rb
  | _ -> false

let _is_share_class_pair a b =
  (not (String.equal a.symbol b.symbol))
  && String.equal a.side b.side && _overlaps a b
  && not (_already_rename_twin a b)

let _date_label d = if Date.equal d far_future then "open" else Date.to_string d

(* Specimen on the earlier-entered holding; detail names both classes and the
   window they were held together. *)
let _pair_spec a b =
  let first, second = if Date.( <= ) a.entry b.entry then (a, b) else (b, a) in
  let until = Date.min a.exit b.exit in
  first.to_spec
    (sprintf "share-class overlap: %s/%s held together %s..%s" first.symbol
       second.symbol
       (Date.to_string second.entry)
       (_date_label until))

let rec _pair_violations = function
  | [] -> []
  | h :: rest ->
      List.filter_map rest ~f:(fun o ->
          if _is_share_class_pair h o then Some (_pair_spec h o) else None)
      @ _pair_violations rest

let _by_group map holdings =
  List.filter_map holdings ~f:(fun h ->
      Scm.group_of map h.symbol |> Option.map ~f:(fun g -> (g, h)))
  |> String.Map.of_alist_multi |> Map.data

let _share_class_violations map inputs =
  let holdings =
    List.map inputs.trades ~f:_of_trade
    @ List.map inputs.open_positions ~f:_of_open
  in
  _by_group map holdings |> List.concat_map ~f:(fun g -> _pair_violations g)

(* ---- V6 ----------------------------------------------------------------- *)

let _unavailable_reason reason =
  sprintf "share-class source unavailable, rename-twin pass only: %s" reason

let check_v6 inputs =
  let renames = _rename_twin_violations inputs.trades in
  let classes, skip_reason =
    match inputs.share_classes with
    | Ok map -> (_share_class_violations map inputs, None)
    | Error reason -> ([], Some (_unavailable_reason reason))
  in
  { empty_finding with violations = renames @ classes; skip_reason }
