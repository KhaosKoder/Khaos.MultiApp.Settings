<#!
.SYNOPSIS
  Formats the solution using dotnet-format.
#>
param([switch]$Verify)

$ErrorActionPreference='Stop'
Write-Host "Formatting solution..." -ForegroundColor Cyan

$cmd = 'dotnet-format'
if ($Verify) { $cmd += ' --verify-no-changes' }
Invoke-Expression $cmd
