# Per-screen faithfulness audit

Screens: 24 | funded: 38 | near-misses: 361 | screens with inversion: 18

Faithfulness question: does any captured feature separate the funded set from the cash-rejected near-misses? Overlapping means = uninformative tie (faithful/expected).

## Funded vs near-miss on captured features

| feature | funded mean | near-miss mean |
|---|---|---|
| score | 56.11 (n=38) | 54.13 (n=361) |
| rs_value | 0.98 (n=9) | 1.01 (n=125) |
| volume_ratio | 2.36 (n=38) | 2.12 (n=361) |
| weeks_advancing | 1.71 (n=38) | 2.09 (n=351) |

Near-miss skip reasons: Insufficient_cash=294, Stop_too_wide=67

## 2023-01-06  (funded 8, near-misses 12)
funded:
  BBY s65 B S2
  BKR s65 B S2
  CIEN s65 B S2
  EG s65 B S2
  EME s65 B S2
  FSLR s65 B S2
  MRNA s65 B S2
  SMCI s65 B S2
near-miss:
  DAL s65 B S2 [Stop_too_wide]
  NKE s65 B S2 [Insufficient_cash]
  PM s65 B S2 [Insufficient_cash]
  SW s65 B S2 [Insufficient_cash]
  TXT s65 B S2 [Insufficient_cash]
  VRSN s65 B S2 [Insufficient_cash]
  BIIB s57 B S2 [Insufficient_cash]
  CPB s57 B S2 [Insufficient_cash]
  LEN s57 B S2 [Insufficient_cash]
  OMC s57 B S2 [Insufficient_cash]
  ORCL s57 B S2 [Insufficient_cash]
  PCG s57 B S2 [Insufficient_cash]
inversion: false

## 2023-01-13  (funded 1, near-misses 19)
funded:
  CSGP s65 B S2
near-miss:
  FANG s65 B S2 [Stop_too_wide]
  HBAN s65 B S2 [Insufficient_cash]
  HUBB s65 B S2 [Insufficient_cash]
  NDSN s65 B S2 [Insufficient_cash]
  REG s65 B S2 [Insufficient_cash]
  TKO s65 B S2 [Insufficient_cash]
  UAL s65 B S2 [Insufficient_cash]
  WDAY s65 B S2 [Insufficient_cash]
  APA s55 B S2 [Insufficient_cash]
  APH s55 B S2 [Insufficient_cash]
  APTV s55 B S2 [Stop_too_wide]
  BG s55 B S2 [Insufficient_cash]
  CASY s55 B S2 [Insufficient_cash]
  CBRE s55 B S2 [Insufficient_cash]
  CDW s55 B S2 [Insufficient_cash]
  CINF s55 B S2 [Insufficient_cash]
  CMCSA s55 B S2 [Insufficient_cash]
  DUK s55 B S2 [Stop_too_wide]
  EIX s55 B S2 [Stop_too_wide]
inversion: false

## 2023-01-20  (funded 3, near-misses 17)
funded:
  AXP s55 B S2
  JBHT s65 B S2
  KIM s55 B S2
near-miss:
  SWKS s65 B S2 [Insufficient_cash]
  CRL s55 B S2 [Stop_too_wide]
  PLD s55 B S2 [Insufficient_cash]
  PRU s55 B S2 [Insufficient_cash]
  TFC s55 B S2 [Insufficient_cash]
  VICI s55 B S2 [Insufficient_cash]
  WAT s55 B S2 [Insufficient_cash]
  BIIB s50 C S2 [Insufficient_cash]
  BK s50 C S2 [Insufficient_cash]
  CDW s50 C S2 [Insufficient_cash]
  FANG s50 C S2 [Stop_too_wide]
  GRMN s50 C S2 [Insufficient_cash]
  GS s50 C S2 [Insufficient_cash]
  HBAN s50 C S2 [Insufficient_cash]
  HUBB s50 C S2 [Insufficient_cash]
  IBKR s50 C S2 [Insufficient_cash]
  MCO s50 C S2 [Insufficient_cash]
