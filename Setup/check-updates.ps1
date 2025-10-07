<#!
.SYNOPSIS
  Checks for outdated NuGet packages.
#>
param()
$ErrorActionPreference='Stop'
Write-Host "Scanning for outdated packages..." -ForegroundColor Cyan

dotnet outdated --include-auto-references --fail-on-updates --ignore "coverlet.collector" || Write-Host "Outdated packages detected (see above)." -ForegroundColor Yellow
