open Core

let load_and_apply ~overrides_path config =
  let overlays =
    try Sexp.load_sexps overrides_path
    with exn ->
      failwith
        (Printf.sprintf "Failed to load config overrides from %s: %s"
           overrides_path (Exn.to_string exn))
  in
  Backtest.Overlay_validator.apply_overrides config overlays
