
# devbox: no Jupyter token or password. Remote access is gated by Cloudflare
# Access and the published port is bound to 127.0.0.1. (An empty JUPYTER_TOKEN
# env var doesn't do this: jupyter_server then generates a random token.)
c.IdentityProvider.token = ""
c.PasswordIdentityProvider.hashed_password = ""
c.PasswordIdentityProvider.password_required = False
