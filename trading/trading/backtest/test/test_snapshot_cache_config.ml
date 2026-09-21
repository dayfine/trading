(** Unit tests for {!Backtest.Snapshot_cache_config}'s run diagnostic.

    The line this module renders is the one artefact every chain log carries and
    every post-mortem greps (#2878), so its {b exact text} is pinned here rather
    than left to whatever a run happens to print. *)

open OUnit2
open Matchers
module Config = Backtest.Snapshot_cache_config
module Daily_panels = Snapshot_runtime.Daily_panels

(* Every field carries a DISTINCT value so no two can be transposed in the
   format string without reddening the assertion — an all-zeros fixture would
   render identically under almost any misordering. *)
let _stats : Daily_panels.stats =
  {
    hits = 11;
    misses = 27;
    miss_absent = 7;
    evictions = 5;
    n_symbols_touched = 10;
    n_symbols_absent = 3;
    occupancy =
      {
        max_entries = 8;
        max_bytes = 4096;
        max_mmap_open = 6;
        avg_entries = 4.5;
        avg_bytes = 2048.75;
      };
  }

let _high_water : Config.process_high_water =
  { top_heap_bytes = 123_456; maxrss_bytes = 987_654 }

let _render ?(stats = _stats) () =
  Config.render_cache_stats_line ~stats ~n_symbols:20 ~cap_mb:4096
    ~cap_mmap_handles:256 ~high_water:_high_water

(* The whole line, character for character. [misses_per_symbol] = 27/20 = 1.35;
   [loads_per_touched] = (27-7)/10 = 2.00; [avg_bytes] truncates to 2048. *)
let test_renders_the_pinned_line _ =
  assert_that (_render ())
    (equal_to
       "Panel_runner: snapshot cache hits=11 misses=27 miss_absent=7 \
        evictions=5 n_symbols=20 misses_per_symbol=1.35 n_symbols_touched=10 \
        n_symbols_absent=3 loads_per_touched=2.00 max_entries=8 max_bytes=4096 \
        max_mmap_open=6 avg_entries=4.5 avg_bytes=2048 cap_mb=4096 \
        cap_mmap_handles=256 top_heap_bytes=123456 maxrss_bytes=987654")

(* [loads_per_touched] excludes the absent-symbol misses; [misses_per_symbol]
   does not. Same [stats] with every absent miss removed must move the former
   and leave the latter alone — the whole point of the split. *)
let test_absent_misses_move_only_the_loads_ratio _ =
  let no_absent = { _stats with miss_absent = 0 } in
  assert_that
    (_render ~stats:no_absent ())
    (all_of
       [
         contains_substring "misses_per_symbol=1.35";
         contains_substring "loads_per_touched=2.70";
       ])

(* A zero denominator must render 0.00, not a nan/inf that would poison a
   downstream parse. Both ratios are exercised: [n_symbols = 0] via the empty
   stats, and [n_symbols_touched = 0] with it. *)
let test_zero_denominators_render_zero _ =
  let empty : Daily_panels.stats =
    {
      hits = 0;
      misses = 0;
      miss_absent = 0;
      evictions = 0;
      n_symbols_touched = 0;
      n_symbols_absent = 0;
      occupancy =
        {
          max_entries = 0;
          max_bytes = 0;
          max_mmap_open = 0;
          avg_entries = 0.0;
          avg_bytes = 0.0;
        };
    }
  in
  assert_that
    (Config.render_cache_stats_line ~stats:empty ~n_symbols:0 ~cap_mb:1
       ~cap_mmap_handles:1 ~high_water:_high_water)
    (all_of
       [
         contains_substring "misses_per_symbol=0.00";
         contains_substring "loads_per_touched=0.00";
       ])

(* The process sampler returns plausible positive marks for the running test
   binary (it has a heap and it is resident), so the two fields on the line are
   real measurements rather than placeholders. *)
let test_process_high_water_is_positive _ =
  let hw = Config.read_process_high_water () in
  assert_that hw
    (all_of
       [
         field
           (fun (h : Config.process_high_water) -> h.top_heap_bytes)
           (gt (module Int_ord) 0);
         field
           (fun (h : Config.process_high_water) -> h.maxrss_bytes)
           (gt (module Int_ord) 0);
       ])

let suite =
  "Snapshot_cache_config"
  >::: [
         "renders the pinned line" >:: test_renders_the_pinned_line;
         "absent misses move only the loads ratio"
         >:: test_absent_misses_move_only_the_loads_ratio;
         "zero denominators render zero" >:: test_zero_denominators_render_zero;
         "process high water is positive"
         >:: test_process_high_water_is_positive;
       ]

let () = run_test_tt_main suite
