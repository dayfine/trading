---
description: OCaml code patterns and idioms for this codebase
globs: ["**/*.ml", "**/*.mli"]
---

## Type Definitions

- Extensive use of variant types for domain modeling (side, order_type, order_status)
- Records with `[@@deriving show, eq]` for core data structures, which can be used for test assertions
- Modules expose both `.ml` and `.mli` files with comprehensive documentation

## Error Handling

- Result types for validation: `type validation_result = (order_params, validation_error list) result`
- Custom error types per domain area
- Status module in `base/status/` for common result patterns

## Validation Patterns

Use **pure functional validation** with applicative composition:

```ocaml
(* Each validation returns Ok () or Error status *)
let _validate_symbol symbol =
  if symbol = "" then Error (invalid_argument_error "Symbol cannot be empty")
  else Ok ()

let _validate_quantity quantity =
  if quantity <= 0.0 then
    Error (invalid_argument_error (Printf.sprintf "Quantity must be positive: %.2f" quantity))
  else Ok ()

(* Compose validations with combine_status_list *)
let create_something params =
  let validations = [
    _validate_symbol params.symbol;
    _validate_quantity params.quantity;
  ] in
  match combine_status_list validations with
  | Ok () -> Result.Ok { ... }
  | Error err -> Result.Error err
```

**Prefer this over imperative patterns:**
- Avoid mutable refs for error collection
- Each validation is independently testable
- All errors are collected and returned together
- Uses Status module's `combine_status_list` for composition

## OCaml Idioms and Best Practices

**Pattern Matching:**
- Use exhaustive matching on variant types
- Prefer `Hashtbl.find` (returns `Option.t`) over `Hashtbl.find_exn`
- Use `filter_map` when filtering and mapping in one pass
- Keep pattern matches clean with inline expressions where appropriate

**Monadic Composition:**
```ocaml
(* Use let%bind for Result chaining *)
let process portfolio trade =
  let%bind new_cash = _check_sufficient_cash portfolio cash_change in
  let%bind () = _update_position_with_trade new_positions trade in
  return { portfolio with current_cash = new_cash; ... }
```

**Helper Functions:**
- Prefix internal helpers with underscore: `_validate_symbol`, `_calculate_cost`
- Keep functions small and focused (≤ 25 lines recommended, 50 lines hard limit)
- Name functions clearly to indicate their purpose
- Extract complex logic into named helper functions

**Avoid Magic Numbers:**
- Semantic zeros (0.0 for "no P&L") are acceptable
- Parameterize tolerances with defaults: `?(epsilon = 1e-9)`
- Extract named constants for domain-specific values
