param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,
    [string]$Source = 'https://api.nuget.org/v3/index.json',
    [string]$PackagesDirectory
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$packagesDir = if ($PackagesDirectory) {
    if ([System.IO.Path]::IsPathRooted($PackagesDirectory)) { $PackagesDirectory } else { Join-Path $repoRoot $PackagesDirectory }
} else {
    Join-Path $repoRoot 'artifacts\packages'
}

if (-not (Test-Path $packagesDir)) {
    throw "Packages directory '$packagesDir' does not exist. Run pack.ps1 first."
}

$packages = Get-ChildItem -Path $packagesDir -Filter '*.nupkg' | Where-Object { $_.Name -notmatch '\.symbols\.' }
if (-not $packages) {
    throw "No .nupkg files were found under $packagesDir."
}

Write-Host "[publish] Pushing packages to $Source" -ForegroundColor Cyan

foreach ($package in $packages) {
    Write-Host " - $($package.Name)" -ForegroundColor Gray
    dotnet nuget push $package.FullName --api-key $ApiKey --source $Source --skip-duplicate
}
