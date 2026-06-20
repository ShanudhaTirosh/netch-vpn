# Contributing

Thanks for helping improve Netch VPN.

## Ground rules

- Stay close to upstream 3x-ui — this repo is installer/branding/automation, not
  a panel fork. Don't vendor 3x-ui source here.
- Keep shell scripts POSIX-friendly bash, `#!/bin/bash`, and **LF** line endings
  (enforced by `.gitattributes`).
- Never commit secrets, certs, or real credentials. CI runs gitleaks.

## Local checks (mirror CI)

```bash
# ShellCheck (gate is error-severity; fix warnings where reasonable)
shellcheck -x install.sh backup.sh scripts/*.sh assets/*.sh

# HTML — static pages strict, template lenient
pip install html5validator
html5validator --root assets --match '*.html'
html5validator --root sub_templates --match '*.html' --ignore-re '(\{\{.*\}\})|(\$\{.*\})' || true

# YAML (Clash profiles)
pip install yamllint
yamllint -c .yamllint assets/clash
```

## Pull requests

- One logical change per PR; describe what you tested.
- If you touch `install.sh`, update the CHANGELOG block at the top and bump the
  version in the header + final summary banner.
- New Clash profiles go in `assets/clash/` and should be added to the
  `URL_CLASH_SUB` array + the `-clash N` table in the README.

## Releases

Tag with `vX.Y.Z` and push the tag — `.github/workflows/release.yml` builds the
bundle, checksums, and publishes the GitHub Release automatically.
