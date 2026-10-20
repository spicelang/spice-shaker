---
name: spice-shaker-architecture
description: Orientation map of Spice Shaker, the Spice package manager — the module layout of `src/` (driver → commands → installer → registry/archive, manifest/lockfile/semver models), how `install`/`sync`/`update` resolve and install packages, the format spec in `media/manifest-spec.md`, and the contracts with the Spice Rack registry and the `github` package. Use when navigating the code, deciding where a change belongs, or changing the manifest/lock format or resolution rules.
---

# Spice Shaker architecture

Spice Shaker is written in Spice and is itself a Spice package: its manifest is `src/spice.toml`, its lock file
`src/spice.lock`, and its dependencies (the [github](https://github.com/spicelang/packages/tree/main/packages/github)
package) are installed to `src/spice_packages/` (imports cannot leave the directory of the importing file, so the
packages live below `src/`).

**`media/manifest-spec.md` is the specification** of `spice.toml`, `spice.lock`, checksums, resolution, how Shaker edits
manifests, validation, and the commands. Behavior changes go into the spec in the same PR.

## Module map (`src/`)

| File | Role |
|------|------|
| `main.spice` | Entry point, hands `argv` to the `Driver` |
| `driver.spice` | CLI definition with `std/io/cli-parser`: subcommands, options, flags; `SHAKER_VERSION` |
| `commands.spice` | One `run*` function per command (`runInit`, `runInstall`, `runSync`, `runUpdate`, `runUninstall`, `runList`, `runSearch`, `runInfo`), each returns the exit code |
| `installer.spice` | `Installer`: breadth-first resolution over manifests, compiler version check (`spice` constraint), pruning of unreachable packages, symlinks for path dependencies |
| `registry.spice` | `Registry` client for the Spice Rack JSON API (`SPICE_RACK_URL` overrides the default) and GitHub commit resolution through the `github` package (`import "spice_packages/github/github" as gh`) |
| `archive.spice` | Download, list and unpack `.tar.gz` archives with `tar` (also a subdirectory for monorepo packages), `sha256-tree:` checksums |
| `manifest.spice` | `Manifest` / `Dependency` model, parsing with the std TOML parser, validation, rendering |
| `manifest-layout.spice` | Line scanner that edits dependency lines in place, so comments and formatting of `spice.toml` survive |
| `lockfile.spice` | `Lockfile` / `LockEntry`: parse, serialize (`TomlSerializer`), load/save `spice.lock` |
| `semver.spice` | Versions and constraints (`^`, `~`, `1.2.x`, ranges, `*`), `pickBestVersion` |
| `util.spice` | Name rules (`isValidPackageName`, GitHub names, refs, package dirs), string helpers, edit distance for suggestions |
| `tests.spice` | Imports every module so `spice test src/tests.spice` runs all `#[test]` functions |

## How a command runs

`install <pkg>`: validate the request → edit `spice.toml` through `manifest-layout` (verified by re-parsing) → the
`Installer` resolves the manifest breadth-first (first requirement per name wins, a different source for a name is
an error, an unsatisfied constraint a warning) → registry packages: versions from `/api/v1/packages/{name}`, archive
from `.../versions/{version}/download`, only the reported `path` subdirectory is unpacked; GitHub packages: ref →
commit via the GitHub API, archive from `codeload.github.com`; path packages: symlink (junction on Windows) → checksum
→ `finish` prunes unreachable packages and writes `spice.lock`, also after a failure.

`sync` keeps locked versions/commits while they still satisfy the manifest; `update` ignores the lock
(`preferLocked = false`).

## Safety rules in the code

- Everything that ends up in a path or a command line passes a validator from `util.spice` first.
- External programs (`tar`, platform tools for removing directories and creating links) get their arguments directly,
  never through a shell.
- Archive entries with `..` or absolute paths are skipped; archives are limited to 256 MiB (`MAX_ARCHIVE_SIZE`).

## Cross-repo contracts

- **Spice Rack** ([spicelang/spice-rack](https://github.com/spicelang/spice-rack)) serves the JSON API and reads
  `spice.toml` itself (`parseManifestDependencies` in its `src/github.spice`). Its semver rules match
  `src/semver.spice`. A change to the manifest format or constraint syntax has to be mirrored there.
- **`bootstrap.py`** reimplements `sync` in Python for the packages in `src/spice.lock` (registry + GitHub sources,
  subdirectories, the `sha256-tree:` checksum). Keep it in sync with `archive.spice` when the archive layout or
  checksum definition changes.
- **`github` package** ([spicelang/packages](https://github.com/spicelang/packages)): bump it in `src/spice.toml`, then
  regenerate `src/spice.lock` with a built Shaker (`cd src && ../build/spice-shaker update`), never by hand.
