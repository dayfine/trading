(** EODHD delisted-symbol audit (offline / fixture-driven).

    Cross-references the Wiki S&P 500 "removed" event list against a pinned
    snapshot of EODHD's exchange-symbol-list endpoint, classifying every removed
    symbol as [matched-in-eodhd-delisted], [live-on-eodhd], or [not-found]. The
    live HTTP fetch is deferred to a follow-up; this exe operates entirely on
    local fixture files.

    Typical usage:
    {v
      eodhd_delisted_audit.exe \
        --removed-sexp data/sp500_removed.sexp \
        --eodhd-fixture data/eodhd_delisted_fixture.json \
        --out reports/eodhd_delisted_audit.md
    v} *)

open Core

let _read_file path =
  try Ok (In_channel.read_all path)
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to read %s: %s" path msg)

let _write_file path content =
  try
    Out_channel.write_all path ~data:content;
    Ok ()
  with Sys_error msg ->
    Status.error_invalid_argument
      (Printf.sprintf "failed to write %s: %s" path msg)

let _run ~removed_sexp_path ~eodhd_fixture_path ~out_path =
  let open Result.Let_syntax in
  let%bind removed_text = _read_file removed_sexp_path in
  let%bind removed = Eodhd_delisted_audit_lib.parse_removed_sexp removed_text in
  let%bind eodhd_text = _read_file eodhd_fixture_path in
  let%bind eodhd = Eodhd_delisted_audit_lib.parse_eodhd_fixture eodhd_text in
  let rows = Eodhd_delisted_audit_lib.cross_reference ~removed ~eodhd in
  let markdown = Eodhd_delisted_audit_lib.render_markdown rows in
  let%bind () = _write_file out_path markdown in
  Ok rows

let _main ~removed_sexp_path ~eodhd_fixture_path ~out_path () =
  match _run ~removed_sexp_path ~eodhd_fixture_path ~out_path with
  | Error e ->
      Printf.eprintf "Error: %s\n" (Status.show e);
      exit 1
  | Ok rows ->
      Printf.printf "Audited %d removed symbols, wrote %s\n%!"
        (List.length rows) out_path

let command =
  Command.basic
    ~summary:
      "Cross-reference Wiki S&P 500 removed-symbol list against EODHD fixture"
    (let%map_open.Command removed_sexp_path =
       flag "removed-sexp" (required string)
         ~doc:
           "PATH Sexp list of removed events (((symbol \"X\") (effective_date \
            \"YYYY-MM-DD\")) ...)"
     and eodhd_fixture_path =
       flag "eodhd-fixture" (required string)
         ~doc:
           "PATH JSON snapshot of EODHD exchange-symbol-list (delisted + live)"
     and out_path =
       flag "out" (required string) ~doc:"PATH Markdown report destination"
     in
     fun () -> _main ~removed_sexp_path ~eodhd_fixture_path ~out_path ())

let () = Command_unix.run command
