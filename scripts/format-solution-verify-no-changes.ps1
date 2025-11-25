$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'

Write-Host "[format] Verifying formatting for $solution" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet format --verify-no-changes --no-restore --verbosity minimal
}
finally {
    Pop-Location
}
