open Core

type alias = {
  current_symbol : string;
  historical_symbol : string;
  effective_date : Date.t;
  rationale : string;
}
[@@deriving show, eq]

let _meta =
  {
    current_symbol = "META";
    historical_symbol = "FB";
    effective_date = Date.create_exn ~y:2022 ~m:Month.Jun ~d:9;
    rationale =
      "Meta Platforms rebrand from Facebook 2022-06-09 (NASDAQ:FB → \
       NASDAQ:META; Meta 8-K filed 2021-10-28).";
  }

let _elv =
  {
    current_symbol = "ELV";
    historical_symbol = "ANTM";
    effective_date = Date.create_exn ~y:2022 ~m:Month.Jun ~d:28;
    rationale =
      "Elevance Health rebrand from Anthem 2022-06-28 (NYSE:ANTM → NYSE:ELV; \
       Elevance 8-K filed 2022-04-28).";
  }

let _vtrs =
  {
    current_symbol = "VTRS";
    historical_symbol = "MYL";
    effective_date = Date.create_exn ~y:2020 ~m:Month.Nov ~d:16;
    rationale =
      "Viatris merger of Mylan + Pfizer Upjohn 2020-11-16 (NASDAQ:MYL → \
       NASDAQ:VTRS; Viatris S-4 effective 2020-06-16).";
  }

let _otis =
  {
    current_symbol = "OTIS";
    historical_symbol = "UTX";
    effective_date = Date.create_exn ~y:2020 ~m:Month.Apr ~d:3;
    rationale =
      "Otis Worldwide spinoff from United Technologies 2020-04-03; UTX \
       simultaneously renamed RTX after Raytheon merger.";
  }

let _carr =
  {
    current_symbol = "CARR";
    historical_symbol = "UTX";
    effective_date = Date.create_exn ~y:2020 ~m:Month.Apr ~d:3;
    rationale =
      "Carrier Global spinoff from United Technologies 2020-04-03 (sister \
       spinoff to OTIS).";
  }

let _rtx =
  {
    current_symbol = "RTX";
    historical_symbol = "UTX";
    effective_date = Date.create_exn ~y:2020 ~m:Month.Apr ~d:3;
    rationale =
      "Raytheon Technologies rename of United Technologies post-Raytheon \
       merger 2020-04-03 (NYSE:UTX → NYSE:RTX).";
  }

let _dow =
  {
    current_symbol = "DOW";
    historical_symbol = "DWDP";
    effective_date = Date.create_exn ~y:2019 ~m:Month.Apr ~d:1;
    rationale =
      "Dow Inc. spinoff from DowDuPont 2019-04-01 (DWDP split into DD, DOW, \
       CTVA).";
  }

let _lin =
  {
    current_symbol = "LIN";
    historical_symbol = "PX";
    effective_date = Date.create_exn ~y:2018 ~m:Month.Oct ~d:31;
    rationale =
      "Linde plc merger of Praxair (PX) + Linde AG 2018-10-31 (NYSE:PX → \
       NYSE:LIN).";
  }

let _dxc =
  {
    current_symbol = "DXC";
    historical_symbol = "CSC";
    effective_date = Date.create_exn ~y:2017 ~m:Month.Apr ~d:3;
    rationale =
      "DXC Technology merger of CSC + HPE Enterprise Services 2017-04-03 \
       (NYSE:CSC → NYSE:DXC).";
  }

let _bkng =
  {
    current_symbol = "BKNG";
    historical_symbol = "PCLN";
    effective_date = Date.create_exn ~y:2018 ~m:Month.Feb ~d:27;
    rationale =
      "Booking Holdings rename of Priceline Group 2018-02-27 (NASDAQ:PCLN → \
       NASDAQ:BKNG).";
  }

let _googl =
  {
    current_symbol = "GOOGL";
    historical_symbol = "GOOG";
    effective_date = Date.create_exn ~y:2014 ~m:Month.Apr ~d:3;
    rationale =
      "Alphabet (Google) class A/C dual-class restructure 2014-04-03; original \
       GOOG became GOOGL (class A, voting), new GOOG (class C, non-voting) \
       issued. Pre-2014 historical bars trade as the single-class GOOG.";
  }

(* Curated list of corporate ticker renames affecting S&P 500 constituents.
   Order is newest-first for ease of human review; [canonicalize] is
   order-independent. Each entry must cite a verifiable source in
   [rationale]. *)
let all =
  [ _meta; _elv; _vtrs; _otis; _carr; _rtx; _dow; _lin; _dxc; _bkng; _googl ]

let _is_pre_rename_date ~symbol ~as_of (a : alias) =
  String.equal a.current_symbol symbol && Date.( < ) as_of a.effective_date

let canonicalize ~symbol ~as_of =
  match List.find all ~f:(_is_pre_rename_date ~symbol ~as_of) with
  | Some a -> a.historical_symbol
  | None -> symbol
