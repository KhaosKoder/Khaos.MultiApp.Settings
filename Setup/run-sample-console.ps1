<#!
.SYNOPSIS
  Runs the console sample with provided connection string and optional app id.
#>
param(
  [Parameter(Mandatory=$true)][string]$ConnectionString,
  [string]$ApplicationId = 'demo-app'
)
$ErrorActionPreference='Stop'
$env:KHAOS_SETTINGS_CS = $ConnectionString
Push-Location Khaos.Settings.ConsoleSample
try {
  Write-Host "Running console sample... (Ctrl+C to exit)" -ForegroundColor Cyan
  dotnet run --no-build -- --application $ApplicationId --connection $ConnectionString
}
finally { Pop-Location }
