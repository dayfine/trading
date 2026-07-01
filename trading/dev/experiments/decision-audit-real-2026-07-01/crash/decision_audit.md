# Per-screen faithfulness audit

Screens: 11 | funded: 27 | near-misses: 147 | screens with inversion: 3

Faithfulness question: does any captured feature separate the funded set from the cash-rejected near-misses? Overlapping means = uninformative tie (faithful/expected).

## Funded vs near-miss on captured features

| feature | funded mean | near-miss mean |
|---|---|---|
| score | 57.96 (n=27) | 51.66 (n=147) |
| rs_value | - (n=0) | - (n=0) |
| volume_ratio | 2.52 (n=27) | 2.21 (n=147) |
| weeks_advancing | 1.70 (n=23) | 1.85 (n=98) |

Near-miss skip reasons: Insufficient_cash=89, Stop_too_wide=36, Short_notional_cap=22

## 2020-01-03  (funded 5, near-misses 15)
funded:
  ADBE s65 B S2
  CCL s65 B S2
  CIEN s65 B S2
  CTAS s65 B S2
  INVH s65 B S2
near-miss:
  APA s65 B S2 [Stop_too_wide]
  CTVA s65 B S2 [Stop_too_wide]
  EOG s65 B S2 [Stop_too_wide]
  GEN s65 B S2 [Insufficient_cash]
  HBAN s65 B S2 [Insufficient_cash]
  JBHT s65 B S2 [Insufficient_cash]
  KKR s65 B S2 [Insufficient_cash]
  LYV s65 B S2 [Stop_too_wide]
  NDSN s65 B S2 [Insufficient_cash]
  NOW s65 B S2 [Insufficient_cash]
  ODFL s65 B S2 [Insufficient_cash]
  PANW s65 B S2 [Insufficient_cash]
  TDY s65 B S2 [Insufficient_cash]
  TRGP s65 B S2 [Stop_too_wide]
  TSLA s65 B S2 [Insufficient_cash]
inversion: false

## 2020-01-10  (funded 1, near-misses 19)
funded:
  APD s65 B S2
near-miss:
  IT s65 B S2 [Insufficient_cash]
  STE s65 B S2 [Insufficient_cash]
  ADP s55 B S2 [Insufficient_cash]
  CDNS s55 B S2 [Insufficient_cash]
  COO s55 B S2 [Insufficient_cash]
  COST s55 B S2 [Insufficient_cash]
  CSX s55 B S2 [Insufficient_cash]
  EVRG s55 B S2 [Insufficient_cash]
  IQV s55 B S2 [Insufficient_cash]
  PFE s55 B S2 [Insufficient_cash]
  PRU s55 B S2 [Insufficient_cash]
  RSG s55 B S2 [Insufficient_cash]
  SNPS s55 B S2 [Insufficient_cash]
  TEL s55 B S2 [Insufficient_cash]
  WEC s55 B S2 [Insufficient_cash]
  APA s50 C S2 [Insufficient_cash]
  APTV s50 C S2 [Insufficient_cash]
  ARE s50 C S2 [Insufficient_cash]
  AXON s50 C S2 [Insufficient_cash]
inversion: false

## 2020-02-28  (funded 3, near-misses 15)
funded:
  GILD s65 B S2
  MCK s50 C S2
  SJM s55 B S2
near-miss:
  NI s50 C S2 [Insufficient_cash]
  O s50 C S2 [Insufficient_cash]
  AVB s40 C S2 [Insufficient_cash]
  BALL s40 C S2 [Insufficient_cash]
  CASY s40 C S2 [Insufficient_cash]
  CB s40 C S2 [Insufficient_cash]
  CHD s40 C S2 [Insufficient_cash]
  CPT s40 C S2 [Insufficient_cash]
  CTSH s40 C S2 [Insufficient_cash]
  DLR s40 C S2 [Insufficient_cash]
  ECL s40 C S2 [Insufficient_cash]
  HSY s40 C S2 [Insufficient_cash]
  IBKR s40 C S2 [Insufficient_cash]
  UDR s40 C S2 [Insufficient_cash]
  ULTA s40 C S2 [Insufficient_cash]
inversion: false

## 2020-03-06  (funded 3, near-misses 1)
funded:
  CASY s40 C S2
  CHD s40 C S2
  IBKR s50 C S2
near-miss:
  CTSH s40 C S2 [Insufficient_cash]
inversion: false

## 2020-03-13  (funded 1, near-misses 9)
funded:
  CRH s65 B S4
near-miss:
  FIX s65 B S4 [Short_notional_cap]
  AMGN s60 B S4 [Short_notional_cap]
  KLAC s60 B S4 [Short_notional_cap]
  TGT s60 B S4 [Short_notional_cap]
  ADI s55 B S4 [Short_notional_cap]
  KEYS s55 B S4 [Short_notional_cap]
  PWR s55 B S4 [Short_notional_cap]
  RVTY s55 B S4 [Short_notional_cap]
  WY s55 B S4 [Short_notional_cap]
inversion: false

## 2020-03-20  (funded 1, near-misses 9)
funded:
  CTAS s65 B S4
near-miss:
  FAST s70 A S4 [Short_notional_cap]
  CMCSA s65 B S4 [Short_notional_cap]
  CPAY s65 B S4 [Stop_too_wide]
  CVS s65 B S4 [Short_notional_cap]
  DAL s65 B S4 [Stop_too_wide]
  DOC s65 B S4 [Stop_too_wide]
  DRI s65 B S4 [Stop_too_wide]
  HLT s65 B S4 [Stop_too_wide]
  IDXX s65 B S4 [Short_notional_cap]
