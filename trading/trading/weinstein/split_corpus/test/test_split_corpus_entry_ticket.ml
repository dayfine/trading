(** Split corpus x entry ticket trigger / limit (issue #2973).

    The entry ticket is a RAW-dollar order: the simulator's [StopLimit (E, cap)]
    built by [Order_generator.transitions_to_orders] from the screener's entry
    level [E] — the ticket anchor ([Screener_entry_anchor.choose], else the
    breakout price, else the MA fallback) plus the entry buffer
    ([Screener_prices.suggested_entry]). Two checks over every corpus window:

    - {b The ticket reads one basis.} A later split, after the window, rescales
      the vintage's [adjusted_close] by a constant and moves no raw price. A
      ticket priced on the raw basis is unchanged by it: same trigger, same
      limit, at every weekly decision date. Each decision is evaluated on the
      corpus vintage and on the vintage restated for a hypothetical later 4:1.
      Scope: decisions anchored on a base level. The MA-fallback anchor (no
      breakout price, e.g. the week the G14 scan truncates to nothing) prices
      the raw ticket off the classifier's ADJUSTED MA, so its ticket moves with
      the vintage; that is recorded as a finding (issue #2973, registry row
      "MA-fallback entry anchor ..."), not asserted here.
    - {b A ticket never meets a bar of another basis.} A ticket resting across
      the ex-date was written on the pre-split chart; [Split_ticket_cancel]
      cancels it on the ex-date (the split detector fires on the corpus's real
      ex-date bar), and not on the day before. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

let _entries =
  [
    "AAPL-2014-06-09";
    "AAPL-2020-08-31";
    "C-1996-05-28";
    "GE-2021-08-02";
    "NVDA-2021-07-20";
    "NVDA-2024-06-10";
    "TSLA-2020-08-31";
  ]

let _sa_config = Stock_analysis.default_config
let _params = Screener.default_candidate_params
let _cap_pct = Weinstein_strategy_config.default_entry_extension_max_pct

(* A later 4:1 forward split restates every adjusted price by a quarter. *)
let _later_split_vintage = 0.25

(* Trigger and limit are rounded to the cent; compare them to the cent. *)
let _cent = 0.005

let _load name : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

let _revintage k (b : Types.Daily_price.t) =
  { b with Types.Daily_price.adjusted_close = b.adjusted_close *. k }

let _weekly bars =
  Array.of_list
    (Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars)

(** The screener's long entry level [E] for one analysis (see the module doc for
    the anchor order). *)
let _entry_level (a : Stock_analysis.t) =
  let default_anchor =
    Option.value a.breakout_price
      ~default:(a.stage.ma_value *. (1.0 +. _params.breakout_fallback_pct))
  in
  let anchor =
    Option.value
      (snd (Screener_entry_anchor.choose ~is_short:false a))
      ~default:default_anchor
  in
  Screener_prices.suggested_entry ~entry_buffer_pct:_params.entry_buffer_pct
    anchor

let _create_entering ~symbol ~date entry_price :
    Trading_strategy.Position.transition =
  {
    position_id = symbol;
    date;
    kind =
      CreateEntering
        {
          symbol;
          side = Trading_base.Types.Long;
          target_quantity = 100.0;
          entry_price;
          reasoning = PricePattern "split corpus";
        };
  }

(** [(trigger, limit)] of the simulator's entry ticket for [E]. *)
let _ticket ~symbol ~date e =
  match
    Trading_simulation.Order_generator.transitions_to_orders ~current_date:date
      ~positions:String.Map.empty ~entry_extension_max_pct:_cap_pct
      [ _create_entering ~symbol ~date e ]
  with
  | Ok ([ { order_type = StopLimit (trigger, limit); _ } ], _) ->
      (trigger, limit)
  | _ -> assert_failure "expected one StopLimit entry ticket"

(** One weekly decision [i] read on the corpus vintage and on the later-split
    vintage:
    [(date, anchor kind, ticket on corpus vintage, ticket on later- split
     vintage)]. *)
let _decision (entry : Split_corpus.entry) i =
  let read k =
    let weekly = _weekly (List.map entry.bars ~f:(_revintage k)) in
    let date = weekly.(i).Types.Daily_price.date in
    let a =
      Stock_analysis.analyze ~config:_sa_config ~ticker:entry.meta.symbol
        ~bars:(Array.to_list (Array.sub weekly ~pos:0 ~len:(i + 1)))
        ~benchmark_bars:[] ~prior_stage:None ~as_of_date:date
    in
    ( date,
      fst (Screener_entry_anchor.choose ~is_short:false a),
      _ticket ~symbol:entry.meta.symbol ~date (_entry_level a) )
  in
  let date, kind, corpus = read 1.0 in
  let _, _, later = read _later_split_vintage in
  (date, kind, corpus, later)

(** Every weekly decision whose ticket is anchored on a base level (not the MA
    fallback — see the module doc). *)
let _base_anchored (entry : Split_corpus.entry) =
  List.range _sa_config.base_end_offset_weeks
    (Array.length (_weekly entry.bars))
  |> List.map ~f:(_decision entry)
  |> List.filter ~f:(fun (_, kind, _, _) ->
      not (Screener_entry_anchor.equal_kind kind Ma_fallback))

let _same_ticket (t1, l1) (t2, l2) =
  Float.( <= ) (Float.abs (t1 -. t2)) _cent
  && Float.( <= ) (Float.abs (l1 -. l2)) _cent

(** Base-anchored decision dates whose ticket moves when only the vintage moves.
*)
let _vintage_violations decisions =
  List.filter_map decisions ~f:(fun (date, _, corpus, later) ->
      if _same_ticket corpus later then None else Some date)

(* ------------------------------------------------------------------ *)
(* Resting ticket across the ex-date                                    *)
(* ------------------------------------------------------------------ *)

(** Number of [CancelEntry] the split-ticket canceller emits for an unfilled
    ticket resting on [current_date]. *)
let _cancels (entry : Split_corpus.entry) ~bar_reader ~current_date =
  let symbol = entry.meta.symbol in
  let pos =
    match
      Trading_strategy.Position.create_entering
        (_create_entering ~symbol ~date:current_date 1.0)
    with
    | Ok p -> p
    | Error err -> assert_failure (Status.show err)
  in
  List.length
    (Split_ticket_cancel.cancellations
       ~positions:(String.Map.singleton symbol pos)
       ~split_factor:(fun ~symbol ->
         Stops_split_runner.detect_split ~bar_reader ~symbol ~as_of:current_date
           ())
       ~current_date)

(** [(cancels on the day before, cancels on the ex-date)] per split. *)
let _cancels_around_ex_date (entry : Split_corpus.entry) =
  let bar_reader =
    Bar_reader.of_in_memory_bars [ (entry.meta.symbol, entry.bars) ]
  in
  List.map entry.meta.splits ~f:(fun (s : Split_corpus.split) ->
      let before =
        (List.last_exn
           (List.take_while entry.bars ~f:(fun b -> Date.( < ) b.date s.ex_date)))
          .date
      in
      ( _cancels entry ~bar_reader ~current_date:before,
        _cancels entry ~bar_reader ~current_date:s.ex_date ))

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let _test_ticket_reads_raw_basis name _ =
  let decisions = _base_anchored (_load name) in
  assert_that
    (List.length decisions, _vintage_violations decisions)
    (all_of
       [
         field fst (gt (module Int_ord) 0);
         field snd (equal_to ([] : Date.t list));
       ])

let _test_resting_ticket_cancelled_on_ex_date name _ =
  assert_that
    (_cancels_around_ex_date (_load name))
    (all_of
       [ field List.length (gt (module Int_ord) 0); each (equal_to (0, 1)) ])

let test_ticket_limit_is_the_cap_above_trigger _ =
  let trigger, limit =
    _ticket ~symbol:"X" ~date:(Date.of_string "2021-08-02") 100.0
  in
  assert_that (limit /. trigger)
    (float_equal ~epsilon:1e-9 (1.0 +. (_cap_pct /. 100.0)))

let _per_entry label test =
  List.map _entries ~f:(fun name ->
      Printf.sprintf "%s/%s" label name >:: test name)

let suite =
  "split_corpus_entry_ticket"
  >::: _per_entry "ticket_reads_raw_basis" _test_ticket_reads_raw_basis
       @ _per_entry "resting_ticket_cancelled_on_ex_date"
           _test_resting_ticket_cancelled_on_ex_date
       @ [
           "ticket_limit_is_the_cap_above_trigger"
           >:: test_ticket_limit_is_the_cap_above_trigger;
         ]

let () = run_test_tt_main suite