inversion: true

## 2023-02-10  (funded 1, near-misses 19)
funded:
  DELL s55 B S2
near-miss:
  CLX s65 B S2 [Insufficient_cash]
  AMD s55 B S2 [Insufficient_cash]
  CHTR s55 B S2 [Insufficient_cash]
  COIN s55 B S2 [Insufficient_cash]
  CRM s55 B S2 [Insufficient_cash]
  HST s55 B S2 [Insufficient_cash]
  MAA s55 B S2 [Insufficient_cash]
  QCOM s55 B S2 [Insufficient_cash]
  ALGN s50 C S2 [Insufficient_cash]
  DIS s50 C S2 [Insufficient_cash]
  FDX s50 C S2 [Insufficient_cash]
  IP s50 C S2 [Insufficient_cash]
  META s50 C S2 [Insufficient_cash]
  NOW s50 C S2 [Insufficient_cash]
  PKG s50 C S2 [Insufficient_cash]
  STE s50 C S2 [Insufficient_cash]
  STX s50 C S2 [Insufficient_cash]
  UBER s50 C S2 [Insufficient_cash]
  UPS s50 C S2 [Insufficient_cash]
inversion: true

## 2023-02-17  (funded 1, near-misses 19)
funded:
  ALL s50 C S2
near-miss:
  DASH s65 B S2 [Insufficient_cash]
  GM s65 B S2 [Insufficient_cash]
  ANET s55 B S2 [Insufficient_cash]
  DLR s55 B S2 [Insufficient_cash]
  FAST s55 B S2 [Insufficient_cash]
  GPN s55 B S2 [Stop_too_wide]
  MSFT s55 B S2 [Insufficient_cash]
  ON s55 B S2 [Insufficient_cash]
  UDR s55 B S2 [Insufficient_cash]
  WST s55 B S2 [Insufficient_cash]
  ABNB s50 C S2 [Insufficient_cash]
  ALGN s50 C S2 [Insufficient_cash]
  BALL s50 C S2 [Insufficient_cash]
  CLX s50 C S2 [Insufficient_cash]
  DIS s50 C S2 [Insufficient_cash]
  FDX s50 C S2 [Insufficient_cash]
  IP s50 C S2 [Insufficient_cash]
  META s50 C S2 [Insufficient_cash]
  NOW s50 C S2 [Insufficient_cash]
inversion: true

## 2023-02-24  (funded 1, near-misses 19)
funded:
  PLTR s65 B S2
near-miss:
  CHRW s65 B S2 [Insufficient_cash]
  PANW s65 B S2 [Insufficient_cash]
  TTD s65 B S2 [Insufficient_cash]
  CHD s55 B S2 [Insufficient_cash]
  DVA s55 B S2 [Stop_too_wide]
  HSY s55 B S2 [Insufficient_cash]
  ABNB s50 C S2 [Insufficient_cash]
  BALL s50 C S2 [Insufficient_cash]
  FDX s50 C S2 [Insufficient_cash]
  GM s50 C S2 [Insufficient_cash]
  IP s50 C S2 [Insufficient_cash]
  META s50 C S2 [Insufficient_cash]
  NOW s50 C S2 [Insufficient_cash]
  STX s50 C S2 [Insufficient_cash]
  UPS s50 C S2 [Insufficient_cash]
  CLX s42 C S2 [Insufficient_cash]
  ADSK s40 C S2 [Insufficient_cash]
  AMD s40 C S2 [Insufficient_cash]
  ANET s40 C S2 [Insufficient_cash]
inversion: false

## 2023-03-03  (funded 1, near-misses 19)
funded:
  ABNB s50 C S2
