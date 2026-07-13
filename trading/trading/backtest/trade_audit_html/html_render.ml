(** Pure serializer: {!Html_data.t} to a self-contained HTML document. See
    [.mli] for the contract. *)

open Core
module TAR = Trade_audit_report
module Ratings = Trade_audit_report.Trade_audit_ratings
open Html_data

(* JSON emit helpers ------------------------------------------------------ *)

(* Emit a JS/JSON string literal, escaping the characters that would break the
   surrounding [const DATA=...] object literal. Tickers are [A-Z0-9._-] but we
   guard quotes/backslash/control chars regardless. Multi-byte UTF-8 (e.g. the
   [\xc2\xa7] section sign in rule descriptions) passes through as raw bytes,
   which is valid inside a JS string. *)
let _js_escape s =
  let b = Buffer.create (String.length s + 2) in
  String.iter s ~f:(fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | c when Char.to_int c < 0x20 ->
          Buffer.add_string b (sprintf "\\u%04x" (Char.to_int c))
      | c -> Buffer.add_char b c);
  Buffer.contents b

let _jstr b s =
  Buffer.add_char b '"';
  Buffer.add_string b (_js_escape s);
  Buffer.add_char b '"'

(* Numbers are emitted in plain decimal (never scientific) so [Number()] on the
   JS side is exact; non-finite values collapse to 0. *)
let _jnum b f =
  Buffer.add_string b (if Float.is_finite f then sprintf "%.4f" f else "0")

let _jint b i = Buffer.add_string b (Int.to_string i)

let _obj b fields =
  Buffer.add_char b '{';
  List.iteri fields ~f:(fun i (name, emit) ->
      if i > 0 then Buffer.add_char b ',';
      _jstr b name;
      Buffer.add_char b ':';
      emit ());
  Buffer.add_char b '}'

let _arr b xs ~f =
  Buffer.add_char b '[';
  List.iteri xs ~f:(fun i x ->
      if i > 0 then Buffer.add_char b ',';
      f x);
  Buffer.add_char b ']'

let _quartile_label (q : Ratings.cascade_quartile) =
  match q with
  | Q1_top -> "Q1 (top)"
  | Q2 -> "Q2"
  | Q3 -> "Q3"
  | Q4_bottom -> "Q4 (bottom)"

(* Section emitters ------------------------------------------------------- *)

(* Curve rows are [date, strat] or [date, strat, bench] (when a benchmark is
   present, aligned index-for-index to the curve). *)
let _emit_curve b ~curve ~benchmark =
  let bench = Option.map benchmark ~f:Array.of_list in
  Buffer.add_char b '[';
  List.iteri curve ~f:(fun i (d, v) ->
      if i > 0 then Buffer.add_char b ',';
      Buffer.add_char b '[';
      _jstr b (Date.to_string d);
      Buffer.add_char b ',';
      _jnum b v;
      (match bench with
      | Some arr when i < Array.length arr ->
          Buffer.add_char b ',';
          _jnum b (snd arr.(i))
      | _ -> ());
      Buffer.add_char b ']');
  Buffer.add_char b ']'

let _emit_util b = function
  | None -> Buffer.add_string b "null"
  | Some xs -> _arr b xs ~f:(_jnum b)

let _emit_str_array b xs = _arr b xs ~f:(_jstr b)

let _emit_kpis b kpis =
  _arr b kpis ~f:(fun k ->
      Buffer.add_char b '[';
      _jstr b k.label;
      Buffer.add_char b ',';
      _jstr b k.value;
      Buffer.add_char b ',';
      _jstr b k.sub;
      Buffer.add_char b ',';
      Buffer.add_string b (if k.hero then "1" else "0");
      Buffer.add_char b ']')

let _emit_opens b opens =
  _arr b opens ~f:(fun (o : open_position) ->
      Buffer.add_char b '[';
      _jstr b o.symbol;
      Buffer.add_char b ',';
      _jstr b (Date.to_string o.entry_date);
      List.iter
        [ o.entry_price; o.quantity; o.mark; o.value; o.unrealized; o.gain_pct ]
        ~f:(fun x ->
          Buffer.add_char b ',';
          _jnum b x);
      Buffer.add_char b ']')

let _emit_trade b (t : trade_row) =
  Buffer.add_char b '[';
  _jstr b t.symbol;
  Buffer.add_char b ',';
  _jstr b (Date.to_string t.entry_date);
  Buffer.add_char b ',';
  _jstr b (Date.to_string t.exit_date);
  Buffer.add_char b ',';
  _jint b t.days_held;
  List.iter
    [ t.entry_price; t.exit_price; t.quantity; t.pnl_dollars; t.pnl_percent ]
    ~f:(fun x ->
      Buffer.add_char b ',';
      _jnum b x);
  List.iter [ t.exit_trigger; t.stage; t.stop_kind ] ~f:(fun s ->
      Buffer.add_char b ',';
      _jstr b s);
  Buffer.add_char b ',';
  (match t.cascade_score with
  | Some s -> _jint b s
  | None -> Buffer.add_string b "null");
  Buffer.add_char b ']'

