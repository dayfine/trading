open Core

(* A trades.csv row projected to the fields the faithfulness lenses read. The
   full 20-column schema is written by [Trade_context]; we parse only
   symbol / entry-year / days_held / pnl / stop-distance. *)
type trade = {
  symbol : string;
  entry_year : int;
  days_held : int;
  pnl : float;
  stop_dist : float option;
}

(* ------------------------------------------------------------------ *)
(* Parsing                                                             *)
(* ------------------------------------------------------------------ *)

let _c_symbol = 0
let _c_entry_date = 2
let _c_days_held = 4
let _c_pnl = 8
let _c_stop_dist = 15
let _cell a i = if i < Array.length a then a.(i) else ""

let _year_of s =
  match String.lsplit2 s ~on:'-' with
  | Some (y, _) -> Int.of_string_opt y
  | None -> None

let _trade_of a ~entry_year ~days_held ~pnl =
  {
    symbol = _cell a _c_symbol;
    entry_year;
    days_held;
    pnl;
    stop_dist = Float.of_string_opt (_cell a _c_stop_dist);
  }

let _parse_line line =
  let a = Array.of_list (String.split line ~on:',') in
  match
    ( _year_of (_cell a _c_entry_date),
      Int.of_string_opt (_cell a _c_days_held),
      Float.of_string_opt (_cell a _c_pnl) )
  with
  | Some entry_year, Some days_held, Some pnl ->
      Some (_trade_of a ~entry_year ~days_held ~pnl)
  | _ -> None

let _drop_header = function [] | [ _ ] -> [] | _ :: rows -> rows

let parse_trades path =
  In_channel.read_lines path |> _drop_header |> List.filter_map ~f:_parse_line

(* ------------------------------------------------------------------ *)
(* Single-arm sensibility profile                                     *)
(* ------------------------------------------------------------------ *)

type year_stat = {
  year : int;
  n : int;
  pnl : float;
  n_whipsaw : int;  (** [days_held <= whipsaw_days] — the shakeout tax. *)
  n_runner : int;  (** [days_held >= hold_ge] — the fat-tail holds. *)
  avg_days : float;
}

let _stat_of_year ~whipsaw_days ~hold_ge year (trades : trade list) =
  let n = List.length trades in
  {
    year;
    n;
    pnl = List.sum (module Float) trades ~f:(fun (t : trade) -> t.pnl);
    n_whipsaw =
      List.count trades ~f:(fun (t : trade) -> t.days_held <= whipsaw_days);
    n_runner = List.count trades ~f:(fun (t : trade) -> t.days_held >= hold_ge);
    avg_days =
      (if n = 0 then 0.0
       else
         Float.of_int
           (List.sum (module Int) trades ~f:(fun (t : trade) -> t.days_held))
         /. Float.of_int n);
  }

let profile_by_year trades ~whipsaw_days ~hold_ge =
  Map.of_alist_multi
    (module Int)
    (List.map trades ~f:(fun t -> (t.entry_year, t)))
  |> Map.mapi ~f:(fun ~key ~data ->
      _stat_of_year ~whipsaw_days ~hold_ge key data)
  |> Map.data

type stop_summary = {
  n : int;  (** trades with a parsed stop distance *)
  n_over : int;  (** stop distance strictly greater than [gt] *)
  mean : float;
  max : float;
}

let stop_width_summary trades ~gt =
  let ds = List.filter_map trades ~f:(fun t -> t.stop_dist) in
  let n = List.length ds in
  {
    n;
    n_over = List.count ds ~f:(fun d -> Float.( > ) d gt);
    mean =
      (if n = 0 then 0.0
       else List.sum (module Float) ds ~f:Fn.id /. Float.of_int n);
    max = Option.value (List.max_elt ds ~compare:Float.compare) ~default:0.0;
  }

(* ------------------------------------------------------------------ *)
(* Two-arm divergence                                                 *)
(* ------------------------------------------------------------------ *)

type year_div = {
  year : int;
  a_n : int;
  a_pnl : float;
  b_n : int;
  b_pnl : float;
}

let _pnl_by_year trades =
  Map.of_alist_multi
    (module Int)
    (List.map trades ~f:(fun t -> (t.entry_year, t)))
  |> Map.map ~f:(fun ts ->
      (List.length ts, List.sum (module Float) ts ~f:(fun t -> t.pnl)))

let divergence_by_year ~a ~b =
  let am = _pnl_by_year a and bm = _pnl_by_year b in
  let years =
    Set.union (Int.Set.of_list (Map.keys am)) (Int.Set.of_list (Map.keys bm))
  in
  Set.to_list years
  |> List.map ~f:(fun year ->
      let a_n, a_pnl = Map.find am year |> Option.value ~default:(0, 0.0) in
      let b_n, b_pnl = Map.find bm year |> Option.value ~default:(0, 0.0) in
      { year; a_n; a_pnl; b_n; b_pnl })

type sym_div = { symbol : string; a_pnl : float; b_pnl : float; delta : float }

