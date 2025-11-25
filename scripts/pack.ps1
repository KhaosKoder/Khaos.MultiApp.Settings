param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'
$packagesDir = if ($OutputDirectory) {
    if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
        $OutputDirectory
    }
    else {
        Join-Path $repoRoot $OutputDirectory
    }
}
else {
    Join-Path $repoRoot 'artifacts\packages'
}

if (-not (Test-Path $packagesDir)) {
    New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null
}

Write-Host "[pack] Packing solution to $packagesDir" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet pack $solution -c $Configuration -o $packagesDir
}
finally {
    Pop-Location
}