near-miss:
  ECL s55 B S2 [Insufficient_cash]
  BALL s50 C S2 [Insufficient_cash]
  CRM s50 C S2 [Insufficient_cash]
  GM s50 C S2 [Insufficient_cash]
  PANW s50 C S2 [Insufficient_cash]
  TTD s50 C S2 [Insufficient_cash]
  CLX s42 C S2 [Insufficient_cash]
  AMD s40 C S2 [Insufficient_cash]
  ANET s40 C S2 [Insufficient_cash]
  CHD s40 C S2 [Insufficient_cash]
  COIN s40 C S2 [Stop_too_wide]
  FAST s40 C S2 [Insufficient_cash]
  FTNT s40 C S2 [Insufficient_cash]
  HPQ s40 C S2 [Insufficient_cash]
  HSY s40 C S2 [Insufficient_cash]
  MCD s40 C S2 [Insufficient_cash]
  MSFT s40 C S2 [Insufficient_cash]
  ON s40 C S2 [Insufficient_cash]
  UDR s40 C S2 [Insufficient_cash]
inversion: true

## 2023-03-10  (funded 1, near-misses 21)
funded:
  TTD s50 C S2
near-miss:
  IBM s70 A S4 [Insufficient_cash]
  ISRG s70 A S4 [Insufficient_cash]
  AES s60 B S4 [Insufficient_cash]
  CASY s60 B S4 [Insufficient_cash]
  ERIE s60 B S4 [Insufficient_cash]
  GD s60 B S4 [Insufficient_cash]
  HST s60 B S4 [Stop_too_wide]
  KIM s60 B S4 [Insufficient_cash]
  MCK s60 B S4 [Insufficient_cash]
  AMGN s55 B S4 [Insufficient_cash]
  TAP s55 B S2 [Insufficient_cash]
  BALL s50 C S2 [Insufficient_cash]
  PANW s50 C S2 [Insufficient_cash]
  ANET s40 C S2 [Insufficient_cash]
  CHD s40 C S2 [Insufficient_cash]
  ECL s40 C S2 [Insufficient_cash]
  FAST s40 C S2 [Insufficient_cash]
  FTNT s40 C S2 [Insufficient_cash]
  HSY s40 C S2 [Insufficient_cash]
  MCD s40 C S2 [Insufficient_cash]
  WST s40 C S2 [Insufficient_cash]
inversion: true

## 2023-03-17  (funded 2, near-misses 8)
funded:
  ABBV s50 C S2
  CIEN s50 C S2
near-miss:
  CME s50 C S2 [Insufficient_cash]
  PANW s50 C S2 [Insufficient_cash]
  CHD s40 C S2 [Insufficient_cash]
  COIN s40 C S2 [Stop_too_wide]
  ECL s40 C S2 [Insufficient_cash]
  HSY s40 C S2 [Insufficient_cash]
  MSFT s40 C S2 [Insufficient_cash]
  TAP s40 C S2 [Insufficient_cash]
inversion: false

## 2023-03-24  (funded 1, near-misses 7)
funded:
  CPB s40 C S2
near-miss:
  TTWO s55 B S2 [Insufficient_cash]
  VRSK s55 B S2 [Insufficient_cash]
  DASH s50 C S2 [Stop_too_wide]
  ADBE s40 C S2 [Stop_too_wide]
  ECL s40 C S2 [Insufficient_cash]
  MCD s40 C S2 [Insufficient_cash]
  MSFT s40 C S2 [Insufficient_cash]
inversion: true

## 2023-04-28  (funded 2, near-misses 18)
funded:
  AEP s55 B S2
  CMS s55 B S2
near-miss:
  BRO s65 B S2 [Insufficient_cash]
  FANG s55 B S2 [Stop_too_wide]
  LNT s55 B S2 [Insufficient_cash]
  MDT s55 B S2 [Insufficient_cash]
  PPL s55 B S2 [Insufficient_cash]
  VZ s55 B S2 [Insufficient_cash]
  ACN s50 C S2 [Stop_too_wide]
  AJG s50 C S2 [Insufficient_cash]
  AON s50 C S2 [Insufficient_cash]
  BIIB s50 C S2 [Insufficient_cash]
  BRK-B s50 C S2 [Insufficient_cash]
  CMG s50 C S2 [Insufficient_cash]
  ISRG s50 C S2 [Insufficient_cash]
  LULU s50 C S2 [Insufficient_cash]
  OKE s50 C S2 [Stop_too_wide]
  PM s50 C S2 [Insufficient_cash]
  PTC s50 C S2 [Insufficient_cash]
  TMO s50 C S2 [Insufficient_cash]
