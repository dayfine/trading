(** Split corpus x stop-fill decision (issue #2973).

    The basis consumer downstream of the stop machine: whether, and at what
    price, the simulator fills a long's protective sell-stop on the ex-date bar
    itself — the one bar where the stop (rescaled overnight by
    [Stop_split_adjust.scale], as [Stops_split_runner] does) and the tape meet
    on a new basis.

    For every split and three stop placements on the ex-date bar — above the
    open (gap-through), between the low and the open (traded through intraday),
    and under the low (untouched) — the decision is read two ways:

    - post-split basis: the rescaled stop against the raw ex-date bar;
    - pre-split basis: the unscaled stop against the ex-date bar multiplied back
      by the split ratio.

    The engine's fill rule ([Fill_rules.would_fill_stop] on the bar's intraday
    path, one fixed seed for both views) and the simulator's trigger-bar
    conversion guard ([Trigger_bar_stop_fill.bar_reaches_stop]) must agree
    across the two views (see [_same_decision] for what is compared). *)

open OUnit2
open Core
open Matchers

let _entries =
  [
    "AAPL-2014-06-09";
    "AAPL-2020-08-31";
    "C-1996-05-28";
    "GE-2021-08-02";
    "INFY-2014-12-08";
    "ISRG-2017-10-06";
    "NVDA-2021-07-20";
    "NVDA-2024-06-10";
    "TSLA-2020-08-31";
  ]

let _sell = Trading_base.Types.Sell

(* Stop placements on the ex-date bar, relative to the pre-split-basis bar: a
   stop this far above the open gaps through at the open, and this far under the
   low is never touched. *)
let _gap_above_open = 1.01
let _under_low = 0.99

(* Fill-vs-trigger % is a ratio of two rescaled prices; allow float noise. *)
let _pct_tol = 1e-9

let _load name : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

let _engine_bar symbol (b : Types.Daily_price.t) :
    Trading_engine.Types.price_bar =
  {
    symbol;
    open_price = b.open_price;
    high_price = b.high_price;
    low_price = b.low_price;
    close_price = b.close_price;
  }

let _scale_bar k (b : Trading_engine.Types.price_bar) :
    Trading_engine.Types.price_bar =
  {
    b with
    open_price = b.open_price *. k;
    high_price = b.high_price *. k;
    low_price = b.low_price *. k;
    close_price = b.close_price *. k;
  }

type decision = { reaches : bool; fill_vs_stop : float option }
(** The stop-fill decision for one view: whether the conversion guard fires, and
    the fill-vs-trigger % when the engine fills. *)

let _decide ~seed ~stop bar =
  let path =
    Trading_engine.Price_path.generate_path
      ~config:{ Trading_engine.Price_path.default_config with seed = Some seed }
      bar
  in
  {
    reaches =
      Trading_simulation.Trigger_bar_stop_fill.bar_reaches_stop ~side:_sell
        ~stop_price:stop bar;
    fill_vs_stop =
      Option.map
        (Trading_engine.Fill_rules.would_fill_stop ~path ~side:_sell
           ~stop_price:stop) ~f:(fun (f : Trading_engine.Types.fill_result) ->
          (f.price -. stop) /. stop);
  }

(** Where a stop sits on the ex-date bar. *)
type placement =
  | Gap_through  (** Above the open: fills at the open. *)
  | Intraday  (** Between the low and the open: traded through on the path. *)
  | Untouched  (** Under the low: never fills. *)

(** Pre-split-basis stop level for each placement against the ex-date bar. *)
let _placements (pre : Trading_engine.Types.price_bar) =
  [
    (Gap_through, pre.open_price *. _gap_above_open);
    ( Intraday,
      (pre.low_price +. Float.min pre.open_price pre.close_price) /. 2.0 );
    (Untouched, pre.low_price *. _under_low);
  ]

(** [(placement, post-split view, pre-split view)] for every placement at every
    split. *)
let _views (entry : Split_corpus.entry) =
  List.concat_map entry.meta.splits ~f:(fun (s : Split_corpus.split) ->
      let ex =
        _engine_bar entry.meta.symbol
          (List.find_exn entry.bars ~f:(fun b -> Date.equal b.date s.ex_date))
      in
      let pre = _scale_bar s.ratio ex in
      let seed = Trading_engine.Price_path.seed_for_bar ex in
      List.map (_placements pre) ~f:(fun (placement, pre_stop) ->
          let post_stop =
            Weinstein_stops.get_stop_level
              (Weinstein_stops.Stop_split_adjust.scale ~factor:s.ratio
                 (Weinstein_stops.Initial
                    { stop_level = pre_stop; reference_level = pre_stop }))
          in
          ( placement,
            _decide ~seed ~stop:post_stop ex,
            _decide ~seed ~stop:pre_stop pre )))

(** The two views take the same decision: the guard fires on both or neither,
    the engine fills on both or neither, and — for a gap-through, which fills at
    the open — at the same fill-vs-trigger %. An intraday fill's % is compared
    only for fill / no-fill: the path's Brownian noise is in absolute dollars,
    so its slippage % is not scale-invariant (finding on issue #2973, registry
    row "intraday path noise is absolute-dollar ..."). *)
let _same_decision (placement, post, pre) =
  Bool.equal post.reaches pre.reaches
  &&
  match (post.fill_vs_stop, pre.fill_vs_stop, placement) with
  | None, None, _ -> true
  | Some a, Some b, Gap_through -> Float.( <= ) (Float.abs (a -. b)) _pct_tol
  | Some _, Some _, (Intraday | Untouched) -> true
  | _ -> false

let _test_stop_fill_basis_invariant name _ =
  assert_that
    (List.map (_views (_load name)) ~f:_same_decision)
    (all_of [ field List.length (gt (module Int_ord) 0); each (equal_to true) ])

(** Guards the test above against vacuity: across the corpus the engine does
    fill some of the placed stops, and leaves some unfilled. *)
let test_stop_fill_placements_cover_fill_and_no_fill _ =
  let posts =
    List.concat_map _entries ~f:(fun name ->
        List.map (_views (_load name)) ~f:(fun (_, post, _) -> post))
  in
  assert_that
    (List.partition_tf posts ~f:(fun d -> Option.is_some d.fill_vs_stop))
    (all_of
       [
         field (fun (filled, _) -> List.length filled) (gt (module Int_ord) 0);
         field
           (fun (_, unfilled) -> List.length unfilled)
           (gt (module Int_ord) 0);
       ])

let _per_entry label test =
  List.map _entries ~f:(fun name ->
      Printf.sprintf "%s/%s" label name >:: test name)

let suite =
  "split_corpus_stop_fill"
  >::: _per_entry "stop_fill_basis_invariant" _test_stop_fill_basis_invariant
       @ [
           "stop_fill_placements_cover_fill_and_no_fill"
           >:: test_stop_fill_placements_cover_fill_and_no_fill;
         ]

let () = run_test_tt_main suite
