(** Split corpus x production stop path (issue #2973, #2982).

    The stop column of [test_split_corpus_stage_stops] drives the stop machine
    by hand. This column drives what the strategy runs on every tick:
    [Stops_split_runner.adjust] (detects the split from the bars and rescales
    [stop_states]) and then [Stops_runner.update] (classifies the stage from the
    bar reader, restates the MA and advances the machine), with
    [Weinstein_stops.config.stop_ma_same_basis] ON (the #2982 fix) and the
    strategy's default [Daily] cadence.

    For every split of every corpus window, one long is opened on the last bar
    before the ex-date (initial stop from the support floor, as in
    [test_split_corpus_stage_stops]) and held, one runner tick per daily bar,
    until its stop exits it or the window ends. Restating each day's stop into
    the window's final basis (dividing by the pending split product), three
    things must hold:

    - {b Distance is continuous across the ex-date.} The stop distance as a
      fraction of the close moves on the ex-date by no more than an ordinary
      day's move. A stop the split rescale missed (or applied twice) jumps by
      the split ratio: on a 2:1 at a 10% distance the distance goes from +10% to
      -80%, on the 1:8 reverse from +10% to +89%.
    - {b The stop never moves down} in the final basis, any day of the hold.
    - {b The ratchet fires after the ex-date}: across the corpus, held positions
      get [UpdateRiskParams] raises dated after their split. *)

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
    "INFY-2014-12-08";
    "GMCR-2010-05-18";
    "ISRG-2017-10-06";
    "NVDA-2021-07-20";
    "NVDA-2024-06-10";
    "TSLA-2020-08-31";
  ]

let _stops_config =
  { Weinstein_stops.default_config with stop_ma_same_basis = true }

let _long = Trading_base.Types.Long

(* Initial-stop fallback when no support floor qualifies: 8% below entry, the
   value the sibling stop column uses. *)
let _fallback_buffer = 0.92

(* The runner's lookback, as in the #2982 production-path test. *)
let _lookback_bars = 52

(* Bound on the ex-date move of the stop distance, in fraction-of-close points.
   The corpus's largest real move is TSLA 2020-08-31 at about 0.10 (a +12.6%
   ex-date). A missed rescale moves it by [(1 - d) * (ratio - 1)] on a forward
   split ([(1 - d) * (1 - ratio)] on the reverse), above 0.25 for the corpus's
   smallest ratio (4:3) at any distance [d] under 25%. *)
let _max_distance_step = 0.15

(* Float noise on a stop restated by the pending split product. *)
let _restate_tol = 1e-9

let _load name : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

(* Test-setup unwrap: a failed position transition aborts the test with the
   status message. *)
let _setup_exn result =
  Result.map_error result ~f:(fun err ->
      "position setup failed: " ^ Status.show err)
  |> Result.ok_or_failwith

let _holding_position ~symbol (bar : Types.Daily_price.t) =
  let open Trading_strategy.Position in
  let step p kind =
    _setup_exn
      (apply_transition p { position_id = symbol; date = bar.date; kind })
  in
  let created =
    _setup_exn
      (create_entering
         {
           position_id = symbol;
           date = bar.date;
           kind =
             CreateEntering
               {
                 symbol;
                 side = _long;
                 target_quantity = 10.0;
                 entry_price = bar.close_price;
                 reasoning = ManualDecision { description = "split corpus" };
               };
         })
  in
  let filled =
    step created
      (EntryFill { filled_quantity = 10.0; fill_price = bar.close_price })
  in
  step filled
    (EntryComplete
       {
         risk_params =
           {
             stop_loss_price = None;
             take_profit_price = None;
             max_hold_days = None;
           };
       })

type day = {
  bar : Types.Daily_price.t;
  stop : float;  (** The stop level after this tick, raw dollars. *)
  restated_stop : float;  (** [stop] in the window's final basis. *)
  exited : bool;
  raised : bool;  (** An [UpdateRiskParams] adjust was emitted. *)
}

type hold = {
  ex_date : Date.t;
  entry_distance : float;
      (** Stop distance on the entry bar (the last pre-split bar): the entry
          close against the initial stop. *)
  days : day list;
      (** From the bar after entry — the ex-date — to the exit bar (inclusive)
          or the window's end. *)
}
(** One position held across [ex_date]. *)

let _distance ~close ~stop = (close -. stop) /. close

(** One runner tick, exactly as the strategy orders it: split rescale, then the
    stop update. *)
let _tick (entry : Split_corpus.entry) ~bar_reader ~positions ~stop_states
    ~prior_stages (bar : Types.Daily_price.t) =
  let symbol = entry.meta.symbol in
  Stops_split_runner.adjust ~positions ~stop_states ~bar_reader ~as_of:bar.date
    ();
  let exits, adjusts =
    Stops_runner.update ~stops_config:_stops_config
      ~stage_config:Stage.default_config ~lookback_bars:_lookback_bars
      ~positions
      ~get_price:(fun s -> Option.some_if (String.equal s symbol) bar)
      ~stop_states ~bar_reader ~as_of:bar.date ~prior_stages ()
  in
  let stop =
    Weinstein_stops.get_stop_level (Map.find_exn !stop_states symbol)
  in
  {
    bar;
    stop;
    restated_stop = stop /. Split_corpus.pending_ratio entry.meta bar.date;
    exited = not (List.is_empty exits);
    raised = not (List.is_empty adjusts);
  }

(** Hold one long from the last bar before [s.ex_date] until its stop exits it
    or the window ends. *)
let _hold_across (entry : Split_corpus.entry) (s : Split_corpus.split) =
  let symbol = entry.meta.symbol in
  let before, after =
    List.partition_tf entry.bars ~f:(fun (b : Types.Daily_price.t) ->
        Date.( < ) b.date s.ex_date)
  in
  let entry_bar = List.last_exn before in
  let initial =
    Weinstein_stops.compute_initial_stop_with_floor ~config:_stops_config
      ~side:_long ~entry_price:entry_bar.close_price ~bars:entry.bars
      ~as_of:entry_bar.date ~fallback_buffer:_fallback_buffer
  in
  let stop_states = ref (String.Map.singleton symbol initial) in
  let tick =
    _tick entry
      ~bar_reader:(Bar_reader.of_in_memory_bars [ (symbol, entry.bars) ])
      ~positions:
        (String.Map.singleton symbol (_holding_position ~symbol entry_bar))
      ~stop_states
      ~prior_stages:(Hashtbl.create (module String))
  in
  let days =
    List.fold_until after ~init:[]
      ~f:(fun acc bar ->
        let d = tick bar in
        if d.exited then Stop (List.rev (d :: acc)) else Continue (d :: acc))
      ~finish:List.rev
  in
  {
    ex_date = s.ex_date;
    entry_distance =
      _distance ~close:entry_bar.close_price
        ~stop:(Weinstein_stops.get_stop_level initial);
    days;
  }

let _holds (entry : Split_corpus.entry) =
  List.map entry.meta.splits ~f:(_hold_across entry)

(** [Some |distance on the ex-date - distance on the entry bar|]; [None] when
    the first tick is not the ex-date (a corpus defect). *)
let _ex_date_step h =
  match h.days with
  | ex :: _ when Date.equal ex.bar.date h.ex_date ->
      Some
        (Float.abs
           (_distance ~close:ex.bar.close_price ~stop:ex.stop
           -. h.entry_distance))
  | _ -> None

let _restated_drops h =
  let stops = List.map h.days ~f:(fun d -> d.restated_stop) in
  match stops with
  | [] -> 0
  | _ :: rest ->
      List.zip_exn (List.drop_last_exn stops) rest
      |> List.count ~f:(fun (a, b) -> Float.( < ) b (a -. (_restate_tol *. a)))

let _raises_after_ex_date h =
  List.count h.days ~f:(fun d -> d.raised && Date.( > ) d.bar.date h.ex_date)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let _test_ex_date_distance_continuous name _ =
  assert_that
    (List.map (_holds (_load name)) ~f:_ex_date_step)
    (all_of
       [
         field List.length (gt (module Int_ord) 0);
         each (is_some_and (lt (module Float_ord) _max_distance_step));
       ])

let _test_stop_never_moves_down name _ =
  assert_that
    (List.map (_holds (_load name)) ~f:_restated_drops)
    (all_of [ field List.length (gt (module Int_ord) 0); each (equal_to 0) ])

(** Across the corpus the runner raises held stops after their ex-date — the
    ratchet survives the rescale (and guards the two tests above against a
    frozen stop, which would pass them trivially). *)
let test_ratchet_fires_after_ex_date _ =
  assert_that
    (List.sum
       (module Int)
       _entries
       ~f:(fun name ->
         List.sum (module Int) (_holds (_load name)) ~f:_raises_after_ex_date))
    (gt (module Int_ord) 0)

let _per_entry label test =
  List.map _entries ~f:(fun name ->
      Printf.sprintf "%s/%s" label name >:: test name)

let suite =
  "split_corpus_stops_runner"
  >::: _per_entry "ex_date_distance_continuous"
         _test_ex_date_distance_continuous
       @ _per_entry "stop_never_moves_down" _test_stop_never_moves_down
       @ [ "ratchet_fires_after_ex_date" >:: test_ratchet_fires_after_ex_date ]

let () = run_test_tt_main suite
