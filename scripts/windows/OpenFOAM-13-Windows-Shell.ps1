# OpenFOAM-13 native Windows shell launcher (PowerShell equivalent of the .cmd).
# Independent, clean-room implementation.
# Configurable (examples): -Msys2Root C:\msys64  -Of13Root C:\OF13WinNormal
param(
    [string]$Msys2Root = $(if ($env:MSYS2_ROOT) { $env:MSYS2_ROOT } else { 'C:\msys64' }),
    [string]$Of13Root  = $(if ($env:OF13_ROOT)  { $env:OF13_ROOT }  else { 'C:\OF13WinNormal' })
)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bash   = Join-Path $Msys2Root 'usr\bin\bash.exe'
$mintty = Join-Path $Msys2Root 'usr\bin\mintty.exe'
if (-not (Test-Path $bash)) { Write-Error "bash.exe not found under $Msys2Root (set -Msys2Root)"; exit 1 }
if (-not (Test-Path (Join-Path $scriptDir 'env.sh'))) { Write-Error 'env.sh not found next to launcher'; exit 1 }

$env:MSYSTEM = 'UCRT64'          # UCRT64, not MINGW64
$env:CHERE_INVOKING = '1'
$env:OF13_ROOT = $Of13Root
$rc = ($scriptDir -replace '\\', '/') + '/openfoam_shell.sh'

if (Test-Path $mintty) {
    Start-Process $mintty -ArgumentList '-t', 'OpenFOAM-13-Windows', '/usr/bin/bash', '--rcfile', $rc, '-i'
} else {
    & $bash --rcfile $rc -i
}
