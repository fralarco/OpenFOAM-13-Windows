# OpenFOAM-13 native Windows shell launcher (PowerShell equivalent of the .cmd).
# Independent, clean-room implementation.
#
# Path precedence:
#   1. explicit -Of13Clone / -Of13Root parameter;
#   2. otherwise this script's own location -- it lives inside the clone
#      (<base>\OpenFOAM-13-Windows\scripts\windows\), so it is authoritative.
# An inherited OF13_CLONE/OF13_ROOT from another installation is reported and
# ignored, so a stale global variable cannot redirect this launcher to a
# different clone. Use -Of13Thirdparty / OF13_THIRDPARTY to relocate ThirdParty.
param(
    [string]$Msys2Root     = $(if ($env:MSYS2_ROOT) { $env:MSYS2_ROOT } else { 'C:\msys64' }),
    [string]$Of13Clone     = '',
    [string]$Of13Root      = '',
    [string]$Of13Thirdparty = $(if ($env:OF13_THIRDPARTY) { $env:OF13_THIRDPARTY } else { '' })
)
$scriptDir = $PSScriptRoot
$selfClone = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$selfBase  = Split-Path -Parent $selfClone

if (-not $Of13Clone) {
    if ($env:OF13_CLONE -and ((Resolve-Path $env:OF13_CLONE -ErrorAction SilentlyContinue).Path -ne $selfClone)) {
        Write-Host "NOTE: ignoring inherited OF13_CLONE=$env:OF13_CLONE"
        Write-Host "      this launcher belongs to $selfClone"
    }
    $Of13Clone = $selfClone
}
if (-not $Of13Root) {
    if ($env:OF13_ROOT -and ((Resolve-Path $env:OF13_ROOT -ErrorAction SilentlyContinue).Path -ne $selfBase)) {
        Write-Host "NOTE: ignoring inherited OF13_ROOT=$env:OF13_ROOT"
        Write-Host "      using $selfBase (the parent of this clone)"
    }
    $Of13Root = $selfBase
}
$bash   = Join-Path $Msys2Root 'usr\bin\bash.exe'
$mintty = Join-Path $Msys2Root 'usr\bin\mintty.exe'
if (-not (Test-Path $bash)) { Write-Error "bash.exe not found under $Msys2Root (set -Msys2Root)"; exit 1 }
if (-not (Test-Path (Join-Path $scriptDir 'env.sh'))) { Write-Error 'env.sh not found next to launcher'; exit 1 }
if (-not (Test-Path (Join-Path $scriptDir 'openfoam_shell.sh'))) { Write-Error 'openfoam_shell.sh not found next to launcher'; exit 1 }

$env:MSYSTEM = 'UCRT64'          # UCRT64, not MINGW64
$env:CHERE_INVOKING = '1'
$env:OF13_CLONE = $Of13Clone
$env:OF13_ROOT  = $Of13Root
if ($Of13Thirdparty) { $env:OF13_THIRDPARTY = $Of13Thirdparty }
$rc = ($scriptDir -replace '\\', '/') + '/openfoam_shell.sh'

if (Test-Path $mintty) {
    Start-Process $mintty -ArgumentList '-t', 'OpenFOAM-13-Windows', '/usr/bin/bash', '--rcfile', $rc, '-i'
} else {
    & $bash --rcfile $rc -i
}
