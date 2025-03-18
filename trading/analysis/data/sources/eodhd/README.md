# EOD HD API

## Install dependencies

In `trading/trading/analysi
s/data_sources`

```sh
$ sudo apt-get install libffi-dev
$ opam install eodhd/eodhd.opam
```

In a codespace dev container, the steps above should have been performed by [Docker](/.devcontainer/Dockerfile).

```sh
$ dune build && dune runtest
```

## Setup

- There should be a `secrets` file with the API key in it
