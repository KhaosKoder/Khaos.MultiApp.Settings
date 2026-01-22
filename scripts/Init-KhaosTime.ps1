[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$submoduleRelPath = 'ext/Khaos.Time'
$submoduleFullPath = Join-Path $repoRoot $submoduleRelPath

Write-Host "[khaos-time] Initializing submodule at $submoduleRelPath" -ForegroundColor Cyan

# Initialize / update only the required submodule so local builds can reference the project source.
$gitArgs = @('submodule', 'update', '--init', '--recursive', $submoduleRelPath)
$process = Start-Process -FilePath 'git' -ArgumentList $gitArgs -WorkingDirectory $repoRoot -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "git submodule update failed with exit code $($process.ExitCode)."
}

if (-not (Test-Path $submoduleFullPath)) {
    throw "Expected submodule path '$submoduleFullPath' does not exist after initialization."
}

Write-Host "[khaos-time] Submodule ready at $submoduleFullPath" -ForegroundColor Green
