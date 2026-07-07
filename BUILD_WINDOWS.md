# Building OpenFOAM-13 on Windows (MinGW-w64)

Native build with MSYS2 UCRT64. No WSL, no Cygwin runtime. A normal
case-insensitive NTFS directory works — no case-sensitive attribute and no
`subst` drive are needed.

## 1. Prerequisites

1. Install **[MSYS2](https://www.msys2.org/)**.
2. In an **MSYS2 UCRT64** shell:
   ```sh
   pacman -Syu
   pacman -S mingw-w64-ucrt-x86_64-gcc make flex bison git
   ```
   GCC 13+ works (validated on GCC 16.1).
3. (Parallel only) Install **MS-MPI**: `msmpisetup.exe` (runtime) **and**
   `msmpisdk.msi` (SDK), free from Microsoft.

## 2. Get the source

```sh
export OF13_ROOT=/c/OF13                     # choose a short path with no case-colliding files
git clone <this-repo> "$OF13_ROOT/OpenFOAM-13-Windows"
```

All build/run scripts are under `scripts/windows/` and are configured by
environment variables (see `scripts/windows/README.md`):

| Var | Default | Meaning |
| --- | --- | --- |
| `OF13_ROOT` | `/c/OF13WinNormal` | base dir (clone + ThirdParty) |
| `OF13_CLONE` | `$OF13_ROOT/OpenFOAM-13-Windows` | the working copy |
| `OF13_THIRDPARTY` | `$OF13_ROOT/ThirdParty` | Scotch / MS-MPI import lib |
| `MSMPI_INC` | SDK Include dir | export if not visible |

## 3. Full build

```sh
CLEAN=1 bash scripts/windows/run_global_build.sh
```

This bootstraps the `libOpenFOAM ↔ libPstream` cycle (PE has no lazy symbol
resolution), builds `src` + `applications` in dependency order, and writes an
artifact inventory. Expect: solvers 5/5, modules 45/45, legacy 15/15, utilities
133/137, src libraries 104/114.

## 4. Serial run

```sh
bash scripts/windows/run_serial.sh
# blockMesh -> checkMesh -> foamRun on incompressibleFluid/pitzDaily
```

## 5. Scotch decomposition (optional)

```sh
cp scripts/windows/scotch/Makefile.inc "$OF13_THIRDPARTY/scotch_7.0.8/src/"
bash scripts/windows/build_scotch.sh          # static libscotch*.a
wmake libso src/parallel/decompose/scotch     # real scotchDecomp
bash scripts/windows/run_decompose.sh         # decomposePar -method scotch
```

## 6. Parallel run (MS-MPI)

```sh
export MSMPI_INC='/c/Program Files (x86)/Microsoft SDKs/MPI/Include'
bash scripts/windows/setup_msmpi.sh           # libmsmpi.a from the SDK
bash scripts/windows/build_pstream_mpi.sh     # lib/msmpi/libPstream.dll
bash scripts/windows/run_parallel.sh          # mpiexec -n 2 foamRun -parallel
```

Notes:
- `MPI_BUFFER_SIZE` must be set (the scripts set it).
- On Windows, name runtime plugin libraries explicitly in the case dictionaries,
  e.g. `libs ("libscotchDecomp.so" "libmomentumTransportModels.so");`
  (`.so` → `.dll` is mapped automatically).

## Notes on the port

The Windows changes are minimal and all guarded (`ifeq ($(WM_ARCH),mingw_w64)`
or `#if defined(_WIN32)`), chiefly in `wmake/makefiles/general` and
`wmake/rules/mingw_w64Gcc/`: hashed short object directories (keeps paths under
`MAX_PATH`, removing the need for `subst`), `-iquote` for the project's own
include dirs (avoids case-insensitive header shadowing), a two-pass
`libOpenFOAM/libPstream` bootstrap, and case-normalising header renames so a
normal NTFS checkout has no collisions.
