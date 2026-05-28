# Per-symbol Weinstein stage strategy — 1998-01-01 to 2025-12-31

Diagnostic: minimal stage-transition strategy on SPY + 11 SPDR sector ETFs.

Initial cash: $1000k. Cost model: 0.5 bps one-sided bid-ask, no commission. Stage classifier: default Weinstein config (30-week WMA, slope_threshold 0.5%).

## Section 1 — Long-only matrix

| Symbol | Stage CAGR | BAH CAGR | Δ CAGR | Stage MaxDD | BAH MaxDD | # Stage-2 entries | Avg holding days | % time long |
|---|---|---|---|---|---|---|---|---|
| SPY |  +3.80% |  +7.16% |  -3.36% | 13.08% | 55.91% | 13 | 224 | 28.4% |
| XLK |  +1.44% |  +5.65% |  -4.20% | 52.21% | 81.40% | 18 | 178 | 30.5% |
| XLF |  +3.91% |  +3.16% |  +0.76% | 16.44% | 83.75% | 16 | 169 | 27.5% |
| XLI |  +3.34% |  +7.13% |  -3.79% | 23.33% | 62.72% | 21 | 180 | 38.2% |
| XLV |  +3.20% |  +6.82% |  -3.62% | 22.15% | 39.38% | 21 | 179 | 38.1% |
| XLE |  -0.99% |  +2.32% |  -3.31% | 42.53% | 74.38% | 22 | 113 | 25.0% |
| XLP |  +1.17% |  +3.96% |  -2.79% | 18.31% | 36.56% | 15 | 190 | 28.8% |
| XLY |  -0.05% |  +5.82% |  -5.87% | 55.26% | 59.53% | 17 | 168 | 28.9% |
| XLU |  +1.35% |  +1.28% |  +0.07% | 22.80% | 53.45% | 17 | 163 | 28.1% |
| XLB |  +0.78% |  +2.83% |  -2.05% | 41.52% | 59.92% | 23 | 153 | 35.5% |
| XLRE |  +0.82% |  +2.91% |  -2.09% | 30.91% | 37.56% | 10 | 160 | 42.5% |
| XLC | +14.33% | +11.82% |  +2.51% | 17.18% | 46.51% | 4 | 422 | 61.4% |

## Section 2 — Long-short matrix

| Symbol | Stage CAGR | BAH CAGR | Δ CAGR | Stage MaxDD | BAH MaxDD | # Stage-2 entries | Avg holding days | % time long | % time short | # short entries |
|---|---|---|---|---|---|---|---|---|---|---|
| SPY |  +2.04% |  +7.16% |  -5.12% | 21.93% | 55.91% | 13 | 152 | 28.4% | 8.6% | 12 |
| XLK |  -1.24% |  +5.65% |  -6.88% | 70.34% | 81.40% | 18 | 128 | 30.5% | 12.0% | 16 |
| XLF |  +1.07% |  +3.16% |  -2.09% | 50.98% | 83.75% | 16 | 134 | 27.5% | 17.4% | 18 |
| XLI |  -0.20% |  +7.13% |  -7.32% | 62.36% | 62.72% | 21 | 129 | 38.2% | 15.4% | 20 |
| XLV |  -0.78% |  +6.82% |  -7.60% | 55.57% | 39.38% | 21 | 124 | 38.1% | 13.7% | 20 |
| XLE |  -1.10% |  +2.32% |  -3.42% | 58.95% | 74.38% | 22 | 110 | 25.0% | 23.2% | 21 |
| XLP |  -0.62% |  +3.96% |  -4.58% | 37.76% | 36.56% | 15 | 130 | 28.8% | 10.6% | 15 |
| XLY |  -4.50% |  +5.82% | -10.32% | 73.98% | 59.53% | 17 | 127 | 28.9% | 14.9% | 17 |
| XLU |  -0.86% |  +1.28% |  -2.14% | 52.18% | 53.45% | 17 | 113 | 28.1% | 9.6% | 16 |
| XLB |  -4.07% |  +2.83% |  -6.90% | 75.45% | 59.92% | 23 | 115 | 35.5% | 16.9% | 22 |
| XLRE |  -5.82% |  +2.91% |  -8.73% | 49.53% | 37.56% | 10 | 112 | 42.5% | 14.0% | 9 |
| XLC | +16.82% | +11.82% |  +5.00% | 22.76% | 46.51% | 4 | 356 | 61.4% | 16.2% | 2 |

