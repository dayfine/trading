(** KPI-tile row for the interactive report. See [.mli]. *)

open Core
module TAR = Trade_audit_report
open Html_data

let _fmt_m v =
  sprintf "%s$%.2fM" (if Float.(v < 0.0) then "-" else "") (Float.abs v /. 1e6)

let _fmt_pct_signed v =
  sprintf "%s%.1f%%" (if Float.(v >= 0.0) then "+" else "") v

let _base ~(report : TAR.t) ~initial_cash ~final_nav =
  let h = report.header in
  let realized =
    List.fold report.rows ~init:0.0 ~f:(fun a (r : TAR.per_trade_row) ->
        a +. r.pnl_dollars)
  in
  let mtm =
    if Float.(initial_cash > 0.0) then
      ((final_nav /. initial_cash) -. 1.0) *. 100.0
    else 0.0
  in
  [
    {
      label = "Final NAV";
      value = _fmt_m final_nav;
      sub = "cash + marked opens";
      hero = true;
    };
    {
      label = "MTM return";
      value = _fmt_pct_signed mtm;
      sub = sprintf "on initial %s" (_fmt_m initial_cash);
      hero = false;
    };
    {
      label = "Realized PnL";
      value = _fmt_m realized;
      sub = "sum of round-trip P&L";
      hero = false;
    };
    {
      label = "Win rate";
      value = sprintf "%.1f%%" h.win_rate_pct;
      sub = sprintf "%d / %d" h.winners h.total_round_trips;
      hero = false;
    };
  ]

let _benchmark_tile ~benchmark ~benchmark_label ~initial_cash =
  match benchmark with
  | Some (_ :: _ as series) ->
      let last = snd (List.last_exn series) in
      let ret =
        if Float.(initial_cash > 0.0) then
          ((last /. initial_cash) -. 1.0) *. 100.0
        else 0.0
      in
      [
        {
          label = benchmark_label;
          value = _fmt_pct_signed ret;
          sub = "same initial cash";
          hero = false;
        };
      ]
  | _ -> []

let _metric_tiles metrics =
  let find k = List.Assoc.find metrics k ~equal:String.equal in
  let cagr =
    match find "cagr" with
    | Some v ->
        [
          {
            label = "CAGR";
            value = sprintf "%.1f%%" v;
            sub = "annualized";
            hero = false;
          };
        ]
    | None -> []
  in
  let sharpe =
    match find "sharperatio" with
    | Some s ->
        let sub =
          match find "maxdrawdown" with
          | Some d -> sprintf "MaxDD %.1f%%" d
          | None -> "risk-adjusted"
        in
        [ { label = "Sharpe"; value = sprintf "%.2f" s; sub; hero = false } ]
    | None -> []
  in
  cagr @ sharpe

let of_run ~report ~metrics ~initial_cash ~final_nav ~benchmark ~benchmark_label
    =
  _base ~report ~initial_cash ~final_nav
  @ _benchmark_tile ~benchmark ~benchmark_label ~initial_cash
  @ _metric_tiles metrics