inversion: true

## 2023-05-05  (funded 2, near-misses 18)
funded:
  JPM s50 C S2
  SPGI s55 B S2
near-miss:
  TECH s57 B S2 [Stop_too_wide]
  BR s55 B S2 [Insufficient_cash]
  BRO s50 C S2 [Insufficient_cash]
  CHRW s50 C S2 [Stop_too_wide]
  ISRG s50 C S2 [Insufficient_cash]
  KHC s50 C S2 [Insufficient_cash]
  LULU s50 C S2 [Insufficient_cash]
  MO s50 C S2 [Insufficient_cash]
  OKE s50 C S2 [Insufficient_cash]
  PM s50 C S2 [Insufficient_cash]
  PTC s50 C S2 [Insufficient_cash]
  TAP s50 C S2 [Insufficient_cash]
  XEL s50 C S2 [Insufficient_cash]
  XOM s50 C S2 [Insufficient_cash]
  AJG s42 C S2 [Insufficient_cash]
  BRK-B s42 C S2 [Insufficient_cash]
  AEP s40 C S2 [Insufficient_cash]
  AMZN s40 C S2 [Stop_too_wide]
inversion: true

## 2023-05-12  (funded 3, near-misses 17)
funded:
  CHRW s50 C S2
  KHC s50 C S2
  MAS s55 B S2
near-miss:
  BRO s50 C S2 [Insufficient_cash]
  DVA s50 C S2 [Insufficient_cash]
  LULU s50 C S2 [Insufficient_cash]
  PTC s50 C S2 [Insufficient_cash]
  TECH s42 C S2 [Stop_too_wide]
  AMZN s40 C S2 [Stop_too_wide]
  BDX s40 C S2 [Insufficient_cash]
  BIIB s40 C S2 [Insufficient_cash]
  BR s40 C S2 [Insufficient_cash]
  COR s40 C S2 [Insufficient_cash]
  DELL s40 C S2 [Insufficient_cash]
  EA s40 C S2 [Stop_too_wide]
  LII s40 C S2 [Insufficient_cash]
  LLY s40 C S2 [Insufficient_cash]
  MDT s40 C S2 [Insufficient_cash]
  MKC s40 C S2 [Insufficient_cash]
  MLM s40 C S2 [Insufficient_cash]
inversion: false

## 2023-05-19  (funded 1, near-misses 11)
funded:
  POOL s40 C S2
near-miss:
  HAS s65 B S2 [Stop_too_wide]
  VRT s65 B S2 [Stop_too_wide]
  VMC s55 B S2 [Insufficient_cash]
  BRO s50 C S2 [Insufficient_cash]
  CVNA s50 C S2 [Stop_too_wide]
  HUBB s50 C S2 [Insufficient_cash]
  TECH s42 C S2 [Insufficient_cash]
  BR s40 C S2 [Insufficient_cash]
  MDT s40 C S2 [Insufficient_cash]
  MLM s40 C S2 [Insufficient_cash]
  UDR s40 C S2 [Insufficient_cash]
inversion: true

## 2023-05-26  (funded 1, near-misses 12)
funded:
  TECH s42 C S2
near-miss:
  AKAM s55 B S2 [Stop_too_wide]
  DDOG s55 B S2 [Insufficient_cash]
  GNRC s55 B S2 [Stop_too_wide]
  LYV s55 B S2 [Insufficient_cash]
  STE s55 B S2 [Stop_too_wide]
  CVNA s50 C S2 [Stop_too_wide]
  HAS s50 C S2 [Stop_too_wide]
  HUBB s50 C S2 [Insufficient_cash]
  VRT s50 C S2 [Insufficient_cash]
  BR s40 C S2 [Insufficient_cash]
  COST s40 C S2 [Insufficient_cash]
  VMC s40 C S2 [Insufficient_cash]
inversion: true

