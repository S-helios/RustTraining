# Production deployment

The unified static site is served from `https://sunp.xyz/` by the existing
Nginx container in `/mnt/services`. Deployments are received by a locked,
unprivileged account and activated with an atomic symbolic-link switch.

## Security model

- The deploy account has no password, sudo access, forwarding, agent access,
  or interactive SSH command access.
- Its SSH key is restricted to the root-owned
  `/usr/local/sbin/deploy-rust-training` command.
- The account can only write releases below
  `/mnt/services/nginx/www/rust-training`.
- The server host key is pinned in `deploy/known_hosts`.
- No password or private key is committed. The local private key lives at
  `.git/rust-training-deploy` with mode `0600`.
- Each release is validated before an atomic switch; the five newest releases
  are retained for rollback.

## Local commands

```bash
scripts/deploy-production.sh  # build, upload, activate, and verify HTTPS
git config core.hooksPath .githooks  # enable deployment after each commit
SKIP_PRODUCTION_DEPLOY=1 git commit ...  # intentionally skip one deployment
```

The server-side receiver and Nginx configuration are managed under the
existing `/mnt/services` lifecycle. Always back up the live configuration and
run `docker exec nginx nginx -t` before reloading Nginx.
