param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$OpenReport
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'
$coverageRoot = Join-Path $repoRoot 'TestResults'
$coverageDir = Join-Path $coverageRoot 'Coverage'
$coverletOutput = Join-Path $coverageDir 'coverage'
$reportDir = Join-Path $coverageDir 'report'

function Invoke-ReportGenerator {
    param(
        [string]$CoverageFile,
        [string]$OutputDir
    )

    if (-not (Test-Path $CoverageFile)) {
        Write-Warning "Coverage file '$CoverageFile' was not produced."
        return
    }

    if (-not (Get-Command reportgenerator -ErrorAction SilentlyContinue)) {
        Write-Warning "reportgenerator not found. Install it via 'pwsh ./Setup/install-tools.ps1' or 'dotnet tool install -g dotnet-reportgenerator-globaltool'."
        return
    }

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    reportgenerator -reports:"$CoverageFile" -targetdir:"$OutputDir" -reporttypes:"Html;TextSummary" | Out-Null
    Write-Host "[coverage] HTML report generated at $OutputDir" -ForegroundColor Green
}

if (-not (Test-Path $coverageDir)) {
    New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
}

Write-Host "[coverage] Collecting coverage to $coverageDir" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet test $solution -c $Configuration "/p:CollectCoverage=true" "/p:CoverletOutput=$coverletOutput" "/p:CoverletOutputFormat=cobertura"
}
finally {
    Pop-Location
}

$coberturaFile = "$coverletOutput.cobertura.xml"
Invoke-ReportGenerator -CoverageFile $coberturaFile -OutputDir $reportDir

if ($OpenReport) {
    $htmlReport = Get-ChildItem -Path $reportDir -Filter 'index.htm*' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $htmlReport) {
        Write-Host "[coverage] Opening $($htmlReport.FullName)" -ForegroundColor Green
        Start-Process $htmlReport.FullName
    }
    else {
        Write-Warning "No HTML report found under $reportDir"
    }
}
