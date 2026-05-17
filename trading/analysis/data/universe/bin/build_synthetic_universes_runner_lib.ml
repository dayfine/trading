open Core
module SC = Shiller.Shiller_client
module KF = Kenneth_french.Kenneth_french_client

(* ---------------------------------------------------------------------- *)
(* Cache-CSV parsers                                                      *)
(* ---------------------------------------------------------------------- *)

let _shiller_header = "period,sp_price,dividend,earnings,cpi,long_rate"
let _shiller_column_count = 6
let _french_header_prefix = "block,date,"
let _french_industries_v1 = [ "Cnsmr"; "Manuf"; "HiTec"; "Hlth"; "Other" ]
let _french_industry_count = List.length _french_industries_v1
let _vw_block_tag = "VW"

let _split_nonempty_lines body =
  String.split_lines body
  |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))

let _parse_date_or_error raw =
  match Date.of_string raw with
  | d -> Ok d
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "runner: unparseable date %S" raw)

let _parse_optional_float ~column raw =
  if String.is_empty raw then Ok None
  else
    match Float.of_string raw with
    | f -> Ok (Some f)
    | exception _ ->
        Status.error_invalid_argument
          (Printf.sprintf "runner: unparseable %s value %S" column raw)

let _parse_float ~column raw =
  match Float.of_string raw with
  | f -> Ok f
  | exception _ ->
      Status.error_invalid_argument
        (Printf.sprintf "runner: unparseable %s value %S" column raw)

let _shiller_column_count_error line_num n =
  Status.error_invalid_argument
    (Printf.sprintf "runner: shiller cache line %d has %d columns (expected %d)"
       line_num n _shiller_column_count)

let _shiller_parse_row line_num raw_line :
    SC.monthly_observation Status.status_or =
  let fields = String.split raw_line ~on:',' in
  let n = List.length fields in
  if n <> _shiller_column_count then _shiller_column_count_error line_num n
  else
    match fields with
    | [ date_s; price_s; div_s; earn_s; cpi_s; rate_s ] ->
        let open Result.Let_syntax in
        let%bind period = _parse_date_or_error date_s in
        let%bind sp_price = _parse_float ~column:"sp_price" price_s in
        let%bind dividend = _parse_optional_float ~column:"dividend" div_s in
        let%bind earnings = _parse_optional_float ~column:"earnings" earn_s in
        let%bind cpi = _parse_optional_float ~column:"cpi" cpi_s in
        let%bind long_rate = _parse_optional_float ~column:"long_rate" rate_s in
        Ok
          ({ period; sp_price; dividend; earnings; cpi; long_rate }
            : SC.monthly_observation)
    | _ ->
        Status.error_internal
          (Printf.sprintf "runner: unreachable shiller destructure on line %d"
             line_num)

let _validate_shiller_header line =
  if String.equal line _shiller_header then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf "runner: shiller cache header drift — expected %S, got %S"
         _shiller_header line)

let parse_shiller_cache_csv body : SC.monthly_observation list Status.status_or
    =
  match _split_nonempty_lines body with
  | [] -> Status.error_invalid_argument "runner: empty shiller cache body"
  | header :: data_lines ->
      let open Result.Let_syntax in
      let%bind () = _validate_shiller_header header in
      List.mapi data_lines ~f:(fun i line -> _shiller_parse_row (i + 2) line)
      |> Result.all

let _french_column_count = 2 + _french_industry_count

let _french_column_count_error line_num n =
  Status.error_invalid_argument
    (Printf.sprintf "runner: french cache line %d has %d columns (expected %d)"
       line_num n _french_column_count)

let _french_industry_returns_from_values values =
  List.map2_exn _french_industries_v1 values ~f:(fun industry raw ->
      let v =
        if String.is_empty raw then Ok None
        else
          match Float.of_string raw with
          | f -> Ok (Some f)
          | exception _ ->
              Status.error_invalid_argument
                (Printf.sprintf "runner: unparseable french value %S for %s" raw
                   industry)
      in
      (industry, v))

(* Lift the per-industry Result.t list into a single Result for the whole
   row. *)
let _french_industry_returns_or_error pairs =
  List.fold pairs
    ~init:(Ok ([] : (string * float option) list))
    ~f:(fun acc (industry, v_or_err) ->
      match (acc, v_or_err) with
      | (Error _ as e), _ -> e
      | Ok _, (Error _ as e) -> e
      | Ok rev, Ok v -> Ok ((industry, v) :: rev))
  |> Result.map ~f:List.rev

