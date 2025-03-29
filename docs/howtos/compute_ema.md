## Compute EMA

```sh
$ dune exec trading/analysis/data/sources/eodhd/bin/main.exe -- -symbol AAPL -output /tmp/data.csv && \
  dune exec trading/analysis/technical/indicators/ema/bin/compute_ema.exe -- -input /tmp/data.csv -period 30
```
