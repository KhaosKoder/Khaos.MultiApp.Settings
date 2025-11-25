param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'

Write-Host "[format] Running dotnet format on $solution" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet format --no-restore --verbosity minimal
}
finally {
    Pop-Location
}