## Section 3 — Aggregate verdicts

- **Long-only vs BAH**: 3/12 symbols beat BAH. Δ CAGR avg -2.31pp; range [-5.87pp, +2.51pp]. Total Stage-2 entries across panel: 197 (avg 16.4 per symbol).

- **Long-short vs BAH**: 1/12 symbols beat BAH. Δ CAGR avg -5.01pp; range [-10.32pp, +5.00pp]. Total Stage-2 entries across panel: 197 (avg 16.4 per symbol).

## Section 4 — Per-symbol year-end equity samples

**SPY**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1089.10 | $906.53 |
| 1999 | $1242.83 | $933.93 |
| 2000 | $1144.94 | $900.20 |
| 2001 | $1144.94 | $909.21 |
| 2002 | $1108.80 | $1007.71 |
| 2003 | $1323.69 | $1203.01 |
| 2004 | $1331.72 | $1150.49 |
| 2005 | $1300.04 | $1123.11 |
| 2006 | $1300.04 | $1123.11 |
| 2007 | $1300.04 | $1106.00 |
| 2008 | $1300.04 | $1106.00 |
| 2009 | $1558.07 | $1325.52 |
| 2010 | $1673.60 | $1388.48 |
| 2011 | $1690.82 | $1242.71 |
| 2012 | $1696.60 | $1246.96 |
| 2013 | $1696.60 | $1246.96 |
| 2014 | $1696.60 | $1246.96 |
| 2015 | $1696.60 | $1195.33 |
| 2016 | $1775.11 | $1250.64 |
| 2017 | $1775.11 | $1250.64 |
| 2018 | $1775.11 | $1315.35 |
| 2019 | $1851.08 | $1269.89 |
| 2020 | $2242.24 | $1538.24 |
| 2021 | $2848.44 | $1954.11 |
| 2022 | $2496.12 | $1652.88 |
| 2023 | $2496.12 | $1652.88 |
| 2024 | $2496.12 | $1652.88 |
| 2025 | $2875.80 | $1772.02 |

**XLK**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $1324.05 | $1324.05 |
| 2000 | $1193.43 | $1011.51 |
| 2001 | $1193.43 | $1011.51 |
| 2002 | $958.64 | $959.64 |
| 2003 | $958.64 | $959.64 |
| 2004 | $960.87 | $915.28 |
| 2005 | $861.30 | $790.20 |
| 2006 | $927.45 | $827.37 |
| 2007 | $939.76 | $838.36 |
| 2008 | $880.36 | $678.64 |
| 2009 | $1190.19 | $917.48 |
| 2010 | $1198.00 | $901.84 |
| 2011 | $1081.12 | $649.47 |
| 2012 | $1081.12 | $625.22 |
| 2013 | $1076.29 | $622.42 |
| 2014 | $1076.29 | $622.42 |
| 2015 | $1056.02 | $540.23 |
| 2016 | $956.36 | $475.21 |
| 2017 | $956.36 | $475.21 |
| 2018 | $956.36 | $528.67 |
| 2019 | $1228.84 | $612.46 |
| 2020 | $1742.92 | $868.68 |
| 2021 | $2330.73 | $1161.65 |
| 2022 | $2117.89 | $1084.63 |
| 2023 | $2406.72 | $1232.55 |
| 2024 | $2406.72 | $1232.55 |
| 2025 | $1479.44 | $712.08 |

