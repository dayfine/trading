(** Regression pin for the selection path — issue #2503.

    {1 What this pins, and why it is shaped this way}

    #2503 reported that a verbatim config clone of a committed baseline spec
    diverged on [main] from the first weeks of the run: different symbols
    entered from day one. The suspects were two PRs (#2500, #2501) framed as
    pure instrumentation. A cross-commit differential built on
    {!Selection_trace} cleared both — the rendered trace is byte-identical
    (129,084 bytes) at [bdcb257b], [b128b1d9] and [2b11c60d], across 45 screener
    / entry-walk cases plus 200 replayed screening days.

    A differential is only worth its verdict if it can detect the defect it
    claims to exclude, so the harness was mutation-tested against the four
    failure modes an "observational" refactor can actually hide. All four were
    caught:

    - a score threshold flipped from [>=] to [>] (21 trace lines moved),
    - a price threshold flipped from [>=] to [>] (17),
    - the equal-score tiebreak reversed (490),
    - the top-N cap off by one (834).

    The cross-commit differential is a one-shot instrument; these tests are the
    durable residue. Each one fails under exactly one of those mutations, so the
    suite carries the differential's detection power forward without a golden
    trace file — which would move on every legitimate config-default change and
    train readers to re-bless it unread.

    The two observational-equivalence tests pin the property the instrumentation
    PRs actually claim: capture on produces the same selection as capture off.
    That is [.claude/rules/experiment-flag-discipline.md] R1 (default-off is the
    prior behaviour) made mechanical for this surface. *)

open OUnit2
open Core
open Matchers
open Weinstein_types

let _cfg = Screener.default_config
let _sector_map = Selection_trace.sector_map
let _stocks = Selection_trace.stocks
let _as_of = Selection_trace.as_of

let _screen ?on_candidates config =
  Screener.screen_with_cooldown ?on_candidates ~config ~macro_trend:Bullish
    ~sector_map:(_sector_map ()) ~stocks:_stocks ~held_tickers:[] ~as_of:_as_of
    ~last_stop_out_dates:[] ()

let _tickers (cs : Screener.scored_candidate list) =
  List.map cs ~f:(fun c -> c.ticker)

let _scores (cs : Screener.scored_candidate list) =
  List.map cs ~f:(fun c -> c.score)

(** The tie group's shared score — read off the fixture rather than hardcoded,
    so a legitimate change to the scoring weights moves the probe with it
    instead of failing this test for the wrong reason. *)
let _tie_score () =
  let buys = (_screen _cfg).buy_candidates in
  List.find_map_exn buys ~f:(fun (c : Screener.scored_candidate) ->
      if List.mem Selection_trace.tie_group c.ticker ~equal:String.equal then
        Some c.score
      else None)

(* ------------------------------------------------------------------ *)
(* Ranking + truncation                                                 *)
(* ------------------------------------------------------------------ *)

(** Equal-score candidates come out in ascending ticker order under the default
    [Alphabetical] tiebreak — regardless of the order they were fed in, which
    the fixture deliberately scrambles. Fails if the tiebreak is reordered. *)
let test_equal_scores_rank_alphabetically _ =
  let buys = (_screen _cfg).buy_candidates in
  let tied =
    List.filter (_tickers buys) ~f:(fun t ->
        List.mem Selection_trace.tie_group t ~equal:String.equal)
  in
  assert_that tied (equal_to Selection_trace.tie_group)

(** A cap that cuts strictly {e inside} the tie group keeps exactly [max_n]
    candidates, and keeps the alphabetically-first members. This is the case a
    reorder or an off-by-one at the cap changes: which symbol survives. Fails
    under a top-N off-by-one and under a tiebreak reversal. *)
let test_cap_inside_tie_group_keeps_alphabetically_first _ =
  let keep = 3 in
  let buys = (_screen { _cfg with max_buy_candidates = keep }).buy_candidates in
  assert_that (_tickers buys)
    (equal_to (List.take Selection_trace.tie_group keep))

(** A cap of zero admits nothing — the degenerate edge of the same cap. *)
let test_zero_cap_admits_nothing _ =
  assert_that (_screen { _cfg with max_buy_candidates = 0 }).buy_candidates
    is_empty

(* ------------------------------------------------------------------ *)
(* Threshold inclusivity                                                *)
(* ------------------------------------------------------------------ *)

(** [min_score_override] is a [score >= n] gate: a candidate scoring exactly [n]
    is admitted, and raising the floor by one drops it. Pins both sides of the
    boundary, so a [>=] to [>] flip cannot pass by making the gate uniformly
    stricter. *)
let test_min_score_override_is_inclusive _ =
  let score = _tie_score () in
  let at = _screen { _cfg with min_score_override = Some score } in
  let above = _screen { _cfg with min_score_override = Some (score + 1) } in
  assert_that
    ( List.count (_scores at.buy_candidates) ~f:(Int.equal score),
      _scores above.buy_candidates )
    (all_of
       [
         field fst (equal_to (List.length Selection_trace.tie_group));
         field snd (all_of [ elements_are []; equal_to [] ]);
       ])

(** [max_score_override] is a [score < m] gate: a candidate scoring exactly [m]
    is {e excluded}, and a ceiling one above admits it. The mirror of the floor
    test — together they pin that the two gates are not both inclusive or both
    exclusive. *)
let test_max_score_override_is_exclusive _ =
  let score = _tie_score () in
  let at = _screen { _cfg with max_score_override = Some score } in
  let above = _screen { _cfg with max_score_override = Some (score + 1) } in
  assert_that
    ( List.count (_scores at.buy_candidates) ~f:(Int.equal score),
      List.count (_scores above.buy_candidates) ~f:(Int.equal score) )
    (all_of
       [
         field fst (equal_to 0);
         field snd (equal_to (List.length Selection_trace.tie_group));
       ])

(** [min_price] is a [breakout_price >= floor] gate: a candidate whose breakout
    price sits exactly on the floor is admitted. Fails under a [>=] to [>] flip
    in the liquidity floor. *)
let test_min_price_floor_is_inclusive _ =
  let buys = (_screen _cfg).buy_candidates in
  let price =
    List.find_map_exn buys ~f:(fun (c : Screener.scored_candidate) ->
        c.analysis.breakout_price)
  in
  let at = _screen { _cfg with min_price = price } in
  assert_that
    (List.count at.buy_candidates ~f:(fun (c : Screener.scored_candidate) ->
         Option.value_map c.analysis.breakout_price ~default:false
           ~f:(Float.equal price)))
    (gt (module Int_ord) 0)

(* ------------------------------------------------------------------ *)
(* Observational equivalence — the instrumentation contract             *)
(* ------------------------------------------------------------------ *)

(** #2501's [?on_candidates] callback is observational: supplying it yields the
    same admitted candidates, in the same order, as omitting it. Pins that the
    G2 cascade trace cannot perturb selection even when capture is ON — the
    stronger claim than "inert when off", and the one a stateful consumer could
    break. *)
let test_screener_on_candidates_does_not_change_selection _ =
  let seen = ref 0 in
  let off = _screen _cfg in
  let on = _screen ~on_candidates:(fun cs -> seen := List.length cs) _cfg in
  assert_that
    (_tickers on.buy_candidates, _tickers on.short_candidates, !seen)
    (all_of
       [
         field (fun (b, _, _) -> b) (equal_to (_tickers off.buy_candidates));
         field (fun (_, s, _) -> s) (equal_to (_tickers off.short_candidates));
         (* The callback really fired, so the equality above is evidence about
            an armed capture rather than a silently-absent one. *)
         field (fun (_, _, n) -> n) (gt (module Int_ord) 0);
       ])

let _entering_symbols (ts : Trading_strategy.Position.transition list) =
  List.filter_map ts ~f:(fun t ->
      match t.kind with
      | CreateEntering { symbol; _ } -> Some symbol
      | _ -> None)

let _walk ?on_candidates_considered (result : Screener.result) =
  let candidates = result.buy_candidates @ result.short_candidates in
  let config =
    Weinstein_strategy.default_config ~universe:Selection_trace.universe_tickers
      ~index_symbol:"GSPCX"
  in
  let get_price symbol =
    List.find_map candidates ~f:(fun (c : Screener.scored_candidate) ->
        if String.equal c.ticker symbol then
          Some
            {
              Types.Daily_price.date = _as_of;
              open_price = c.suggested_entry;
              high_price = c.suggested_entry;
              low_price = c.suggested_entry;
              close_price = c.suggested_entry;
              adjusted_close = c.suggested_entry;
              volume = 1_000_000;
              active_through = None;
            }
        else None)
  in
  Weinstein_strategy.entries_from_candidates ?on_candidates_considered ~config
    ~candidates ~stop_states:(ref String.Map.empty)
    ~bar_reader:(Weinstein_strategy.Bar_reader.empty ())
    ~portfolio:{ cash = 250_000.0; positions = String.Map.empty }
    ~get_price ~current_date:_as_of ()

(** #2500's [?on_candidates_considered] callback is observational: the entry
    walk emits the same entries, in the same order, with and without it. The
    entry walk's transitions — not the screener's top-N — are the actual
    selection outcome, so this is the pin that matters for "which symbols got
    bought". *)
let test_entry_walk_callback_does_not_change_entries _ =
  let result = _screen _cfg in
  let off = _walk result in
  let on = _walk ~on_candidates_considered:(fun _ -> ()) result in
  let on_symbols = _entering_symbols on in
  assert_that
    (on_symbols, List.length on_symbols)
    (all_of
       [
         field fst (equal_to (_entering_symbols off));
         (* The walk really emitted entries, so the equality above is evidence
            about a live selection rather than two empty lists. *)
         field snd (gt (module Int_ord) 0);
       ])

(* ------------------------------------------------------------------ *)
(* The harness itself                                                   *)
(* ------------------------------------------------------------------ *)

(* Rendering walks 45 screener cases plus 200 replayed screening days, so it
   costs seconds. Held once and shared, to keep the suite's two trace tests to
   the two renders the determinism check genuinely needs. *)
let _rendered = lazy (Selection_trace.render ())

(** The trace is a pure function of the code under test: two renders in one
    process are equal. Without this the cross-commit [cmp] result would be
    unfalsifiable — a trace that varied run to run could never be compared
    across builds. *)
let test_trace_is_deterministic _ =
  assert_that (Selection_trace.render ()) (equal_to (Lazy.force _rendered))

(** The trace actually covers a surface. A harness that silently degraded to
    zero cases — or to a replay that never screens — would still [cmp] equal
    across every commit, which is how an exoneration claim like #2503's fails
    quietly. The replay-day floor is the specific guard: an empty [Bar_reader]
    makes [is_screening_day_view] permanently false, and the whole replay then
    renders identical no-op rows at every commit. *)
let test_trace_covers_cases _ =
  let rendered = Lazy.force _rendered in
  let screening_days =
    List.count (String.split_lines rendered) ~f:(fun l ->
        String.is_substring l ~substring:"entered=")
  in
  assert_that
    (Selection_trace.case_count, screening_days)
    (all_of
       [ field fst (gt (module Int_ord) 0); field snd (gt (module Int_ord) 0) ])

let suite =
  "selection_trace"
  >::: [
         "equal scores rank alphabetically"
         >:: test_equal_scores_rank_alphabetically;
         "cap inside tie group keeps first"
         >:: test_cap_inside_tie_group_keeps_alphabetically_first;
         "zero cap admits nothing" >:: test_zero_cap_admits_nothing;
         "min_score_override is inclusive"
         >:: test_min_score_override_is_inclusive;
         "max_score_override is exclusive"
         >:: test_max_score_override_is_exclusive;
         "min_price floor is inclusive" >:: test_min_price_floor_is_inclusive;
         "screener on_candidates is observational"
         >:: test_screener_on_candidates_does_not_change_selection;
         "entry walk callback is observational"
         >:: test_entry_walk_callback_does_not_change_entries;
         "trace is deterministic" >:: test_trace_is_deterministic;
         "trace covers cases" >:: test_trace_covers_cases;
       ]

let () = run_test_tt_main suite
