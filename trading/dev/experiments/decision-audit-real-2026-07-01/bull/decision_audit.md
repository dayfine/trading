# Per-screen faithfulness audit

Screens: 8 | funded: 15 | near-misses: 115 | screens with inversion: 5

Faithfulness question: does any captured feature separate the funded set from the cash-rejected near-misses? Overlapping means = uninformative tie (faithful/expected).

## Funded vs near-miss on captured features

| feature | funded mean | near-miss mean |
|---|---|---|
| score | 58.67 (n=15) | 52.50 (n=115) |
| rs_value | 0.95 (n=1) | 1.00 (n=19) |
| volume_ratio | 2.39 (n=15) | 2.33 (n=115) |
| weeks_advancing | 1.60 (n=15) | 1.92 (n=115) |

Near-miss skip reasons: Insufficient_cash=96, Stop_too_wide=19

## 2019-06-07  (funded 6, near-misses 14)
funded:
  BF-B s65 B S2
  BLDR s65 B S2
  CPB s65 B S2
  DPZ s65 B S2
  IT s65 B S2
  MAS s65 B S2
near-miss:
  HAS s65 B S2 [Insufficient_cash]
  LYV s65 B S2 [Insufficient_cash]
  NEM s65 B S2 [Stop_too_wide]
  NI s65 B S2 [Insufficient_cash]
  O s65 B S2 [Insufficient_cash]
  TDY s65 B S2 [Insufficient_cash]
  VTR s65 B S2 [Insufficient_cash]
  WSM s65 B S2 [Stop_too_wide]
  APO s57 B S2 [Insufficient_cash]
  ED s57 B S2 [Insufficient_cash]
  HSIC s57 B S2 [Stop_too_wide]
  TMUS s57 B S2 [Insufficient_cash]
  TYL s57 B S2 [Insufficient_cash]
  ADSK s55 B S2 [Insufficient_cash]
inversion: false

## 2019-06-14  (funded 1, near-misses 19)
funded:
  CASY s65 B S2
near-miss:
  D s65 B S2 [Insufficient_cash]
  ORLY s65 B S2 [Insufficient_cash]
  TJX s65 B S2 [Insufficient_cash]
  DAL s55 B S2 [Insufficient_cash]
  DLR s55 B S2 [Insufficient_cash]
  CPB s50 C S2 [Insufficient_cash]
  DECK s50 C S2 [Insufficient_cash]
  EFX s50 C S2 [Insufficient_cash]
  EPAM s50 C S2 [Insufficient_cash]
  GNRC s50 C S2 [Insufficient_cash]
  HAS s50 C S2 [Insufficient_cash]
  LIN s50 C S2 [Insufficient_cash]
  LYV s50 C S2 [Insufficient_cash]
  NI s50 C S2 [Insufficient_cash]
  O s50 C S2 [Insufficient_cash]
  RTX s50 C S2 [Insufficient_cash]
  SATS s50 C S2 [Insufficient_cash]
  SNPS s50 C S2 [Insufficient_cash]
  TDY s50 C S2 [Insufficient_cash]
inversion: false

## 2019-06-21  (funded 3, near-misses 17)
funded:
  AMAT s55 B S2
  CIEN s65 B S2
  SW s65 B S2
near-miss:
  FRT s65 B S2 [Insufficient_cash]
  AAPL s55 B S2 [Stop_too_wide]
  APH s55 B S2 [Insufficient_cash]
  EIX s55 B S2 [Insufficient_cash]
  ETN s55 B S2 [Insufficient_cash]
  EW s55 B S2 [Stop_too_wide]
  EXPE s55 B S2 [Stop_too_wide]
  GRMN s55 B S2 [Insufficient_cash]
  HII s55 B S2 [Insufficient_cash]
  JNJ s55 B S2 [Insufficient_cash]
  KEY s55 B S2 [Stop_too_wide]
  KEYS s55 B S2 [Stop_too_wide]
  MTB s55 B S2 [Insufficient_cash]
  NKE s55 B S2 [Insufficient_cash]
  OKE s55 B S2 [Insufficient_cash]
  PPG s55 B S2 [Insufficient_cash]
  PPL s55 B S2 [Insufficient_cash]
inversion: true

