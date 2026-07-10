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

## 4. The OpenFOAM 13 Windows Shell

For day-to-day use, launch the ready-made environment instead of sourcing
scripts by hand. Double-click **`scripts/windows/OpenFOAM-13-Windows-Shell.cmd`**
(or run `scripts/windows/OpenFOAM-13-Windows-Shell.ps1`). It opens an MSYS2
**UCRT64** terminal with the OpenFOAM environment loaded (banner, `OF13-Windows`
prompt, `$FOAM_RUN` created). Configure `MSYS2_ROOT` (default `C:\msys64`) and
`OF13_ROOT` (default `C:\OF13WinNormal`) via the environment before launching.
Verify inside the shell:

```sh
echo $WM_PROJECT_DIR
which foamRun
foamDictionary -help
```

## 5. Running a case (standard OpenFOAM workflow)

Use the normal OpenFOAM flow — copy a tutorial and run its `Allrun`:

```sh
cd $FOAM_RUN
cp -r $FOAM_TUTORIALS/incompressibleFluid/pitzDaily .
cd pitzDaily
./Allrun
```

`Allrun` sources `bin/tools/RunFunctions`; `runApplication` runs serial steps and
`runParallel` runs parallel steps with `mpiexec` on Windows. `Allclean` cleans
the case.

> **`scripts/windows/run_serial.sh` and `run_parallel.sh` are Windows-port
> validation smoke tests, not the standard workflow.** They exercise the
> toolchain end-to-end (e.g. `run_serial.sh` prints `SERIAL_PITZDAILY_OK`); for
> real cases use `./Allrun`.

## 6. Scotch decomposition (optional)

```sh
cp scripts/windows/scotch/Makefile.inc "$OF13_THIRDPARTY/scotch_7.0.8/src/"
bash scripts/windows/build_scotch.sh          # static libscotch*.a
wmake libso src/parallel/decompose/scotch     # real scotchDecomp
bash scripts/windows/run_decompose.sh         # decomposePar -method scotch
```

`decomposePar` needs no manual turbulence libraries — wall-function BCs
(`nutkWallFunction`, …) are read via the generic patch-field fallback, as on
Linux. Only a decomposition *method* plugin is named, e.g.
`libs ("libscotchDecomp.so");` for `method scotch`.

## 7. Parallel run (MS-MPI)

```sh
export MSMPI_INC='/c/Program Files (x86)/Microsoft SDKs/MPI/Include'
bash scripts/windows/setup_msmpi.sh           # libmsmpi.a from the SDK
bash scripts/windows/build_pstream_mpi.sh     # lib/msmpi/libPstream.dll
bash scripts/windows/run_parallel.sh          # mpiexec -n 2 foamRun -parallel
```

Notes:
- `MPI_BUFFER_SIZE` must be set (the scripts set it).
- A runtime-loaded decomposition *method* is named in `decomposeParDict`, e.g.
  `libs ("libscotchDecomp.so");` for `method scotch` (`.so` → `.dll` is mapped
  automatically) — the same as on Linux.
- You do **not** need to add turbulence/model libraries for `decomposePar` to
  read wall-function BCs (`nutkWallFunction`, …); those are handled by the
  generic patch-field fallback, exactly as on Linux.

## Notes on the port

The Windows changes are minimal and all guarded (`ifeq ($(WM_ARCH),mingw_w64)`
or `#if defined(_WIN32)`), chiefly in `wmake/makefiles/general` and
`wmake/rules/mingw_w64Gcc/`: hashed short object directories (keeps paths under
`MAX_PATH`, removing the need for `subst`), `-iquote` for the project's own
include dirs (avoids case-insensitive header shadowing), a two-pass
`libOpenFOAM/libPstream` bootstrap, and case-normalising header renames so a
normal NTFS checkout has no collisions.
