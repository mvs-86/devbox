#!/bin/bash
# Sourced by b-data's start.sh (as root when the container starts as root).
# Do not use `exit` or `set -e` here.
#
# Note: b-data's 50-rstudio.sh already copies the container environment
# (incl. ALPHAVANTAGE_API_KEY / AV_API_KEY) into Renviron.site for RStudio.

# Select BLAS implementation from $BLAS_IMPL (default: keep image default)
if [ -n "${BLAS_IMPL:-}" ]; then
  echo "devbox: selecting BLAS implementation '${BLAS_IMPL}'"
  /usr/local/bin/blas-switch "${BLAS_IMPL}" || echo "devbox: WARNING: blas-switch failed"
fi
