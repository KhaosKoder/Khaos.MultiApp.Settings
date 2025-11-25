param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'

Write-Host "[build] Restoring and building $solution ($Configuration)" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet restore $solution
    dotnet build $solution -c $Configuration --no-restore
}
finally {
    Pop-Location
}
