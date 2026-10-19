# NYSE A-D fixture provenance

The Unicorn archive was imported as described in `dev/ops/2026-04-10-data-fetch.md`
and restored in full by #3252. Counts are daily advancing/declining issues.

## Calendar cleanup (#3263)

Rows dated 2000-01-01 onwards were checked for weekends and closures using
Exchange_calendar's scheduled holiday rules. Pre-2000 rows are unchanged and
are deliberately unchecked by the regression test. The 2007-01-02 Ford and 2018-12-05 Bush mourning
closures were also removed: Exchange_calendar deliberately omits midweek exceptional
closures, so the test does not cover that class of closure.

Known missing trading days: **1999-11-26** (outside the validation window) and
**2002-06-20** (inside it). These remain gaps, not invented counts. The existing
interior-gap fill only fills gaps wider than seven calendar days by default;
it does not fill these isolated missing sessions.

Removed from both CSVs (original counts):

Date | advn | decln
--- | ---: | ---:
2002-07-04 | 1232 | 1941
2002-11-28 | 2595 | 675
2004-04-09 | 1087 | 1918
2005-02-21 | 1172 | 1933
2005-05-30 | 2202 | 1022
2005-09-05 | 1447 | 1752
2005-11-24 | 1958 | 1312
2005-12-26 | 2051 | 1186
2006-01-02 | 1351 | 1918
2006-01-16 | 1806 | 1461
2006-02-20 | 1852 | 1424
2006-04-14 | 1466 | 1767
2006-05-29 | 2271 | 952
2006-07-04 | 2358 | 837
2006-09-04 | 2099 | 1095
2006-11-23 | 1978 | 1270
2006-12-25 | 1259 | 1933
2007-01-01 | 1265 | 2013
2007-01-02 | 1265 | 2013
2007-01-15 | 2145 | 1094
2007-02-19 | 1634 | 1618
2007-04-06 | 1949 | 1237
2007-05-28 | 2243 | 988
2007-07-04 | 1971 | 1186
2007-12-25 | 2550 | 762
2008-01-01 | 1557 | 1793
2008-02-18 | 1459 | 1823
2008-07-04 | 1139 | 2172
2008-11-27 | 3100 | 581
2008-12-25 | 2150 | 1489
2009-10-24 | 936 | 2819
2010-02-15 | 1613 | 1394
2015-07-03 | 1573 | 1559
2016-12-26 | 0 | 0
2017-01-02 | 1360 | 1647
2018-01-15 | 1590 | 1370
2018-12-05 | 498 | 2542
2019-01-21 | 2219 | 774
2020-01-20 | 1480 | 1431