let _emit_trades b trades = _arr b trades ~f:(_emit_trade b)

let _emit_conformance b = function
  | None -> Buffer.add_string b "null"
  | Some (a : TAR.analysis) ->
      let w = a.weinstein in
      Buffer.add_string b "{\"spirit\":";
      Buffer.add_string b
        (if Float.is_finite w.spirit_score then sprintf "%.2f" w.spirit_score
         else "0");
      Buffer.add_string b ",\"rules\":";
      let rules =
        List.filter w.per_rule ~f:(fun (r : Ratings.rule_violation_summary) ->
            r.applicable_count > 0)
      in
      _arr b rules ~f:(fun (r : Ratings.rule_violation_summary) ->
          Buffer.add_char b '[';
          _jstr b
            (Ratings.rule_label r.rule ^ " \xc2\xb7 "
            ^ Ratings.rule_description r.rule);
          Buffer.add_char b ',';
          _jstr b (sprintf "%.1f%%" r.pass_rate_pct);
          Buffer.add_char b ',';
          _jint b r.fail_count;
          Buffer.add_char b ']');
      Buffer.add_char b '}'

let _behavioral_lines (a : TAR.analysis) =
  let bm = a.behavioral in
  let ot = bm.over_trading and ew = bm.exit_winners_too_early in
  let el = bm.exit_losers_too_late in
  let f1 v = if Float.is_finite v then sprintf "%.1f" v else "n/a" in
  [
    sprintf "%s trades/yr; burst share %.1f%%" (f1 ot.trades_per_year)
      ot.concentrated_burst_pct;
    sprintf "Winners cut early: %d of %d below MFE floor, avg %.1fpp left"
      ew.flagged_count ew.winners_evaluated ew.avg_left_on_table_pct;
    sprintf "Stop discipline: %.1f%% of losers within 1R; %d late exits flagged"
      el.stop_discipline_pct el.flagged_count;
  ]

let _emit_behavioral b = function
  | None -> Buffer.add_string b "[]"
  | Some a -> _emit_str_array b (_behavioral_lines a)

let _emit_decision b = function
  | None -> Buffer.add_string b "null"
  | Some (a : TAR.analysis) ->
      let dq = a.decision_quality in
      Buffer.add_string b (sprintf "{\"total\":%d,\"overall\":" dq.total_trades);
      _jstr b (sprintf "%.1f%%" dq.overall_win_rate_pct);
      Buffer.add_string b ",\"quartiles\":";
      _arr b dq.per_quartile ~f:(fun (q : Ratings.cascade_quartile_stat) ->
          Buffer.add_char b '[';
          _jstr b (_quartile_label q.quartile);
          Buffer.add_char b ',';
          _jint b q.trade_count;
          Buffer.add_char b ',';
          _jint b q.win_count;
          Buffer.add_char b ',';
          _jstr b (sprintf "%.1f%%" q.win_rate_pct);
          Buffer.add_char b ']');
      Buffer.add_char b '}'

(* Render ----------------------------------------------------------------- *)

let render (d : data) : string =
  let b = Buffer.create 65536 in
  _obj b
    [
      ("scenario", fun () -> _jstr b d.scenario_name);
      ("subtitle", fun () -> _jstr b d.subtitle);
      ("initial_cash", fun () -> _jnum b d.initial_cash);
      ("final_nav", fun () -> _jnum b d.final_nav);
      ( "has_benchmark",
        fun () ->
          Buffer.add_string b (Bool.to_string (Option.is_some d.benchmark)) );
      ("bench_label", fun () -> _jstr b d.benchmark_label);
      ("curve", fun () -> _emit_curve b ~curve:d.curve ~benchmark:d.benchmark);
      ("util", fun () -> _emit_util b d.utilization);
      ("opens", fun () -> _emit_opens b d.opens);
      ("stale_held", fun () -> _emit_str_array b d.stale_held);
      ("kpis", fun () -> _emit_kpis b d.kpis);
      ("conformance", fun () -> _emit_conformance b d.analysis);
      ("behavioral", fun () -> _emit_behavioral b d.analysis);
      ("decision", fun () -> _emit_decision b d.analysis);
      ("trades", fun () -> _emit_trades b d.trades);
    ];
  String.substr_replace_first
    (Html_template.markup ^ Html_script.script)
    ~pattern:"/*DATA*/" ~with_:(Buffer.contents b)
