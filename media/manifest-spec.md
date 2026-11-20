# Spice Shaker manifest and lock file

Format version: **1** (manifest and lock file)

This document specifies `spice.lock`, the lock file written by Spice Shaker, and the behavior of Spice Shaker that depends on it and on
`spice.toml`, the project manifest of Spice packages. The format of `spice.toml` itself is specified by the
[manifest package](https://github.com/spicelang/packages/blob/main/packages/manifest/README.md#the-format), which Spice Shaker, Spice Rack and the compiler use to read it. Both files are
[TOML v1.0.0](https://toml.io/en/v1.0.0) documents and are read and written with the TOML implementation of the standard library
(`std/text/toml/*`).

The keywords "must", "must not" and "should" are used as in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).

## Goals

1. The manifest is pleasant to edit by hand: it allows comments and has little syntactic noise.
2. Dependency sources (registry, GitHub, local path) are expressed with keys, not with micro-syntaxes inside strings, so new kinds of
   sources and options can be added without new string formats.
3. Typos are errors: unknown keys are rejected instead of silently ignored.
4. A package can declare which Spice compiler version it needs.
5. A package can declare its entry point, so consumers do not depend on its internal layout.
6. Installs are reproducible: the lock file records the exact commit of GitHub dependencies and a checksum of every package.

## Prior art

| Concept                                                     | Taken from                                  |
|-------------------------------------------------------------|---------------------------------------------|
| TOML, `[package]` table, short and detailed dependency form | Cargo (`Cargo.toml`)                        |
| Minimum toolchain version (`spice`)                         | Go (`go` directive), Cargo (`rust-version`) |
| Declared entry point (`entry`)                              | npm (`exports`)                             |
| `[tool.*]` namespace for third-party configuration          | Python (`pyproject.toml`, PEP 518)          |
| Commits and content checksums in the lock file              | Cargo (`Cargo.lock`), Go (`go.sum`)         |
| Checksum over the extracted file tree, not the archive      | Go (`dirhash`), Zig (`build.zig.zon`)       |

These were considered and rejected:

- **JSON** allows no comments and is noisy to edit by hand (quoted keys, no trailing commas).
- **YAML** (Dart) is hard to parse correctly and has type pitfalls (`1.10` is a float, `no` is `false`).
- **A custom line format** (Go) means one more grammar to design, document and maintain.
- **Manifests as code** (Swift, Gradle, Elixir) cannot be read without running them, so neither the registry nor Shaker could read or
  rewrite them safely.

## Files

| File              | Purpose                                            | Version control          |
|-------------------|----------------------------------------------------|--------------------------|
| `spice.toml`      | Manifest, written by humans and edited by Shaker   | commit                   |
| `spice.lock`      | Lock file, written by Shaker only                  | commit                   |
| `spice_packages/` | Installed packages, one directory per dependency   | ignore (`.gitignore`)    |

All three live in the **project root**, which is the directory Shaker is invoked from. Shaker does not search parent directories.

Every command except `init`, `search` and `info` requires a `spice.toml` in the project root.

## `spice.toml`

The format of `spice.toml` (tables, keys, names, version constraints, validation, and how dependencies are edited without touching
the rest of the file) is specified in the README of the [manifest package](https://github.com/spicelang/packages/blob/main/packages/manifest/README.md#the-format). Shaker reads, validates and edits
manifests with that package, so its rules apply exactly. A minimal manifest:

```toml
[package]
name = "my-app"
version = "0.1.0"

[dependencies]
json-parser = "^1.2.0"
http-utils = { github = "owner/Http-Utils", rev = "v1.0.0" }
my-local = { path = "../my-local" }

[dev-dependencies]
test-kit = "~1.2.0"
```

On top of the format, Shaker defines:

**Compiler check.** If `package.spice` is set, Shaker determines the compiler version from the first line of `spice --version` that
starts with `Spice version:`. If the compiler cannot be run or the version is not valid SemVer (e.g. a development build), the check is
skipped. Otherwise a mismatch is a **warning** for the root project and an **error** for a dependency.

**Allowed sources.** Which kinds of dependencies a manifest may have depends on how the package itself was installed:

| Source   | Allowed in the manifest of                      |
|----------|-------------------------------------------------|
| registry | every package                                   |
| GitHub   | the root project, GitHub and path dependencies  |
| path     | the root project only                           |

A dependency that violates this table (e.g. a registry package that depends on a GitHub repository) fails to install. The
`[dev-dependencies]` of dependencies are ignored.

## `spice.lock`

The lock file records the exact result of [resolution](#resolution). It is written by Shaker only.

```toml
# This file is generated by Spice Shaker. Do not edit it by hand.
version = 1

[[package]]
name = "http-utils"
source = "github:owner/Http-Utils"
version = "v1.0.0"
commit = "3f2a9c0e8b1d4f7a6c5e2d9b8a7f6e5d4c3b2a19"
checksum = "sha256-tree:9b1c..."
dependencies = ["json-parser"]

[[package]]
name = "json-parser"
source = "registry"
version = "1.2.4"
checksum = "sha256-tree:0d7e..."
dependencies = []

[[package]]
name = "my-local"
source = "path:../my-local"
dependencies = []
```

| Key        | Type            | Description |
|------------|-----------------|-------------|
| `version`  | integer         | Lock file format version. Must be `1`. |
| `package`  | array of tables | One entry per installed package, sorted by `name` |

| Key (`[[package]]`) | Type             | Present for       | Description |
|---------------------|------------------|-------------------|-------------|
| `name`              | string           | all               | Dependency name |
| `source`            | string           | all               | `"registry"`, `"github:<owner>/<repo>"` or `"path:<path>"` |
| `version`           | string           | registry, GitHub  | Resolved version (registry) or requested ref (GitHub, `"HEAD"` if no `rev` was given) |
| `commit`            | string           | GitHub            | Full commit sha the ref resolved to |
| `checksum`          | string           | registry, GitHub  | [Content checksum](#checksums) |
| `dependencies`      | array of strings | all               | Names of the packages this package depends on, sorted |

Shaker writes the keys in the order of this table and omits keys that do not apply. The file starts with the comment shown above.

A missing `spice.lock` is treated as empty. A lock file with another `version`, or one that is not valid TOML, is an error.

### Checksums

The checksum is computed over the **unpacked file tree** of a package, not over the downloaded archive, because GitHub does not
guarantee that generated archives stay byte-identical.

```
checksum = "sha256-tree:" + hex(sha256(L))
L        = concatenation, over all regular files of the package sorted by their relative path (byte order), of
           hex(sha256(file contents)) + "  " + relative path + "\n"
```

Relative paths use `/` as separator and are relative to the package root (the top-level directory of the archive is stripped; for
a registry package in a subdirectory of its repository, the package root is that directory).
Directories, symbolic links and other non-regular entries are not included. Hex digits are lowercase.

Shaker computes the checksum every time it downloads a package. If the lock file has a checksum for the same source and version
(registry) or commit (GitHub), the two must match; otherwise the package is removed again and the command fails. Packages that are
already installed in the locked version are not hashed again.

## Resolution

Resolution determines which version of which package is installed. All packages share one flat namespace: there is exactly one
installed package per dependency name.

1. The requirements of the root manifest, `[dependencies]` first and `[dev-dependencies]` second, each in file order, form a queue.
2. Requirements are processed in queue (breadth-first) order. The **first** requirement for a name decides how it is installed. The
   requirements of the installed package (its `[dependencies]`) are appended to the queue.
3. A later requirement for an already resolved name
   - with a different source (e.g. registry vs. GitHub, or another repository) is an **error**,
   - whose constraint the resolved version does not satisfy is a **warning**.
4. Installed packages that are no longer reachable from the root manifest are removed (from `spice_packages/` and the lock file).

Resolution stops at the first error. The manifest is then left unchanged, step 4 still runs, and the lock file records what is
installed.

**Registry dependencies.** Shaker fetches the package's versions from the registry. It picks the highest version that satisfies the
constraint, ignoring pre-releases unless no stable version matches. In `sync`, a locked version is kept as long as it satisfies the
constraint. The archive is downloaded from the registry's download endpoint. If the registry reports a `path` for the package (a
repository with several packages, each in its own directory such as `packages/github`), only that directory of the archive is
unpacked, as the root of `spice_packages/<name>`.

**GitHub dependencies.** Shaker resolves `rev` (or `HEAD` for the default branch) to a commit sha with the GitHub REST API
(`GET /repos/{owner}/{repo}/commits/{ref}`). If the `GITHUB_TOKEN` (or else `GH_TOKEN`) environment variable is set, it is sent as a bearer token. In `sync`,
a locked commit is reused as long as the lock entry has the same source and ref. The archive of the commit is downloaded from
`https://codeload.github.com/{owner}/{repo}/tar.gz/{commit}`.

**Path dependencies.** `spice_packages/<name>` becomes a symbolic link (a directory junction on Windows) to the absolute path of the
directory, so changes show up without reinstalling. The directory must contain a `spice.toml`.

**Manifests of dependencies.** The requirements of a downloaded package are read from its `spice.toml`. If it has none, the package has
no dependencies.

**External programs.** Shaker needs `tar` to unpack archives and uses the platform's tools to remove directories and to create links. It
does not use a shell; arguments are passed to the programs directly.

## Editing by Shaker

`install` and `uninstall` change the manifest. They keep it as the user wrote it (comments, blank lines, key order and formatting of
every line that is not affected) by editing the dependency lines in place, as specified in
[Editing](https://github.com/spicelang/packages/blob/main/packages/manifest/README.md#editing) of the manifest package. The edited text is validated again, and the file is only written if the result
contains exactly the intended dependencies.

`init` and the lock file have no user content to preserve; they are written with `TomlSerializer`.

## Validation

Shaker rejects a manifest that violates the [validation rules](https://github.com/spicelang/packages/blob/main/packages/manifest/README.md#validation) of the manifest package, with its messages
(the file, the table and the key, and for an unknown key a suggestion of the known key with the smallest edit distance).

## Commands

| Command | Description |
|---------|-------------|
| `init` | Create `spice.toml` in the project root (fails if `spice.toml` exists). The name is the directory name, lowercased, with disallowed characters replaced by `-`. Also adds `/spice_packages/` to the `.gitignore` of the project root (creating it if needed), unless a line already ignores `spice_packages`. |
| `install <name>` | Add a registry dependency. `--version <constraint>` sets the constraint; without it, Shaker records `^<installed version>` (or the exact version for a pre-release). |
| `install <owner/repo> --github` | Add a GitHub dependency. `--rev <ref>` sets `rev`. The dependency name is the repository name, lowercased, with disallowed characters replaced by `-`; `--as <name>` overrides it. |
| `install <path> --path` | Add a path dependency. The dependency name is the `package.name` of the target's `spice.toml`; `--as <name>` overrides it. |
| `install ... --dev` | Add the dependency to `[dev-dependencies]` instead (moving it if it is in the other table). |
| `uninstall <name>` | Remove a direct dependency and every package that is no longer needed. |
| `sync` | Install everything the manifest requires, preferring the versions and commits of the lock file. |
| `update` | Like `sync`, but resolve every dependency to the newest version or commit its specification allows. |
| `list` | Show the dependency tree from the manifest and the lock file. |
| `search <term>`, `info <name>` | Query the registry. |

After `install`, Shaker prints how to import the package: `import "spice_packages/<name>/<entry without .spice>";`.

Every command that changes the manifest writes it before the lock file. Every command exits with code 0 on success and 1 on failure.

## Registry

The registry ([Spice Rack](https://github.com/spicelang/spice-rack)) reads the manifest of each release to know its dependencies. It
reads `spice.toml` and uses only the registry dependencies of `[dependencies]` and
`[dev-dependencies]`; GitHub and path dependencies are not registry dependencies and are not listed. Package metadata (description,
license, ...) continues to come from the GitHub repository.

A repository can hold several packages, each in a directory with its own `spice.toml`. The registry reads the manifest and README
from that directory, takes the releases whose tag starts with the directory (full path or last segment) and `-`, `/` or `@`
(`github-v1.0.0`, `github/v1.0.0`, `github@1.0.0`, `packages/github/v1.0.0`), takes the description from `[package]` of the
manifest and reports the directory as `path` in its API.