let _pnl_by_symbol trades =
  Map.of_alist_multi
    (module String)
    (List.map trades ~f:(fun (t : trade) -> (t.symbol, t.pnl)))
  |> Map.map ~f:(List.sum (module Float) ~f:Fn.id)

(* Symbols ranked by |a_pnl - b_pnl| — where the two arms diverge most on the
   same name, the trade-by-trade signature of the fill-model difference. *)
let top_symbol_divergences ~a ~b ~k =
  let am = _pnl_by_symbol a and bm = _pnl_by_symbol b in
  let syms =
    Set.union
      (String.Set.of_list (Map.keys am))
      (String.Set.of_list (Map.keys bm))
  in
  Set.to_list syms
  |> List.map ~f:(fun symbol ->
      let a_pnl = Map.find am symbol |> Option.value ~default:0.0 in
      let b_pnl = Map.find bm symbol |> Option.value ~default:0.0 in
      { symbol; a_pnl; b_pnl; delta = a_pnl -. b_pnl })
  |> List.sort ~compare:(fun x y ->
      Float.compare (Float.abs y.delta) (Float.abs x.delta))
  |> fun l -> List.take l k

(* ------------------------------------------------------------------ *)
(* Rendering                                                           *)
(* ------------------------------------------------------------------ *)

let _pct n d = if d = 0 then 0.0 else 100.0 *. Float.of_int n /. Float.of_int d

let render_profile ~label ~whipsaw_days ~hold_ge ~stop_gt
    (stats : year_stat list) (ss : stop_summary) =
  let buf = Buffer.create 512 in
  bprintf buf "## Sensibility profile — %s\n\n" label;
  bprintf buf
    "| year | n | pnl | whipsaw (<=%dd) | runner (>=%dd) | avg days |\n"
    whipsaw_days hold_ge;
  bprintf buf "|---|---:|---:|---:|---:|---:|\n";
  List.iter stats ~f:(fun s ->
      bprintf buf "| %d | %d | %+.0f | %d (%.0f%%) | %d | %.0f |\n" s.year s.n
        s.pnl s.n_whipsaw (_pct s.n_whipsaw s.n) s.n_runner s.avg_days);
  bprintf buf
    "\n\
     Stop width: %d/%d entries (%.0f%%) wider than %.0f%% (mean %.1f%%, max \
     %.1f%%).\n"
    ss.n_over ss.n (_pct ss.n_over ss.n) (stop_gt *. 100.0) (ss.mean *. 100.0)
    (ss.max *. 100.0);
  Buffer.contents buf

let render_divergence ~a_label ~b_label (yds : year_div list)
    (sds : sym_div list) =
  let buf = Buffer.create 512 in
  bprintf buf "## Divergence — %s (A) vs %s (B)\n\n" a_label b_label;
  bprintf buf "| year | A n | A pnl | B n | B pnl | Δpnl |\n";
  bprintf buf "|---|---:|---:|---:|---:|---:|\n";
  List.iter yds ~f:(fun d ->
      bprintf buf "| %d | %d | %+.0f | %d | %+.0f | %+.0f |\n" d.year d.a_n
        d.a_pnl d.b_n d.b_pnl (d.a_pnl -. d.b_pnl));
  bprintf buf "\n### Top symbol divergences (by |Δpnl|)\n\n";
  bprintf buf "| symbol | A pnl | B pnl | Δpnl |\n";
  bprintf buf "|---|---:|---:|---:|\n";
  List.iter sds ~f:(fun s ->
      bprintf buf "| %s | %+.0f | %+.0f | %+.0f |\n" s.symbol s.a_pnl s.b_pnl
        s.delta);
  Buffer.contents buf

(* Read one run's [trades.csv] and render its single-arm sensibility profile;
   when [b_path] is given, also render the two-arm divergence. Pure over file
   contents — the report is returned, not written. *)
let _profile ~whipsaw_days ~hold_ge ~stop_gt trades label =
  render_profile ~label ~whipsaw_days ~hold_ge ~stop_gt
    (profile_by_year trades ~whipsaw_days ~hold_ge)
    (stop_width_summary trades ~gt:stop_gt)

let _two_arm ~profile ~a_label ~b_label ~top_k a b =
  String.concat ~sep:"\n"
    [
      profile a a_label;
      profile b b_label;
      render_divergence ~a_label ~b_label (divergence_by_year ~a ~b)
        (top_symbol_divergences ~a ~b ~k:top_k);
    ]

let run ?b_path ?(a_label = "A") ?(b_label = "B") ?(whipsaw_days = 3)
    ?(hold_ge = 200) ?(stop_gt = 0.15) ?(top_k = 20) ~a_path () =
  let a = parse_trades a_path in
  let profile = _profile ~whipsaw_days ~hold_ge ~stop_gt in
  match b_path with
  | None -> profile a a_label
  | Some b_path ->
      _two_arm ~profile ~a_label ~b_label ~top_k a (parse_trades b_path)
