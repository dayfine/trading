(** Per-phase tracing for backtest runs. See [trace.mli]. *)

open Core

module Phase = struct
  type t =
    | Load_universe
    | Load_bars
    | Macro
    | Sector_rank
    | Rs_rank
    | Stage_classify
    | Screener
    | Stop_update
    | Order_gen
    | Fill
    | Teardown
  [@@deriving show, eq, sexp]
end

type phase_metrics = {
  phase : Phase.t;
  elapsed_ms : int;
  symbols_in : int option;
  symbols_out : int option;
  peak_rss_kb : int option;
  bar_loads : int option;
}
[@@deriving show, eq, sexp]

type t = { mutable entries : phase_metrics list }

let create () = { entries = [] }

(** Parse a [VmHWM: 123456 kB] line. Returns kB (native unit from
    [/proc/self/status]; do not pre-divide by 1024 to MB — short-lived or small
    processes would integer-truncate to 0 MB and hide real regressions). [None]
    if the line can't be parsed. *)
let _parse_vmhwm_line line : int option =
  String.drop_prefix line (String.length "VmHWM:")
  |> String.strip
  |> String.chop_suffix_if_exists ~suffix:"kB"
  |> String.strip |> Int.of_string_opt

(** Scan [ic] line-by-line for a [VmHWM:] entry. Returns [None] if no such line.
*)
let _scan_for_vmhwm ic =
  let rec loop () =
    match In_channel.input_line ic with
    | None -> None
    | Some line when String.is_prefix line ~prefix:"VmHWM:" ->
        _parse_vmhwm_line line
    | Some _ -> loop ()
  in
  loop ()

let _status_path = "/proc/self/status"

let _status_file_readable () =
  match Sys_unix.file_exists _status_path with
  | `Yes -> true
  | `No | `Unknown -> false

(** Read peak RSS (in kB — native unit from VmHWM) from [/proc/self/status].
    Returns [None] if the file isn't available or can't be parsed — typical on
    macOS/BSD. Uses VmHWM which is the "high water mark" (peak resident size).
*)
let _read_peak_rss_kb () : int option =
  if not (_status_file_readable ()) then None
  else try In_channel.with_file _status_path ~f:_scan_for_vmhwm with _ -> None

let _append_entry t ~phase ~elapsed_ms ~symbols_in ~symbols_out ~bar_loads =
  let entry =
    {
      phase;
      elapsed_ms;
      symbols_in;
      symbols_out;
      peak_rss_kb = _read_peak_rss_kb ();
      bar_loads;
    }
  in
  t.entries <- entry :: t.entries

let record ?trace ?symbols_in ?symbols_out ?bar_loads phase f =
  match trace with
  | None -> f ()
  | Some t ->
      let start = Time_ns.now () in
      let result = f () in
      let elapsed_ms =
        Time_ns.diff (Time_ns.now ()) start |> Time_ns.Span.to_int_ms
      in
      _append_entry t ~phase ~elapsed_ms ~symbols_in ~symbols_out ~bar_loads;
      result

let snapshot t = List.rev t.entries

let _ensure_parent_dir path =
  let dir = Filename.dirname path in
  if not (String.equal dir "" || String.equal dir ".") then
    (* core_unix provides mkdir_p via Core_unix *)
    Core_unix.mkdir_p dir

let write ~out_path metrics =
  _ensure_parent_dir out_path;
  let sexp = [%sexp_of: phase_metrics list] metrics in
  Out_channel.with_file out_path ~f:(fun oc ->
      Out_channel.output_string oc (Sexp.to_string_hum sexp);
      Out_channel.output_char oc '\n')
