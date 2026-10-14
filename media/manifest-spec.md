# Spice Shaker manifest and lock file

Format version: **1** (manifest and lock file)

This document specifies `spice.toml`, the project manifest of Spice packages, and `spice.lock`, the lock file written by Spice Shaker,
together with the behavior of Spice Shaker that depends on them. Both files are [TOML v1.0.0](https://toml.io/en/v1.0.0) documents and
are read and written with the TOML implementation of the standard library (`std/text/toml/*`).

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

### Example

```toml
[package]
name = "my-app"
version = "0.1.0"
description = "Does things"
license = "MIT"
authors = ["Jane Doe <jane@example.com>"]
repository = "https://github.com/jane/my-app"
spice = ">=0.29.0"
entry = "src/lib.spice"

[dependencies]
json-parser = "^1.2.0"
http-utils = { github = "owner/Http-Utils", rev = "v1.0.0" }
my-local = { path = "../my-local" }

[dev-dependencies]
test-kit = "~1.2.0"

[tool.some-linter]
max-line = 120
```

### Top-level tables

| Table                | Required | Description                                       |
|----------------------|----------|---------------------------------------------------|
| `[package]`          | yes      | Metadata of the package                           |
| `[dependencies]`     | no       | Dependencies needed to build and run the package  |
| `[dev-dependencies]` | no       | Dependencies only needed to develop and test it   |
| `[tool]`             | no       | Configuration of other tools, ignored by Shaker   |

Any other top-level key is an error. Shaker never reads or validates anything below `[tool]`; each tool uses only
`[tool.<its own name>]`.

### `[package]`

| Key           | Type             | Required | Description |
|---------------|------------------|----------|-------------|
| `name`        | string           | yes      | Package name, see [Names](#names) |
| `version`     | string           | yes      | Version of the package, [SemVer 2.0.0](https://semver.org) without a leading `v` |
| `description` | string           | no       | One-line summary |
| `license`     | string           | no       | [SPDX license expression](https://spdx.org/licenses/), e.g. `"MIT OR Apache-2.0"` |
| `authors`     | array of strings | no       | `"Name <email>"` or `"Name"` |
| `repository`  | string           | no       | URL of the source repository |
| `homepage`    | string           | no       | URL of the project website |
| `spice`       | string           | no       | [Version constraint](#version-constraints) on the Spice compiler |
| `entry`       | string           | no       | File consumers import, relative to the package root. Default: `src/main.spice` |

Any other key in `[package]` is an error. `entry` must be a relative path with `/` as separator, must not contain `..` components and
must end in `.spice`. Shaker does not check that the file exists.

**Compiler check.** If `spice` is set, Shaker determines the compiler version from the first line of `spice --version` that starts
with `Spice version:`. If the compiler cannot be run or the version is not valid SemVer (e.g. a development build), the check is skipped.
Otherwise a mismatch is a **warning** for the root project and an **error** for a dependency.

### Dependencies

`[dependencies]` and `[dev-dependencies]` map a **dependency name** to a **dependency specification**. The dependency name is the name
of the directory below `spice_packages/` and must be a valid [package name](#names). A name must not appear in both tables.

A specification is either a string (short form) or an inline table (detailed form). The short form `"^1.2.0"` is equivalent to
`{ version = "^1.2.0" }`. Shaker always writes the short form for registry dependencies.

| Key       | Type   | Description |
|-----------|--------|-------------|
| `version` | string | [Version constraint](#version-constraints) for a registry package |
| `github`  | string | `owner/repo` of a GitHub repository |
| `rev`     | string | Tag, branch or commit sha of the GitHub repository. Default: the repository's default branch |
| `path`    | string | Path of a local package, relative to the project root, with `/` as separator |

Exactly one of `version`, `github` and `path` must be present. `rev` is only allowed together with `github`. Any other key is an
error.

| Source   | Allowed in the manifest of                      |
|----------|-------------------------------------------------|
| registry | every package                                   |
| GitHub   | the root project, GitHub and path dependencies  |
| path     | the root project only                           |

A dependency that violates this table (e.g. a registry package that depends on a GitHub repository) fails to install. The
`[dev-dependencies]` of dependencies are ignored.

**Format restriction.** Every dependency must be written as a single `name = value` line inside a `[dependencies]` or
`[dev-dependencies]` section. The table headers must be written exactly like that (bare keys, optionally surrounded by spaces inside
the brackets). Sub-tables (`[dependencies.foo]`), dotted keys (`foo.version = "1.0"`), quoted dependency names and a top-level
`dependencies = { ... }` are errors. This keeps [editing by Shaker](#editing-by-shaker) simple and safe; TOML does not allow line breaks
inside inline tables, so the restriction costs no expressiveness.

### Names

Package and dependency names consist of lowercase ASCII letters, digits, `-` and `_`, start with a letter or digit and are at most 64
characters long.

### Version constraints

A constraint is a list of clauses separated by commas and/or spaces. A version satisfies the constraint if it satisfies every clause.

| Clause              | Matches                                                 |
|---------------------|---------------------------------------------------------|
| `1.2.3`, `=1.2.3`   | exactly `1.2.3`                                          |
| `^1.2.3`            | `>=1.2.3, <2.0.0`; `^0.2.3` = `>=0.2.3, <0.3.0`; `^0.0.3` = `>=0.0.3, <0.0.4` |
| `~1.2.3`            | `>=1.2.3, <1.3.0`                                        |
| `1.2.x`, `1.x`      | `>=1.2.0, <1.3.0` and `>=1.0.0, <2.0.0`                  |
| `>=`, `>`, `<=`, `<` followed by a version | comparison                        |
| `*`                 | any version                                              |

Versions in constraints may omit minor and patch (`^1` = `^1.0.0`). Versions published to the registry may have a leading `v` (from git
tags), which is ignored. Pre-releases sort before their release.

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
(`GET /repos/{owner}/{repo}/commits/{ref}`). If the `GITHUB_TOKEN` environment variable is set, it is sent as a bearer token. In `sync`,
a locked commit is reused as long as the lock entry has the same source and ref. The archive of the commit is downloaded from
`https://codeload.github.com/{owner}/{repo}/tar.gz/{commit}`.

**Path dependencies.** `spice_packages/<name>` becomes a symbolic link (a directory junction on Windows) to the absolute path of the
directory, so changes show up without reinstalling. The directory must contain a `spice.toml`.

**Manifests of dependencies.** The requirements of a downloaded package are read from its `spice.toml`. If it has none, the package has
no dependencies.

**External programs.** Shaker needs `tar` to unpack archives and uses the platform's tools to remove directories and to create links. It
does not use a shell; arguments are passed to the programs directly.

## Editing by Shaker

`install` and `uninstall` change the manifest. They must keep it as the user wrote it: comments, blank lines, key order and formatting of
every line that is not affected.

**Reading.** The file is parsed with `parseToml` from `std/text/toml/toml-parser`, and the resulting tree is [validated](#validation).
Additionally, a line scanner locates each dependency line. The scanner

- skips the contents of multi-line strings (`"""` and `'''`),
- recognizes table headers (`[name]` and `[[name]]`, optionally followed by a comment), and
- inside `[dependencies]` and `[dev-dependencies]` recognizes lines of the form `<bare key> = <value> [# comment]`, using a small
  lexer (basic strings with escapes, literal strings, braces and brackets) to find where the value ends and the comment begins.

Every dependency in the parsed tree must be found by the scanner in the matching section; if one is not, the manifest violates the
[format restriction](#dependencies) and is rejected.

**Writing.** The parsed tree is not serialized back. Instead, the original text is edited line by line:

- The value of a dependency is formatted from `TomlValue`s with `TomlSerializer.serializeValue`: a string for the short form, or
  `{ key = value, ... }` with the keys in the order `version`, `github`, `rev`, `path`.
- **Changing** a dependency replaces the value of its line and keeps the comment at the end of the line.
- **Adding** a dependency inserts `name = value` after the last dependency line of the section, or directly after the section header
  if the section is empty. If the section does not exist, a blank line, the header and the dependency line are appended to the end of the
  file.
- **Removing** a dependency deletes its line.
- Moving a dependency between `[dependencies]` and `[dev-dependencies]` is a removal followed by an addition.

**Verification.** The edited text is parsed and validated again, and the file is only written if the result contains exactly the
intended dependencies. This guards against bugs in the line editing.

`init` and the lock file have no user content to preserve; they are written with `TomlSerializer`.

## Validation

A manifest is rejected if any of the following holds. The error message names the file, the table and the key; for an unknown key it
suggests the known key with the smallest edit distance, if that distance is at most 2.

- It is not valid TOML.
- `[package]`, `package.name` or `package.version` is missing.
- A value has the wrong type.
- There is an unknown key at the top level, in `[package]` or in a dependency specification.
- `name` or a dependency name is not a valid [name](#names).
- `version` is not valid SemVer, or a constraint (`spice`, a dependency `version`) is not a valid [constraint](#version-constraints).
- `entry` violates the rules of [`[package]`](#package).
- A dependency specification has no source, more than one source, or `rev` without `github`.
- `github` is not `owner/repo` (letters, digits, `-`, `_` and `.` each), or `rev` contains characters other than letters, digits, `-`,
  `_`, `.` and `/`.
- `path` is empty or contains `\`.
- A name is in both `[dependencies]` and `[dev-dependencies]`.
- The [format restriction](#dependencies) is violated.

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

## Out of scope

The format leaves room for these, but this version does not specify them:

- **Workspaces**: multiple packages sharing one `spice.lock` and `spice_packages/` (`[workspace]` table).
- **Target-specific dependencies**, e.g. `[target.windows.dependencies]`.
- **Features and optional dependencies**: `optional = true` in the detailed form, plus a `[features]` table.
- **Renaming**: installing a registry package under another dependency name (a `package` key in the detailed form).
- **Import by package name**: `import "@json-parser";` resolving to the `entry` of the package. `entry` is specified now so that the
  compiler can add this later without a format change.
- **Scripts / tasks** (npm `scripts`). These can live under `[tool.<name>]` for now.
