# OpenFOAM-13 native Windows shell launcher (PowerShell equivalent of the .cmd).
# Independent, clean-room implementation.
#
# The clone and its base directory are derived from this script's own location
# (<base>\OpenFOAM-13-Windows\scripts\windows\), so the repository runs from
# wherever it was cloned -- nothing needs editing. Override with -Of13Clone /
# -Of13Root, or the matching environment variables.
param(
    [string]$Msys2Root = $(if ($env:MSYS2_ROOT) { $env:MSYS2_ROOT } else { 'C:\msys64' }),
    [string]$Of13Clone = $(if ($env:OF13_CLONE) { $env:OF13_CLONE }
                           else { (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }),
    [string]$Of13Root  = $(if ($env:OF13_ROOT)  { $env:OF13_ROOT }
                           else { Split-Path -Parent (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path })
)
$scriptDir = $PSScriptRoot
$bash   = Join-Path $Msys2Root 'usr\bin\bash.exe'
$mintty = Join-Path $Msys2Root 'usr\bin\mintty.exe'
if (-not (Test-Path $bash)) { Write-Error "bash.exe not found under $Msys2Root (set -Msys2Root)"; exit 1 }
if (-not (Test-Path (Join-Path $scriptDir 'env.sh'))) { Write-Error 'env.sh not found next to launcher'; exit 1 }
if (-not (Test-Path (Join-Path $scriptDir 'openfoam_shell.sh'))) { Write-Error 'openfoam_shell.sh not found next to launcher'; exit 1 }

$env:MSYSTEM = 'UCRT64'          # UCRT64, not MINGW64
$env:CHERE_INVOKING = '1'
$env:OF13_CLONE = $Of13Clone
$env:OF13_ROOT  = $Of13Root
$rc = ($scriptDir -replace '\\', '/') + '/openfoam_shell.sh'

if (Test-Path $mintty) {
    Start-Process $mintty -ArgumentList '-t', 'OpenFOAM-13-Windows', '/usr/bin/bash', '--rcfile', $rc, '-i'
} else {
    & $bash --rcfile $rc -i
}