## 2019-07-19  (funded 1, near-misses 19)
funded:
  DXCM s50 C S2
near-miss:
  LITE s55 B S2 [Stop_too_wide]
  MPWR s55 B S2 [Stop_too_wide]
  WDC s55 B S2 [Insufficient_cash]
  DVA s50 C S2 [Insufficient_cash]
  IBM s50 C S2 [Insufficient_cash]
  JBL s50 C S2 [Insufficient_cash]
  MU s50 C S2 [Insufficient_cash]
  NWSA s50 C S2 [Insufficient_cash]
  NXPI s50 C S2 [Insufficient_cash]
  TXT s50 C S2 [Insufficient_cash]
  URI s50 C S2 [Insufficient_cash]
  FAST s42 C S2 [Insufficient_cash]
  CFG s40 C S2 [Insufficient_cash]
  DE s40 C S2 [Stop_too_wide]
  GEN s40 C S2 [Insufficient_cash]
  GILD s40 C S2 [Insufficient_cash]
  GLW s40 C S2 [Stop_too_wide]
  JKHY s40 C S2 [Insufficient_cash]
  LYB s40 C S2 [Stop_too_wide]
inversion: true

## 2019-08-02  (funded 1, near-misses 17)
funded:
  AES s40 C S2
near-miss:
  FTNT s55 B S2 [Stop_too_wide]
  PM s55 B S2 [Insufficient_cash]
  ZBH s55 B S2 [Insufficient_cash]
  MU s50 C S2 [Insufficient_cash]
  UHS s50 C S2 [Insufficient_cash]
  VRT s50 C S2 [Insufficient_cash]
  BBY s40 C S2 [Insufficient_cash]
  CLX s40 C S2 [Insufficient_cash]
  COHR s40 C S2 [Stop_too_wide]
  DE s40 C S2 [Insufficient_cash]
  DVA s40 C S2 [Insufficient_cash]
  HUM s40 C S2 [Insufficient_cash]
  LITE s40 C S2 [Stop_too_wide]
  MPWR s40 C S2 [Insufficient_cash]
  ODFL s40 C S2 [Insufficient_cash]
  RF s40 C S2 [Insufficient_cash]
  WDC s40 C S2 [Insufficient_cash]
inversion: true

## 2019-08-16  (funded 1, near-misses 6)
funded:
  DLR s40 C S2
near-miss:
  GOOGL s65 B S2 [Stop_too_wide]
  CVS s55 B S2 [Insufficient_cash]
  UPS s50 C S2 [Insufficient_cash]
  VRT s50 C S2 [Insufficient_cash]
  HUM s40 C S2 [Insufficient_cash]
  ZBH s40 C S2 [Insufficient_cash]
inversion: true

## 2019-08-30  (funded 1, near-misses 4)
funded:
  UPS s50 C S2
near-miss:
  JBHT s50 C S2 [Insufficient_cash]
  AMGN s40 C S2 [Insufficient_cash]
  CVS s40 C S2 [Insufficient_cash]
  STX s40 C S2 [Insufficient_cash]
inversion: false

## 2019-12-13  (funded 1, near-misses 19)
funded:
  HPQ s60 B S2
near-miss:
  NOW s75 A S2 [Insufficient_cash]
  PRU s65 B S2 [Insufficient_cash]
  WYNN s65 B S2 [Insufficient_cash]
  ADBE s60 B S2 [Insufficient_cash]
  AXON s60 B S2 [Insufficient_cash]
  CSGP s60 B S2 [Stop_too_wide]
  DHR s60 B S2 [Insufficient_cash]
  DIS s60 B S2 [Insufficient_cash]
  GE s60 B S2 [Insufficient_cash]
  HRL s60 B S2 [Insufficient_cash]
  KHC s60 B S2 [Insufficient_cash]
  LLY s60 B S2 [Insufficient_cash]
  RL s60 B S2 [Insufficient_cash]
  VRT s60 B S2 [Insufficient_cash]
  ADP s50 C S2 [Insufficient_cash]
  ADSK s50 C S2 [Insufficient_cash]
  CRM s50 C S2 [Insufficient_cash]
  EIX s50 C S2 [Stop_too_wide]
  EXPD s50 C S2 [Insufficient_cash]
inversion: true

