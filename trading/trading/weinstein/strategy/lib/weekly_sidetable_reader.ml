open Core
module Weekly_sidetable = Data_panel_snapshot.Weekly_sidetable
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema

(* Horizon / band / lookback constants — replicated from
   [Snapshot_pipeline.Resistance_sketch] (the v4 semantic authority). Any drift
   is caught bit-for-bit by the v5-equals-v4 equality property in
   [test_weekly_sidetable_reader.ml] (the intended anti-drift guard), so these
   are deliberately duplicated rather than exposed from the analysis module. The
   histogram grid sizes ([n_hist_buckets] / [n_age_bands] / [n_hist_cells]) are
   instead read from [Snapshot_schema] so they can never drift. *)
let _horizon_130_weeks = 130
let _horizon_260_weeks = 260
let _horizon_520_weeks = 520
let _hist_lookback_weeks = 520
let _bars_seen_cap = 520
let _age_break_26_weeks = 26
let _age_break_78_weeks = 78
let _age_break_130_weeks = 130
let _ln2 = Float.log 2.0

(* Age band index (0..n_age_bands-1) for a weekly bar of [age] weeks — verbatim
   from [Resistance_sketch._age_band_of]. Half-open bands
   [0,26) / [26,78) / [78,130) / [130,520). *)
let _age_band_of ~age =
  if age < _age_break_26_weeks then 0
  else if age < _age_break_78_weeks then 1
  else if age < _age_break_130_weeks then 2
  else 3

let _cell_index ~band ~bucket = (band * Snapshot_schema.n_hist_buckets) + bucket

(* Bucket index for a weekly bar's mid-price in the log grid anchored at
   [anchor] — verbatim from [Resistance_sketch._bucket_of], including the exact
   float arithmetic order, so ties at a bucket edge resolve identically. *)
let _bucket_of ~anchor ~mid =
  let k =
    Float.round_down
      (Float.of_int Snapshot_schema.n_hist_buckets
      *. Float.log (mid /. anchor)
      /. _ln2)
  in
  if Float.is_finite k then Some (Int.of_float k) else None

(* Count one weekly entry of age band [band] into [hist] at the anchor when its
   raw high sits above [anchor] and its mid lands in a canonical bucket. Mirrors
   [Resistance_sketch._accumulate_hist]: the entry's precomputed [mid] / [high]
   are exactly the fields that function gates + buckets, so no recomputation. *)
let _accumulate_hist ~hist ~band ~anchor ~(entry : Weekly_sidetable.entry) =
  if Float.(entry.high > anchor) then
    match _bucket_of ~anchor ~mid:entry.mid with
    | Some bucket when bucket >= 0 && bucket < Snapshot_schema.n_hist_buckets ->
        let cell = _cell_index ~band ~bucket in
        hist.(cell) <- hist.(cell) +. 1.0
    | _ -> ()

(* Number of entries whose [week_end_date] is <= [as_of]. Entries are sorted
   ascending by [week_end_date] (the builder emits oldest-first), so this is the
   upper-bound position found by binary search — O(log n). *)
let _count_upto (entries : Weekly_sidetable.entry array) ~as_of =
  let n = Array.length entries in
  let lo = ref 0 and hi = ref n in
  while !lo < !hi do
    let mid = (!lo + !hi) / 2 in
    if Date.( <= ) entries.(mid).week_end_date as_of then lo := mid + 1
    else hi := mid
  done;
  !lo

(* All-NaN sketch for a corrupt anchor (non-positive / non-finite close),
   mirroring [Resistance_sketch._nan_day]: every derived cell degrades to NaN,
   [anchor_close] carries the raw (corrupt) close verbatim. *)
let _nan_sketch ~close : Resistance_supply.sketch =
  {
    max_high_130w = Float.nan;
    max_high_260w = Float.nan;
    max_high_520w = Float.nan;
    bars_seen = Float.nan;
    hist_bands =
      Array.make_matrix ~dimx:Snapshot_schema.n_age_bands
        ~dimy:Snapshot_schema.n_hist_buckets Float.nan;
    anchor_close = close;
  }

