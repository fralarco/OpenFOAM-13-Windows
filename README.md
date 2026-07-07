# OpenFOAM-13 — Native Windows (MinGW-w64)

> **Unofficial native Windows port of OpenFOAM Foundation OpenFOAM-13.
> Not affiliated with or endorsed by OpenFOAM Foundation.**

A native Windows build of [OpenFOAM Foundation **OpenFOAM-13**](https://openfoam.org),
built with **MSYS2 UCRT64 / MinGW-w64**. **No WSL, no Cygwin runtime, no blueCFD.**

This is a fork of OpenFOAM-13 with minimal, guarded (`ifeq ($(WM_ARCH),mingw_w64)`)
changes so the toolbox compiles and runs from a **normal NTFS directory** — no
case-sensitive attribute and no `subst` drive required.

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

From an **MSYS2 UCRT64** shell:

```sh
git clone <this-repo> /c/OF13/OpenFOAM-13-Windows
export OF13_ROOT=/c/OF13
CLEAN=1 bash /c/OF13/OpenFOAM-13-Windows/scripts/windows/run_global_build.sh
```

See [BUILD_WINDOWS.md](BUILD_WINDOWS.md) for details and options.

## Run pitzDaily (serial)

```sh
bash scripts/windows/run_serial.sh          # -> SERIAL_PITZDAILY_OK
```

## Run pitzDaily (parallel)

```sh
# once: Scotch + real scotchDecomp
cp scripts/windows/scotch/Makefile.inc "$OF13_THIRDPARTY/scotch_7.0.8/src/"
bash scripts/windows/build_scotch.sh
wmake libso src/parallel/decompose/scotch

# once: MS-MPI (after installing msmpisdk.msi)
export MSMPI_INC='/c/Program Files (x86)/Microsoft SDKs/MPI/Include'
bash scripts/windows/setup_msmpi.sh
bash scripts/windows/build_pstream_mpi.sh

bash scripts/windows/run_parallel.sh        # -> FOAMRUN_PARALLEL_OK
```

## Known limitations

- Serial and 2-rank parallel are validated; large-scale scaling is not benchmarked.
- Runtime plugins (decomposition methods, turbulence BCs) must be named via
  `libs (...)` in the case dictionaries on Windows (`.so` → `.dll` is auto-mapped).
- Parallel runs require `MPI_BUFFER_SIZE` in the environment.
- Not built: real metis/ptscotch/zoltan, ParaView/TECIO/ccmio utilities
  (need their own external SDKs).

## Licensing

OpenFOAM is **GPL-3.0**; this fork keeps that license (`COPYING`). Third-party
components and their licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

> OpenFOAM is a registered trademark of OpenCFD Ltd. This project is not
> approved or endorsed by OpenCFD Ltd or the OpenFOAM Foundation.
