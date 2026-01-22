[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$submoduleRelPath = 'ext/Khaos.Time'
$submoduleFullPath = Join-Path $repoRoot $submoduleRelPath
$submoduleUrl = 'https://github.com/KhaosKoder/Khaos.Time.git'

if (Test-Path $submoduleFullPath) {
    Write-Host "[khaos-time] Submodule folder already exists at $submoduleRelPath" -ForegroundColor Yellow
}

# Detect whether git already knows about this submodule by querying config
$gitConfigArgs = @('config', '--file', '.gitmodules', '--get-regexp', '^submodule\..*\.path$')
$knownSubmodules = try {
    (git @gitConfigArgs 2>$null) | ForEach-Object {
        ($_ -split '\s+', 2)[1]
    }
}
catch {
    @()
}

if ($knownSubmodules -contains $submoduleRelPath) {
    Write-Host "[khaos-time] Submodule already registered in .gitmodules" -ForegroundColor Cyan
} else {
    Write-Host "[khaos-time] Adding submodule from $submoduleUrl to $submoduleRelPath" -ForegroundColor Cyan
    $addArgs = @('submodule', 'add', $submoduleUrl, $submoduleRelPath)
    $process = Start-Process -FilePath 'git' -ArgumentList $addArgs -WorkingDirectory $repoRoot -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "git submodule add failed with exit code $($process.ExitCode)."
    }
}

Write-Host "[khaos-time] Initializing and updating $submoduleRelPath" -ForegroundColor Cyan
$updateArgs = @('submodule', 'update', '--init', '--recursive', $submoduleRelPath)
$updateProcess = Start-Process -FilePath 'git' -ArgumentList $updateArgs -WorkingDirectory $repoRoot -NoNewWindow -Wait -PassThru
if ($updateProcess.ExitCode -ne 0) {
    throw "git submodule update failed with exit code $($updateProcess.ExitCode)."
}

if (-not (Test-Path $submoduleFullPath)) {
    throw "Expected submodule path '$submoduleFullPath' does not exist after initialization."
}

Write-Host "[khaos-time] Submodule ready at $submoduleFullPath" -ForegroundColor Green
Write-Host "[khaos-time] Remember to commit .gitmodules and the $submoduleRelPath entry after running this script." -ForegroundColor Yellow
