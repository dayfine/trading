open Trading_base.Types
open Status
open Types

type order_params = {
  symbol : symbol;
  side : side;
  order_type : order_type;
  quantity : quantity;
  time_in_force : time_in_force;
}
[@@deriving show, eq]

let _generate_order_id () =
  let timestamp =
    Time_ns_unix.now () |> Time_ns_unix.to_int63_ns_since_epoch
    |> Core.Int63.to_string
  in
  let random_suffix = Random.int 10000 |> Printf.sprintf "%04d" in
  timestamp ^ "_" ^ random_suffix

(* Pure validation functions - each returns Ok () or Error *)
let _validate_symbol symbol =
  if symbol = "" then Error (invalid_argument_error "Symbol cannot be empty")
  else Ok ()

let _validate_quantity quantity =
  if quantity <= 0.0 then
    Error
      (invalid_argument_error
         (Printf.sprintf "Quantity must be positive: %.2f" quantity))
  else Ok ()

let _validate_price_positive price price_name =
  if price <= 0.0 then
    Error
      (invalid_argument_error
         (Printf.sprintf "%s must be positive: %.2f" price_name price))
  else Ok ()

let _validate_stop_limit_relationship side stop_price limit_price =
  match side with
  | Buy when stop_price > limit_price ->
      Error
        (invalid_argument_error
           (Printf.sprintf
              "For buy stop-limit orders, stop price (%.2f) must be <= limit \
               price (%.2f)"
              stop_price limit_price))
  | Sell when stop_price < limit_price ->
      Error
        (invalid_argument_error
           (Printf.sprintf
              "For sell stop-limit orders, stop price (%.2f) must be >= limit \
               price (%.2f)"
              stop_price limit_price))
  | _ -> Ok ()

let _validate_order_type params =
  match params.order_type with
  | Limit price -> _validate_price_positive price "Limit price"
  | Stop price -> _validate_price_positive price "Stop price"
  | StopLimit (stop_price, limit_price) ->
      let validations =
        [
          _validate_price_positive stop_price "Stop price";
          _validate_price_positive limit_price "Limit price";
          _validate_stop_limit_relationship params.side stop_price limit_price;
        ]
      in
      combine_status_list validations
  | Market -> Ok ()

let create_order ?(now_time = Time_ns_unix.now ()) params =
  (* Collect all validation results *)
  let validations =
    [
      _validate_symbol params.symbol;
      _validate_quantity params.quantity;
      _validate_order_type params;
    ]
  in

  (* Combine all validations - returns first error or Ok () *)
  match combine_status_list validations with
  | Ok () ->
      Result.Ok
        {
          id = _generate_order_id ();
          symbol = params.symbol;
          side = params.side;
          order_type = params.order_type;
          quantity = params.quantity;
          time_in_force = params.time_in_force;
          status = Pending;
          filled_quantity = 0.0;
          avg_fill_price = None;
          created_at = now_time;
          updated_at = now_time;
        }
  | Error err -> Result.Error err
