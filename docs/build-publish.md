# Build, Test, and Publish Guide

Use these commands (or the helper scripts) from the repository root to build, test, collect coverage, and publish packages.

## Quick reference

| Task | Script (run from `scripts/` folder) | Equivalent command |
| --- | --- | --- |
| Restore & build | `powershell -File build.ps1` | `dotnet build Khaos.MultiApp.Settings.sln -c Release` |
| Run tests (coverage on by default) | `powershell -File test.ps1` | `dotnet test Khaos.MultiApp.Settings.sln -c Release /p:CollectCoverage=true` |
| Generate HTML coverage + open report | `powershell -File coverage.ps1` | `dotnet test Khaos.MultiApp.Settings.sln -c Release /p:CollectCoverage=true /p:CoverletOutput=TestResults/Coverage/coverage` |
| Clean build outputs + reports | `powershell -File clean.ps1` | `dotnet clean Khaos.MultiApp.Settings.sln -c Release` (script also deletes `bin/`, `obj/`, and `TestResults` contents) |
| Format solution source | `powershell -File format-solution.ps1` | `dotnet format --no-restore --verbosity minimal` |
| Verify formatting (no changes) | `powershell -File format-solution-verify-no-changes.ps1` | `dotnet format --verify-no-changes --no-restore --verbosity minimal` |
| Pack NuGet + tool packages | `powershell -File pack.ps1` | `dotnet pack Khaos.MultiApp.Settings.sln -c Release -o artifacts/packages` |
| Publish packages to NuGet.org | `powershell -File publish.ps1` | `dotnet nuget push artifacts/packages/*.nupkg -k <token> -s https://api.nuget.org/v3/index.json --skip-duplicate` |

> All scripts assume PowerShell 5.1+ and must be executed from the `scripts` directory with no parameters, e.g., `cd scripts; powershell -File build.ps1`.

### Manage the Khaos.Time submodule (local dev only)

`UseLocalKhaosTime` defaults to `true`, so you need the dependency source when building locally. Use these scripts (always run from `scripts/`):

1. **First-time setup (adds the submodule to your clone):**
	```powershell
	cd scripts
	powershell -File add-khaos-time.ps1
	```
	This runs `git submodule add` (if needed) and initializes the checkout. Commit the resulting `.gitmodules` + submodule entry if you’re the first to add it.

2. **Subsequent syncs or fresh clones (submodule already tracked):**
	```powershell
	cd scripts
	powershell -File init-khaos-time.ps1
	```
	This executes `git submodule update --init --recursive ext/Khaos.Time` so you can step into and edit the `Khaos.Time` project during local development.

CI and release builds override `UseLocalKhaosTime=false`, so they do not require the submodule.

## Test coverage output

- Coverage is enabled automatically for `Khaos.Settings.Tests` via Coverlet.
- `./scripts/coverage.ps1` forces Cobertura output and then runs [ReportGenerator](https://github.com/danielpalme/ReportGenerator) to create `TestResults/Coverage/report/index.html` plus a text summary. Install the tool once with `pwsh ./Setup/install-tools.ps1` (or `dotnet tool install -g dotnet-reportgenerator-globaltool`).
- The raw `coverage.cobertura.xml` and `coverage.json` files also live under `TestResults/Coverage/` if you need to feed them into another system.

## Release workflow (local)

1. `./scripts/build.ps1 -Configuration Release`
2. `./scripts/test.ps1`
3. `./scripts/coverage.ps1`
4. Tag the commit as described in `docs/versioning-guide.md`.
5. `./scripts/pack.ps1 -Configuration Release`
6. Inspect `artifacts/packages/*.nupkg` and `TestResults/Coverage`.
7. `./scripts/publish.ps1 -ApiKey <nuget-token>` (or use your CI system).
8. Optionally run `./scripts/clean.ps1` and `./scripts/format-solution-verify-no-changes.ps1` before pushing to confirm the repo stays tidy.

## Viewing sample apps

- Run `dotnet run --project Khaos.Settings.ConsoleSample` to smoke-test the console sample.
- Run `dotnet run --project Khaos.Settings.Sample` for the ASP.NET sample (uses the same configuration provider extensions).
