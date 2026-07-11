@echo off
setlocal EnableExtensions
rem ==========================================================================
rem  OpenFOAM-13 native Windows shell launcher -- MinTTY fallback
rem  (MSYS2 UCRT64 / MinGW-w64). For the modern experience use
rem  OpenFOAM-13-Windows-Terminal.cmd (Windows Terminal); this launcher is the
rem  fallback and sources the same openfoam_shell.sh -- no duplicated env logic.
rem  Independent, clean-room implementation.
rem
rem  Configurable (examples -- override via environment or edit here):
rem    MSYS2_ROOT   MSYS2 install root      (default C:\msys64)
rem    OF13_ROOT    OpenFOAM base directory (default C:\OF13WinNormal)
rem  No administrator rights required.
rem ==========================================================================

if not defined MSYS2_ROOT set "MSYS2_ROOT=C:\msys64"
if not defined OF13_ROOT  set "OF13_ROOT=C:\OF13WinNormal"

rem --- this launcher's directory: scripts\windows\ ---
set "OF_SCRIPT_DIR=%~dp0"

rem --- prerequisites ---
if not exist "%MSYS2_ROOT%\usr\bin\bash.exe" (
  echo ERROR: bash.exe not found under "%MSYS2_ROOT%".
  echo Install MSYS2 ^(https://www.msys2.org^) or set MSYS2_ROOT to its location.
  pause
  exit /b 1
)
if not exist "%OF_SCRIPT_DIR%env.sh" (
  echo ERROR: env.sh not found next to this launcher.
  pause
  exit /b 1
)
if not exist "%OF_SCRIPT_DIR%openfoam_shell.sh" (
  echo ERROR: openfoam_shell.sh not found next to this launcher.
  pause
  exit /b 1
)

rem --- UCRT64 toolchain (not MINGW64) ---
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"

rem --- forward-slash path so bash --rcfile accepts it ---
set "OF_RC=%OF_SCRIPT_DIR:\=/%openfoam_shell.sh"

rem --- launch: prefer MinTTY, otherwise a plain bash console ---
if exist "%MSYS2_ROOT%\usr\bin\mintty.exe" (
  start "" "%MSYS2_ROOT%\usr\bin\mintty.exe" -t "OpenFOAM-13-Windows" /usr/bin/bash --rcfile "%OF_RC%" -i
) else (
  "%MSYS2_ROOT%\usr\bin\bash.exe" --rcfile "%OF_RC%" -i
)

endlocal