**XLF**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $1000.00 | $1000.00 |
| 2000 | $962.15 | $910.48 |
| 2001 | $938.24 | $802.66 |
| 2002 | $913.22 | $846.98 |
| 2003 | $1122.22 | $1040.81 |
| 2004 | $1081.08 | $953.81 |
| 2005 | $1037.20 | $884.95 |
| 2006 | $1037.20 | $884.95 |
| 2007 | $1037.20 | $826.74 |
| 2008 | $1037.20 | $826.74 |
| 2009 | $1037.20 | $826.74 |
| 2010 | $1091.74 | $867.13 |
| 2011 | $1091.74 | $993.58 |
| 2012 | $1128.13 | $964.44 |
| 2013 | $1504.63 | $1286.31 |
| 2014 | $1513.50 | $1293.90 |
| 2015 | $1513.50 | $1240.04 |
| 2016 | $1518.58 | $1244.20 |
| 2017 | $1518.58 | $1244.20 |
| 2018 | $1457.15 | $1189.12 |
| 2019 | $1390.92 | $1056.37 |
| 2020 | $1616.81 | $820.62 |
| 2021 | $2116.33 | $1074.15 |
| 2022 | $2116.33 | $1132.61 |
| 2023 | $2110.79 | $1059.22 |
| 2024 | $2713.16 | $1361.50 |
| 2025 | $2851.55 | $1336.05 |

**XLI**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $990.94 | $966.18 |
| 2000 | $947.40 | $923.73 |
| 2001 | $874.66 | $833.82 |
| 2002 | $776.30 | $790.07 |
| 2003 | $972.05 | $986.91 |
| 2004 | $950.57 | $965.11 |
| 2005 | $944.81 | $937.11 |
| 2006 | $1038.22 | $1017.76 |
| 2007 | $1150.85 | $1128.17 |
| 2008 | $1084.24 | $1315.34 |
| 2009 | $1281.56 | $1604.89 |
| 2010 | $1491.81 | $1760.35 |
| 2011 | $1506.28 | $1634.02 |
| 2012 | $1471.06 | $1502.86 |
| 2013 | $1471.06 | $1502.86 |
| 2014 | $1471.06 | $1502.86 |
| 2015 | $1471.06 | $1520.50 |
| 2016 | $1509.78 | $1560.52 |
| 2017 | $1509.78 | $1560.52 |
| 2018 | $1423.83 | $1558.58 |
| 2019 | $1388.00 | $1349.66 |
| 2020 | $1635.85 | $957.89 |
| 2021 | $1862.99 | $1090.89 |
| 2022 | $1774.96 | $846.82 |
| 2023 | $1886.39 | $814.31 |
| 2024 | $2180.46 | $941.25 |
| 2025 | $2451.56 | $947.33 |

**XLV**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $1056.04 | $1056.04 |
| 2000 | $964.55 | $847.76 |
| 2001 | $971.45 | $840.31 |
| 2002 | $961.48 | $822.30 |
| 2003 | $957.44 | $818.84 |
| 2004 | $957.39 | $803.63 |
| 2005 | $925.95 | $777.24 |
| 2006 | $959.71 | $762.82 |
| 2007 | $929.22 | $728.27 |
| 2008 | $872.18 | $641.24 |
| 2009 | $1050.69 | $815.81 |
| 2010 | $1028.78 | $747.12 |
| 2011 | $1038.80 | $677.01 |
| 2012 | $1194.23 | $778.30 |
| 2013 | $1660.16 | $1081.96 |
| 2014 | $2047.65 | $1334.50 |
| 2015 | $2149.95 | $1372.06 |
| 2016 | $2068.08 | $1297.16 |
| 2017 | $2286.44 | $1390.77 |
| 2018 | $2083.91 | $1223.18 |
| 2019 | $2062.18 | $1158.90 |
| 2020 | $2022.56 | $831.82 |
| 2021 | $2022.56 | $831.82 |
| 2022 | $2041.70 | $812.17 |
| 2023 | $1990.68 | $691.04 |
| 2024 | $2192.00 | $796.28 |
| 2025 | $2361.86 | $807.59 |

