# devbox

JupyterLab R 4.5 dev container built on b-data's
`glcr.b-data.ch/jupyterlab/r/verse:4.5.3-devtools-docker`, published through DockFlare
(Cloudflare tunnel + Access). See `README.md` for usage.

## Layout

- `Dockerfile`: adds dev tools, DuckDB CLI, alternative BLAS libs, Rust, Claude Code, marimo, Python/R packages
- `docker-compose.yml`: `jupyterlab-r` (main) + `routes` (Caddy) on external `cloudflare-net`
- `Caddyfile`: gives code-server / RStudio their own subdomains (redirects `/` to the sub-path)
- `scripts/blas-switch.sh`: installed as `/usr/local/bin/blas-switch`
- `scripts/before-notebook.d/10-devbox.sh`: startup hook, applies `$BLAS_IMPL`
- `conf/marimo_config.py`, `conf/auth_config.py`: appended to `/etc/jupyter/jupyter_server_config.py`
- `conf/claude/CLAUDE.md`: installed as `/etc/claude-code/CLAUDE.md` (managed memory for Claude Code
  inside the container); update it when tools or conventions change
- `scripts/gen-inventory.sh`: installed as `/usr/local/bin/gen-inventory`; the build's last install
  step writes `/usr/local/share/devbox/inventory/` (R/Python packages, CLI tools). Add new CLI tools
  to its `tools` list
- `.env.example`: template; `.env` holds secrets and is git-ignored

## Build / test

```bash
docker compose build jupyterlab-r
docker compose config --quiet          # validate (needs .env with required vars)
```

Smoke test without DockFlare: `docker run -u root -p 127.0.0.1:18888:8888 devbox/jupyterlab-r:4.5.3`,
then check `/lab`, `/marimo/`, `/code-server/` and `/rstudio/` (no token needed).
RStudio needs a cookie jar to get past `auth-sign-in`.

## Gotchas (verified)

- **`$HOME` is `/home/jovyan` during root build steps.** Installers write there as root, so the
  final `chown -R` of the home must stay last. Install tools system-wide (`/opt`, `/usr/local/bin`),
  because the `jovyan-home` volume shadows the image's home after the first run.
- **Claude Code:** native installer, then the binary is copied to `/usr/local/bin`.
  `DISABLE_AUTOUPDATER=1`; rebuild the image to upgrade.
- **BLAS switching** has to set four alternatives: `libblas.so.3`, `liblapack.so.3`, `libopenblas.so.0`
  and `libblis.so.4`. If `libopenblas.so.0` doesn't match the variant, R dies with
  `undefined symbol: blas_omp_number_max`. `blas-switch` sanity-checks R and reverts on failure.
- **marimo-jupyter-extension:** `MarimoProxyConfig` is ignored in `jupyter_server_config.d/*.json`;
  only the `.py` config works. Its defaults (`host ::1`, uv sandbox) time out behind
  jupyter-server-proxy, so the config forces `127.0.0.1` and `sandbox = None`.
- **The code-server proxy path is `/code-server/`** (not `/codeserver/`). RStudio's is `/rstudio/`.
- **b-data's `50-rstudio.sh`** already dumps the container env (including secrets) into `Renviron.site`.
  Don't duplicate that.
- **Startup hooks in `before-notebook.d` are *sourced*,** so don't use `exit` or `set -e` there.
- **R binaries come from PPM** (`p3m.dev/cran/__linux__/trixie/<date>`, appended to `Rprofile.site`).
  They need the `R/x.y.z R (...)` `HTTPUserAgent`; with R's default UA PPM silently serves source.
  Keep the snapshot date in step with the base image's.
- **Scripts must stay LF** (enforced via `.gitattributes`).
