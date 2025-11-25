param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$WithoutCoverage
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'
$testResults = Join-Path $repoRoot 'TestResults'

if (-not (Test-Path $testResults)) {
    New-Item -ItemType Directory -Path $testResults | Out-Null
}

$collectCoverage = if ($WithoutCoverage) { 'false' } else { 'true' }

Write-Host "[test] Running unit tests ($Configuration, coverage=$collectCoverage)" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet test $solution -c $Configuration "/p:CollectCoverage=$collectCoverage"
}
finally {
    Pop-Location
}