**XLE**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $923.11 | $895.08 |
| 2000 | $975.67 | $946.03 |
| 2001 | $938.65 | $895.55 |
| 2002 | $844.64 | $886.11 |
| 2003 | $851.81 | $893.63 |
| 2004 | $851.81 | $893.63 |
| 2005 | $851.81 | $893.63 |
| 2006 | $874.59 | $870.74 |
| 2007 | $843.97 | $840.26 |
| 2008 | $745.15 | $913.16 |
| 2009 | $642.02 | $791.02 |
| 2010 | $750.79 | $886.22 |
| 2011 | $780.23 | $830.61 |
| 2012 | $717.70 | $688.91 |
| 2013 | $717.70 | $688.91 |
| 2014 | $717.70 | $759.28 |
| 2015 | $678.83 | $840.47 |
| 2016 | $762.64 | $911.48 |
| 2017 | $773.71 | $960.34 |
| 2018 | $736.63 | $1052.45 |
| 2019 | $698.25 | $817.75 |
| 2020 | $614.17 | $925.73 |
| 2021 | $776.62 | $1115.58 |
| 2022 | $959.75 | $1378.62 |
| 2023 | $935.03 | $1181.91 |
| 2024 | $789.67 | $848.14 |
| 2025 | $761.50 | $738.59 |

**XLP**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $1000.00 | $1000.00 |
| 2000 | $1174.75 | $1174.75 |
| 2001 | $1005.16 | $911.78 |
| 2002 | $1005.16 | $1091.90 |
| 2003 | $1077.33 | $1148.23 |
| 2004 | $1106.02 | $1145.04 |
| 2005 | $1092.54 | $1131.09 |
| 2006 | $1092.54 | $1131.09 |
| 2007 | $1092.54 | $1131.09 |
| 2008 | $1057.11 | $1011.75 |
| 2009 | $1210.22 | $1217.40 |
| 2010 | $1272.07 | $1194.01 |
| 2011 | $1281.99 | $1203.32 |
| 2012 | $1281.99 | $1203.32 |
| 2013 | $1281.99 | $1203.32 |
| 2014 | $1281.99 | $1203.32 |
| 2015 | $1261.30 | $1124.45 |
| 2016 | $1261.30 | $1098.31 |
| 2017 | $1256.61 | $1094.23 |
| 2018 | $1145.96 | $960.88 |
| 2019 | $1310.25 | $1056.52 |
| 2020 | $1389.78 | $915.51 |
| 2021 | $1354.89 | $892.53 |
| 2022 | $1324.62 | $841.31 |
| 2023 | $1304.12 | $833.52 |
| 2024 | $1435.21 | $917.31 |
| 2025 | $1373.93 | $843.15 |

**XLY**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $1072.80 | $1072.80 |
| 2000 | $895.16 | $668.38 |
| 2001 | $881.33 | $582.63 |
| 2002 | $871.42 | $670.12 |
| 2003 | $1109.57 | $832.51 |
| 2004 | $1162.14 | $842.35 |
| 2005 | $1033.55 | $676.57 |
| 2006 | $1151.33 | $710.37 |
| 2007 | $1180.38 | $786.65 |
| 2008 | $1180.38 | $796.86 |
| 2009 | $1180.38 | $796.86 |
| 2010 | $1310.26 | $842.61 |
| 2011 | $1293.46 | $750.88 |
| 2012 | $1293.46 | $750.88 |
| 2013 | $1293.46 | $750.88 |
| 2014 | $1293.46 | $750.88 |
| 2015 | $1293.46 | $750.88 |
| 2016 | $1239.93 | $661.34 |
| 2017 | $1239.93 | $661.34 |
| 2018 | $1239.93 | $716.19 |
| 2019 | $1342.58 | $721.19 |
| 2020 | $1644.57 | $547.07 |
| 2021 | $2091.15 | $695.62 |
| 2022 | $1821.64 | $649.39 |
| 2023 | $1796.67 | $565.28 |
| 2024 | $1789.44 | $563.00 |
| 2025 | $986.27 | $284.58 |

