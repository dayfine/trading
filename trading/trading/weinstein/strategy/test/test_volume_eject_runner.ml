(** Unit tests for {!Volume_eject_runner} — F5's at-fill breakout-volume
    confirmation and the eject that is inseparable from it (plan
    [dev/plans/entry-ticket-async-v2-2026-08-10.md] §3-F5;
    [docs/design/weinstein-book-reference.md] §4.2 + §4.7).

    Pins:
    - Both §4.2 branches confirm and HOLD: a fill week at 2x the prior 4 weeks
      (spike), and a fill week that only qualifies via the 3-4-week build-up.
    - Neither branch ⇒ eject, carrying the [volume_eject] label at the close.
    - Default config ([volume_confirm_at_fill = false]) ⇒ no eject on the same
      unconfirmed bars (R1 bit-identity), and arming the flag WITHOUT the
      StopLimit family is likewise inert.
    - An unfilled ticket ([Entering]) is never volume-checked.
    - No partial-week lookahead: a mid-week (non-screening) tick evaluates
      nothing; the same position ejects on the week's closing tick.
    - Fail-soft: too little history for either branch holds the position.
    - Short side, stale fills, and skip-list collisions are no-ops.
    - The audit population is WIDER than the eject population: a skipped
      position still yields a row, tagged [Skipped_other_exit], and the same
      [Unconfirmed] verdict carries all three outcomes. *)

open OUnit2
open Core
open Matchers
open Weinstein_strategy

(* ------------------------------------------------------------------ *)
(* Helpers                                                              *)
(* ------------------------------------------------------------------ *)

let make_bar date ~close ~volume =
  {
    Types.Daily_price.date = Date.of_string date;
    open_price = close;
    high_price = close *. 1.01;
    low_price = close *. 0.99;
    close_price = close;
    adjusted_close = close;
    volume;
    active_through = None;
  }

(** A [Holding] position for [ticker] whose entry (fill) date is [date] — the
    date the runner reads to locate the fill week. Mirrors the helper in
    [test_liquidity_exit_runner.ml]. *)
let make_holding_pos ?(side = Trading_base.Types.Long) ticker price date =
  let make_trans kind =
    { Trading_strategy.Position.position_id = ticker; date; kind }
  in
  let unwrap = function
    | Ok p -> p
    | Error _ -> OUnit2.assert_failure "position setup failed"
  in
  let open Trading_strategy.Position in
  let p =
    create_entering
      (make_trans
         (CreateEntering
            {
              symbol = ticker;
              side;
              target_quantity = 10.0;
              entry_price = price;
              reasoning = ManualDecision { description = "test" };
            }))
    |> unwrap
  in
  let p =
    apply_transition p
      (make_trans (EntryFill { filled_quantity = 10.0; fill_price = price }))
    |> unwrap
  in
  apply_transition p
    (make_trans
       (EntryComplete
          {
            risk_params =
              {
                stop_loss_price = None;
                take_profit_price = None;
                max_hold_days = None;
              };
          }))
  |> unwrap

(** An [Entering] position — the ticket is resting, nothing has filled. *)
let make_entering_pos ticker price date =
  match
    Trading_strategy.Position.create_entering
      {
        Trading_strategy.Position.position_id = ticker;
        date;
        kind =
          Trading_strategy.Position.CreateEntering
            {
              symbol = ticker;
              side = Trading_base.Types.Long;
              target_quantity = 10.0;
              entry_price = price;
              reasoning =
                Trading_strategy.Position.ManualDecision
                  { description = "test" };
            };
      }
  with
  | Ok p -> p
  | Error _ -> OUnit2.assert_failure "position setup failed"

let _ticker = "AXTI"

(* The evaluation tick: the Friday closing the fill week. *)
let _screening_friday = Date.of_string "2024-03-29"

(* The fill: the Monday inside that same week. *)
let _fill_date = Date.of_string "2024-03-25"

(* Mid-week tick — used to pin the no-partial-week-lookahead contract. *)
let _midweek = Date.of_string "2024-03-27"

