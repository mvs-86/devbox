#!/usr/bin/env bash
# Write the image's package/tool inventory for Claude Code (and humans) to grep.
# Run as the last install step of the build; see conf/claude/CLAUDE.md.
set -euo pipefail

out=${1:-/usr/local/share/devbox/inventory}
mkdir -p "$out"

## R: package, version, library, title (tab-separated)
Rscript -e '
ip <- installed.packages(fields = "Title")
ip <- ip[order(tolower(ip[, "Package"])), , drop = FALSE]
title <- gsub("[[:space:]]+", " ", ip[, "Title"])
write.table(data.frame(package = ip[, "Package"], version = ip[, "Version"],
                       library = ip[, "LibPath"], title = title),
            file = commandArgs(TRUE)[1], sep = "\t", quote = FALSE, row.names = FALSE)
' "$out/r-packages.tsv"

## Python (system pip)
pip list --format=freeze 2>/dev/null | sort -f > "$out/python-packages.txt"

## CLI tools: name, path, first line of the version output
tools=(
  R Rscript quarto pandoc python uv marimo jupyter claude
  rustc cargo gcc cmake make git gh docker
  duckdb sqlite3 mlr vd csvlook csvsql
  rg fd fzf bat delta jq tree
  hyperfine btop htop dust ncdu
  parallel pv entr just xh shfmt shellcheck
  tmux nvim zsh curl wget rsync zip unzip
  blas-switch
)
{
  printf 'tool\tpath\tversion\n'
  for t in "${tools[@]}"; do
    p=$(command -v "$t" 2>/dev/null) || { printf '%s\t-\tNOT INSTALLED\n' "$t"; continue; }
    case "$t" in
      blas-switch) cmd=("$t") ;;
      jupyter)     cmd=(jupyter lab --version) ;;
      tmux)        cmd=(tmux -V) ;;
      zip|unzip)   cmd=("$t" -v) ;;
      *)           cmd=("$t" --version) ;;
    esac
    v=$(timeout 10 "${cmd[@]}" 2>&1 </dev/null \
      | grep -m1 -iE '[0-9]+\.[0-9]+' | cut -c1-100 || true)
    printf '%s\t%s\t%s\n' "$t" "$p" "${v:-?}"
  done
} > "$out/cli-tools.tsv"

## BLAS / LAPACK alternatives available to blas-switch
blas-switch list > "$out/blas.txt" 2>&1 || true

printf 'Generated %s\n' "$(date -u +%Y-%m-%dT%H:%MZ)" > "$out/README"
wc -l "$out"/*.tsv "$out"/*.txt
