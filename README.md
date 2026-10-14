<p align="center">
  <img alt="Spice Logo" src="https://github.com/spicelang/spice/raw/main/docs/docs/static/avatar.png" height="220" />
  <h3 align="center">Spice Shaker</h3>
  <p align="center">Official Package Manager for the Spice programming language.</p>
  <p align="center">
    <a target="_blank" href="https://github.com/spicelang/spice-shaker/releases/latest"><img src="https://img.shields.io/github/v/release/spicelang/spice-shaker?include_prereleases"></a>
    <a target="_blank" href="https://github.com/spicelang/spice-shaker/actions/workflows/ci.yml"><img src="https://github.com/spicelang/spice-shaker/actions/workflows/ci.yml/badge.svg"></a>
    <a target="_blank" href="https://makeapullrequest.com"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg"></a>
    <a target="_blank" href="./LICENSE.md"><img src="https://img.shields.io/github/license/spicelang/spice-shaker"></a>
  </p>
</p>

---

This is the home repo of the Spice Shaker project. It is the official package manager for the Spice Programming Language and gets distributed along with it. Spice Shaker can be used to dynamically retrieve official and third party libraries from GitHub and make it available for Spice development.

If you like Spice Shaker, please consider a GitHub star! ⭐

## Usage
Spice Shaker talks to the [Spice Rack](https://github.com/spicelang/spice-rack) package registry (`https://rack.spicelang.com`; override with the
`SPICE_RACK_URL` environment variable) and to GitHub (set `GITHUB_TOKEN` to raise the API rate limit). It needs `tar` on the path.

```bash
spice-shaker init                          # create spice.toml and ignore spice_packages/ in .gitignore
spice-shaker install json-parser           # latest version, recorded as ^x.y.z in spice.toml
spice-shaker install test-kit --dev --version "~1.2.0"
spice-shaker install owner/repo --github --rev v1.0.0   # straight from GitHub (tag, branch or sha)
spice-shaker install ../my-lib --path      # link a local package
spice-shaker sync                          # install everything from spice.toml, honoring spice.lock
spice-shaker update                        # newest versions and commits the manifest allows
spice-shaker uninstall json-parser         # also removes dependencies nobody needs anymore
spice-shaker list | search <term> | info <package>
```

A manifest looks like this:

```toml
[package]
name = "my-app"
version = "0.1.0"
spice = ">=0.29.0"          # optional: required compiler version
entry = "src/lib.spice"     # optional: the file other packages import (default: src/main.spice)

[dependencies]
json-parser = "^1.2.0"
http-utils = { github = "owner/http-utils", rev = "v1.0.0" }
my-lib = { path = "../my-lib" }

[dev-dependencies]
test-kit = "~1.2.0"
```

Packages (and their dependencies) are installed to `spice_packages/<name>/`; the resolved versions, commits and content checksums are
written to `spice.lock`. Import their sources relative to your file, e.g. `import "spice_packages/json-parser/src/main";`. Version
constraints follow the registry: `1.2.3`, `^1.2.3`, `~1.2.3`, `1.2.x`, `>=1.0.0, <2.0.0`, `*`. The full format is specified in
[media/manifest-spec.md](./media/manifest-spec.md).

## Development
```bash
./build.sh                           # builds build/spice-shaker
spice test src/tests.spice           # unit tests
```

## Documentation
Please visit the documentation at [spicelang.com](https://www.spicelang.com).

## Contribute to the project
If you want to contribute to this project, please ensure you comply with the [contribution guidelines](./CONTRIBUTING.md).

© ChilliBits 2022-2026
