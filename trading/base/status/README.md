# Status Module

Standard status handling for the trading system. Based on [Abseil's status codes](https://abseil.io/docs/cpp/guides/status-codes).

## Overview

This module provides a standardized way to handle operation status across the trading system. It defines:
- A set of status codes that cover both success and failure scenarios
- A standard status type that includes both a code and a descriptive message
- Helper functions for creating and working with status values

## Usage

```ocaml
open Trading.Base.Status

(* Create a status *)
let status = Status.create Invalid_argument "Invalid price format"

(* Convert status to string *)
let msg = Status.to_string status  (* "INVALID_ARGUMENT: Invalid price format" *)

(* Check status *)
let is_error = Status.is_error status  (* true *)

(* Raise as exception *)
raise (Status.Status_error status)
```

## Status Codes

The following status codes are available:

- `Ok`: The operation succeeded
- `Cancelled`: Operation cancelled, typically by the caller
- `Invalid_argument`: Invalid parameters or arguments
- `Deadline_exceeded`: Operation timed out
- `NotFound`: Requested entity not found
- `Already_exists`: Entity already exists
- `Permission_denied`: Caller lacks required permissions
- `Unauthenticated`: Authentication failed
- `Resource_exhausted`: Resource limits exceeded
- `Failed_precondition`: System not in valid state for operation
- `Aborted`: Operation aborted (e.g. concurrency issues)
- `Unavailable`: Service temporarily unavailable
- `Out_of_range`: Operation outside valid range
- `Unimplemented`: Operation not implemented
- `Internal`: Internal errors
- `Data_loss`: Unrecoverable data loss/corruption
- `Unknown`: Unknown error

## Guidelines

When choosing between similar status codes:

- Use `Unavailable` if the client can retry just the failing call
- Use `Aborted` if the client should retry at a higher transaction level
- Use `Failed_precondition` if the client should not retry until the system state has been fixed
- Use `Invalid_argument` (not `Out_of_range`) if the input will never be accepted
- Use `Out_of_range` for inputs that are invalid only due to current system state
