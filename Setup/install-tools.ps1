<#!
.SYNOPSIS
  Installs global dotnet tools required by the project.
.DESCRIPTION
  Installs:
    - reportgenerator (coverage HTML + text reports)
    - dotnet-format (code style / formatting)
    - dotnet-outdated-tool (dependency audit)
  Safe to re-run (idempotent).
#>
param()

Write-Host "Installing / Updating required global tools..." -ForegroundColor Cyan

$ErrorActionPreference = 'Stop'

function Ensure-Tool {
    param([string]$Name,[string]$Command)
    if (-not (dotnet tool list -g | Select-String -SimpleMatch $Name)) {
        Write-Host "Installing $Name" -ForegroundColor Green
        dotnet tool install -g $Command | Out-Null
    } else {
        Write-Host "Updating $Name" -ForegroundColor Yellow
        dotnet tool update -g $Command | Out-Null
    }
}

Ensure-Tool -Name 'reportgenerator' -Command 'dotnet-reportgenerator-globaltool'
Ensure-Tool -Name 'dotnet-format' -Command 'dotnet-format'
Ensure-Tool -Name 'dotnet-outdated' -Command 'dotnet-outdated-tool'

Write-Host "Tools ready." -ForegroundColor Cyan
