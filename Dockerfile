# syntax=docker/dockerfile:1
#
# JupyterLab R 4.5 dev box built on b-data's jupyterlab-r-docker-stack.
# https://github.com/b-data/jupyterlab-r-docker-stack
#
# Default base: glcr.b-data.ch/jupyterlab/r/verse:4.5.3-devtools-docker
#   verse     = tidyverse + Quarto + TinyTeX + pandoc
#   devtools  = contributor requirements for code-server / vscode-R
#   docker    = Docker CLI, Buildx and Compose plugins

ARG IMAGE_FLAVOR=verse
ARG R_VERSION=4.5.3
ARG IMAGE_SUFFIX=-devtools-docker

FROM glcr.b-data.ch/jupyterlab/r/${IMAGE_FLAVOR}:${R_VERSION}${IMAGE_SUFFIX}

ARG RUST_TOOLCHAIN=stable
## Keep in step with the R duckdb package from the base image's CRAN snapshot
ARG DUCKDB_VERSION=1.5.2
ARG TARGETARCH

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

## Dev tools + alternative BLAS/LAPACK implementations
## (the base image already ships OpenBLAS pthread as the default)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    ripgrep \
    fd-find \
    jq \
    htop \
    tmux \
    tree \
    zip \
    unzip \
    less \
    gh \
    miller \
    visidata \
    sqlite3 \
    fzf \
    bat \
    git-delta \
    hyperfine \
    btop \
    du-dust \
    parallel \
    pv \
    entr \
    just \
    xh \
    shfmt \
    libopenblas0-pthread \
    libopenblas0-openmp \
    libopenblas0-serial \
    libblis4-pthread \
    libblis4-openmp \
    libblas3 \
    liblapack3 \
  && ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
  && ln -sf "$(command -v batcat)" /usr/local/bin/bat \
  && rm -rf /var/lib/apt/lists/*

## DuckDB CLI
RUN curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/duckdb_cli-linux-${TARGETARCH:-amd64}.gz" \
    | gunzip > /usr/local/bin/duckdb \
  && chmod 0755 /usr/local/bin/duckdb \
  && duckdb --version

## Rust (system-wide so the bind-mounted home does not shadow it)
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin:${PATH}
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y \
    --no-modify-path \
    --profile minimal \
    --default-toolchain "${RUST_TOOLCHAIN}" \
    --component rustfmt,clippy,rust-analyzer,rust-src \
  && chgrp -R "${NB_GID:-100}" "${RUSTUP_HOME}" "${CARGO_HOME}" \
  && chmod -R g+rwX "${RUSTUP_HOME}" "${CARGO_HOME}" \
  && find "${RUSTUP_HOME}" "${CARGO_HOME}" -type d -exec chmod g+s {} + \
  && printf 'export RUSTUP_HOME=%s\nexport CARGO_HOME=%s\ncase ":$PATH:" in *":%s/bin:"*) ;; *) export PATH="%s/bin:$PATH" ;; esac\n' \
    "${RUSTUP_HOME}" "${CARGO_HOME}" "${CARGO_HOME}" "${CARGO_HOME}" > /etc/profile.d/rust.sh \
  && rustc --version && cargo --version

## Claude Code (native installer, binary relocated to /usr/local/bin)
## Auto-update is disabled because /usr/local/bin is not user-writable;
## rebuild the image to upgrade.
ENV DISABLE_AUTOUPDATER=1
RUN curl -fsSL https://claude.ai/install.sh | bash \
  && install -m 0755 "$(readlink -f "${HOME}/.local/bin/claude")" /usr/local/bin/claude \
  && rm -rf "${HOME}/.local/bin/claude" "${HOME}/.local/share/claude" \
    "${HOME}/.local/state/claude" "${HOME}/.cache/claude" \
    "${HOME}/.claude" "${HOME}/.claude.json" \
  && claude --version

## Python: marimo (+ JupyterLab launcher integration) and JupyterLab essentials
RUN pip install --no-cache-dir \
    uv \
    "marimo[sandbox]" \
    marimo-jupyter-extension \
    ipywidgets \
    jupytext \
    nbdime \
    jupyterlab-execute-time \
    jupyter-resource-usage \
    pandas \
    polars \
    pyarrow \
    duckdb \
    csvkit \
    requests \
    python-dotenv \
  && marimo --version

## R: use Posit Package Manager binaries for Debian trixie (same snapshot date
## as the base image). PPM only serves binaries to the "R/x.y.z R (...)" user
## agent; R's default one gets source packages.
RUN cat >> "$(R RHOME)/etc/Rprofile.site" <<'EOF'
options(
  repos = c(CRAN = "https://p3m.dev/cran/__linux__/trixie/2026-04-23"),
  HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
    paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"]))
)
EOF

## R packages: Alpha Vantage / finance + BLAS thread control
RUN Rscript -e 'install.packages(c("pak", "alphavantager", "quantmod", "httr2", "RhpcBLASctl"), Ncpus = parallel::detectCores())' \
  && Rscript -e 'for (p in c("pak", "alphavantager", "quantmod", "httr2", "RhpcBLASctl")) library(p, character.only = TRUE)'

## R packages: modelling, optimisation, Rcpp, tables/plots, data I/O, profiling
## (only the ones the base image doesn't already ship are installed)
RUN Rscript -e 'pkgs <- c("duckdb", "tidyquant", "tidymodels", "optimx", "Rcpp", "RcppArmadillo", "RcppNumerical", "gmm", "sandwich", "scales", "gt", "ggrepel", "glue", "dbplyr", "readxl", "openxlsx", "fst", "plotly", "modelsummary", "bench", "profvis"); \
    missing <- setdiff(pkgs, rownames(installed.packages())); \
    if (length(missing)) install.packages(missing, Ncpus = parallel::detectCores()); \
    for (p in pkgs) library(p, character.only = TRUE)'

## R packages: time series, rolling windows, ML, optimisation, parallel
RUN Rscript -e 'pkgs <- c( \
      "fable", "fabletools", "feasts", "tsibble", "forecast", "rugarch", "rmgarch", "vars", "urca", "tseries", "timetk", "modeltime", \
      "slider", "roll", "RcppRoll", "runner", \
      "ranger", "xgboost", "lightgbm", "bonsai", "glmnet", "vip", "DALEX", "finetune", "stacks", \
      "nloptr", "CVXR", "quadprog", "osqp", "DEoptim", "GA", "numDeriv", "PortfolioAnalytics", \
      "future", "future.apply", "furrr", "doFuture", "mirai", "future.mirai", "data.table", "RcppParallel", "progressr"); \
    missing <- setdiff(pkgs, rownames(installed.packages())); \
    if (length(missing)) install.packages(missing, Ncpus = parallel::detectCores()); \
    for (p in pkgs) library(p, character.only = TRUE)'

## QuantLib headers for RQuantLib (libpq-dev for RPostgres ships with the base image)
RUN apt-get update \
  && apt-get install -y --no-install-recommends libquantlib0-dev \
  && rm -rf /var/lib/apt/lists/*

## R packages: empirical / econometric finance
RUN Rscript -e 'pkgs <- c( \
      "fixest", "plm", "ivreg", "AER", "clubSandwich", "estimatr", "marginaleffects", "car", "quantreg", "did", "momentfit", \
      "frenchdata", "tidyfinance", "RPostgres", "fredr", "alfred", \
      "highfrequency", "tsgarch", "MSGARCH", "MSwM", "tsDyn", "midasr", "mfGARCH", "BVAR", "MTS", \
      "copula", "rvinecopulib", "fitdistrplus", "ghyp", \
      "NMOF", "RQuantLib", "texreg"); \
    missing <- setdiff(pkgs, rownames(installed.packages())); \
    if (length(missing)) install.packages(missing, Ncpus = parallel::detectCores()); \
    for (p in pkgs) library(p, character.only = TRUE)'

## BLAS switcher + startup hook (runs as root before the server starts)
COPY --chmod=0755 scripts/blas-switch.sh /usr/local/bin/blas-switch
COPY --chmod=0755 scripts/before-notebook.d/10-devbox.sh /usr/local/bin/before-notebook.d/10-devbox.sh

## marimo launcher: use the installed marimo (no per-start uv sandbox) and
## bind to IPv4 loopback, which is what jupyter-server-proxy connects to
## (MarimoProxyConfig is only read from the .py config, not conf.d JSON)
COPY conf/marimo_config.py /tmp/marimo_config.py
RUN cat /tmp/marimo_config.py >> /etc/jupyter/jupyter_server_config.py \
  && rm /tmp/marimo_config.py

## Auth: no token/password (Cloudflare Access + loopback-only port instead)
COPY conf/auth_config.py /tmp/auth_config.py
RUN cat /tmp/auth_config.py >> /etc/jupyter/jupyter_server_config.py \
  && rm /tmp/auth_config.py

## Claude Code: environment notes (managed CLAUDE.md, loaded in every session)
## + a greppable inventory of R/Python packages and CLI tools. Keep this last
## among the install steps so the inventory covers everything.
COPY conf/claude/CLAUDE.md /etc/claude-code/CLAUDE.md
COPY --chmod=0755 scripts/gen-inventory.sh /usr/local/bin/gen-inventory
RUN gen-inventory /usr/local/share/devbox/inventory

## HOME is /home/jovyan during root build steps; hand back anything created there
RUN chown -R "${NB_UID}:${NB_GID}" "/home/${NB_USER}"

USER ${NB_USER}
WORKDIR /home/${NB_USER}