(** One daily bar per week (each on that week's Friday), so each weekly bucket's
    summed volume is exactly the value given here and its date is that Friday.
    [weekly_volumes] runs oldest-first and ends with the FILL week. *)
let _bars_of_weekly_volumes weekly_volumes =
  let fridays =
    [
      "2024-01-26";
      "2024-02-02";
      "2024-02-09";
      "2024-02-16";
      "2024-02-23";
      "2024-03-01";
      "2024-03-08";
      "2024-03-15";
      "2024-03-22";
      "2024-03-29";
    ]
  in
  let n = List.length weekly_volumes in
  List.zip_exn (List.drop fridays (List.length fridays - n)) weekly_volumes
  |> List.map ~f:(fun (d, v) -> make_bar d ~close:100.0 ~volume:v)

(* Branch (a): fill week 3000 vs 1000-average prior 4 weeks => ratio 3.0. *)
let _spike_volumes = [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 1000; 3000 ]

(* Branch (b) only: the fill week is 1500 against a 1100 prior-4-week average
   (ratio 1.36 — branch (a) FAILS), but the 4-week build-up (1500/1400/1300/
   1200, mean 1350) is 2.7x the prior 4-week baseline (500, mean 500) and the
   fill week increases over the week before it. *)
let _buildup_volumes = [ 500; 500; 500; 500; 500; 1200; 1300; 1400; 1500 ]

(* Neither branch: the fill week is BELOW the prior week and the build-up is
   flat against its baseline. *)
let _unconfirmed_volumes =
  [ 1000; 1000; 1000; 1000; 1000; 1000; 1000; 1000; 900 ]

let _default_config () =
  Weinstein_strategy_config.default_config ~universe:[ _ticker ]
    ~index_symbol:"GSPCX"

let _armed_config =
  {
    (_default_config ()) with
    Weinstein_strategy_config.volume_confirm_at_fill = true;
    sim_entry_trigger_at_suggested = true;
    enable_sim_entry_stoplimit = true;
  }

let run ?(config = _armed_config) ?(is_screening_day = true)
    ?(skip_position_ids = String.Set.empty) ?(current_date = _screening_friday)
    ~positions ~weekly_volumes () =
  let bars = _bars_of_weekly_volumes weekly_volumes in
  let bar_reader = Bar_reader.of_in_memory_bars [ (_ticker, bars) ] in
  let last_bar = List.last_exn bars in
  Volume_eject_runner.update ~config ~volume_config:Volume.default_config
    ~is_screening_day ~positions ~bar_reader
    ~get_price:(fun s -> if String.equal s _ticker then Some last_bar else None)
    ~skip_position_ids ~current_date

let _held_positions ?(side = Trading_base.Types.Long) ?(fill_date = _fill_date)
    () =
  String.Map.singleton _ticker (make_holding_pos ~side _ticker 100.0 fill_date)

(** The [volume_eject] transition shape: a full [TriggerExit] on the evaluation
    tick, at that bar's close, labelled with the [Volume_eject] audit tag. *)
let _is_volume_eject ~at_date =
  all_of
    [
      field
        (fun (t : Trading_strategy.Position.transition) -> t.position_id)
        (equal_to _ticker);
      field
        (fun (t : Trading_strategy.Position.transition) -> t.date)
        (equal_to at_date);
      field
        (fun (t : Trading_strategy.Position.transition) -> t.kind)
        (matching ~msg:"Expected TriggerExit with StrategySignal volume_eject"
           (function
             | Trading_strategy.Position.TriggerExit
                 {
                   exit_reason =
                     Trading_strategy.Position.StrategySignal { label; _ };
                   exit_price;
                 } ->
                 Some (label, exit_price)
             | _ -> None)
           (all_of
              [
                field (fun (l, _) -> l) (equal_to "volume_eject");
                field (fun (_, p) -> p) (float_equal 100.0);
              ]));
    ]

(* ------------------------------------------------------------------ *)
(* Both §4.2 branches confirm => the position is HELD                    *)
(* ------------------------------------------------------------------ *)

(** Branch (a) — "breakout-week volume >= 2x average volume of prior 4 weeks".
    3x confirms, so nothing is ejected. *)
let test_fill_week_spike_confirms_and_holds _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_spike_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** Branch (b) — "volume build-up over 3-4 weeks that is >= 2x average of prior
    several weeks, with at least some increase on breakout week". The fill week
    alone is only 1.36x its prior 4 weeks, so implementing branch (a) alone
    would eject this book-valid breakout (plan §3-F5 amendment (ii)). *)
let test_buildup_branch_confirms_and_holds _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_buildup_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* Neither branch => eject                                              *)
(* ------------------------------------------------------------------ *)

(** §4.2's low-volume-breakout SELL rule: a buy-stop that filled on unconfirmed
    volume is sold, not held. *)
