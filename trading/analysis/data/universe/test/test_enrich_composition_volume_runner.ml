open Core
open OUnit2
open Matchers
module Snapshot = Universe.Snapshot
open Universe.Snapshot
module Enrich = Enrich_composition_volume_runner_lib

(* ---------------------------------------------------------------------- *)
(* Fixture builders                                                        *)
(* ---------------------------------------------------------------------- *)

(* Snapshots anchor at 2020-05-31; the trailing dollar-volume window is the
   builder default 60 calendar days back ([2020-04-01, 2020-05-31]). *)
let _anchor_date = Date.create_exn ~y:2020 ~m:Month.May ~d:31

let _make_tmp_dir suffix =
  let dir = Stdlib.Filename.temp_file "enrich_test_" ("_" ^ suffix ^ ".d") in
  (try Stdlib.Sys.remove dir with _ -> ());
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  dir

let _cleanup_dir dir =
  ignore
    (Stdlib.Sys.command (Printf.sprintf "rm -rf %s" (Filename.quote dir)) : int)

(* Mirror the production sharding rule used by Composition_bar_reader:
   data/<L1>/<L2>/<symbol>/data.csv (L1 = first letter, L2 = last letter, or
   L1 for single-char symbols). *)
let _bars_path ~root sym =
  let l1 = String.prefix sym 1 in
  let l2 =
    if String.length sym >= 2 then
      String.sub sym ~pos:(String.length sym - 1) ~len:1
    else l1
  in
  let dir =
    Filename.concat (Filename.concat (Filename.concat root l1) l2) sym
  in
  ignore
    (Stdlib.Sys.command (Printf.sprintf "mkdir -p %s" (Filename.quote dir))
      : int);
  Filename.concat dir "data.csv"

(* [n_bars] daily points stepping back from 2020-05-29 at constant
   (close, volume) → flat dollar-volume score = close * volume. *)
let _write_bars ~root sym ~close ~volume ~n_bars =
  let path = _bars_path ~root sym in
  let anchor = Date.create_exn ~y:2020 ~m:Month.May ~d:29 in
  let buf = Buffer.create 1024 in
  Buffer.add_string buf "date,open,high,low,close,adjusted_close,volume\n";
  List.iter
    (List.init n_bars ~f:(fun i -> Date.add_days anchor (-i)))
    ~f:(fun date ->
      Buffer.add_string buf
        (Printf.sprintf "%s,%.2f,%.2f,%.2f,%.2f,%.2f,%d\n" (Date.to_string date)
           close close close close close volume));
  Out_channel.write_all path ~data:(Buffer.contents buf)

let _entry ~symbol ~weight ~sector ~synthetic : Snapshot.entry =
  { symbol; weight; sector; synthetic; avg_dollar_volume = None }

(* A snapshot with two real entries (AAA: 60 bars → score; SPRS: 5 bars →
   None) and one synthetic entry (left untouched). Order is deliberate so the
   composition-preservation check has order to verify. *)
let _make_snapshot () : Snapshot.t =
  {
    date = _anchor_date;
    method_ = Composition_from_individuals;
    size = 3;
    entries =
      [
        _entry ~symbol:"AAA" ~weight:0.001 ~sector:"Tech" ~synthetic:false;
        _entry ~symbol:"SPRS" ~weight:0.001 ~sector:"" ~synthetic:false;
        _entry ~symbol:"SYNTH_HiTec_0001" ~weight:0.001 ~sector:"HiTec"
          ~synthetic:true;
      ];
    aggregate_period_return = 0.123;
  }

(* Returns (goldens_dir, bars_root, golden_path). Caller cleans up the root. *)
let _setup () =
  let root = _make_tmp_dir "fixture" in
  let goldens_dir = Filename.concat root "goldens" in
  let bars_root = Filename.concat root "bars" in
  ignore
    (Stdlib.Sys.command
       (Printf.sprintf "mkdir -p %s" (Filename.quote goldens_dir))
      : int);
  (* AAA: 60 trailing bars at (100.0, 1_000_000) → score = 100M.
     SPRS: only 5 bars → below min_window_bars=30 → None. *)
  _write_bars ~root:bars_root "AAA" ~close:100.0 ~volume:1_000_000 ~n_bars:60;
  _write_bars ~root:bars_root "SPRS" ~close:50.0 ~volume:1_000_000 ~n_bars:5;
  let golden_path = Filename.concat goldens_dir "top-3-2020.sexp" in
  (match Snapshot.save (_make_snapshot ()) ~path:golden_path with
  | Ok () -> ()
  | Error err -> assert_failure ("setup save failed: " ^ Status.show err));
  (root, goldens_dir, bars_root, golden_path)

let _run_or_fail ~goldens_dir ~bars_root =
  match Enrich.run ~goldens_dir ~bars_root with
  | Ok r -> r
  | Error err -> assert_failure ("run failed: " ^ Status.show err)

let _load_or_fail path =
  match Snapshot.load ~path with
  | Ok s -> s
  | Error err -> assert_failure ("load failed: " ^ Status.show err)

(* ---------------------------------------------------------------------- *)
(* Tests                                                                   *)
(* ---------------------------------------------------------------------- *)

(* A non-synthetic entry with enough bars gets its trailing dollar-volume
   score (close * volume = 100M); a sparse one stays None; a synthetic one is
   left None. The post-write golden carries exactly these. *)
