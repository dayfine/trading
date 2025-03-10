open Ctypes
include C.Functions

let check_retcode code =
  if code <> 0 then failwith (Printf.sprintf "TA-Lib error: %d" code)

let initialize () = check_retcode @@ ta_initialize ()
let shutdown () = check_retcode @@ ta_shutdown ()
let round_to_two_decimals x = Float.round (x *. 100.) /. 100.

let calculate_indicator indicator_fn data period =
  let len = Array.length data in
  if len < period then
    Error
      (Printf.sprintf "Not enough data: need at least %d elements, got %d"
         period len)
  else
    let out_begin = allocate int 0 in
    let out_nbelement = allocate int 0 in
    let output = CArray.make C.Types.ta_real len in
    let input_data = CArray.of_list C.Types.ta_real (Array.to_list data) in

    check_retcode
    @@ indicator_fn 0 (len - 1) (CArray.start input_data) period out_begin
         out_nbelement (CArray.start output);

    if !@out_nbelement <= 0 then Error "Not enough data to calculate indicator"
    else
      Ok
        (Array.init !@out_nbelement (fun i ->
             CArray.get output i |> round_to_two_decimals))

let sma = calculate_indicator ta_sma
let ema = calculate_indicator ta_ema
let rsi = calculate_indicator ta_rsi

module type TA = sig
  val initialize : unit -> unit
  val shutdown : unit -> unit

  (* takes a float array of prices and a period, returns a float array *)
  val sma : float array -> int -> (float array, string) result
  val ema : float array -> int -> (float array, string) result
  val rsi : float array -> int -> (float array, string) result
end

module Ta : TA = struct
  let initialize = initialize
  let shutdown = shutdown
  let sma = sma
  let ema = ema
  let rsi = rsi
end