let test_unconfirmed_fill_week_ejects _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that result
    (elements_are [ _is_volume_eject ~at_date:_screening_friday ])

(* ------------------------------------------------------------------ *)
(* R1 — the default config is inert on the very same bars               *)
(* ------------------------------------------------------------------ *)

(** [volume_confirm_at_fill = false] (default): volume stays a screen-time gate
    and no eject path is reachable — bit-identical to pre-F5. *)
let test_default_config_never_ejects _ =
  let result =
    run ~config:(_default_config ()) ~positions:(_held_positions ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** The flag alone does not arm F5: the mechanism is defined only for the
    resting E-anchored ticket family, so without
    [sim_entry_trigger_at_suggested] + [enable_sim_entry_stoplimit] the runner
    stays inert ({!Weinstein_strategy_config.volume_confirm_at_fill_armed}). *)
let test_flag_without_stoplimit_family_never_ejects _ =
  let config =
    {
      (_default_config ()) with
      Weinstein_strategy_config.volume_confirm_at_fill = true;
    }
  in
  let result =
    run ~config ~positions:(_held_positions ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* An unfilled ticket is never volume-checked                           *)
(* ------------------------------------------------------------------ *)

(** The confirmation is defined on the week the ticket FILLS. A resting
    ([Entering]) ticket has no fill week, so no check runs — however bad the
    current volume looks. *)
let test_unfilled_ticket_is_never_checked _ =
  let positions =
    String.Map.singleton _ticker (make_entering_pos _ticker 100.0 _fill_date)
  in
  let result = run ~positions ~weekly_volumes:_unconfirmed_volumes () in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* No partial-week lookahead                                            *)
(* ------------------------------------------------------------------ *)

(** A fill lands mid-week; the Wednesday tick is not a screening tick, so the
    still-open fill week is never judged. The identical position ejects on the
    Friday tick that closes that week — pinning that the verdict waits for a
    complete week. *)
let test_no_partial_week_lookahead _ =
  let midweek_result =
    run ~is_screening_day:false ~current_date:_midweek
      ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  let friday_result =
    run ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that
    (List.length midweek_result, List.length friday_result)
    (equal_to (0, 1))

(* ------------------------------------------------------------------ *)
(* Window, side, skip-list and fail-soft no-ops                         *)
(* ------------------------------------------------------------------ *)

(** A fill from three weeks back is outside the evaluation window: it was
    already judged (and, if unconfirmed, ejected) at the time. *)
let test_stale_fill_week_is_not_re_judged _ =
  let result =
    run
      ~positions:(_held_positions ~fill_date:(Date.of_string "2024-03-05") ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** F5 is a property of the long-side breakout ticket; shorts are untouched. *)
let test_short_position_is_not_ejected _ =
  let result =
    run
      ~positions:(_held_positions ~side:Trading_base.Types.Short ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** A position already exiting this tick via another channel is skipped — two
    exits on one position would be rejected by the state machine. *)
let test_skip_list_collision_is_a_no_op _ =
  let result =
    run
      ~skip_position_ids:(String.Set.singleton _ticker)
      ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that (List.length result) (equal_to 0)

(** Fail-soft: with only three weekly bars neither branch can be evaluated
    ([Volume.confirms_breakout] returns [None]). Absence of evidence is not an
    unconfirmed breakout, so the position is held. *)
let test_insufficient_history_holds _ =
  let result =
    run ~positions:(_held_positions ()) ~weekly_volumes:[ 1000; 1000; 900 ] ()
  in
  assert_that (List.length result) (equal_to 0)

(* ------------------------------------------------------------------ *)
(* fill_week_confirmations — the PR-5 audit surface                      *)
(* ------------------------------------------------------------------ *)

(** Render one [(position_id, classification)] row so a single [assert_that] can
    pin the constructor without exact-float record equality. *)
let _summary (position_id, confirmation) =
  let label =
    match confirmation with
    | None -> "no_verdict"
    | Some (Volume.Spike _) -> "spike"
    | Some (Volume.Buildup _) -> "buildup"
    | Some (Volume.Unconfirmed _) -> "unconfirmed"
  in
  position_id ^ ":" ^ label

