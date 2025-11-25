# Khaos Settings Versioning Guide

## Overview
- The entire Khaos Settings solution (all NuGet-packable libraries and the CLI) follows **Semantic Versioning 2.0.0**.
- **Git tags** are the single source of truth for release numbers. No project file contains a hard-coded `<Version>`.
- **MinVer** reads the latest matching Git tag (`Khaos.Settings/vX.Y.Z`) and computes `Version`, `PackageVersion`, `AssemblyVersion`, `FileVersion`, and `InformationalVersion` at build time.
- Every packable project (`Khaos.Settings.*` libraries and `Khaos.Settings.Cli`) receives the **same version number** for a given commit, so a single tag describes the whole product.

## Semantic Versioning Rules
- **MAJOR** (`X.0.0`): Introduce breaking API or behavior changes (e.g., remove/rename a public type, change observable provider behavior, alter configuration contract in a non-backward-compatible way).
- **MINOR** (`1.Y.0`): Add backward-compatible functionality (e.g., new extension methods, optional parameters, additional metrics, or new configuration options that default off).
- **PATCH** (`1.2.Z`): Backward-compatible fixes/improvements (e.g., bug fixes, performance tweaks, documentation-only updates, internal refactors with no API change).

When deciding the next version, evaluate the highest level of change across the release. If any change is breaking, bump MAJOR even if there are also minor/patch fixes bundled.

## Tagging and Releasing
1. Ensure the working tree is clean and all tests/linters pass.
2. Decide the new SemVer (`MAJOR.MINOR.PATCH`) using the rules above.
3. Create and push a tag with the required prefix:
   ```bash
   git tag Khaos.Settings/v1.2.0
   git push origin Khaos.Settings/v1.2.0
   ```
4. Build and pack from the repo root so every project uses the MinVer-computed version:
   ```bash
   dotnet pack -c Release
   ```
5. Verify that all produced `.nupkg`/`.snupkg` files share the expected version (e.g., `Khaos.Settings.Core.1.2.0.nupkg`).
6. Publish to NuGet.org (or another feed) using `dotnet nuget push` or your preferred CI/CD workflow.

## Pre-release and Development Builds
- Commits after the last tag automatically receive pre-release versions such as `1.3.0-alpha.1`, `1.3.0-alpha.2`, etc., because `MinVerDefaultPreReleasePhase` is `alpha` and `MinVerAutoIncrement` is `minor`.
- Use these builds for local development, internal feeds, or preview drops.
- Only push pre-release packages externally when you intentionally want a preview/beta build—otherwise wait until you can tag the next stable version.

## Do's and Don'ts
**Do**
- Change the version **only** by creating/pushing a Git tag named `Khaos.Settings/vX.Y.Z`.
- Keep tags in sync with actual code changes; if you need a new release, create a new tag.
- Run `dotnet pack -c Release` (or CI equivalent) from a commit reachable from that tag so MinVer resolves the correct version.

**Don't**
- Manually edit `<Version>`, `<PackageVersion>`, `<AssemblyVersion>`, or `<FileVersion>` in any `.csproj`.
- Override MinVer properties in individual projects.
- Leave incorrect tags in the history. If you tag the wrong version, delete (`git tag -d ...`) and recreate/push the correct tag instead of hacking the build.

## Cheat Sheet
- **Breaking change** (removed public method, incompatible configuration behavior) → `git tag Khaos.Settings/v2.0.0`.
- **New feature** (new provider API, optional behavior, new CLI verb) → `git tag Khaos.Settings/v1.3.0`.
- **Bug fix** (null-reference fix, EF Core query optimization) → `git tag Khaos.Settings/v1.2.1`.

## Relation to Other Libraries
- Khaos Settings is one product within a broader ecosystem. Each repository/solution maintains its own independent SemVer/tag stream.
- Downstream bundles or meta-packages consume specific ranges of `Khaos.Settings` packages. When coordinating releases, treat this solution’s version as authoritative for anything built from this repo.
