@echo off
setlocal EnableExtensions
rem ==========================================================================
rem  OpenFOAM-13 native Windows launcher -- modern terminal (MSYS2 UCRT64).
rem  Preferred entry point: opens the OpenFOAM-13 environment in Windows
rem  Terminal (wt.exe) when available, otherwise falls back to the MinTTY
rem  launcher (OpenFOAM-13-Windows-Shell.cmd). Independent, clean-room
rem  implementation.
rem
rem  Configurable (override via environment; nothing needs editing here):
rem    MSYS2_ROOT   MSYS2 install root  (default C:\msys64)
rem    OF13_CLONE   OpenFOAM clone      (default: derived from this file)
rem    OF13_ROOT    base directory      (default: the clone's parent)
rem  No administrator rights required.
rem ==========================================================================

if not defined MSYS2_ROOT set "MSYS2_ROOT=C:\msys64"

rem --- this launcher's directory: scripts\windows\ ---
set "OF_SCRIPT_DIR=%~dp0"

rem --- Clone resolution. This launcher physically lives inside the clone
rem       <base>\OpenFOAM-13-Windows\scripts\windows\<this file>
rem     so its own path is authoritative: a stale global OF13_ROOT/OF13_CLONE
rem     left over from another installation must never silently redirect this
rem     launcher to a different clone. Inherited values that disagree are
rem     reported and ignored; use OF13_THIRDPARTY to relocate ThirdParty.
for %%I in ("%~dp0..\..") do set "OF_CLONE_DIR=%%~fI"
for %%I in ("%OF_CLONE_DIR%\..") do set "OF_BASE_DIR=%%~fI"

if defined OF13_CLONE for %%I in ("%OF13_CLONE%") do if /I not "%%~fI"=="%OF_CLONE_DIR%" (
  echo NOTE: ignoring inherited OF13_CLONE=%OF13_CLONE%
  echo       this launcher belongs to "%OF_CLONE_DIR%"
)
if defined OF13_ROOT for %%I in ("%OF13_ROOT%") do if /I not "%%~fI"=="%OF_BASE_DIR%" (
  echo NOTE: ignoring inherited OF13_ROOT=%OF13_ROOT%
  echo       using "%OF_BASE_DIR%" ^(the parent of this clone^)
)
set "OF13_CLONE=%OF_CLONE_DIR%"
set "OF13_ROOT=%OF_BASE_DIR%"

rem --- prerequisites ---
if not exist "%MSYS2_ROOT%\usr\bin\bash.exe" (
  echo ERROR: bash.exe not found under "%MSYS2_ROOT%".
  echo Install MSYS2 ^(https://www.msys2.org^) or set MSYS2_ROOT to its location.
  pause
  exit /b 1
)
if not exist "%OF_SCRIPT_DIR%openfoam_shell.sh" (
  echo ERROR: openfoam_shell.sh not found next to this launcher.
  pause
  exit /b 1
)
if not exist "%OF_SCRIPT_DIR%env.sh" (
  echo ERROR: env.sh not found next to this launcher.
  pause
  exit /b 1
)

rem --- UCRT64 toolchain (not MINGW64); CHERE_INVOKING keeps the start dir ---
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"

rem --- forward-slash path so bash --rcfile accepts it ---
set "OF_RC=%OF_SCRIPT_DIR:\=/%openfoam_shell.sh"

rem --- start directory: $OF13_ROOT\run (created if missing) ---
set "OF_RUN=%OF13_ROOT%\run"
if not exist "%OF_RUN%" mkdir "%OF_RUN%" >nul 2>&1
if not exist "%OF_RUN%" set "OF_RUN=%OF13_ROOT%"

rem --- detect Windows Terminal (wt.exe) ---
set "WT_EXE="
for %%W in (wt.exe) do if not defined WT_EXE if exist "%%~$PATH:W" set "WT_EXE=%%~$PATH:W"
if not defined WT_EXE if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe" set "WT_EXE=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"

if defined WT_EXE (
  rem --- modern: open the OpenFOAM shell inside Windows Terminal ---
  "%WT_EXE%" new-tab --title "OF13 Windows" --startingDirectory "%OF_RUN%" ^
    "%MSYS2_ROOT%\usr\bin\bash.exe" --rcfile "%OF_RC%" -i
) else (
  echo Windows Terminal ^(wt.exe^) not found -- falling back to the MinTTY launcher.
  call "%OF_SCRIPT_DIR%OpenFOAM-13-Windows-Shell.cmd"
)

endlocal
