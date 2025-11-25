# Build, Test, and Publish Guide

Use these commands (or the helper scripts) from the repository root to build, test, collect coverage, and publish packages.

## Quick reference

| Task | Script | Equivalent command |
| --- | --- | --- |
| Restore & build | `./scripts/build.ps1 -Configuration Release` | `dotnet build Khaos.MultiApp.Settings.sln -c Release` |
| Run tests (coverage on by default) | `./scripts/test.ps1` | `dotnet test Khaos.MultiApp.Settings.sln -c Release /p:CollectCoverage=true` |
| Generate HTML coverage + open report | `./scripts/coverage.ps1 -OpenReport` | `dotnet test Khaos.MultiApp.Settings.sln -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=html,lcov,json /p:CoverletOutput=TestResults/Coverage/coverage` |
| Pack NuGet + tool packages | `./scripts/pack.ps1 -Configuration Release` | `dotnet pack Khaos.MultiApp.Settings.sln -c Release -o artifacts/packages` |
| Publish packages to NuGet.org | `./scripts/publish.ps1 -ApiKey <token>` | `dotnet nuget push artifacts/packages/*.nupkg -k <token> -s https://api.nuget.org/v3/index.json --skip-duplicate` |

> All scripts assume PowerShell 5.1+ and resolve paths relative to the `scripts` directory. Run them from anywhere by prefixing with `pwsh`/`powershell` if needed.

## Test coverage output

- Coverage is enabled automatically for `Khaos.Settings.Tests` via Coverlet.
- HTML, Cobertura, JSON, LCOV, and OpenCover reports are written to `TestResults/Coverage/` at the repository root.
- Open `TestResults/Coverage/index.htm` (or run `./scripts/coverage.ps1 -OpenReport`) to view the report in a browser.

## Release workflow (local)

1. `./scripts/build.ps1 -Configuration Release`
2. `./scripts/test.ps1`
3. `./scripts/coverage.ps1`
4. Tag the commit as described in `docs/versioning-guide.md`.
5. `./scripts/pack.ps1 -Configuration Release`
6. Inspect `artifacts/packages/*.nupkg` and `TestResults/Coverage`.
7. `./scripts/publish.ps1 -ApiKey <nuget-token>` (or use your CI system).

## Viewing sample apps

- Run `dotnet run --project Khaos.Settings.ConsoleSample` to smoke-test the console sample.
- Run `dotnet run --project Khaos.Settings.Sample` for the ASP.NET sample (uses the same configuration provider extensions).
