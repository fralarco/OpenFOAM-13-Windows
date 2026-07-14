# OpenFOAM-13 — Native Windows (MinGW-w64)

> **Unofficial native Windows port / modified fork of OpenFOAM Foundation OpenFOAM-13.
> Independent project — not affiliated with or endorsed by the OpenFOAM Foundation or CFD Direct.**

A native Windows build of [OpenFOAM Foundation **OpenFOAM-13**](https://openfoam.org),
built with **MSYS2 UCRT64 / MinGW-w64**. **No WSL, no Cygwin runtime.**

## Upstream & provenance

This repository is a **Windows-native port / modified fork** of OpenFOAM Foundation
OpenFOAM-13.

Upstream: <https://github.com/OpenFOAM/OpenFOAM-13>

Most files remain **unchanged** from upstream OpenFOAM-13. Windows-specific changes are
layered on top to support native Windows builds with MSYS2 UCRT64 / MinGW-w64, MS-MPI, and
Windows-specific runtime/linking behaviour. All changes are minimal and guarded
(`ifeq ($(WM_ARCH),mingw_w64)` / `#if defined(_WIN32)`), so Linux behaviour is preserved and
the toolbox compiles and runs from a **normal NTFS directory** — no case-sensitive attribute
and no `subst` drive required.

This project is independent and is **not affiliated with or endorsed by the OpenFOAM
Foundation or CFD Direct**.

### Companion ThirdParty repository

Optional third-party components (Scotch) live in a **separate sibling repository**,
[`ThirdParty-13-Windows`](https://github.com/fralarco/ThirdParty-13-Windows) — a Windows
companion to OpenFOAM Foundation
[ThirdParty-13](https://github.com/OpenFOAM/ThirdParty-13). It is **not** bundled inside
this repository; clone it **next to** this one (see [Quick build](#quick-build)). MS-MPI is
an external Microsoft dependency and is not vendored in either repository.

## What works

- Full build: solvers 5/5, modules 45/45, legacy 15/15, utilities 133/137,
  src libraries 104/114 (105/114 with Scotch). The unbuilt items are
  external/Linux-only (real metis/ptscotch/zoltan, ParaView/TECIO readers).
- Serial: `blockMesh → checkMesh → foamRun` (e.g. `incompressibleFluid/pitzDaily`).
- Decomposition: `decomposePar` with the **scotch** method (Scotch built natively).
- Parallel: `mpiexec -n 2 foamRun -parallel` with **MS-MPI**.

## Requirements

- **Windows 10/11 (x64)** — the Universal CRT ships with the OS.
- **[MSYS2](https://www.msys2.org/)** with the UCRT64 toolchain:
  `pacman -S mingw-w64-ucrt-x86_64-gcc make flex bison`
- **Git**
- Optional, for parallel: **MS-MPI** runtime (`msmpisetup.exe`) + SDK
  (`msmpisdk.msi`), both free from Microsoft.

## Quick build

From an **MSYS2 UCRT64** shell, clone this repo **and** its ThirdParty sibling
side by side under a short base dir:

```sh
export OF13_ROOT=/c/OF13
git clone https://github.com/fralarco/OpenFOAM-13-Windows.git  "$OF13_ROOT/OpenFOAM-13-Windows"
git clone https://github.com/fralarco/ThirdParty-13-Windows.git "$OF13_ROOT/ThirdParty-13-Windows"

cd "$OF13_ROOT/OpenFOAM-13-Windows"
source scripts/windows/env.sh
cd "$WM_PROJECT_DIR" && ./Allwmake
```

This gives the recommended **sibling layout** (ThirdParty is a separate repo, not a
sub-directory of the OpenFOAM clone):

```
/c/OF13/
  OpenFOAM-13-Windows/     # this repository
  ThirdParty-13-Windows/   # companion repo: Scotch + MinGW build helpers
```

The ThirdParty clone is only needed for Scotch decomposition; a plain serial build
does not require it. To reuse an existing tree instead, set
`export OF13_THIRDPARTY=/c/OF13WinNormal/ThirdParty` before sourcing `env.sh`.

See [BUILD_WINDOWS.md](BUILD_WINDOWS.md) for details and options.

## OpenFOAM 13 Windows Terminal

Double-click **`scripts/windows/OpenFOAM-13-Windows-Terminal.cmd`** — the
preferred launcher. It opens the OpenFOAM environment in **Windows Terminal**
(`wt.exe`) when available, and falls back to the MinTTY launcher
**`scripts/windows/OpenFOAM-13-Windows-Shell.cmd`** otherwise. Either way it
opens an MSYS2 **UCRT64** shell that loads OpenFOAM, sets the MS-MPI variables,
starts in `$FOAM_RUN`, and shows a compact banner with a modern prompt.

Override the install locations before launching:

```bat
set OF13_ROOT=C:\MyOpenFOAM
set MSYS2_ROOT=C:\msys64
```

(`OF13_ROOT` defaults to `C:\OF13WinNormal`, `MSYS2_ROOT` to `C:\msys64`; no admin
required.) Inside the shell, `of13help` prints the workflow and `of13status`
prints the environment. Verify:

```sh
echo $WM_PROJECT_DIR
which foamRun
foamDictionary -help
of13status
```

### Terminal appearance (optional)

**Windows Terminal** is recommended for the nicest look. An optional profile and
colour scheme (**OpenFOAM Dark**) is provided at
[`scripts/windows/windows-terminal-profile.json`](scripts/windows/windows-terminal-profile.json):
copy its `scheme` and `profile` blocks into your Windows Terminal `settings.json`
(Settings → *Open JSON file*). The **MinTTY** fallback opens with matching dark
colours automatically. The theme is purely cosmetic — OpenFOAM runs the same
without it — and **no font files are bundled** (Cascadia Mono ships with Windows
Terminal; the default font is used if it is absent).

## Running a case (standard OpenFOAM workflow)

Use the normal OpenFOAM tutorial flow — copy a tutorial and run its `Allrun`:

```sh
cd $FOAM_RUN
cp -r $FOAM_TUTORIALS/incompressibleFluid/pitzDaily .
cd pitzDaily
./Allrun            # blockMesh, foamRun, ... via bin/tools/RunFunctions
```

Parallel tutorials work the same way: `runParallel` in `RunFunctions` uses
`mpiexec` on Windows (MS-MPI), so `./Allrun` on a parallel case just works. For a
scotch/MS-MPI parallel case you first build Scotch and the MS-MPI Pstream once
(see [BUILD_WINDOWS.md](BUILD_WINDOWS.md)).

> **`scripts/windows/run_serial.sh` and `run_parallel.sh` are Windows-port
> validation smoke tests, not the standard way to run OpenFOAM.** Use them to
> check the toolchain; use `./Allrun` for real cases.

## Notes and limitations

- **decomposePar** uses the **standard** `decomposeParDict` syntax. For Scotch,
  `method scotch;` is enough — **no** `libs (...)` entry is required (the plugin
  is loaded on demand, as on Linux), and no manual turbulence libraries are
  needed either: wall-function BCs (`nutkWallFunction`, …) are read through the
  generic patch-field fallback. (Case-specific *function objects* may still use
  the normal OpenFOAM `libs (...)` when a case defines them.)
- **Parallel** uses **MS-MPI** (`mpiexec`). `RunFunctions`' `runParallel` calls
  `mpiexec` on Windows and keeps `mpirun` on Linux (override via `$FOAM_MPIRUN`).
  Parallel runs need `MPI_BUFFER_SIZE` set (the shell sets it).
- Serial and 2-rank parallel are validated; large-scale scaling is not benchmarked.
- Not built: real metis/ptscotch/zoltan, ParaView/TECIO/ccmio utilities
  (they need their own external SDKs).

## Licensing

OpenFOAM is **GPL-3.0**; this fork keeps that license (`COPYING`). Third-party
components and their licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

> OpenFOAM is a registered trademark of OpenCFD Ltd. This project is not
> approved or endorsed by OpenCFD Ltd or the OpenFOAM Foundation.
