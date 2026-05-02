open Core
module Snapshot = Data_panel_snapshot.Snapshot
module Snapshot_schema = Data_panel_snapshot.Snapshot_schema
module Daily_panels = Snapshot_runtime.Daily_panels

(* Lookback window (in calendar days) for [get_previous_bar]. 60 days covers
   any realistic US equity holiday gap (year-end clusters ~5 trading days);
   delisted / suspended symbols whose last bar is older than this surface
   [None], matching the CSV path's behaviour. *)
let _previous_bar_lookback_days = 60

(* Read one OHLCV field from a snapshot. NaN is the "value unknown" sentinel
   per the schema docstring. Any field returning NaN cascades to "no bar" via
   the [Option.bind] chain in [_snapshot_to_daily_price]. *)
let _get_field (s : Snapshot.t) (field : Snapshot_schema.field) : float option =
  match Snapshot.get s field with
  | None ->
      (* Field absent from this row's schema. The schema is fixed at manifest
         level so this only happens if the snapshot was built under a schema
         that doesn't carry the OHLCV columns (e.g. pre-Phase-A.1). Surface as
         "no bar" rather than raising — the simulator handles missing bars
         gracefully via Option.t. *)
      None
  | Some v when Float.is_nan v -> None
  | Some v -> Some v

(* Convert a single snapshot row to a [Daily_price.t]. Returns [None] when any
   OHLCV field is absent / NaN (mirrors the CSV path's "no row" semantics). *)
let _snapshot_to_daily_price (s : Snapshot.t) : Types.Daily_price.t option =
  let%bind.Option open_price = _get_field s Snapshot_schema.Open in
  let%bind.Option high_price = _get_field s Snapshot_schema.High in
  let%bind.Option low_price = _get_field s Snapshot_schema.Low in
  let%bind.Option close_price = _get_field s Snapshot_schema.Close in
  let%bind.Option volume_f = _get_field s Snapshot_schema.Volume in
  let%bind.Option adjusted_close =
    _get_field s Snapshot_schema.Adjusted_close
  in
  Some
    {
      Types.Daily_price.date = s.date;
      open_price;
      high_price;
      low_price;
      close_price;
      volume = Float.to_int volume_f;
      adjusted_close;
    }

(* Today's bar: a single read_today call, then OHLCV reconstruction. *)
let _make_get_price ~panels =
 fun ~symbol ~date ->
  match Daily_panels.read_today panels ~symbol ~date with
  | Error _ ->
      (* Symbol not in manifest, schema-skew, or decode error — surface as
         "no bar". The simulator handles None via the same path as a missing
         CSV row. *)
      None
  | Ok snapshot -> _snapshot_to_daily_price snapshot

(* Previous bar: read_history over a bounded lookback, take the last entry
   that converts cleanly. The list is chronological (oldest first), so the
   last entry is the most recent. *)
let _make_get_previous_bar ~panels =
 fun ~symbol ~date ->
  let from = Date.add_days date (-_previous_bar_lookback_days) in
  let until = Date.add_days date (-1) in
  match Daily_panels.read_history panels ~symbol ~from ~until with
  | Error _ -> None
  | Ok rows ->
      (* Walk in reverse chronological order, return the first row that
         converts to a usable Daily_price.t (i.e. all OHLCV fields present and
         non-NaN). This matches Price_cache.get_previous_bar's contract: the
         most recent valid bar strictly before [date]. *)
      List.rev rows |> List.find_map ~f:_snapshot_to_daily_price

let make_callbacks ~panels ~callbacks:_ =
  (* [callbacks] is accepted in the API to keep the contract symmetric with
     the rest of the snapshot_runtime surface (callers may already hold one),
     but the OHLCV path goes through [Daily_panels] directly — there's no
     win in routing through the [read_field]-shaped shim for a 6-field
     reconstruction that's natural to express as one [read_today] call. *)
  let get_price = _make_get_price ~panels in
  let get_previous_bar = _make_get_previous_bar ~panels in
  (get_price, get_previous_bar)
