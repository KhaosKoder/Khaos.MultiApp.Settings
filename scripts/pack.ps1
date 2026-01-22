<#
.SYNOPSIS
    Creates NuGet packages for the Khaos.MultiApp.Settings solution.

.DESCRIPTION
    Builds and packs the Khaos.MultiApp.Settings projects into NuGet packages.
    The main package (KhaosCode.MultiApp.Settings) bundles multiple assemblies:
    - Khaos.Settings.Abstractions
    - Khaos.Settings.Core
    - Khaos.Settings.Data
    - Khaos.Settings.Encryption
    - Khaos.Settings.Metrics
    - Khaos.Settings.Provider

    A separate CLI tool package (KhaosCode.Settings.Cli) is also created.

.PARAMETER Configuration
    Build configuration. Default is 'Release'.

.PARAMETER NoBuild
    Skip building and pack existing binaries.

.PARAMETER OutputDirectory
    Custom output directory for packages. Default is 'artifacts/packages'.

.EXAMPLE
    .\Pack.ps1
    .\Pack.ps1 -Configuration Debug
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$NoBuild,

    [string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot 'artifacts\packages'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot $OutputDirectory
}

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Projects to pack (Provider bundles the settings assemblies, Cli is separate tool)
$projectsToPack = @(
    'Khaos.Settings.Provider\Khaos.Settings.Provider.csproj'
    'Khaos.Settings.Cli\Khaos.Settings.Cli.csproj'
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         PACK KHAOS.MULTIAPP.SETTINGS (Multi-DLL Package)       ║" -ForegroundColor Cyan
Write-Host "║  Configuration: $($Configuration.PadRight(46))║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  Provider package bundles:" -ForegroundColor White
Write-Host "    • Khaos.Settings.Abstractions" -ForegroundColor DarkGray
Write-Host "    • Khaos.Settings.Core" -ForegroundColor DarkGray
Write-Host "    • Khaos.Settings.Data" -ForegroundColor DarkGray
Write-Host "    • Khaos.Settings.Encryption" -ForegroundColor DarkGray
Write-Host "    • Khaos.Settings.Metrics" -ForegroundColor DarkGray
Write-Host "    • Khaos.Settings.Provider" -ForegroundColor DarkGray
Write-Host ""

Push-Location $repoRoot
try {
    foreach ($project in $projectsToPack) {
        $projectPath = Join-Path $repoRoot $project
        $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project)

        Write-Host "  Packing: $projectName" -ForegroundColor Yellow

        $packArgs = @(
            'pack'
            $projectPath
            '--configuration', $Configuration
            '--output', $OutputDirectory
            '--nologo'
        )

        if ($NoBuild) {
            $packArgs += '--no-build'
        }

        dotnet @packArgs

        if ($LASTEXITCODE -ne 0) {
            throw "dotnet pack failed for $projectName with exit code $LASTEXITCODE"
        }
    }

    Write-Host ""
    Write-Host "  ✓ Packages created in: $OutputDirectory" -ForegroundColor Green
    Write-Host ""
}
finally {
    Pop-Location
}
