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

if (-not (Test-Path $coverageDir)) {
    New-Item -ItemType Directory -Path $coverageDir -Force | Out-Null
}

Write-Host "[coverage] Collecting coverage to $coverageDir" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet test $solution -c $Configuration "/p:CollectCoverage=true" "/p:CoverletOutput=$coverletOutput"
}
finally {
    Pop-Location
}

if ($OpenReport) {
    $htmlReport = Get-ChildItem -Path $coverageDir -Filter '*.htm*' -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -ne $htmlReport) {
        Write-Host "[coverage] Opening $($htmlReport.FullName)" -ForegroundColor Green
        Start-Process $htmlReport.FullName
    }
    else {
        Write-Warning "No HTML report found under $coverageDir"
    }
}