let test_enriched_volumes_written _ =
  let root, goldens_dir, bars_root, golden_path = _setup () in
  let _ = _run_or_fail ~goldens_dir ~bars_root in
  let enriched = _load_or_fail golden_path in
  _cleanup_dir root;
  assert_that enriched
    (field
       (fun s -> List.map s.entries ~f:(fun e -> e.avg_dollar_volume))
       (elements_are
          [
            is_some_and (float_equal ~epsilon:1.0 100_000_000.0);
            is_none;
            is_none;
          ]))

(* Behavior-neutrality: every field except avg_dollar_volume is preserved
   bit-for-bit. The run reports composition_changed=0, and the projection of
   the written golden onto (symbol, weight, sector, synthetic, order) +
   snapshot-level fields equals the original. *)
let test_composition_preserved _ =
  let root, goldens_dir, bars_root, golden_path = _setup () in
  let before = _make_snapshot () in
  let result = _run_or_fail ~goldens_dir ~bars_root in
  let after = _load_or_fail golden_path in
  _cleanup_dir root;
  assert_that
    (result.composition_changed, Enrich.composition_preserved before after)
    (equal_to (0, true))

(* The per-file tally counts each entry class once. *)
let test_run_tally _ =
  let root, goldens_dir, bars_root, _ = _setup () in
  let result = _run_or_fail ~goldens_dir ~bars_root in
  _cleanup_dir root;
  assert_that result
    (all_of
       [
         field (fun (r : Enrich.result) -> List.length r.files) (equal_to 1);
         field (fun (r : Enrich.result) -> r.composition_changed) (equal_to 0);
         field
           (fun (r : Enrich.result) -> (List.hd_exn r.files).result)
           (equal_to
              ({ enriched = 1; no_volume = 1; synthetic = 1 }
                : Enrich.entry_result));
       ])

(* Idempotence: enriching an already-enriched golden is a no-op (composition
   still preserved, volumes unchanged). *)
let test_idempotent _ =
  let root, goldens_dir, bars_root, golden_path = _setup () in
  let _ = _run_or_fail ~goldens_dir ~bars_root in
  let first = _load_or_fail golden_path in
  let second_result = _run_or_fail ~goldens_dir ~bars_root in
  let second = _load_or_fail golden_path in
  _cleanup_dir root;
  assert_that
    (second_result.composition_changed, Snapshot.equal first second)
    (equal_to (0, true))

(* Negative path for the behavior-neutrality guard. [run] writes a golden back
   ONLY when [composition_preserved] holds (a false → file not written,
   composition_changed incremented). [run] itself cannot drift composition by
   construction ([enrich_snapshot] only touches avg_dollar_volume, with no
   fault-injection seam), so the guard is defense-in-depth against a future
   regression in [enrich_snapshot]. This test pins the guard's *decision
   function* directly: each single-aspect non-volume drift must read as
   composition-CHANGED (false), while a volume-only diff must read as preserved
   (true). A regression that let a non-volume field mutate would flip one of
   these from false→true and fail here — the exact failure the invariant exists
   to catch. *)
let test_composition_drift_detected _ =
  let before = _make_snapshot () in
  let first = List.hd_exn before.entries in
  let rest = List.tl_exn before.entries in
  let with_first e = { before with entries = e :: rest } in
  let drift_weight = with_first { first with weight = first.weight +. 0.5 } in
  let drift_symbol = with_first { first with symbol = "ZZZ" } in
  let drift_sector = with_first { first with sector = "Energy" } in
  let drift_synthetic = with_first { first with synthetic = true } in
  let drift_order = { before with entries = List.rev before.entries } in
  let drift_date = { before with date = Date.add_days before.date 1 } in
  let drift_size = { before with size = before.size + 1 } in
  let drift_aggregate =
    {
      before with
      aggregate_period_return = before.aggregate_period_return +. 1.0;
    }
  in
  (* avg_dollar_volume is the ONE field the guard ignores → still preserved. *)
  let volume_only = with_first { first with avg_dollar_volume = Some 123.0 } in
  assert_that
    (List.map
       ~f:(Enrich.composition_preserved before)
       [
         drift_weight;
         drift_symbol;
         drift_sector;
         drift_synthetic;
         drift_order;
         drift_date;
         drift_size;
         drift_aggregate;
         volume_only;
       ])
    (elements_are
       [
         equal_to false;
         equal_to false;
         equal_to false;
         equal_to false;
         equal_to false;
         equal_to false;
         equal_to false;
         equal_to false;
         equal_to true;
       ])

(* enrich_entry leaves a synthetic entry completely untouched regardless of
   whether bars happen to exist for its (synthetic) symbol. *)
let test_synthetic_entry_untouched _ =
  let config =
    Universe.Build_from_individuals.default_config ~size:1
      ~bars_root:"/nonexistent" ~symbol_types_path:"" ~sectors_csv_path:""
      ~inventory_path:""
  in
  let synth =
    _entry ~symbol:"SYNTH_HiTec_0001" ~weight:0.5 ~sector:"HiTec"
      ~synthetic:true
  in
  let out = Enrich.enrich_entry ~date:_anchor_date ~config synth in
  assert_that out (equal_to (synth : Snapshot.entry))

let suite =
  "Enrich_composition_volume_runner"
  >::: [
         "test_enriched_volumes_written" >:: test_enriched_volumes_written;
         "test_composition_preserved" >:: test_composition_preserved;
         "test_composition_drift_detected" >:: test_composition_drift_detected;
         "test_run_tally" >:: test_run_tally;
         "test_idempotent" >:: test_idempotent;
         "test_synthetic_entry_untouched" >:: test_synthetic_entry_untouched;
       ]

let () = run_test_tt_main suite