## 2023-06-02  (funded 1, near-misses 12)
funded:
  CRWD s60 B S2
near-miss:
  CSGP s75 A S2 [Insufficient_cash]
  CVNA s60 B S2 [Stop_too_wide]
  HAS s60 B S2 [Stop_too_wide]
  VRT s60 B S2 [Insufficient_cash]
  HUBB s52 C S2 [Insufficient_cash]
  AKAM s50 C S2 [Insufficient_cash]
  CCL s50 C S2 [Stop_too_wide]
  DDOG s50 C S2 [Insufficient_cash]
  GNRC s50 C S2 [Stop_too_wide]
  LYV s50 C S2 [Insufficient_cash]
  STE s50 C S2 [Stop_too_wide]
  VMC s50 C S2 [Insufficient_cash]
inversion: true

## 2023-06-09  (funded 1, near-misses 17)
funded:
  DDOG s50 C S2
near-miss:
  NTAP s75 A S2 [Insufficient_cash]
  ESS s65 B S2 [Stop_too_wide]
  HST s65 B S2 [Stop_too_wide]
  WDC s65 B S2 [Stop_too_wide]
  CSGP s60 B S2 [Insufficient_cash]
  CVNA s60 B S2 [Insufficient_cash]
  HAS s60 B S2 [Insufficient_cash]
  VRT s60 B S2 [Insufficient_cash]
  HUBB s52 C S2 [Insufficient_cash]
  AKAM s50 C S2 [Insufficient_cash]
  CCL s50 C S2 [Insufficient_cash]
  GNRC s50 C S2 [Stop_too_wide]
  LYV s50 C S2 [Insufficient_cash]
  NXPI s50 C S2 [Stop_too_wide]
  STE s50 C S2 [Stop_too_wide]
  UAL s50 C S2 [Stop_too_wide]
  VMC s50 C S2 [Insufficient_cash]
inversion: true

## 2023-06-16  (funded 1, near-misses 19)
funded:
  MPWR s50 C S2
near-miss:
  ALLE s75 A S2 [Stop_too_wide]
  BX s65 B S2 [Stop_too_wide]
  COF s65 B S2 [Stop_too_wide]
  HPE s65 B S2 [Insufficient_cash]
  SHW s65 B S2 [Insufficient_cash]
  SWK s65 B S2 [Insufficient_cash]
  CCL s60 B S2 [Insufficient_cash]
  COHR s60 B S2 [Insufficient_cash]
  CSGP s60 B S2 [Insufficient_cash]
  NCLH s60 B S2 [Insufficient_cash]
  NTAP s60 B S2 [Insufficient_cash]
  AKAM s50 C S2 [Insufficient_cash]
  EQR s50 C S2 [Insufficient_cash]
  ESS s50 C S2 [Stop_too_wide]
  GNRC s50 C S2 [Stop_too_wide]
  HST s50 C S2 [Stop_too_wide]
  LYV s50 C S2 [Insufficient_cash]
  MAS s50 C S2 [Stop_too_wide]
  NXPI s50 C S2 [Insufficient_cash]
inversion: true

## 2023-08-18  (funded 1, near-misses 19)
funded:
  GD s65 B S2
near-miss:
  IEX s75 A S2 [Insufficient_cash]
  IP s65 B S2 [Insufficient_cash]
  TPL s65 B S2 [Insufficient_cash]
  AVY s60 B S2 [Insufficient_cash]
  CDW s60 B S2 [Insufficient_cash]
  EXE s60 B S2 [Insufficient_cash]
  FFIV s60 B S2 [Insufficient_cash]
  FRT s60 B S2 [Insufficient_cash]
  JNJ s60 B S2 [Insufficient_cash]
  PKG s60 B S2 [Insufficient_cash]
  SATS s60 B S2 [Insufficient_cash]
  SCHW s60 B S2 [Insufficient_cash]
  STX s60 B S2 [Insufficient_cash]
  SW s60 B S2 [Insufficient_cash]
  TXT s60 B S2 [Insufficient_cash]
  AMGN s50 C S2 [Insufficient_cash]
  DHR s50 C S2 [Insufficient_cash]
  GEN s50 C S2 [Insufficient_cash]
  GPN s50 C S2 [Insufficient_cash]
