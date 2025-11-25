param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$solution = Join-Path $repoRoot 'Khaos.MultiApp.Settings.sln'

Write-Host "[clean] Cleaning solution ($Configuration)" -ForegroundColor Cyan

Push-Location $repoRoot
try {
    dotnet clean $solution -c $Configuration
}
finally {
    Pop-Location
}

Write-Host "[clean] Removing bin/obj folders" -ForegroundColor Cyan

$patterns = @('bin', 'obj')
foreach ($pattern in $patterns) {
    Get-ChildItem -Path $repoRoot -Recurse -Directory -Filter $pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git' } |
        ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Warning "Failed to remove $($_.FullName): $_"
            }
        }
}

$testResultsRoot = Join-Path $repoRoot 'TestResults'
if (Test-Path $testResultsRoot) {
    Write-Host "[clean] Clearing TestResults" -ForegroundColor Cyan
    Get-ChildItem -Path $testResultsRoot -Recurse -Force -File | Remove-Item -Force
    Get-ChildItem -Path $testResultsRoot -Recurse -Force -Directory | Sort-Object FullName -Descending | Remove-Item -Recurse -Force
}
