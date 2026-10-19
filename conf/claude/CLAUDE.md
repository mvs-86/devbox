# devbox container environment

You are inside the devbox container: Debian 13 (trixie), user `jovyan` (uid 1000), JupyterLab R
image from b-data with R 4.5.3, Python 3.13, Quarto, code-server and RStudio. `sudo` only works
when the container was started with `GRANT_SUDO=yes`.

## Check what is installed: grep the inventory first

`/usr/local/share/devbox/inventory/` is generated at image build time:

- `r-packages.tsv`: package, version, library, title
- `python-packages.txt`: `pip freeze` style
- `cli-tools.tsv`: tool, path, version
- `blas.txt`: BLAS variants available to `blas-switch`

```bash
rg -i '^fixest\t' /usr/local/share/devbox/inventory/r-packages.tsv
rg -i 'garch|copula' /usr/local/share/devbox/inventory/r-packages.tsv   # search by title
```

Prefer this over starting R or pip to check. It only covers the image. If something is missing,
it may have been installed later in a user library (R: `~/R/x86_64-pc-linux-gnu-library/4.5`,
pip: `~/.local`), so check there before installing.

## Tools to reach for

- Search: `rg`, `fd` (not grep -r / find), `fzf`, `bat` (`cat` with highlighting)
- Data: `duckdb` CLI (queries CSV/Parquet directly), `mlr` (Miller), csvkit (`csvlook`, `csvstat`,
  `csvsql`), `vd` (VisiData), `sqlite3`, `jq`
- Benchmarks/profiling: `hyperfine`; in R `bench`, `profvis`
- Shell: `parallel` (GNU), `pv`, `entr`, `just`, `xh`, `shfmt`, `shellcheck`, `delta`, `btop`, `dust`
- Builds: `gcc`, `cmake`, Rust (`cargo`, `clippy`, `rustfmt`, `rust-analyzer`)
- Python: `uv`, `marimo`, pandas/polars/pyarrow/duckdb

## R

- `install.packages()` gets **binaries** from Posit Package Manager (trixie, fixed CRAN snapshot
  set in `$(R RHOME)/etc/Rprofile.site`). Don't change `repos` or `HTTPUserAgent`; without that
  user agent PPM serves source and everything compiles.
- The system libraries are root-owned, so runtime installs go to the user library
  (`~/R/x86_64-pc-linux-gnu-library/4.5`, `pip install --user`) on the home volume. Packages
  everyone should get belong in the devbox repo's Dockerfile.
- BLAS: `blas-switch` (show), `blas-switch list`, `sudo blas-switch <variant>`; restart R afterwards.
  With `future`/`mirai`/`parallel` workers, call `RhpcBLASctl::blas_set_num_threads(1)` in each
  worker, or N workers × BLAS threads oversubscribe the CPU.
- Already installed for the usual work: tidyverse, data.table, tidymodels, fixest, plm, fable,
  rugarch, quantmod/tidyquant, duckdb, Rcpp/RcppArmadillo, future/furrr/mirai. Check the inventory
  for the rest.

## Environment

- `$HOME` (`/home/jovyan`) is a persistent volume, so files there survive restarts but shadow the
  image's home. System-wide tools live in `/usr/local/bin`, `/opt`.
- API keys are environment variables (e.g. `ALPHAVANTAGE_API_KEY`, `AV_API_KEY`). Never print them.
- Claude Code auto-update is off; the image is rebuilt to upgrade.