inversion: true

## 2023-09-08  (funded 1, near-misses 9)
funded:
  IT s60 B S2
near-miss:
  AXON s75 A S2 [Stop_too_wide]
  CB s65 B S2 [Insufficient_cash]
  ERIE s60 B S2 [Insufficient_cash]
  IEX s60 B S2 [Insufficient_cash]
  ADSK s50 C S2 [Insufficient_cash]
  AON s50 C S2 [Insufficient_cash]
  APD s50 C S2 [Insufficient_cash]
  IP s50 C S2 [Insufficient_cash]
  TPL s50 C S2 [Insufficient_cash]
inversion: true

## 2023-09-29  (funded 1, near-misses 4)
funded:
  AON s50 C S2
near-miss:
  BSX s50 C S2 [Insufficient_cash]
  CIEN s50 C S2 [Insufficient_cash]
  EG s50 C S2 [Insufficient_cash]
  WRB s50 C S2 [Insufficient_cash]
inversion: false

## 2023-11-03  (funded 1, near-misses 7)
funded:
  HUM s50 C S2
near-miss:
  GDDY s75 A S2 [Insufficient_cash]
  NOC s75 A S2 [Insufficient_cash]
  STLD s65 B S2 [Insufficient_cash]
  FAST s60 B S2 [Insufficient_cash]
  GRMN s60 B S2 [Insufficient_cash]
  FIX s50 C S2 [Stop_too_wide]
  GD s50 C S2 [Insufficient_cash]
inversion: true

## 2023-12-08  (funded 1, near-misses 19)
funded:
  EXPD s65 B S2
near-miss:
  CCI s75 A S2 [Insufficient_cash]
  CSGP s75 A S2 [Insufficient_cash]
  EPAM s75 A S2 [Stop_too_wide]
  NTRS s75 A S2 [Insufficient_cash]
  NUE s75 A S2 [Stop_too_wide]
  STT s75 A S2 [Stop_too_wide]
  TGT s75 A S2 [Insufficient_cash]
  ZTS s75 A S2 [Stop_too_wide]
  AXP s65 B S2 [Insufficient_cash]
  BLDR s65 B S2 [Stop_too_wide]
  CBRE s65 B S2 [Stop_too_wide]
  CFG s65 B S2 [Stop_too_wide]
  FIS s65 B S2 [Insufficient_cash]
  HD s65 B S2 [Stop_too_wide]
  ICE s65 B S2 [Insufficient_cash]
  ISRG s65 B S2 [Stop_too_wide]
  ITW s65 B S2 [Stop_too_wide]
  KIM s65 B S2 [Stop_too_wide]
  MCHP s65 B S2 [Insufficient_cash]
inversion: true

## 2023-12-15  (funded 1, near-misses 19)
funded:
  CIEN s60 B S2
near-miss:
  GNRC s75 A S2 [Insufficient_cash]
  IQV s75 A S2 [Insufficient_cash]
  WAT s75 A S2 [Insufficient_cash]
  CRL s65 B S2 [Insufficient_cash]
  DHR s65 B S2 [Stop_too_wide]
  DOW s65 B S2 [Stop_too_wide]
  EXR s65 B S2 [Insufficient_cash]
  HON s65 B S2 [Insufficient_cash]
  JKHY s65 B S2 [Stop_too_wide]
  KHC s65 B S2 [Insufficient_cash]
  MMM s65 B S2 [Stop_too_wide]
  POOL s65 B S2 [Insufficient_cash]
  TDY s65 B S2 [Insufficient_cash]
  UHS s65 B S2 [Insufficient_cash]
  WY s65 B S2 [Insufficient_cash]
  BLDR s60 B S2 [Insufficient_cash]
  CCI s60 B S2 [Insufficient_cash]
  CRM s60 B S2 [Insufficient_cash]
  CSGP s60 B S2 [Insufficient_cash]
inversion: true

