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

  let to_string = function
    | Load_universe -> "load_universe"
    | Load_bars -> "load_bars"
    | Macro -> "macro"
    | Sector_rank -> "sector_rank"
    | Rs_rank -> "rs_rank"
    | Stage_classify -> "stage_classify"
    | Screener -> "screener"
    | Stop_update -> "stop_update"
    | Order_gen -> "order_gen"
    | Fill -> "fill"
    | Teardown -> "teardown"
end

type phase_metrics = {
  phase : Phase.t;
  elapsed_ms : int;
  symbols_in : int;
  symbols_out : int;
  peak_rss_mb : int option;
  bar_loads : int;
}
[@@deriving show, eq, sexp]

type t = { mutable entries : phase_metrics list }

let create () = { entries = [] }

(** Read peak RSS (in MB) from [/proc/self/status]. Returns [None] if the file
    isn't available or can't be parsed — typical on macOS/BSD. Uses VmHWM which
    is the "high water mark" (peak resident size). *)
let _read_peak_rss_mb () : int option =
  let path = "/proc/self/status" in
  match Sys_unix.file_exists path with
  | `No | `Unknown -> None
  | `Yes -> (
      try
        In_channel.with_file path ~f:(fun ic ->
            let rec loop () =
              match In_channel.input_line ic with
              | None -> None
              | Some line ->
                  if String.is_prefix line ~prefix:"VmHWM:" then
                    (* Line format: "VmHWM:\t   123456 kB" *)
                    let tail = String.drop_prefix line (String.length "VmHWM:") in
                    let tail = String.strip tail in
                    let tail =
                      String.chop_suffix tail ~suffix:"kB"
                      |> Option.value ~default:tail
                    in
                    let tail = String.strip tail in
                    Option.map (Int.of_string_opt tail) ~f:(fun kb -> kb / 1024)
                  else loop ()
            in
            loop ())
      with _ -> None)

let _now_ms () =
  Time_ns.now () |> Time_ns.to_int_ns_since_epoch |> fun ns -> ns / 1_000_000

let record ?trace ?(symbols_in = 0) ?(symbols_out = 0) ?(bar_loads = 0) phase f
    =
  match trace with
  | None -> f ()
  | Some t ->
      let start_ms = _now_ms () in
      let result = f () in
      let elapsed_ms = _now_ms () - start_ms in
      let peak_rss_mb = _read_peak_rss_mb () in
      let entry =
        {
          phase;
          elapsed_ms;
          symbols_in;
          symbols_out;
          peak_rss_mb;
          bar_loads;
        }
      in
      t.entries <- entry :: t.entries;
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
