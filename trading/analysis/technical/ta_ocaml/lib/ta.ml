open Ctypes
include C.Functions

(* Helper function to check return codes *)
let check_retcode code =
  if code <> 0 then failwith (Printf.sprintf "TA-Lib error: %d" code)

(* Initialize TA-Lib *)
let initialize () =
  let code = ta_initialize () in
  check_retcode code

(* Shutdown TA-Lib *)
let shutdown () =
  let code = ta_shutdown () in
  check_retcode code

(* Common function to handle technical indicators *)
let calculate_indicator
    (indicator_fn :
      int -> int -> float ptr -> int -> int ptr -> int ptr -> float ptr -> int)
    (data : float array) (period : int) : (float array, string) result =
  let len = Array.length data in
  if len < period then
    Error
      (Printf.sprintf "Not enough data: need at least %d elements, got %d"
         period len)
  else
    let out_begin = allocate int 0 in
    let out_nbelement = allocate int 0 in
    let output = CArray.make C.Types.ta_real len in

    (* Convert input data to C array *)
    let input_data = CArray.of_list C.Types.ta_real (Array.to_list data) in

    (* Debug print input data *)
    Printf.printf "Debug: input data length=%d, period=%d\n" len period;
    Printf.printf "Debug: input data=[%s]\n"
      (String.concat ", " (Array.to_list data |> List.map string_of_float));

    (* Call TA-Lib function with full range *)
    let code =
      indicator_fn 0 (* startIdx - start from beginning *)
        (len - 1) (* endIdx - process until end *)
        (CArray.start input_data) (* inReal - input data *)
        period (* optInTimePeriod - period for calculation *)
        out_begin (* outBegIdx - where valid output starts *)
        out_nbelement (* outNBElement - number of valid elements *)
        (CArray.start output)
      (* outReal - output buffer *)
    in

    check_retcode code;

    (* Debug print to understand what TA-Lib is returning *)
    Printf.printf "Debug: begin_idx=%d, nb_elements=%d\n" !@out_begin
      !@out_nbelement;

    if !@out_nbelement <= 0 then Error "Not enough data to calculate indicator"
    else
      let result = Array.make !@out_nbelement 0.0 in
      for i = 0 to !@out_nbelement - 1 do
        result.(i) <- CArray.get output (!@out_begin + i)
      done;
      Ok result

(* Moving Averages *)
let sma data period = calculate_indicator ta_sma data period

(* Exponential Moving Average *)
let ema data period = calculate_indicator ta_ema data period

(* Relative Strength Index *)
let rsi data period = calculate_indicator ta_rsi data period

(* Export the module interface *)
module type TA = sig
  val initialize : unit -> unit
  val shutdown : unit -> unit
  val sma : float array -> int -> (float array, string) result
  val ema : float array -> int -> (float array, string) result
  val rsi : float array -> int -> (float array, string) result
end

(* Create the module *)
module Ta : TA = struct
  let initialize = initialize
  let shutdown = shutdown
  let sma = sma
  let ema = ema
  let rsi = rsi
end
