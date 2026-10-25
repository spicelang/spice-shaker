---
name: spice-shaker-build-test
description: Build and test Spice Shaker — install its own dependencies with `bootstrap.py`, run the Spice unit tests, build `build/spice-shaker` with `build.py`, and run the CI smoke and self-install checks or a manual run in a scratch project. Use when building the package manager, verifying a change, reproducing a CI failure, or trying a command end to end.
---

# Build and test Spice Shaker

CI (`.github/workflows/ci.yml`) runs: bootstrap dependencies → unit tests → build → `--help` smoke test →
self-install. Reproduce the same sequence before pushing.

## Prerequisites

- The Spice compiler on the `PATH` as `spice` (`build.py` calls `spice` directly), with its std (`SPICE_STD_DIR` for
  a release archive). `src/spice.toml` requires `spice >= 0.29.2`.
- `clang` and `lld` (CI installs them), `tar`, Python 3.11+ (`tomllib`), and network access to
  `rack.spicelang.com` and GitHub for the dependencies.

## Steps

```sh
python3 bootstrap.py                 # src/spice_packages from src/spice.lock, checksums verified (--force reinstalls)
spice test src/tests.spice           # unit tests; needs the bootstrapped packages (registry.spice imports github)
python3 build.py                     # runs bootstrap.py, then builds build/spice-shaker in release mode
./build/spice-shaker --help          # smoke test
(cd src && rm -rf spice_packages && ../build/spice-shaker sync)   # self-install: Shaker installs its own deps
```

- `src/tests.spice` imports every module; a new module with `#[test]` functions must be added there.
- `build.py` fixes the executable bit that Spice 0.29.0 loses when it takes the executable from its cache.
- The self-install must reproduce `src/spice.lock` exactly (same versions and checksums); a diff in `git status` after
  it points to a resolution or checksum bug.

## Trying commands by hand

Run the built binary in a scratch directory, never in the repository root:

```sh
mkdir -p /tmp/shaker-play && cd /tmp/shaker-play
/path/to/spice-shaker/build/spice-shaker init
/path/to/spice-shaker/build/spice-shaker install github
/path/to/spice-shaker/build/spice-shaker list
```

`media/test-project/` is a small project with a manifest and lock file for manual checks. `SPICE_RACK_URL` points
Shaker at a local registry (see the `spice-rack-build-test` skill of spicelang/spice-rack), `GITHUB_TOKEN` / `GH_TOKEN`
raise the GitHub rate limit.

## If the environment cannot run a step

No network means no bootstrap, so neither tests nor build can run. Say so in the PR description instead of silently
skipping the checks.