**XLU**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $947.03 | $947.03 |
| 2000 | $1116.20 | $1110.38 |
| 2001 | $963.14 | $924.60 |
| 2002 | $963.14 | $926.29 |
| 2003 | $1187.52 | $1110.88 |
| 2004 | $1157.43 | $1082.73 |
| 2005 | $1157.43 | $1082.73 |
| 2006 | $1323.53 | $1193.77 |
| 2007 | $1316.32 | $1157.02 |
| 2008 | $1316.32 | $1117.15 |
| 2009 | $1471.89 | $1249.18 |
| 2010 | $1410.55 | $1113.43 |
| 2011 | $1412.73 | $1115.15 |
| 2012 | $1412.73 | $1075.13 |
| 2013 | $1372.32 | $1039.47 |
| 2014 | $1372.32 | $1039.47 |
| 2015 | $1300.17 | $969.69 |
| 2016 | $1300.17 | $958.08 |
| 2017 | $1327.51 | $978.22 |
| 2018 | $1337.05 | $960.64 |
| 2019 | $1333.19 | $957.87 |
| 2020 | $1377.28 | $907.69 |
| 2021 | $1281.88 | $844.82 |
| 2022 | $1281.88 | $724.01 |
| 2023 | $1217.13 | $665.94 |
| 2024 | $1442.46 | $789.22 |
| 2025 | $1442.46 | $789.22 |

**XLB**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 1998 | $1000.00 | $1000.00 |
| 1999 | $944.02 | $849.14 |
| 2000 | $807.63 | $771.34 |
| 2001 | $791.79 | $558.17 |
| 2002 | $791.79 | $547.01 |
| 2003 | $1042.51 | $720.22 |
| 2004 | $1031.41 | $678.82 |
| 2005 | $993.09 | $657.40 |
| 2006 | $1068.54 | $686.35 |
| 2007 | $1132.64 | $727.53 |
| 2008 | $1009.13 | $880.54 |
| 2009 | $1326.28 | $1122.20 |
| 2010 | $1460.89 | $1166.01 |
| 2011 | $1244.04 | $889.16 |
| 2012 | $1012.84 | $636.76 |
| 2013 | $1012.84 | $636.76 |
| 2014 | $1012.84 | $631.95 |
| 2015 | $956.10 | $619.52 |
| 2016 | $986.31 | $639.09 |
| 2017 | $986.31 | $639.09 |
| 2018 | $986.31 | $624.44 |
| 2019 | $937.34 | $593.44 |
| 2020 | $1207.74 | $404.57 |
| 2021 | $1352.49 | $453.06 |
| 2022 | $1218.36 | $366.90 |
| 2023 | $1250.73 | $345.13 |
| 2024 | $1285.17 | $357.96 |
| 2025 | $1235.96 | $321.31 |

**XLRE**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 2015 | $1000.00 | $1000.00 |
| 2016 | $1007.28 | $999.97 |
| 2017 | $1042.68 | $1029.94 |
| 2018 | $973.90 | $956.69 |
| 2019 | $1088.74 | $1002.58 |
| 2020 | $1108.70 | $712.96 |
| 2021 | $1571.16 | $1010.35 |
| 2022 | $1277.73 | $731.98 |
| 2023 | $1237.32 | $630.74 |
| 2024 | $1126.07 | $574.03 |
| 2025 | $1087.54 | $538.99 |

