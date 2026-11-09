(** Split corpus x volume consumers (issue #2973).

    The bar store's [volume] is restated for every later split (the window's
    final share count) while [close] is raw. A consumer that reads only the
    volume column is on one basis; a consumer that multiplies the two columns is
    on a mixed basis unless it divides out the pending splits.

    Oracle: the {b no-split tape}. Every corpus bar is restated into the first
    bar's basis: O/H/L/C by {!Split_corpus.restate_bar} [~as_of:first], volume
    divided by the pending split product of the first bar (store volume is in
    the final share count). That tape has no ex-date anywhere, so a consumer
    reading one consistent basis gives the same relative answer on it as on the
    store tape. A consumer on a mixed basis steps by the split ratio at the
    ex-date on the store tape and not on the no-split tape. Three consumers:

    - {b Breakout volume ratio} ([Volume.analyze_breakout] over weekly bars, the
      screener's confirmation, and [Volume.confirms_breakout], the verdict the
      at-fill eject runner reads through its named form
      [Volume.classify_breakout]): same ratio and same verdict at every week.
    - {b Strategy dollar-ADV} ([Liquidity_metric.dollar_adv], the entry gate,
      the held-position exit and the short-borrow gate), armed with the split
      divisor as [Liquidity_config.true_dollar_volume] arms it ([F] over the
      ranker's applied splits): the same reading at every bar. The unarmed
      default reads raw close x restated volume, which is the mixed basis this
      column rejects (#3136; the flag is default-off, unpromoted).
    - {b Universe ranker dollar volume}
      ([Universe.Dollar_volume_basis.bar_dollar_volume True_dollars] over
      [applied_splits]): every corpus split is applied, and every bar's dollar
      volume matches the no-split tape.

    The two dollar-volume columns skip {!_volume_basis_unresolved}: entries
    whose split the ranker's volume check drops (a recorded finding).

    Built-in mutation pins: feeding the volume consumer raw volume, or the
    dollar-ADV raw close x restated volume, moves the reading by about the split
    ratio at every split, so each oracle above has teeth on every corpus split.
*)

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
    "GMCR-2010-05-18";
    "ISRG-2017-10-06";
    "NVDA-2021-07-20";
    "NVDA-2024-06-10";
    "TSLA-2020-08-31";
  ]

(* Entries whose split [Dollar_volume_basis.applied_splits] drops as "stored
   volume not restated" (the volume jump-share check): both dollar-volume
   consumers then read raw close x stored volume before the ex-date. GMCR's 3:1
   reads a 10-bar median jump share of ~0.66 (>= 0.5); whether its store volume
   is raw or the check misfires on a real volume surge cannot be settled from
   the window (mean share 0.21 to 0.70 over 20 to 100 bars). Recorded in
   dev/findings/registry.sexp; excluded from the dollar-volume columns only. *)
let _volume_basis_unresolved = [ "GMCR-2010-05-18" ]
let _volume_config = Volume.default_config

let _adv_lookback =
  Weinstein_strategy.Liquidity_config.default_config.adv_lookback_days

(* The no-split tape rounds restated volume to whole shares; corpus volumes are
   at least ~10^5 shares a day, so the rounding moves a reading by < 1e-5. *)
let _rel_tol = 1e-5

(* A mutated basis must move a reading by at least half the split's log ratio:
   a step nearer the full ratio than none. *)
let _min_step_share = 0.5

let _load name : Split_corpus.entry =
  match Split_corpus.find_root () with
  | Some root -> Split_corpus.load ~root name
  | None -> assert_failure "trading/test_data/split_corpus not found above cwd"

let _rel_diff a b = Float.abs (a -. b) /. Float.abs b
let _log_gap a b = Float.abs (Float.log (a /. b))

let _with_volume (b : Types.Daily_price.t) v : Types.Daily_price.t =
  { b with volume = Float.iround_nearest_exn v }

(** The store tape restated into the first bar's basis: no ex-date remains. *)
let _no_split_tape (entry : Split_corpus.entry) =
  let first = (List.hd_exn entry.bars).date in
  let k = Split_corpus.pending_ratio entry.meta first in
  List.map entry.bars ~f:(fun b ->
      _with_volume
        (Split_corpus.restate_bar entry.meta ~as_of:first b)
        (Float.of_int b.volume /. k))

(** Mutation: the volume as printed that day (not restated for the window's
    later splits), as a store with raw volume would carry it. *)
let _raw_volume_tape (entry : Split_corpus.entry) =
  List.map entry.bars ~f:(fun (b : Types.Daily_price.t) ->
      _with_volume b
        (Float.of_int b.volume /. Split_corpus.pending_ratio entry.meta b.date))

(* ------------------------------------------------------------------ *)
(* Breakout volume ratio                                                *)
(* ------------------------------------------------------------------ *)

let _weekly bars =
  Array.of_list
    (Time_period.Conversion.daily_to_weekly ~include_partial_week:true bars)

(** [(volume ratio, eject-runner verdict)] at every week with a full lookback.
*)
let _volume_readings bars =
  let weekly = _weekly bars in
  let n = Array.length weekly in
  let callbacks = Volume.callbacks_from_bars ~bars:(Array.to_list weekly) in
  List.filter_map (List.range _volume_config.lookback_bars n) ~f:(fun i ->
      Volume.analyze_breakout ~config:_volume_config
        ~bars:(Array.to_list weekly) ~event_idx:i
      |> Option.map ~f:(fun (r : Volume.result) ->
          ( r.volume_ratio,
            Volume.confirms_breakout ~config:_volume_config ~callbacks
              ~event_offset:(n - 1 - i) )))

let _split_week weekly (s : Split_corpus.split) =
  fst
    (Option.value_exn
       (Array.findi weekly ~f:(fun _ (b : Types.Daily_price.t) ->
            Date.( >= ) b.date s.ex_date)))

(** Largest log gap between the raw-volume ratio and the no-split ratio over the
    weeks whose event bar or lookback straddles [s], as a share of the split's
    log ratio. *)
let _raw_volume_step_share (entry : Split_corpus.entry) s =
  let weekly = _weekly entry.bars in
  let w = _split_week weekly s in
  let ratio_at bars i =
    (Option.value_exn
       (Volume.analyze_breakout ~config:_volume_config
          ~bars:(Array.to_list (_weekly bars))
          ~event_idx:i))
      .volume_ratio
  in
  let raw = _raw_volume_tape entry and one = _no_split_tape entry in
  List.range w
    (Int.min (Array.length weekly) (w + _volume_config.lookback_bars + 1))
  |> List.map ~f:(fun i -> _log_gap (ratio_at raw i) (ratio_at one i))
  |> List.max_elt ~compare:Float.compare
  |> Option.value ~default:0.0
  |> fun gap -> gap /. Float.abs (Float.log s.Split_corpus.ratio)

(* ------------------------------------------------------------------ *)
(* Universe ranker dollar volume                                        *)
(* ------------------------------------------------------------------ *)

let _composition_bar (b : Types.Daily_price.t) :
    Universe.Composition_bar_reader.bar =
  {
    date = b.date;
    close = b.close_price;
    adjusted_close = b.adjusted_close;
    volume = Float.of_int b.volume;
  }

let _vendor_splits (meta : Split_corpus.meta) =
  List.map meta.splits ~f:(fun (s : Split_corpus.split) ->
      ({ date = s.ex_date; factor = s.ratio } : Corporate_actions.split))

let _applied_splits (entry : Split_corpus.entry) =
  Universe.Dollar_volume_basis.applied_splits
    Universe.Dollar_volume_basis.true_dollars_config
    (List.map entry.bars ~f:_composition_bar)
    (_vendor_splits entry.meta)

(** [(ranker's true dollars, no-split close x volume)] for every bar. *)
let _ranker_pairs (entry : Split_corpus.entry) =
  let splits = _applied_splits entry in
  List.map2_exn entry.bars (_no_split_tape entry) ~f:(fun b o ->
      ( Universe.Dollar_volume_basis.bar_dollar_volume True_dollars ~splits
          (_composition_bar b),
        o.close_price *. Float.of_int o.volume ))

(* ------------------------------------------------------------------ *)
(* Strategy dollar-ADV                                                  *)
(* ------------------------------------------------------------------ *)

let _adv ?split_divisor bars =
  Option.value_exn
    (Weinstein_strategy.Liquidity_metric.dollar_adv ?split_divisor
       ~lookback_days:_adv_lookback bars)

(** [(store-tape reading, no-split reading)] for the window ending on every bar
    from the first full window on. [split_divisor] is the store tape's divisor:
    {!_armed} is the armed production path. *)
let _adv_pairs ?split_divisor (entry : Split_corpus.entry) =
  let one = _no_split_tape entry in
  List.range _adv_lookback (List.length entry.bars + 1)
  |> List.map ~f:(fun len ->
      (_adv ?split_divisor (List.take entry.bars len), _adv (List.take one len)))

(** The divisor [Liquidity_config.true_dollar_volume] arms: [F] over the
    ranker's applied splits, as [True_dollar_divisor] computes it from the
    symbol's [splits.csv] (here the corpus entry's splits). *)
let _armed (entry : Split_corpus.entry) =
  Universe.Dollar_volume_basis.split_divisor ~splits:(_applied_splits entry)

(** Log gap, as a share of the split's log ratio, between the unarmed reading
    (raw close x restated volume) and the no-split reading on the window ending
    the day before the ex-date. *)
let _mixed_adv_step_share (entry : Split_corpus.entry) (s : Split_corpus.split)
    =
  let len =
    List.count entry.bars ~f:(fun (b : Types.Daily_price.t) ->
        Date.( < ) b.date s.ex_date)
  in
  let one = _no_split_tape entry in
  _log_gap (_adv (List.take entry.bars len)) (_adv (List.take one len))
  /. Float.abs (Float.log s.ratio)

(* ------------------------------------------------------------------ *)
(* Tests                                                                *)
(* ------------------------------------------------------------------ *)

let _same_reading =
  field (fun (a, b) -> _rel_diff a b) (lt (module Float_ord) _rel_tol)

let _test_volume_ratio_one_basis name _ =
  let entry = _load name in
  let one = _volume_readings (_no_split_tape entry) in
  assert_that
    (_volume_readings entry.bars)
    (all_of
       [
         field List.length (gt (module Int_ord) 0);
         elements_are
           (List.map one ~f:(fun (ratio, verdict) ->
                all_of
                  [
                    field
                      (fun (r, _) -> _rel_diff r ratio)
                      (lt (module Float_ord) _rel_tol);
                    field snd (equal_to (verdict : bool option));
                  ]));
       ])

let _test_dollar_adv_one_basis name _ =
  let entry = _load name in
  assert_that
    (_adv_pairs ~split_divisor:(_armed entry) entry)
    (all_of [ field List.length (gt (module Int_ord) 0); each _same_reading ])

let _test_ranker_applies_every_split name _ =
  let entry = _load name in
  assert_that (_applied_splits entry)
    (elements_are
       (List.map (_vendor_splits entry.meta) ~f:(fun s ->
            equal_to (s : Corporate_actions.split))))

let _test_ranker_dollar_volume_one_basis name _ =
  assert_that
    (_ranker_pairs (_load name))
    (all_of [ field List.length (gt (module Int_ord) 0); each _same_reading ])

(** Mutation pin: raw volume steps the volume ratio at every corpus split. *)
let test_raw_volume_steps_every_split _ =
  assert_that
    (List.concat_map _entries ~f:(fun name ->
         let entry = _load name in
         List.map entry.meta.splits ~f:(_raw_volume_step_share entry)))
    (each (ge (module Float_ord) _min_step_share))

(** Mutation pin: raw close x restated volume (the unarmed dollar-ADV) steps by
    the split ratio at every corpus split. *)
let test_mixed_dollar_adv_steps_every_split _ =
  assert_that
    (List.concat_map _entries ~f:(fun name ->
         let entry = _load name in
         List.map entry.meta.splits ~f:(_mixed_adv_step_share entry)))
    (each (ge (module Float_ord) _min_step_share))

(** Tripwire for {!_volume_basis_unresolved}: the ranker's volume check
    currently drops GMCR's 2010-05-18 3:1 (the vendor record carries it, the
    applied list is empty). If the check changes and applies the split, this
    fails, flagging the exclusion as stale rather than letting it mask a
    now-resolvable entry. *)
let test_ranker_drops_gmcr_2010_split_pending_finding _ =
  let entry = _load "GMCR-2010-05-18" in
  assert_that
    (_vendor_splits entry.meta, _applied_splits entry)
    (all_of
       [
         field fst
           (elements_are
              [
                equal_to
                  ({ date = Date.of_string "2010-05-18"; factor = 3.0 }
                    : Corporate_actions.split);
              ]);
         field snd (elements_are []);
       ])

let _per_entry ?(entries = _entries) label test =
  List.map entries ~f:(fun name ->
      Printf.sprintf "%s/%s" label name >:: test name)

(** The dollar-volume columns run over the entries whose basis is settled. *)
let _dollar_entries =
  List.filter _entries ~f:(fun name ->
      not (List.mem _volume_basis_unresolved name ~equal:String.equal))

let suite =
  "split_corpus_volume"
  >::: _per_entry "volume_ratio_one_basis" _test_volume_ratio_one_basis
       @ _per_entry ~entries:_dollar_entries "dollar_adv_one_basis"
           _test_dollar_adv_one_basis
       @ _per_entry ~entries:_dollar_entries "ranker_applies_every_split"
           _test_ranker_applies_every_split
       @ _per_entry ~entries:_dollar_entries "ranker_dollar_volume_one_basis"
           _test_ranker_dollar_volume_one_basis
       @ [
           "raw_volume_steps_every_split" >:: test_raw_volume_steps_every_split;
           "mixed_dollar_adv_steps_every_split"
           >:: test_mixed_dollar_adv_steps_every_split;
           "ranker_drops_gmcr_2010_split_pending_finding"
           >:: test_ranker_drops_gmcr_2010_split_pending_finding;
         ]

let () = run_test_tt_main suite
