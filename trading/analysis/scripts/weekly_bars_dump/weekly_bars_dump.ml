(* CLI wrapper for the blind-judge harness (.claude/skills/blind-judge/):
   dumps one symbol's weekly OHLCV history, truncated at a decision week and
   optionally blinded, for feeding to an independent LLM judge. See
   [Bar_window] for the lookahead guard, [Blind] for the blinding
   primitives, and [Table_format] for the rendered shape. *)
open Core
module Bar_window = Weekly_bars_dump_lib.Bar_window
module Blind = Weekly_bars_dump_lib.Blind
module Table_format = Weekly_bars_dump_lib.Table_format
module Bar_source = Weekly_bars_dump_lib.Bar_source

let _default_weeks_back = 260 (* ~5 years of weekly bars *)
let _ma_period = 30 (* Weinstein's investor-mode MA period *)

let _parse_through (s : string) : Bar_window.through =
  let as_date =
    Option.try_with (fun () -> Date.of_string s)
    |> Option.map ~f:(fun d -> Bar_window.By_date d)
  in
  let as_index =
    Int.of_string_opt s |> Option.map ~f:(fun i -> Bar_window.By_index i)
  in
  match Option.first_some as_date as_index with
  | Some t -> t
  | None ->
      eprintf
        "--through-week %s is neither an ISO date nor an integer index\n%!" s;
      exit 1

let _fail_status ~what (e : Status.t) =
  eprintf "%s: %s\n%!" what (Status.show e);
  exit 1

let _write_out ~out text =
  match out with
  | None -> print_string text
  | Some path -> Out_channel.write_all path ~data:text

(* Mapping file is required under [-blind] (never defaulted to stderr) so a
   routine `... > case.txt 2>&1` redirect cannot leak the de-blinding key
   into the judge's file alongside the table. *)
let _emit_mapping ~mapping_out ~pseudonym ~symbol =
  let line = Printf.sprintf "%s %s\n" pseudonym symbol in
  Out_channel.write_all mapping_out ~data:line

(* Operator-facing metadata: which store served this symbol's bars. Always to
   stderr, never to [out] / stdout -- the judge's channel -- so a cohort run
   can confirm homogeneity across cases without touching what the judge sees. *)
let _emit_source (source : Bar_source.source) =
  let label =
    match source with
    | Bar_source.Warehouse -> "warehouse-snap"
    | Bar_source.Csv -> "csv-store"
  in
  eprintf "# source: %s\n%!" label

let _plain_week_label (b : Types.Daily_price.t) = Date.to_string b.date

let _render_and_emit ~symbol ~blind ~with_ma ~out ~mapping_out bars =
  let n = List.length bars in
  let symbol_label =
    if blind then Blind.pseudonym_of_symbol symbol else symbol
  in
  let week_labels =
    if blind then Blind.week_labels n else List.map bars ~f:_plain_week_label
  in
  let ma_30w =
    if with_ma then Bar_window.trailing_average_close bars ~period:_ma_period
    else None
  in
  _write_out ~out (Table_format.render ~symbol_label ~bars ~week_labels ~ma_30w);
  if blind then
    let mapping_out =
      Option.value_exn mapping_out
        ~message:"_run enforces -mapping-out under -blind"
    in
    _emit_mapping ~mapping_out ~pseudonym:symbol_label ~symbol

let _run ~symbol ~through_week ~weeks_back ~blind ~with_ma ~out ~mapping_out
    ~warehouse_dir ~csv_data_dir () =
  if blind && Option.is_none mapping_out then (
    eprintf
      "weekly_bars_dump: -blind requires -mapping-out FILE -- never redirect \
       stderr for a blinded run, or the de-blinding key can land in the \
       judge's file (see .claude/skills/blind-judge/SKILL.md)\n\
       %!";
    exit 1);
  let through = _parse_through through_week in
  let result =
    let open Result.Let_syntax in
    let%bind weekly, source =
      Bar_source.load_weekly ~symbol ~warehouse_dir ~csv_data_dir
    in
    let%bind bars = Bar_window.select ~weekly ~through ~weeks_back in
    _emit_source source;
    return (_render_and_emit ~symbol ~blind ~with_ma ~out ~mapping_out bars)
  in
  match result with
  | Ok () -> ()
  | Error e -> _fail_status ~what:"weekly_bars_dump" e

let command =
  Command.basic
    ~summary:
      "Dump one symbol's weekly OHLCV history for the blind-judge harness"
    ~readme:(fun () ->
      "Reads the snapshot warehouse's SYMBOL.snap (preferred) or the CSV \
       store, folds to weekly bars via Time_period.Conversion.daily_to_weekly, \
       truncates at --through-week (never emitting a bar after it -- the \
       lookahead guard), and prints an aligned OHLCV table. --blind replaces \
       the symbol with a stable pseudonym and dates with sequential week \
       labels; the mapping goes to the required --mapping-out file, never to \
       the table itself. Which store served the bars (warehouse-snap or \
       csv-store) is reported on stderr as '# source: ...', so a cohort run \
       can be checked for homogeneity.")
    (let%map_open.Command symbol =
       flag "-symbol" (required string) ~doc:"SYM ticker to dump"
     and through_week =
       flag "-through-week" (required string)
         ~doc:"DATE|INDEX decision week: ISO date or 0-based weekly-bar index"
     and weeks_back =
       flag "-weeks-back"
         (optional_with_default _default_weeks_back int)
         ~doc:
           (Printf.sprintf "N trailing weekly bars to emit (default %d)"
              _default_weeks_back)
     and blind = flag "-blind" no_arg ~doc:" blind the symbol and dates"
     and with_ma =
       flag "-with-ma" no_arg ~doc:" append the 30w MA at the decision week"
     and out =
       flag "-out" (optional string)
         ~doc:"FILE write the table here (default stdout)"
     and mapping_out =
       flag "-mapping-out" (optional string)
         ~doc:
           "FILE write the blind mapping here (required with --blind; ignored \
            otherwise)"
     and warehouse_dir =
       flag "-warehouse-dir" (optional string)
         ~doc:"DIR snapshot warehouse holding SYMBOL.snap"
     and csv_data_dir =
       flag "-csv-data-dir" (optional string)
         ~doc:"DIR CSV store, fallback source"
     in
     _run ~symbol ~through_week ~weeks_back ~blind ~with_ma ~out ~mapping_out
       ~warehouse_dir ~csv_data_dir)

let () = Command_unix.run command