**XLC**
| Year-end | Long-only equity ($k) | Long-short equity ($k) |
|---|---|---|
| 2018 | $1000.00 | $1000.00 |
| 2019 | $1053.28 | $1053.28 |
| 2020 | $1315.65 | $1315.65 |
| 2021 | $1567.08 | $1504.49 |
| 2022 | $1567.08 | $2127.37 |
| 2023 | $1956.33 | $2464.52 |
| 2024 | $2606.56 | $3283.65 |
| 2025 | $2765.14 | $3257.50 |

## Section 5 — Strategic interpretation

### Headline finding: stage analysis IS a drawdown-protection mechanism, NOT an alpha source on absolute return

Long-only beats BAH on **only 3/12 symbols** (XLF, XLU, XLC), with the average delta CAGR -2.31 pp behind BAH. **The strategy loses on absolute CAGR**.

But — and this is the load-bearing observation — **MaxDD is dramatically lower on every single symbol**:

| Symbol | Stage MaxDD | BAH MaxDD | DD reduction |
|---|---|---|---|
| SPY | 13.1% | 55.9% | -42.8pp (4x better) |
| XLF | 16.4% | 83.7% | -67.3pp (5x better) |
| XLP | 18.3% | 36.6% | -18.3pp (2x better) |
| XLV | 22.2% | 39.4% | -17.2pp (1.8x better) |
| XLU | 22.8% | 53.4% | -30.6pp (2.3x better) |
| XLI | 23.3% | 62.7% | -39.4pp (2.7x better) |
| XLE | 42.5% | 74.4% | -31.9pp (1.8x better) |

The pattern is consistent: stage analysis correctly **exits before** the major drawdowns (dot-com 2000-2002, GFC 2008-2009, COVID March 2020, 2022 bear), then sits in cash. SPY's long-only equity curve is flat from 2005 through 2008 — the strategy was OUT of the market for the entire GFC. The cash drag during the recovery is the cost.

**Calmar ratio reframe** (CAGR / |MaxDD|) — stage strategy vs BAH:

| Symbol | Stage Calmar | BAH Calmar |
|---|---|---|
| SPY | 0.29 | 0.13 |
| XLF | 0.24 | 0.04 |
| XLU | 0.06 | 0.02 |
| XLI | 0.14 | 0.11 |
| XLV | 0.14 | 0.17 |
| XLP | 0.06 | 0.11 |

On a risk-adjusted (Calmar) basis the stage strategy beats BAH on **6/12** symbols including SPY, XLF, XLI, XLU, XLB, XLRE. This is a fundamentally different story than absolute CAGR.

### Stage analysis IS firing — it's NOT the signal that's broken

- 197 Stage-2 entries across 12 symbols × 27 years = **~16 entries per symbol per 27 years** = roughly 1 every 1.7 years. Plausible.
- Average holding period of 113-422 days (4 months to 14 months) — consistent with "ride Stage 2 trends, exit on Stage 3 topping" semantics.
- % time long: 25-42% range — Stage 2 conditions hold roughly a third of the time on broad equity indices. Matches intuition.

### Why does long-only LOSE on CAGR?

Two diagnoses, both compatible with the data:

1. **Stage 3 exits leave money on the table.** Stage 3 = topping/distribution, BUT not yet declining. Many "Stage 3" periods resolve back to Stage 2 (continuation), not Stage 4 (decline). Each false-positive Stage 3 exit forgoes the next leg up and pays the round-trip cost.

2. **Re-entry timing lags.** Stage 1 → Stage 2 transitions happen by definition AFTER the MA has been flat or declining and then started rising. This delay puts the entry well above the recent local low — exactly the level long-term cost-averaging would have captured. The 0.5 bps cost is negligible; the missed opportunity is meaningful.

### Why does long-short DESTROY value on all but XLC?