let _confirmations ?(config = _armed_config) ?(is_screening_day = true)
    ?(current_date = _screening_friday) ~positions ~weekly_volumes () =
  let bars = _bars_of_weekly_volumes weekly_volumes in
  Volume_eject_runner.fill_week_confirmations ~config
    ~volume_config:Volume.default_config ~is_screening_day ~positions
    ~bar_reader:(Bar_reader.of_in_memory_bars [ (_ticker, bars) ])
    ~current_date
  |> List.map ~f:_summary

let _outcome_label : Audit_recorder.fill_volume_outcome -> string = function
  | Ejected -> "ejected"
  | Skipped_other_exit -> "skipped_other_exit"
  | Held -> "held"

(** ["<position_id>:<verdict>:<outcome>"] — renders both halves of an emitted
    event so one [assert_that] pins the pairing. *)
let _event_summary (e : Audit_recorder.fill_volume_event) =
  _summary (e.position_id, e.confirmation) ^ ":" ^ _outcome_label e.outcome

(** Drive {!Volume_eject_runner.emit_fill_week_audit} with a capturing recorder
    and explicit id sets, so the outcome tagging can be exercised independently
    of the exit pipeline that normally supplies those sets. *)
let _audit_events ?(config = _armed_config)
    ?(skip_position_ids = String.Set.empty)
    ?(ejected_position_ids = String.Set.empty) ~positions ~weekly_volumes () =
  let captured = ref [] in
  let recorder : Audit_recorder.t =
    {
      Audit_recorder.noop with
      record_fill_volume = (fun e -> captured := e :: !captured);
    }
  in
  let bars = _bars_of_weekly_volumes weekly_volumes in
  Volume_eject_runner.emit_fill_week_audit ~config ~audit_recorder:recorder
    ~volume_config:Volume.default_config ~is_screening_day:true ~positions
    ~bar_reader:(Bar_reader.of_in_memory_bars [ (_ticker, bars) ])
    ~skip_position_ids ~ejected_position_ids ~current_date:_screening_friday;
  List.rev !captured |> List.map ~f:_event_summary

