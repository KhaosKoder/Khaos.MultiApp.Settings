<#!
.SYNOPSIS
  Runs tests collecting BRANCH coverage (coverlet.msbuild).
.DESCRIPTION
  Uses msbuild integration with /p:EnableBranchCoverage=true; output ./coverage-branch/coverage.cobertura.xml
#>
param(
  [switch]$OpenHtml
)
$ErrorActionPreference='Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$coverageDir = Join-Path $repoRoot 'TestResults/BranchCoverage'
if (Test-Path $coverageDir) { Remove-Item $coverageDir -Recurse -Force }
New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null

Write-Host "Running tests (branch coverage)..." -ForegroundColor Cyan

dotnet test `
  /p:CollectCoverage=true `
  /p:EnableBranchCoverage=true `
  /p:CoverletOutput="$coverageDir/" `
  /p:CoverletOutputFormat=cobertura `
  /p:IncludeTestAssembly=false `
  --configuration Debug
if (!$?) { throw "Tests failed" }

$coverageFile = Join-Path $coverageDir 'coverage.cobertura.xml'
if (!(Test-Path $coverageFile)) { throw "Coverage file not generated: $coverageFile" }

if (-not (Get-Command reportgenerator -ErrorAction SilentlyContinue)) { Write-Warning "reportgenerator not installed. Run: pwsh ./Setup/install-tools.ps1"; return }

reportgenerator -reports:"$coverageFile" -targetdir:"$coverageDir/report" -reporttypes:"Html;TextSummary" | Out-Null
$summary = Get-ChildItem "$coverageDir/report" -Filter '*ummary.txt' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($summary) { Get-Content $summary.FullName } else { Write-Warning "Summary text file not found." }
if ($OpenHtml) { Start-Process "$coverageDir/report/index.html" }
Write-Host "Done. Reports in $coverageDir/report" -ForegroundColor Green
