(** Self-contained interactive HTML report — public facade. See [.mli]. *)

open Core
module TAR = Trade_audit_report
include Html_data

let render = Html_render.render

(* Derived: open positions -------------------------------------------------- *)

let _open_position ~final_prices (sym, side_str, entry_date, entry_price, qty) :
    open_position =
  let mark =
    Option.value
      (List.Assoc.find final_prices sym ~equal:String.equal)
      ~default:0.0
  in
  let is_short = String.equal (String.uppercase side_str) "SHORT" in
  let value = mark *. qty in
  let unrealized =
    if is_short then (entry_price -. mark) *. qty
    else (mark -. entry_price) *. qty
  in
  let gain_pct =
    if Float.(entry_price <= 0.0) then 0.0
    else if is_short then (entry_price -. mark) /. entry_price *. 100.0
    else (mark -. entry_price) /. entry_price *. 100.0
  in
  {
    symbol = sym;
    entry_date;
    entry_price;
    quantity = qty;
    mark;
    value;
    unrealized;
    gain_pct;
  }

(* Derived: chart series ---------------------------------------------------- *)

let _downsample ~every rows =
  match rows with
  | [] | [ _ ] -> rows
  | _ ->
      let n = List.length rows in
      let sampled = List.filteri rows ~f:(fun i _ -> i % every = 0) in
      if (n - 1) % every = 0 then sampled else sampled @ [ List.last_exn rows ]

let _benchmark ~bar_close ~symbol ~initial_cash ~dates =
  match dates with
  | [] -> None
  | first :: _ -> (
      match bar_close ~symbol ~as_of:first with
      | Some base when Float.(base > 0.0) ->
          let vals =
            List.map dates ~f:(fun d ->
                Option.map (bar_close ~symbol ~as_of:d) ~f:(fun c ->
                    (d, initial_cash *. c /. base)))
          in
          if List.for_all vals ~f:Option.is_some then
            Some (List.filter_map vals ~f:Fn.id)
          else None
      | _ -> None)

type _interval = {
  i_sym : string;
  i_lo : Date.t;
  i_hi : Date.t option;
  i_qty : float;
}

let _qty_of extras ~sym ~entry ~exit_ =
  let key =
    Html_sources.key sym (Date.to_string entry) (Date.to_string exit_)
  in
  Option.value (Map.find extras key) ~default:(0.0, "")

let _intervals (report : TAR.t) extras (opens : open_position list) =
  let rts =
    List.map report.rows ~f:(fun (r : TAR.per_trade_row) ->
        let qty, _ =
          _qty_of extras ~sym:r.symbol ~entry:r.entry_date ~exit_:r.exit_date
        in
        {
          i_sym = r.symbol;
          i_lo = r.entry_date;
          i_hi = Some r.exit_date;
          i_qty = qty;
        })
  in
  let ops =
    List.map opens ~f:(fun o ->
        {
          i_sym = o.symbol;
          i_lo = o.entry_date;
          i_hi = None;
          i_qty = o.quantity;
        })
  in
  rts @ ops

let _covers iv d =
  Date.( >= ) d iv.i_lo
  && match iv.i_hi with None -> true | Some hi -> Date.( <= ) d hi

let _utilization ~bar_close ~intervals ~curve =
  List.map curve ~f:(fun (d, nav) ->
      if Float.(nav <= 0.0) then 0.0
      else
        let deployed =
          List.fold intervals ~init:0.0 ~f:(fun acc iv ->
              if _covers iv d then
                match bar_close ~symbol:iv.i_sym ~as_of:d with
                | Some c -> acc +. (iv.i_qty *. c)
                | None -> acc
              else acc)
        in
        deployed /. nav *. 100.0)

(* Derived: subtitle -------------------------------------------------------- *)

let _opt_date = function Some d -> Date.to_string d | None -> "?"

let _subtitle (report : TAR.t) =
  let h = report.header in
  sprintf "%s \xe2\x86\x92 %s \xc2\xb7 universe %s \xc2\xb7 %d round-trips"
    (_opt_date h.period_start) (_opt_date h.period_end)
    (Option.value_map h.universe_size ~default:"?" ~f:Int.to_string)
    h.total_round_trips

let _stage_label = function
  | None -> ""
  | Some (s : Weinstein_types.stage) -> (
      match s with
      | Stage1 _ -> "Stage1"
      | Stage2 _ -> "Stage2"
      | Stage3 _ -> "Stage3"
      | Stage4 _ -> "Stage4")

let _trade_rows (report : TAR.t) extras =
  List.map report.rows ~f:(fun (r : TAR.per_trade_row) ->
      let qty, stop_kind =
        _qty_of extras ~sym:r.symbol ~entry:r.entry_date ~exit_:r.exit_date
      in
      ({
         symbol = r.symbol;
         entry_date = r.entry_date;
         exit_date = r.exit_date;
         days_held = r.days_held;
         entry_price = r.entry_price;
         exit_price = r.exit_price;
         quantity = qty;
         pnl_dollars = r.pnl_dollars;
         pnl_percent = r.pnl_percent;
         exit_trigger = r.exit_trigger;
         stage = _stage_label r.entry_stage;
         stop_kind;
         cascade_score = r.cascade_score;
       }
        : trade_row))

(* Load --------------------------------------------------------------------- *)

let _extras_map extras =
  Map.of_alist_reduce (module String) extras ~f:(fun a _ -> a)

let load ?bar_close ?(benchmark_symbol = "SPY") ?(benchmark_label = "SPY TR")
    ~(report : TAR.t) ~scenario_dir () : data =
  let path f = Filename.concat scenario_dir f in
  let curve =
    _downsample ~every:5
      (Html_sources.read_equity_curve (path "equity_curve.csv"))
  in
  let dates = List.map curve ~f:fst in
  let final_prices = Html_sources.read_final_prices (path "final_prices.csv") in
  let opens =
    List.map
      (Html_sources.read_open_positions (path "open_positions.csv"))
      ~f:(_open_position ~final_prices)
  in
  let extras =
    _extras_map (Html_sources.read_trade_extras (path "trades.csv"))
  in
  let summary = Html_sources.read_summary (path "summary.sexp") in
  let initial_cash =
    match summary.initial_cash with
    | Some v -> v
    | None -> ( match curve with (_, v) :: _ -> v | [] -> 0.0)
  in
  let final_nav =
    match summary.final_portfolio_value with
    | Some v -> v
    | None -> ( match List.last curve with Some (_, v) -> v | None -> 0.0)
  in
  let benchmark =
    Option.bind bar_close ~f:(fun bar_close ->
        _benchmark ~bar_close ~symbol:benchmark_symbol ~initial_cash ~dates)
  in
  let utilization =
    Option.map bar_close ~f:(fun bar_close ->
        _utilization ~bar_close
          ~intervals:(_intervals report extras opens)
          ~curve)
  in
  {
    scenario_name = Option.value report.header.scenario_name ~default:"scenario";
    subtitle = _subtitle report;
    initial_cash;
    final_nav;
    curve;
    benchmark;
    benchmark_label;
    utilization;
    opens;
    stale_held = summary.stale_held;
    kpis =
      Html_kpis.of_run ~report ~metrics:summary.metrics ~initial_cash ~final_nav
        ~benchmark ~benchmark_label;
    analysis = report.analysis;
    trades = _trade_rows report extras;
  }
