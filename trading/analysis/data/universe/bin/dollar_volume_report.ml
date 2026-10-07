open Core
module Scan = Dollar_volume_scan
module BR = Universe.Composition_bar_reader
module CA = Corporate_actions

type mover = {
  symbol : string;
  legacy_rank : int option;
  true_rank : int option;
  ratio : float option;
  splits : CA.split list;
}

type row = {
  year : int;
  size : int;
  committed : int;
  entered : mover list;
  left : mover list;
  committed_out : int;
  drift_out : int;
  true_top : (string * float) list;
}

(* ------------------------------------------------------------------ *)
(* Ranking + diff                                                      *)
(* ------------------------------------------------------------------ *)

let _year_score (scan : Scan.t) year =
  List.find scan.scores ~f:(fun (s : Scan.year_score) -> s.year = year)

(* Descending score, symbol ascending as the tie-break. *)
let _ranking scans ~year ~pick =
  List.filter_map scans ~f:(fun (scan : Scan.t) ->
      Option.bind (_year_score scan year) ~f:pick
      |> Option.map ~f:(fun v -> (scan.symbol, v)))
  |> List.sort ~compare:(fun (s1, v1) (s2, v2) ->
      match Float.compare v2 v1 with 0 -> String.compare s1 s2 | c -> c)

let _rank_table ranking =
  let table = Hashtbl.create (module String) in
  List.iteri ranking ~f:(fun i (s, _) -> Hashtbl.set table ~key:s ~data:(i + 1));
  table

let _top_set ranking ~size =
  List.take ranking size |> List.map ~f:fst |> String.Set.of_list

let _ratio scan year =
  Option.bind (_year_score scan year) ~f:(fun (s : Scan.year_score) ->
      match (s.legacy, s.truth) with
      | Some l, Some t when Float.(l > 0.0) -> Some (t /. l)
      | _ -> None)

let _mover ~by_symbol ~legacy_ranks ~true_ranks ~year symbol =
  let scan : Scan.t = Hashtbl.find_exn by_symbol symbol in
  let list_date = Date.create_exn ~y:year ~m:Month.May ~d:31 in
  {
    symbol;
    legacy_rank = Hashtbl.find legacy_ranks symbol;
    true_rank = Hashtbl.find true_ranks symbol;
    ratio = _ratio scan year;
    splits =
      List.filter scan.applied ~f:(fun (s : CA.split) ->
          Date.( > ) s.date list_date);
  }

let _by_ratio ~descending a b =
  let key m = Option.value m.ratio ~default:1.0 in
  if descending then Float.compare (key b) (key a)
  else Float.compare (key a) (key b)

let _movers ~make ~descending set =
  Set.to_list set |> List.map ~f:make
  |> List.sort ~compare:(_by_ratio ~descending)

let membership_row ~committed ~size ~top_k scans year =
  let legacy =
    _ranking scans ~year ~pick:(fun (s : Scan.year_score) -> s.legacy)
  in
  let truth =
    _ranking scans ~year ~pick:(fun (s : Scan.year_score) -> s.truth)
  in
  let l_set = _top_set legacy ~size and t_set = _top_set truth ~size in
  let c_set = Option.value committed ~default:String.Set.empty in
  let by_symbol = Hashtbl.create (module String) in
  List.iter scans ~f:(fun (s : Scan.t) ->
      ignore
        (Hashtbl.add by_symbol ~key:s.symbol ~data:s : [ `Ok | `Duplicate ]));
  let make =
    _mover ~by_symbol ~legacy_ranks:(_rank_table legacy)
      ~true_ranks:(_rank_table truth) ~year
  in
  {
    year;
    size;
    committed = Set.length c_set;
    entered = _movers ~make ~descending:true (Set.diff t_set l_set);
    left = _movers ~make ~descending:false (Set.diff l_set t_set);
    committed_out = Set.length (Set.diff c_set t_set);
    drift_out = Set.length (Set.diff c_set l_set);
    true_top = List.take truth top_k;
  }

(* ------------------------------------------------------------------ *)
(* Rendering                                                           *)
(* ------------------------------------------------------------------ *)

let _pct n d =
  if d = 0 then "n/a"
  else sprintf "%.1f%%" (100.0 *. Float.of_int n /. Float.of_int d)

