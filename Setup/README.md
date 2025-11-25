# Setup Scripts

PowerShell helper scripts to simplify common tasks.

> Run from repository root with: `pwsh ./Setup/<script>.ps1` (PowerShell 7+) or `powershell -ExecutionPolicy Bypass -File .\Setup\<script>.ps1` on Windows.

## Scripts

### install-tools.ps1
Installs/updates required global tools:
- reportgenerator (coverage reports)
- dotnet-format (code style)
- dotnet-outdated (dependency audit)

Re-run anytime; idempotent.

### test-with-line-coverage.ps1
Runs the full test suite collecting LINE coverage only.
Output directory: `./TestResults/LineCoverage/`
Produces:
- `coverage.cobertura.xml`
- `coverage.opencover.xml`
- `report/index.html` (HTML report)
- `report/Summary.txt` (text summary)
Open HTML automatically by adding `-OpenHtml` switch.

### test-with-branch-coverage.ps1
Same as above but enables branch coverage metrics (`/p:BranchCoverage=true`).
Output directory: `./TestResults/BranchCoverage/`
Artifacts analogous to line coverage script.
Use `-OpenHtml` to auto-open report.

### format-code.ps1
Formats the entire solution with `dotnet-format`.
Optional `-Verify` switch fails if any files would change (CI enforcement mode).

### check-updates.ps1
Audits NuGet dependencies using `dotnet outdated`.
Non-zero exit if updates found (except coverlet collector ignored).

### clean-rebuild.ps1
Performs `dotnet clean`, `dotnet restore`, then `dotnet build`.
Parameter: `-Configuration Release` (default Debug).

### run-sample-console.ps1
Runs the console sample project.
Parameters:
- `-ConnectionString <value>` (required)
- `-ApplicationId <id>` (optional; default demo-app)
Sets `KHAOS_SETTINGS_CS` env var before launching.

## Viewing Coverage
1. Run one of the coverage scripts.
2. Navigate to the output folder (`TestResults/LineCoverage/report` or `TestResults/BranchCoverage/report`).
3. Open `index.html` in a browser for detailed drill-down.
4. For quick terminal view, read `Summary.txt`. Branch percentage appears when using branch script.

## Typical Workflow Examples
```powershell
# First time
pwsh ./Setup/install-tools.ps1

# Build and test with branch coverage, open report
pwsh ./Setup/test-with-branch-coverage.ps1 -OpenHtml

# Line coverage only (faster)
pwsh ./Setup/test-with-line-coverage.ps1

# Format and verify no diffs (CI mode)
pwsh ./Setup/format-code.ps1 -Verify

# Check for dependency updates
pwsh ./Setup/check-updates.ps1

# Run console sample
pwsh ./Setup/run-sample-console.ps1 -ConnectionString "Server=.;Database=DemoSettings;Trusted_Connection=True;TrustServerCertificate=True" -ApplicationId demo
```

## Notes
- Ensure global tools path is in your PATH (dotnet usually configures automatically).
- Coverage output folders are deleted and recreated each run.
- Branch coverage requires more instrumentation and may run slightly slower.

## Future Additions (Placeholder)
- SQL integration test harness script
- Packaging / publishing script
- GitHub Actions bootstrap script

---
Enjoy.