(* Max raw high over the trailing [horizon] window entries (ages 0..horizon-1),
   including the current (age-0) week — the same span
   [Resistance_sketch._rolling_max_column] folds. [k] = number of entries at/
   before the anchor; the window is the trailing [min horizon k] of them. *)
let _rolling_max (entries : Weekly_sidetable.entry array) ~k ~horizon =
  let len = Int.min horizon k in
  if len = 0 then Float.nan
  else begin
    let start = k - len in
    let acc = ref Float.neg_infinity in
    for i = start to k - 1 do
      acc := Float.max !acc entries.(i).high
    done;
    !acc
  end

(* Age-banded histogram over the trailing [min _hist_lookback_weeks k] window
   entries. The current (age-0) week is the last kept entry; entry
   [entries.(k-1-age)] has that [age]. Mirrors [Resistance_sketch._hist_for_day]:
   ages 0..min(519, k-1) are counted. *)
let _hist_bands (entries : Weekly_sidetable.entry array) ~k ~anchor =
  let hist = Array.create ~len:Snapshot_schema.n_hist_cells 0.0 in
  let len = Int.min _hist_lookback_weeks k in
  for i = k - len to k - 1 do
    let age = k - 1 - i in
    let band = _age_band_of ~age in
    _accumulate_hist ~hist ~band ~anchor ~entry:entries.(i)
  done;
  Array.init Snapshot_schema.n_age_bands ~f:(fun band ->
      Array.init Snapshot_schema.n_hist_buckets ~f:(fun bucket ->
          hist.(_cell_index ~band ~bucket)))

let sketch_of_entries ~(entries : Weekly_sidetable.entry list) ~as_of ~close :
    Resistance_supply.sketch =
  if not (Float.is_finite close && Float.(close > 0.0)) then _nan_sketch ~close
  else
    let arr = Array.of_list entries in
    let k = _count_upto arr ~as_of in
    {
      max_high_130w = _rolling_max arr ~k ~horizon:_horizon_130_weeks;
      max_high_260w = _rolling_max arr ~k ~horizon:_horizon_260_weeks;
      max_high_520w = _rolling_max arr ~k ~horizon:_horizon_520_weeks;
      bars_seen = Float.of_int (Int.min k _bars_seen_cap);
      hist_bands = _hist_bands arr ~k ~anchor:close;
      anchor_close = close;
    }

(* ------------------------------------------------------------------ *)
(* Side-table load + manifest-format-hash gate                          *)
(* ------------------------------------------------------------------ *)

let _weekly_path ~snapshot_dir ~symbol =
  Filename.concat snapshot_dir (symbol ^ ".weekly")

(* Load the side-file for a symbol whose warehouse advertises a matching format
   hash: an absent file means this symbol simply has no side-table (fall back to
   the dense columns), a present file is decoded. Extracted from [load_gated] so
   that function stays a flat 3-arm match (nesting linter). *)
let _load_present ~snapshot_dir ~symbol :
    Weekly_sidetable.entry list option Status.status_or =
  let path = _weekly_path ~snapshot_dir ~symbol in
  if not (Stdlib.Sys.file_exists path) then Ok None
  else
    Result.map (Weekly_sidetable.read_file ~path) ~f:(fun entries ->
        Some entries)

let load_gated ~snapshot_dir ~symbol ~manifest_format_hash :
    Weekly_sidetable.entry list option Status.status_or =
  match manifest_format_hash with
  | None -> Ok None
  | Some h when not (String.equal h Weekly_sidetable.format_hash) ->
      Status.error_internal
        (Printf.sprintf
           "weekly side-table format hash mismatch: manifest %s, reader %s" h
           Weekly_sidetable.format_hash)
  | Some _ -> _load_present ~snapshot_dir ~symbol

let loader_for ~snapshot_dir ~manifest_format_hash ~symbol =
  match load_gated ~snapshot_dir ~symbol ~manifest_format_hash with
  | Ok entries -> entries
  | Error err ->
      failwithf
        "Weekly_sidetable_reader.loader_for: side-table load failed for %s: %s"
        symbol (Status.show err) ()
