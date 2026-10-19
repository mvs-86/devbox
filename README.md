# devbox: JupyterLab R 4.5

Built on [b-data/jupyterlab-r-docker-stack](https://github.com/b-data/jupyterlab-r-docker-stack)
(`glcr.b-data.ch/jupyterlab/r/verse:4.5.3-devtools-docker`), published through
[DockFlare](https://github.com/ChrispyBacon-dev/DockFlare) behind Cloudflare Access.

## What's inside

| Area | Contents |
|---|---|
| Base (b-data) | R 4.5.3, JupyterLab 4, code-server, RStudio, Quarto, TinyTeX, pandoc, git/git-lfs, zsh, neovim, LSP, jupyterlab-git, Docker CLI + Compose |
| Added | Claude Code, DuckDB CLI, Rust (rustup stable, clippy, rustfmt, rust-analyzer), marimo + JupyterLab launcher, ipywidgets, jupytext, nbdime, execute-time, resource-usage, pandas/polars/pyarrow/duckdb, uv, gh, ripgrep, fd, jq, tmux, htop, cmake |
| R | pak, alphavantager, quantmod, httr2, RhpcBLASctl, duckdb, tidyquant, tidymodels, optimx, Rcpp, RcppArmadillo, RcppNumerical, gmm, sandwich, scales, gt, ggrepel, glue, dbplyr, readxl, openxlsx, fst, plotly, modelsummary, bench, profvis |
| R: time series | fable, fabletools, feasts, tsibble, forecast, rugarch, rmgarch, vars, urca, tseries, timetk, modeltime |
| R: rolling | slider, roll, RcppRoll, runner |
| R: ML | ranger, xgboost, lightgbm, bonsai, glmnet, vip, DALEX, finetune, stacks |
| R: optimisation | nloptr, CVXR, quadprog, osqp, DEoptim, GA, numDeriv, PortfolioAnalytics |
| R: parallel | future, future.apply, furrr, doFuture, mirai, future.mirai, data.table, RcppParallel, progressr |
| R: econometric finance | fixest, plm, ivreg, AER, clubSandwich, estimatr, marginaleffects, car, quantreg, did, momentfit, frenchdata, tidyfinance, RPostgres, fredr, alfred, highfrequency, tsgarch, MSGARCH, MSwM, tsDyn, midasr, mfGARCH, BVAR, MTS, copula, rvinecopulib, fitdistrplus, ghyp, NMOF, RQuantLib (+ QuantLib), texreg |
| BLAS | OpenBLAS (pthread/openmp/serial), BLIS (pthread/openmp), reference. Switch with `blas-switch` |

## Setup

```bash
docker network create cloudflare-net   # skip if DockFlare already created it
cp .env.example .env                   # fill in hostnames, ACCESS_EMAILS, API keys
docker compose up -d --build
```

- Local: http://127.0.0.1:8888/
- `JUPYTER_HOSTNAME`: JupyterLab
- `CODE_HOSTNAME`: code-server (redirects to `/code-server/`)
- `RSTUDIO_HOSTNAME`: RStudio (redirects to `/rstudio/`)

All three hostnames require Cloudflare Access login (`ACCESS_EMAILS`); Jupyter itself has no token or password.
The code and RStudio subdomains go through a small Caddy sidecar (`routes`),
because both apps are served by jupyter-server-proxy under sub-paths.

## Using it

- **Claude Code:** open a terminal and run `claude`. If `ANTHROPIC_API_KEY` is not set, log in.
  Its config is kept in `~/.claude` on the `jovyan-home` volume. Auto-update is off; rebuild the image to upgrade.
- **Alpha Vantage:** the key is available as `ALPHAVANTAGE_API_KEY` and as `AV_API_KEY`, which `alphavantager` reads automatically:
  ```r
  library(alphavantager)
  av_get("MSFT", av_fun = "TIME_SERIES_DAILY")
  ```
  ```python
  import os; os.environ["ALPHAVANTAGE_API_KEY"]
  ```
- **marimo:** use the JupyterLab launcher tile, or run `marimo edit notebook.py` in a terminal.
  The launcher uses the installed marimo. To get per-notebook PEP 723 uv sandboxes, set
  `c.MarimoProxyConfig.sandbox = "uv"` in `conf/marimo_config.py` and rebuild.
- **BLAS:**
  ```bash
  blas-switch            # current selection
  blas-switch list
  sudo blas-switch openblas-openmp   # needs GRANT_SUDO=yes; restart R afterwards
  ```
  Set `BLAS_IMPL` in `.env` to make the choice persist across restarts. Control threads with
  `OPENBLAS_NUM_THREADS` / `OMP_NUM_THREADS`, or at runtime with `RhpcBLASctl::blas_set_num_threads()`.
  Check from R with `sessionInfo()` (it shows the BLAS/LAPACK paths).
  With `future`/`mirai` workers, set `RhpcBLASctl::blas_set_num_threads(1)` in each worker
  (or use `openblas-serial`), otherwise N workers × BLAS threads oversubscribe the CPU.

## Security notes

- Mounting `/var/run/docker.sock` gives the notebook root-equivalent control of the host.
  Remove that volume (and `group_add`) if you don't need Docker from inside the box.
- Jupyter token auth is disabled (`conf/auth_config.py`). Cloudflare Access is the only gate
  remotely, and anything that can reach port 8888 (local processes, other containers on
  `cloudflare-net`) gets a shell, which with the Docker socket mounted means host root.
- b-data's startup copies the container environment, including API keys,
  into `$(R RHOME)/etc/Renviron.site` so that RStudio sessions can see it.
