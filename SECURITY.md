# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Email
**security@netchsolutions.com** (or open a private GitHub Security Advisory).
Include reproduction steps and the affected version (`install.sh` header).

We aim to acknowledge within 72 hours.

## Scope

This repository is installer/automation + branding + subscription templates. The
panel itself (3x-ui) is installed from upstream releases at runtime — report
panel-core issues to https://github.com/MHSanaei/3x-ui.

## Hardening built in

- Panel credentials are randomized per install and shown once.
- No secrets are committed (enforced by `.gitignore` + the gitleaks scan in CI).
- The decoy site is generic and never impersonates a real brand.
- `trustedXForwardedFor` / `acceptProxyProtocol` are server-side only.

## Recommended operator steps

- Add an Nginx `limit_req` on the panel login path.
- Enable Fail2ban (`XUI_ENABLE_FAIL2BAN=true` on the container path, or the
  native hooks).
- Keep certs auto-renewing (the installer adds a monthly certbot cron).
- Rotate the WARP identity periodically (see `scripts/warp.md`).