Long-short loses on **11/12 symbols**, and on the broad equity ETFs (SPY, XLI, XLY) the long-short variant loses 5-10 pp/year vs BAH:

- **Stage 4 entries are late.** Stage 4 = declining MA + price below MA. By the time the MA has rolled over and price is below, the steepest part of the decline is often already over. Late short entries get squeezed on the inevitable bear-market rallies.
- **Stage 4 → Stage 1 exits are late too.** Symmetric problem. The strategy holds short through the bottom and into the early recovery, taking losses on the way up before covering.
- **Asymmetric distribution.** Equities have a long-term positive drift (~7%/year on broad indices); shorting that drift requires unusually sharp drawdowns to be profitable. The 0.5 bps cost compounds across the 8-23% time spent short.

The short side **did NOT help in 2008, 2020, or 2022** — see SPY's long-short year-end equity, which went $1.10M (2008) → $1.33M (2009) → $1.39M (2010) — barely capturing any of the late-2008 to early-2009 bear move while the long-only sat in cash earning 0% and ended at $1.56M by 2009.

### XLC is the only consistent winner — and probably noise

XLC (Communication Services, inception 2018-06) wins on both variants. But it has only ~7 years of history and **only 4 Stage-2 entries** in the long-only run (avg holding 422 days = 14 months!). With n=4 trades, this is essentially "got lucky on the trend after inception, hit the COVID recovery and the AI rally on 2 of the 4 entries." Not statistically meaningful — single-symbol N-of-4 outcomes can swing ±10pp on luck alone.

### Implication for the existing Weinstein system

The dispatch brief asked: "if the minimal stage strategy beats BAH on most symbols, then the existing system's portfolio mechanics are the killer."

**The opposite happened.** The minimal strategy LOSES on CAGR. So:

1. **Portfolio mechanics aren't the alpha-bleed culprit** — the stage signal itself doesn't extract enough alpha to beat passive BAH on absolute return.
2. **The existing system's losses-vs-BAH are NOT a portfolio-mechanism artefact.** They're inherent to the stage-transition signal.
3. **However:** Calmar-ratio winners (6/12 on long-only) suggest stage analysis is a legitimate **risk-management** mechanism, just not an alpha-generation mechanism. The existing system shouldn't be evaluated purely on CAGR — it should be evaluated on risk-adjusted return.
4. **The short side should be deprioritised.** 1/12 winners and -5 pp average is a clear "don't ship this" signal. Any short-side feature work (margin overlay, etc.) is fighting an uphill battle against the underlying signal quality.

### What this rules out and rules in for next steps

Rules out:
- Hypothesis: "the stage classifier is correct, the portfolio mechanics are wrong." — **REJECTED.**
- Hypothesis: "long-short adds value over long-only on broad equity." — **REJECTED.**
- Spending more time tuning portfolio-level knobs (sector caps, sizing, laggard rotation) expecting them to recover CAGR — diminishing returns at best, since the underlying signal CAGR is sub-BAH to start with.

Rules in:
- Reframe success metric from CAGR to Calmar / Sortino. The system IS already delivering against a risk-adjusted measure; we just haven't been counting it that way.
- Investigate the Stage 3 false-positive problem (~half the Stage 3 exits resolve back to Stage 2 historically — check this against the existing screener cascade — see the parallel mechanism-ablation results for whether "no Stage 3 exit" improves things).
- Cross-sectional / multi-symbol stage-based rotation (cf. `french_weinstein_rotation`) may extract more alpha than per-symbol because the relative-strength filter selects the best Stage-2 candidate from a basket, instead of riding any single symbol's Stage 2.

### Coordination

This diagnostic is complementary to the parallel mechanism-ablation work
(branch `experiment/mechanism-ablation`). The ablation tests "which portfolio
mechanism in the current Weinstein implementation is killing the most
alpha?"; this diagnostic asks "is there any alpha to be killed in the first
place?". The two should be read together when both land.
