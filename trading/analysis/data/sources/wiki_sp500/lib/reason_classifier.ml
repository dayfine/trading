open Core

type reason_category = M_and_A | Bankruptcy | Mcap_change | Spinoff | Other
[@@deriving show, eq]

(* Keywords associated with each category, listed in precedence order:
   M_and_A > Bankruptcy > Mcap_change > Spinoff > Other.

   Matching is case-insensitive substring against the lowercased reason text. *)
let _m_and_a_keywords =
  [ "acquired"; "purchased"; "merged with"; "acquisition" ]

let _bankruptcy_keywords = [ "bankruptcy"; "filed for" ]
let _mcap_keywords = [ "market capitalization"; "market cap" ]
let _spinoff_keywords = [ "spinoff"; "spun off"; "split off" ]

let _matches_any keywords lowered =
  List.exists keywords ~f:(fun kw -> String.is_substring lowered ~substring:kw)

let classify reason_text =
  let lowered = String.lowercase reason_text in
  if _matches_any _m_and_a_keywords lowered then M_and_A
  else if _matches_any _bankruptcy_keywords lowered then Bankruptcy
  else if _matches_any _mcap_keywords lowered then Mcap_change
  else if _matches_any _spinoff_keywords lowered then Spinoff
  else Other