inversion: true

## 2020-03-27  (funded 1, near-misses 9)
funded:
  DG s65 B S4
near-miss:
  PODD s70 A S4 [Short_notional_cap]
  CIEN s65 B S4 [Short_notional_cap]
  CPT s65 B S4 [Short_notional_cap]
  DGX s65 B S4 [Short_notional_cap]
  GDDY s65 B S4 [Short_notional_cap]
  HD s65 B S4 [Short_notional_cap]
  ICE s65 B S4 [Short_notional_cap]
  LEN s65 B S4 [Short_notional_cap]
  NI s65 B S4 [Short_notional_cap]
inversion: true

## 2020-04-17  (funded 3, near-misses 16)
funded:
  AKAM s55 B S2
  CTRA s65 B S2
  PODD s55 B S4
near-miss:
  CRWD s55 B S2 [Stop_too_wide]
  WST s55 B S4 [Insufficient_cash]
  ADM s50 C S4 [Insufficient_cash]
  CIEN s50 C S4 [Insufficient_cash]
  CMCSA s50 C S4 [Insufficient_cash]
  CMS s50 C S4 [Insufficient_cash]
  COF s50 C S4 [Stop_too_wide]
  COO s50 C S4 [Insufficient_cash]
  CSX s50 C S4 [Insufficient_cash]
  CVNA s50 C S4 [Stop_too_wide]
  GIS s50 C S2 [Insufficient_cash]
  HRL s50 C S2 [Stop_too_wide]
  AMZN s40 C S2 [Insufficient_cash]
  CCI s40 C S2 [Stop_too_wide]
  EQIX s40 C S2 [Insufficient_cash]
  EQT s40 C S2 [Insufficient_cash]
inversion: false

## 2020-04-24  (funded 4, near-misses 20)
funded:
  CIEN s50 C S2
  CTRA s50 C S2
  DG s65 B S2
  HRL s50 C S2
near-miss:
  CMS s50 C S4 [Insufficient_cash]
  COO s50 C S4 [Insufficient_cash]
  GIS s50 C S2 [Insufficient_cash]
  HD s50 C S4 [Insufficient_cash]
  ODFL s50 C S4 [Insufficient_cash]
  POOL s50 C S4 [Insufficient_cash]
  RMD s50 C S4 [Insufficient_cash]
  WST s50 C S2 [Insufficient_cash]
  CSGP s45 C S4 [Insufficient_cash]
  PCG s45 C S4 [Stop_too_wide]
  AON s42 C S4 [Stop_too_wide]
  CPT s42 C S4 [Insufficient_cash]
  AKAM s40 C S2 [Insufficient_cash]
  AMZN s40 C S2 [Insufficient_cash]
  CAG s40 C S2 [Stop_too_wide]
  CCI s40 C S2 [Stop_too_wide]
  CRWD s40 C S2 [Insufficient_cash]
  EQT s40 C S2 [Insufficient_cash]
  SJM s40 C S2 [Insufficient_cash]
  WMT s40 C S2 [Insufficient_cash]
inversion: false

## 2020-05-08  (funded 1, near-misses 21)
funded:
  IDXX s65 B S2
near-miss:
  CHD s55 B S2 [Stop_too_wide]
  CHTR s55 B S2 [Stop_too_wide]
  GDDY s55 B S2 [Stop_too_wide]
  KMB s55 B S2 [Stop_too_wide]
  PYPL s55 B S2 [Insufficient_cash]
  CVNA s50 C S2 [Stop_too_wide]
  RMD s50 C S2 [Stop_too_wide]
  ROL s50 C S2 [Insufficient_cash]
  ABT s40 C S2 [Insufficient_cash]
  ADBE s40 C S2 [Stop_too_wide]
  AMGN s40 C S2 [Insufficient_cash]
  ARE s40 C S4 [Insufficient_cash]
  BAX s40 C S2 [Insufficient_cash]
  CAG s40 C S2 [Insufficient_cash]
  CCI s40 C S2 [Stop_too_wide]
  CMG s40 C S2 [Stop_too_wide]
  COST s40 C S2 [Insufficient_cash]
  CPB s40 C S2 [Stop_too_wide]
  CRWD s40 C S2 [Insufficient_cash]
  D s40 C S4 [Insufficient_cash]
  EA s40 C S2 [Insufficient_cash]
inversion: false

## 2020-05-15  (funded 4, near-misses 13)
funded:
  COHR s65 B S2
  DDOG s50 C S2
  DGX s55 B S2
  TTD s55 B S2
near-miss:
  ABBV s55 B S2 [Stop_too_wide]
  CSGP s55 B S2 [Stop_too_wide]
  META s55 B S2 [Stop_too_wide]
  AEE s50 C S4 [Stop_too_wide]
  FFIV s50 C S2 [Insufficient_cash]
  PODD s50 C S2 [Insufficient_cash]
  ROL s50 C S2 [Insufficient_cash]
  ABT s40 C S2 [Insufficient_cash]
  ANET s40 C S2 [Stop_too_wide]
  GDDY s40 C S2 [Stop_too_wide]
  PYPL s40 C S2 [Insufficient_cash]
  TECH s40 C S2 [Insufficient_cash]
  TMUS s40 C S2 [Stop_too_wide]
inversion: true