let _add buf fmt = Printf.ksprintf (Buffer.add_string buf) fmt

(* Bin lower edges for the volume jump share: 0 = restated, 1 = raw. *)
let _jump_bin_width = 0.25
let _jump_bin_lo = -1.0
let _jump_bin_hi = 2.0

let _jump_bin share =
  let clamped =
    Float.clamp_exn share ~min:_jump_bin_lo ~max:(_jump_bin_hi -. 1e-9)
  in
  Float.iround_down_exn ((clamped -. _jump_bin_lo) /. _jump_bin_width)

let _jump_histogram buf shares =
  let n_bins =
    Float.iround_nearest_exn ((_jump_bin_hi -. _jump_bin_lo) /. _jump_bin_width)
  in
  let counts = Array.create ~len:n_bins 0 in
  List.iter shares ~f:(fun s ->
      let b = _jump_bin s in
      counts.(b) <- counts.(b) + 1);
  _add buf
    "Volume jump share of the close-confirmed splits of 3:1 or more either way \
     (log volume ratio over log factor; 0 = volume restated, 1 = raw; outer \
     bins are open):\n\n\
     | bin | splits |\n\
     |---|---:|\n";
  Array.iteri counts ~f:(fun i c ->
      let lo = _jump_bin_lo +. (Float.of_int i *. _jump_bin_width) in
      _add buf "| [%.2f, %.2f) | %d |\n" lo (lo +. _jump_bin_width) c);
  _add buf "\n"

let _split_diag buf scans =
  let sum f = List.sum (module Int) scans ~f in
  let n_vendor = sum (fun (s : Scan.t) -> List.length s.vendor_splits) in
  let n_confirmed = sum (fun (s : Scan.t) -> List.length s.confirmed) in
  let n_applied = sum (fun (s : Scan.t) -> List.length s.applied) in
  _add buf "## Store split diagnostics\n\n";
  _add buf "| item | count |\n|---|---:|\n";
  _add buf "| symbols scanned | %d |\n" (List.length scans);
  _add buf "| without `splits.csv` (scored with F = 1) | %d |\n"
    (List.count scans ~f:(fun (s : Scan.t) -> not s.has_splits_file));
  _add buf "| vendor splits | %d |\n" n_vendor;
  _add buf "| ignored: close shows no matching jump | %d |\n"
    (n_vendor - n_confirmed);
  _add buf "| ignored: close confirms, volume stored raw | %d |\n"
    (n_confirmed - n_applied);
  _add buf "| applied (divided out of volume) | %d |\n\n" n_applied;
  _jump_histogram buf
    (List.concat_map scans ~f:(fun (s : Scan.t) -> s.volume_jump_shares))

let _specimens buf specimens =
  _add buf
    "## Specimen check\n\n\
     | symbol | date | stored close*volume | true | stored / true |\n\
     |---|---|---:|---:|---:|\n";
  List.iter specimens ~f:(fun (sym, date, stored, truth) ->
      _add buf "| %s | %s | %.4g | %.4g | %.3f |\n" sym (Date.to_string date)
        stored truth (stored /. truth));
  _add buf "\n"

let _headline buf rows =
  _add buf
    "## Membership change per vintage\n\n\
     L = rebuilt on the stored basis, T = true-dollar basis, C = committed \
     list.\n\n\
     | year | N | in (T\\L) | out (L\\T) | out share | C\\T | C\\T share | \
     C\\L (store drift) |\n\
     |---|---:|---:|---:|---:|---:|---:|---:|\n";
  List.iter rows ~f:(fun r ->
      let out = List.length r.left in
      _add buf "| %d | %d | %d | %d | %s | %d | %s | %d |\n" r.year r.size
        (List.length r.entered) out (_pct out r.size) r.committed_out
        (_pct r.committed_out r.committed)
        r.drift_out);
  _add buf "\n"

