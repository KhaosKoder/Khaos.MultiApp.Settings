param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectsToPack = @(
    'Khaos.Settings.Provider/Khaos.Settings.Provider.csproj',
    'Khaos.Settings.Cli/Khaos.Settings.Cli.csproj'
)
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

Write-Host "[pack] Packing projects to $packagesDir" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    foreach ($project in $projectsToPack) {
        $projectPath = Join-Path $repoRoot $project
        Write-Host "[pack] dotnet pack $project" -ForegroundColor DarkCyan
        dotnet pack $projectPath -c $Configuration -o $packagesDir
    }
}
finally {
    Pop-Location
}
