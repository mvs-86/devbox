
# devbox: marimo launcher uses the installed marimo (set sandbox = "uv" for
# per-notebook PEP 723 environments) and binds to the IPv4 loopback that
# jupyter-server-proxy connects to.
c.MarimoProxyConfig.host = "127.0.0.1"
c.MarimoProxyConfig.sandbox = None
c.MarimoProxyConfig.skip_update_check = True
c.MarimoProxyConfig.timeout = 120
