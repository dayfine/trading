# EOD HD API

## Install dependencies

In `trading/analysis/data/sources/eodhd`

```sh
$ sudo apt-get install libffi-dev
$ opam install eodhd/eodhd.opam
```

In a codespace dev container, the steps above should have been performed by [Docker](/.devcontainer/Dockerfile).

```sh
$ dune build && dune runtest
```

## Setup

1. Get an API key from [EOD Historical Data](https://eodhd.com/cp/dashboard)
2. Create a `secrets` file in this directory with your API key:
   ```sh
   echo "YOUR_API_KEY_HERE" > trading/analysis/data/sources/eodhd/secrets
   ```
3. The `secrets` file is git-ignored and should never be committed