let _parse_vw_row line_num date_s value_strs : KF.daily_return Status.status_or
    =
  let open Result.Let_syntax in
  let%bind date = _parse_date_or_error date_s in
  let pairs = _french_industry_returns_from_values value_strs in
  let%bind industry_returns = _french_industry_returns_or_error pairs in
  ignore line_num;
  Ok ({ date; industry_returns } : KF.daily_return)

(* One row of the value-weighted block; ignore equal-weighted rows. *)
let _french_parse_row line_num raw_line :
    KF.daily_return option Status.status_or =
  let fields = String.split raw_line ~on:',' in
  let n = List.length fields in
  if n <> _french_column_count then _french_column_count_error line_num n
  else
    match fields with
    | block :: date_s :: value_strs when String.equal block _vw_block_tag ->
        let open Result.Let_syntax in
        let%bind row = _parse_vw_row line_num date_s value_strs in
        Ok (Some row)
    | _block :: _date :: _values -> Ok None
    | _ ->
        Status.error_internal
          (Printf.sprintf "runner: unreachable french destructure on line %d"
             line_num)

let _validate_french_header line =
  if String.is_prefix line ~prefix:_french_header_prefix then Ok ()
  else
    Status.error_invalid_argument
      (Printf.sprintf
         "runner: french cache header drift — expected prefix %S, got %S"
         _french_header_prefix line)

let parse_french_cache_csv body : KF.daily_return list Status.status_or =
  match _split_nonempty_lines body with
  | [] -> Status.error_invalid_argument "runner: empty french cache body"
  | header :: data_lines ->
      let open Result.Let_syntax in
      let%bind () = _validate_french_header header in
      let%bind rows_with_opts =
        List.mapi data_lines ~f:(fun i line -> _french_parse_row (i + 2) line)
        |> Result.all
      in
      Ok (List.filter_map rows_with_opts ~f:Fn.id)

(* ---------------------------------------------------------------------- *)
(* Runner                                                                  *)
(* ---------------------------------------------------------------------- *)

type result = {
  written : int;
  skipped : int;
  skip_reasons : (int * int * string) list;
}
[@@deriving show, eq]

let _reconstitution_date ~year = Date.create_exn ~y:year ~m:Month.May ~d:31

let _snapshot_path ~out_dir ~top_n ~year =
  Filename.concat out_dir (Printf.sprintf "top-%d-%d.sexp" top_n year)

let _save_or_record_skip ~out_dir ~top_n ~year snapshot acc =
  let path = _snapshot_path ~out_dir ~top_n ~year in
  match Universe.Snapshot.save snapshot ~path with
  | Ok () -> { acc with written = acc.written + 1 }
  | Error err ->
      {
        acc with
        skipped = acc.skipped + 1;
        skip_reasons = (year, top_n, Status.show err) :: acc.skip_reasons;
      }

let _step ~shiller_obs ~french_obs ~rng_seed ~out_dir ~top_n ~year acc =
  let date = _reconstitution_date ~year in
  let config = Universe.Build_from_index.default_config ~size:top_n ~rng_seed in
  match
    Universe.Build_from_index.build ~date ~shiller_obs ~french_obs ~config
  with
  | Ok snapshot -> _save_or_record_skip ~out_dir ~top_n ~year snapshot acc
  | Error err ->
      {
        acc with
        skipped = acc.skipped + 1;
        skip_reasons = (year, top_n, Status.show err) :: acc.skip_reasons;
      }

let _years_inclusive ~start_year ~end_year =
  List.init (end_year - start_year + 1) ~f:(fun i -> start_year + i)

let _mkdir_p path =
  (* Create the output directory and all parents if missing. Idempotent. *)
  let cmd = Printf.sprintf "mkdir -p %s" (Filename.quote path) in
  ignore (Stdlib.Sys.command cmd : int)

let run ~shiller_obs ~french_obs ~out_dir ~start_year ~end_year ~top_ns
    ~rng_seed =
  _mkdir_p out_dir;
  let years = _years_inclusive ~start_year ~end_year in
  let initial = { written = 0; skipped = 0; skip_reasons = [] } in
  List.fold years ~init:initial ~f:(fun acc year ->
      List.fold top_ns ~init:acc ~f:(fun acc top_n ->
          _step ~shiller_obs ~french_obs ~rng_seed ~out_dir ~top_n ~year acc))
