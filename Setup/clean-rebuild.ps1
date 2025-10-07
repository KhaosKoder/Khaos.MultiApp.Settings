<#!
.SYNOPSIS
  Cleans and rebuilds the entire solution.
#>
param(
  [string]$Configuration = 'Debug'
)
$ErrorActionPreference='Stop'
Write-Host "Cleaning..." -ForegroundColor Cyan
dotnet clean
Write-Host "Restoring..." -ForegroundColor Cyan
dotnet restore
Write-Host "Building ($Configuration)..." -ForegroundColor Cyan
dotnet build -c $Configuration --no-restore