let _rejected_summary buf scans =
  let with_rej =
    List.filter scans ~f:(fun (s : Scan.t) -> not (List.is_empty s.rejected))
  in
  let worst (s : Scan.t) =
    List.fold s.rejected ~init:0.0 ~f:(fun a (_, dv) -> Float.max a dv)
  in
  let ranked =
    List.sort with_rej ~compare:(fun a b -> Float.compare (worst b) (worst a))
  in
  _add buf
    "## Rejected bars\n\n\
     %d bars across %d symbols (full list: the rejected-bars CSV). Largest:\n\n\
     | symbol | bars | max true $/day |\n\
     |---|---:|---:|\n"
    (List.sum (module Int) with_rej ~f:(fun s -> List.length s.rejected))
    (List.length with_rej);
  List.iter (List.take ranked 15) ~f:(fun s ->
      _add buf "| %s | %d | %.3g |\n" s.symbol (List.length s.rejected)
        (worst s));
  _add buf "\n"

let _liquidity_totals scans =
  let table = Hashtbl.create (module Int) in
  List.iter scans ~f:(fun (s : Scan.t) ->
      List.iter s.liquidity ~f:(fun (l : Scan.liquidity_year) ->
          Hashtbl.update table l.cal_year ~f:(fun prev ->
              let w, lo, g, sl, sg =
                Option.value prev ~default:(0, 0, 0, 0, 0)
              in
              ( w + l.weeks,
                lo + l.lost,
                g + l.gained,
                (sl + if l.lost > 0 then 1 else 0),
                sg + if l.gained > 0 then 1 else 0 ))));
  Hashtbl.to_alist table
  |> List.sort ~compare:(fun (a, _) (b, _) -> Int.compare a b)

let _liquidity buf ~floor scans =
  _add buf
    "## Entry liquidity gate flips ($%.0f floor, week-end bars of committed \
     top-3000 members)\n\n\
     | year | symbol-weeks | pass->fail | fail->pass | flip share | symbols \
     pass->fail | symbols fail->pass |\n\
     |---|---:|---:|---:|---:|---:|---:|\n"
    floor;
  List.iter (_liquidity_totals scans) ~f:(fun (y, (w, lo, g, sl, sg)) ->
      _add buf "| %d | %d | %d | %d | %s | %d | %d |\n" y w lo g
        (_pct (lo + g) w)
        sl sg);
  _add buf "\n"

let _rank_str = function Some r -> Int.to_string r | None -> "-"

let _split_str splits =
  List.map splits ~f:(fun (s : CA.split) ->
      sprintf "%s x%.4g" (Date.to_string s.date) s.factor)
  |> String.concat ~sep:", "

let _mover_lines buf ~label ~k movers =
  _add buf
    "%s:\n\n\
     | symbol | stored rank | true rank | true/stored | splits after |\n\
     |---|---:|---:|---:|---|\n"
    label;
  List.iter (List.take movers k) ~f:(fun m ->
      _add buf "| %s | %s | %s | %s | %s |\n" m.symbol (_rank_str m.legacy_rank)
        (_rank_str m.true_rank)
        (Option.value_map m.ratio ~default:"-" ~f:(sprintf "%.3g"))
        (_split_str m.splits));
  _add buf "\n"

let _movers_section buf ~size ~k rows =
  _add buf "## Top movers, top-%d lists\n\n" size;
  List.iter
    (List.filter rows ~f:(fun r -> r.size = size))
    ~f:(fun r ->
      _add buf "### %d\n\nTrue-basis head: %s\n\n" r.year
        (List.map r.true_top ~f:(fun (s, v) -> sprintf "%s %.3g" s v)
        |> String.concat ~sep:", ");
      _mover_lines buf ~label:"Entering" ~k r.entered;
      _mover_lines buf ~label:"Leaving" ~k r.left)

let render ~liquidity_floor ~rows ~movers_size ~movers_k ~scans ~specimens =
  let buf = Buffer.create 65536 in
  _specimens buf specimens;
  _split_diag buf scans;
  _headline buf rows;
  _rejected_summary buf scans;
  _liquidity buf ~floor:liquidity_floor scans;
  _movers_section buf ~size:movers_size ~k:movers_k rows;
  Buffer.contents buf

let rejected_csv scans =
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "symbol,date,close,volume,true_dollar_volume\n";
  List.iter scans ~f:(fun (s : Scan.t) ->
      List.iter s.rejected ~f:(fun ((b : BR.bar), dv) ->
          _add buf "%s,%s,%.17g,%.17g,%.17g\n" s.symbol (Date.to_string b.date)
            b.close b.volume dv));
  Buffer.contents buf
