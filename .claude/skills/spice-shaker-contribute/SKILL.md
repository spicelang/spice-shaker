---
name: spice-shaker-contribute
description: Guidelines for contributing changes to the Spice Shaker GitHub repository (spicelang/spice-shaker) — branch naming conventions (enforced by a hook), commit message format, PR workflow, no-push-to-main rule, and quality gates. Use when preparing a branch for review, writing a commit, opening a PR, or checking that a contribution is ready to merge.
---

# Contribute to Spice Shaker

This skill covers the full contribution workflow: naming branches, writing commits, opening a PR, and satisfying the
quality gates before merge. It follows the conventions of the main [Spice repository](https://github.com/spicelang/spice).

## Branch naming

All work happens on a dedicated branch, never directly on `main`. Never use auto-generated or `claude/...` branch names.

| Prefix | Use for |
|--------|---------|
| `feature/<slug>` | New commands, options or manifest features |
| `fix/<slug>` (or `bug/<slug>`) | Bug fixes in resolution, installation, manifest editing or the CLI |
| `chore/<slug>` | Dependency bumps (`src/spice.toml` + `src/spice.lock`), build scripts, repo maintenance |
| `ci/<slug>` | GitHub Actions workflows |
| `test/<slug>` | New or updated unit tests or the test project |
| `docs/<slug>` | README, `media/manifest-spec.md` clarifications and other documentation-only changes |
| `security/<slug>` | Security-sensitive fixes (prefer non-public disclosure first — see `SECURITY.md`) |

Rules:
- Use lowercase `kebab-case` slugs (`fix/lockfile-path-entries`, not `Fix/LockfilePathEntries`).
- Keep slugs short but descriptive; the squash-commit headline is taken from the PR title.
- Tie the slug to the issue number when one exists: `fix/42-lockfile-path-entries`.
- If the session starts on a pre-created branch, rename it with `git branch -m <type>/<slug>` before the first push.
- This is enforced by the `.claude/hooks/check-branch-name.py` hook, which blocks git commands that create, rename or
  push a branch with a non-conforming name.

```sh
git checkout main
git pull origin main
git checkout -b fix/lockfile-path-entries
```

## Commit message format

Use a short, descriptive headline — no type prefix or scope annotation:

```
<Short descriptive headline>

[optional body — explain WHY, not what]

[optional footer — Fixes #<issue>, Refs #<issue>, Co-authored-by: …]
```

Examples from this repository's history:

```
Install registry packages that live in a subdirectory of their repository

Remove the JSON wrapper and decode registry answers into typed structs

Replace spice.json with spice.toml and rewrite Spice Shaker on top of the std
```

Rules:
- Headline ≤ 72 characters, imperative mood ("Add", "Fix", not "Added", "Fixes").
- No trailing period on the headline.
- Blank line between headline and body.
- Reference issues in the footer with `Fixes #N` (auto-closes) or `Refs #N`.

## No-push-to-main rule

`main` only receives changes through pull requests. Never `git push origin main`; push the branch
(`git push -u origin <type>/<slug>`) and open a PR. If you accidentally committed to `main` locally, move the work to a
branch before pushing:

```sh
git checkout -b <type>/<slug>          # create branch at current HEAD
git checkout main
git reset --hard origin/main           # restore main to remote state
git checkout <type>/<slug>             # continue on the branch
```

## Repository rules

- `media/manifest-spec.md` is the specification. A change to the manifest or lock format, resolution or command
  behavior updates the spec in the same PR, and is mirrored in Spice Rack if the registry reads that part
  (see `spice-shaker-architecture`).
- `src/spice.lock` is generated: change dependencies in `src/spice.toml` and regenerate the lock with the built
  Shaker, never edit it by hand. Keep `bootstrap.py` able to install what the lock file lists.
- The version lives in two places: `[package] version` in `src/spice.toml` and `SHAKER_VERSION` in `src/driver.spice`.
  Bump both together.

## Pre-PR quality gate

Run the same checks as CI (details in the `spice-shaker-build-test` skill):

```sh
python3 bootstrap.py                                           # 1. dependencies
spice test src/tests.spice                                     # 2. unit tests
python3 build.py && ./build/spice-shaker --help                # 3. build + smoke test
(cd src && rm -rf spice_packages && ../build/spice-shaker sync && git status --short .)   # 4. self-install, no lock diff
```

If the environment cannot run a check, say so explicitly in the PR description. Do not silently skip checks.

## Opening the pull request

Target branch: **`main`**. The PR title uses the same style as commit headlines: short, descriptive, imperative mood,
no type prefix.

PR description template:

```markdown
## What changed
<!-- 1-3 bullets describing the change -->

## Why
<!-- Motivation, linked issue, or design rationale -->

## How it was validated
<!-- Exact commands run + outcome, e.g.: -->
- `spice test src/tests.spice` — all pass
- `python3 build.py && ./build/spice-shaker --help` — builds, help printed
- Ran `spice-shaker install <pkg>` in a scratch project — manifest and lock as expected

## Follow-up / known limitations
<!-- Anything deferred, or limitations the reviewer should know -->

Fixes #<issue>
```

Additional rules:
- Keep PRs focused — one logical change per PR.
- Add or extend `#[test]` functions next to the changed code.
- Update the README usage section if commands, options or environment variables change.
- Do not force-push a branch that already has a PR open (use a new commit instead) unless a reviewer explicitly asks
  for a rebase.

## Merge strategy

PRs are merged by a maintainer using **squash and merge** — every PR lands as a single commit on `main` with the PR
title as headline. Write clean incremental commits on your branch so the reviewer can follow the progression.

## Checklist

- [ ] Branch named `<type>/<slug>` with an allowed type and a descriptive slug
- [ ] All commits have a short descriptive headline (no type prefix)
- [ ] Unit tests pass (`spice test src/tests.spice`)
- [ ] Build and smoke test pass (`python3 build.py`, `--help`)
- [ ] Self-install reproduces `src/spice.lock`
- [ ] `media/manifest-spec.md` and README updated if behavior or formats changed
- [ ] Spice Rack follow-up noted if the registry reads the changed format
- [ ] Issue linked in footer (`Fixes #N` or `Refs #N`)
- [ ] PR targets `main`