(** The four cells a ladder-v4 F5 arm must report separately. Only the third
    ejects; the first, second and FOURTH are all held — and the eject count
    alone cannot separate the fourth (held without a verdict, the qc-behavioral
    #2267 residual) from the confirmed holds. *)
let test_confirmations_distinguish_all_four_verdict_classes _ =
  let summarise weekly_volumes =
    _confirmations ~positions:(_held_positions ()) ~weekly_volumes ()
  in
  assert_that
    (List.concat_map ~f:summarise
       [
         _spike_volumes;
         _buildup_volumes;
         _unconfirmed_volumes;
         [ 1000; 1000; 900 ];
       ])
    (elements_are
       [
         equal_to (_ticker ^ ":spike");
         equal_to (_ticker ^ ":buildup");
         equal_to (_ticker ^ ":unconfirmed");
         equal_to (_ticker ^ ":no_verdict");
       ])

(** The audit surface reads the same fill-week WINDOW and applies the same SHAPE
    test as the eject path (LONG, [Holding], inside the evaluation window), so
    the two can never disagree about which week was judged. It does {i not}
    share the eject path's {b eligibility} — see
    {!test_skipped_position_is_audited_but_not_ejected}. *)
let test_confirmations_share_the_eject_paths_window_and_shape _ =
  let stale = _held_positions ~fill_date:(Date.of_string "2024-03-05") () in
  let short = _held_positions ~side:Trading_base.Types.Short () in
  let entering =
    String.Map.singleton _ticker
      (make_entering_pos _ticker 100.0 _screening_friday)
  in
  let rows positions =
    _confirmations ~positions ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that
    (List.map [ stale; short; entering ] ~f:(fun p -> List.length (rows p)))
    (elements_are [ equal_to 0; equal_to 0; equal_to 0 ])

(** R1: under the default config — and under the flag armed without the
    StopLimit family — no at-fill check runs, so the audit surface emits nothing
    and reads no bars. A mid-week tick is likewise silent (the fill week has not
    closed). *)
let test_confirmations_are_empty_when_unarmed_or_midweek _ =
  let unarmed = _default_config () in
  let flag_only =
    {
      (_default_config ()) with
      Weinstein_strategy_config.volume_confirm_at_fill = true;
    }
  in
  let counts =
    [
      _confirmations ~config:unarmed ~positions:(_held_positions ())
        ~weekly_volumes:_unconfirmed_volumes ();
      _confirmations ~config:flag_only ~positions:(_held_positions ())
        ~weekly_volumes:_unconfirmed_volumes ();
      _confirmations ~is_screening_day:false ~current_date:_midweek
        ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ();
    ]
  in
  assert_that
    (List.map counts ~f:List.length)
    (elements_are [ equal_to 0; equal_to 0; equal_to 0 ])

(* ------------------------------------------------------------------ *)
(* The audit population DIVERGES from the eject population              *)
(* ------------------------------------------------------------------ *)

(** The blocking divergence, pinned. A position already exiting this tick via
    another channel is in [skip_position_ids]: {!Volume_eject_runner.update}
    emits no eject for it, yet the audit surface still records its fill-week
    verdict — because that verdict is a property of the {i fill}, and this
    cohort (weak-volume breakout that stops out in week 0/1) is exactly what the
    plan's §5 prediction 4 measures. The row is tagged [Skipped_other_exit] so
    it can never be miscounted as an eject. *)
let test_skipped_position_is_audited_but_not_ejected _ =
  let skip = String.Set.singleton _ticker in
  let ejects =
    run ~skip_position_ids:skip ~positions:(_held_positions ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  let audited =
    _audit_events ~skip_position_ids:skip ~positions:(_held_positions ())
      ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that
    (List.length ejects, audited)
    (equal_to (0, [ _ticker ^ ":unconfirmed:skipped_other_exit" ]))

(** [outcome] is read off what the run DID, never off the verdict: one and the
    same [Unconfirmed] verdict carries all three outcomes, decided only by the
    id sets the tick observed. *)
let test_outcome_distinguishes_ejected_skipped_and_held _ =
  let events ?skip_position_ids ?ejected_position_ids () =
    _audit_events ?skip_position_ids ?ejected_position_ids
      ~positions:(_held_positions ()) ~weekly_volumes:_unconfirmed_volumes ()
  in
  assert_that
    (List.concat
       [
         events ~ejected_position_ids:(String.Set.singleton _ticker) ();
         events ~skip_position_ids:(String.Set.singleton _ticker) ();
         events ();
       ])
    (elements_are
       [
         equal_to (_ticker ^ ":unconfirmed:ejected");
         equal_to (_ticker ^ ":unconfirmed:skipped_other_exit");
         equal_to (_ticker ^ ":unconfirmed:held");
       ])

(* ------------------------------------------------------------------ *)
(* Special_exits.run integration — the audit glue actually fires         *)
(* ------------------------------------------------------------------ *)

(* A weekly_view whose last bar is the screening Friday, so
   [is_screening_day_view] is true inside [Special_exits.run]. *)
let _friday_weekly_view : Snapshot_runtime.Snapshot_bar_views.weekly_view =
  {
    closes = [| 100.0 |];
    raw_closes = [| 100.0 |];
    highs = [| 100.0 |];
    lows = [| 100.0 |];
    volumes = [| 1000.0 |];
    dates = [| _screening_friday |];
    n = 1;
  }

(** Drive the whole special-exit pipeline with a capturing recorder and read
    back the [fill_volume_event]s it emitted. This pins the glue between
    {!Volume_eject_runner.fill_week_confirmations} and
    {!Audit_recorder.record_fill_volume} — the runner-level tests above only pin
    the classification itself. *)
let _fill_volume_events_from_run ~config ~weekly_volumes =
  let captured = ref [] in
  let recorder : Audit_recorder.t =
    {
      Audit_recorder.noop with
      record_fill_volume = (fun e -> captured := e :: !captured);
    }
  in
  let bars = _bars_of_weekly_volumes weekly_volumes in
  let bar_reader = Bar_reader.of_in_memory_bars [ (_ticker, bars) ] in
  let last_bar = List.last_exn bars in
  let positions = _held_positions () in
  let no_op_record_force_exit ~last_stop_out_dates:_ ~positions:_
      ~current_date:_ ~cooldown_weeks:_ ~label:_ _ =
    ()
  in
  let _ =
    Special_exits.run ~config ~record_force_exit:no_op_record_force_exit
      ~positions
      ~last_stop_out_dates:(Hashtbl.create (module String))
      ~portfolio:{ cash = 1_000_000.0; positions }
      ~get_price:(fun s ->
        if String.equal s _ticker then Some last_bar else None)
      ~peak_tracker:Portfolio_risk.Force_liquidation.Peak_tracker.(create ())
      ~audit_recorder:recorder ~prior_macro_result:(ref None)
      ~prior_stages:(Hashtbl.create (module String))
      ~prior_stage_ma_values:(Hashtbl.create (module String))
      ~stage3_streaks:(Hashtbl.create (module String))
      ~laggard_streaks:(Hashtbl.create (module String))
      ~bar_reader ~index_view:_friday_weekly_view ~exit_transitions:[]
      ~current_date:_screening_friday
  in
  List.rev !captured

(** End-to-end through the real config path: with F5 armed on a config built by
    [default_config], a held ticket whose fill week confirmed via branch (a)
    produces one audit event carrying that classification — and, since nothing
    ejected it, the [Held] outcome. *)
let test_armed_config_emits_a_fill_volume_audit_event _ =
  assert_that
    (_fill_volume_events_from_run ~config:_armed_config
       ~weekly_volumes:_spike_volumes)
    (elements_are
       [
         all_of
           [
             field
               (fun (e : Audit_recorder.fill_volume_event) -> e.position_id)
               (equal_to _ticker);
             field
               (fun (e : Audit_recorder.fill_volume_event) -> e.confirmation)
               (matching ~msg:"Expected Some (Spike _)"
                  (function Some (Volume.Spike r) -> Some r | _ -> None)
                  (float_equal 3.0));
             field
               (fun (e : Audit_recorder.fill_volume_event) ->
                 _outcome_label e.outcome)
               (equal_to "held");
           ];
       ])

(** The other half of the end-to-end pairing: an unconfirmed fill week ejects,
    and the very same pipeline pass records the row as
    [Unconfirmed] + [Ejected]. Pins that [Special_exits] hands the eject ids it
    just produced to the audit emitter, so the two halves of the record agree
    without anyone re-deriving one from the other. *)
let test_unconfirmed_fill_week_audit_event_is_tagged_ejected _ =
  assert_that
    (_fill_volume_events_from_run ~config:_armed_config
       ~weekly_volumes:_unconfirmed_volumes
    |> List.map ~f:_event_summary)
    (elements_are [ equal_to (_ticker ^ ":unconfirmed:ejected") ])

(** R1: the default config emits no audit event at all on the same bars — the
    capture is inert exactly where the mechanism is. *)
let test_default_config_emits_no_fill_volume_audit_event _ =
  assert_that
    (_fill_volume_events_from_run ~config:(_default_config ())
       ~weekly_volumes:_spike_volumes)
    is_empty

let suite =
  "volume_eject_runner"
  >::: [
         "armed config emits a fill_volume audit event"
         >:: test_armed_config_emits_a_fill_volume_audit_event;
         "unconfirmed fill week audit event is tagged ejected"
         >:: test_unconfirmed_fill_week_audit_event_is_tagged_ejected;
         "default config emits no fill_volume audit event"
         >:: test_default_config_emits_no_fill_volume_audit_event;
         "fill_week_confirmations distinguish all four verdict classes"
         >:: test_confirmations_distinguish_all_four_verdict_classes;
         "fill_week_confirmations share the eject path's window and shape"
         >:: test_confirmations_share_the_eject_paths_window_and_shape;
         "skipped position is audited but not ejected"
         >:: test_skipped_position_is_audited_but_not_ejected;
         "outcome distinguishes ejected, skipped and held"
         >:: test_outcome_distinguishes_ejected_skipped_and_held;
         "fill_week_confirmations are empty when unarmed or mid-week"
         >:: test_confirmations_are_empty_when_unarmed_or_midweek;
         "fill-week 2x volume confirms and holds"
         >:: test_fill_week_spike_confirms_and_holds;
         "3-4-week build-up branch confirms and holds"
         >:: test_buildup_branch_confirms_and_holds;
         "neither branch ejects with the volume_eject tag"
         >:: test_unconfirmed_fill_week_ejects;
         "default config never ejects" >:: test_default_config_never_ejects;
         "flag without the StopLimit family never ejects"
         >:: test_flag_without_stoplimit_family_never_ejects;
         "unfilled ticket is never volume-checked"
         >:: test_unfilled_ticket_is_never_checked;
         "no partial-week lookahead" >:: test_no_partial_week_lookahead;
         "stale fill week is not re-judged"
         >:: test_stale_fill_week_is_not_re_judged;
         "short position is not ejected" >:: test_short_position_is_not_ejected;
         "skip-list collision is a no-op"
         >:: test_skip_list_collision_is_a_no_op;
         "insufficient history holds" >:: test_insufficient_history_holds;
       ]

let () = run_test_tt_main suite
