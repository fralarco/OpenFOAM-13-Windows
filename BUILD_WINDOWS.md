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
   A few tutorial `Allrun`/mesh scripts use `bc` for arithmetic; install it with
   `pacman -S bc`. `gnuplot` (`pacman -S mingw-w64-ucrt-x86_64-gnuplot`) is
   optional and only used to render post-processing graphs.
3. (Parallel only) Install **MS-MPI**: `msmpisetup.exe` (runtime) **and**
   `msmpisdk.msi` (SDK), free from Microsoft.

## 2. Get the source

Clone this repository **and** its ThirdParty companion as **siblings** under a
short base dir (`ThirdParty-13-Windows` is a separate repo, not a sub-directory of
the OpenFOAM clone):

```sh
export OF13_ROOT=/c/OF13                     # short path, no case-colliding files
git clone https://github.com/fralarco/OpenFOAM-13-Windows.git  "$OF13_ROOT/OpenFOAM-13-Windows"
git clone https://github.com/fralarco/ThirdParty-13-Windows.git "$OF13_ROOT/ThirdParty-13-Windows"
```

Recommended layout:

```
/c/OF13/
  OpenFOAM-13-Windows/     # this repository
  ThirdParty-13-Windows/   # companion repo: Scotch + MinGW build helpers
```

The ThirdParty clone is only needed for Scotch decomposition (§6); a plain serial
build does not require it. To reuse an existing tree, set
`export OF13_THIRDPARTY=/c/OF13WinNormal/ThirdParty` before sourcing `env.sh`.

All build/run scripts are under `scripts/windows/` and are configured by
environment variables (see `scripts/windows/README.md`):

| Var | Default | Meaning |
| --- | --- | --- |
| `OF13_ROOT` | `/c/OF13WinNormal` | base dir holding both sibling clones |
| `OF13_CLONE` | `$OF13_ROOT/OpenFOAM-13-Windows` | the working copy |
| `OF13_THIRDPARTY` | `$OF13_ROOT/ThirdParty-13-Windows` | companion repo (Scotch / MS-MPI import lib); override for an existing tree |
| `MSMPI_INC` | SDK Include dir | export if not visible |

## 3. Full build

Source the environment, then run the standard OpenFOAM build driver from
`$WM_PROJECT_DIR`:

```sh
source scripts/windows/env.sh
cd "$WM_PROJECT_DIR" && ./Allwmake
```

`Allwmake` follows the standard upstream sequence: it builds the wmake tools,
runs the sibling ThirdParty `Allwmake` (which prepares **Scotch** automatically
on Windows, see §6), and then builds `src` + `applications` in dependency order.
On a clean Windows tree it first seeds the `libOpenFOAM ↔ libPstream` link cycle
once (PE has no lazy symbol resolution); re-runs skip that step and resume
incrementally.

Compilation is parallel per target (`WM_NCOMPPROCS`, default: all cores). Use
`./Allwmake -j N` to limit it — a moderate `N` (e.g. `-j 4`) is kinder to
laptops or machines with little RAM. A first build takes a while.

## 4. The OpenFOAM 13 Windows Terminal

For day-to-day use, launch the ready-made environment instead of sourcing
scripts by hand.

- **Preferred:** double-click **`scripts/windows/OpenFOAM-13-Windows-Terminal.cmd`**.
  It opens the environment in **Windows Terminal** (`wt.exe`) when available and
  falls back to the MinTTY launcher otherwise.
- **Fallback:** **`scripts/windows/OpenFOAM-13-Windows-Shell.cmd`** (MinTTY), or
  `scripts/windows/OpenFOAM-13-Windows-Shell.ps1` (PowerShell).

Both open an MSYS2 **UCRT64** shell that loads OpenFOAM, sets the MS-MPI
variables, starts in `$FOAM_RUN`, and shows a compact banner and a modern
prompt. Override the install locations before launching:

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

**Terminal appearance (optional).** Windows Terminal is recommended. An optional
profile + colour scheme (**OpenFOAM Dark**) is provided at
`scripts/windows/windows-terminal-profile.json` — copy its `scheme` and `profile`
blocks into your Windows Terminal `settings.json`. The MinTTY fallback opens with
matching dark colours automatically. The theme is purely cosmetic (OpenFOAM runs
the same without it) and **no font files are bundled** — Cascadia Mono ships with
Windows Terminal and the default font is used if it is missing.

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

Scotch is built **automatically** by `./Allwmake` (§3), exactly as on Linux: the
sibling `ThirdParty-13-Windows` clone's own `Allwmake` installs its MinGW
configuration (`etc/wmakeFiles/scotch/Makefile.inc.x86-64_pc_mingw_w64-OpenFOAM`)
into the scotch source tree and builds the static `libscotch*.a`, after which the
OpenFOAM build compiles the real `scotchDecomp` (`SCOTCH_TYPE=ThirdParty`, set by
`env.sh`, override honoured). No manual step is needed.

To rerun only the Scotch stage — e.g. after adding the ThirdParty clone later:

```sh
bash scripts/windows/build_scotch.sh          # wrapper: runs $WM_THIRD_PARTY_DIR/Allwmake
wmake libso src/parallel/decompose/scotch     # real scotchDecomp (if not via ./Allwmake)
bash scripts/windows/run_decompose.sh         # decomposePar -method scotch
```

`decomposePar` uses the standard `decomposeParDict` — just `method scotch;`, with
**no** `libs (...)` entry: the Scotch plugin is loaded on demand, as on Linux.
No manual turbulence libraries are needed either — wall-function BCs
(`nutkWallFunction`, …) are read via the generic patch-field fallback.

## 7. Parallel run (MS-MPI)

Build the MS-MPI Pstream once (needs the MS-MPI SDK):

```sh
export MSMPI_INC='/c/Program Files (x86)/Microsoft SDKs/MPI/Include'
bash scripts/windows/setup_msmpi.sh           # libmsmpi.a from the SDK
bash scripts/windows/build_pstream_mpi.sh     # lib/msmpi/libPstream.dll
bash scripts/windows/run_parallel.sh          # mpiexec -n 2 foamRun -parallel
```

Once `platforms/<opt>/lib/msmpi/libPstream.dll` exists and MS-MPI is installed,
the OpenFOAM shell **auto-selects MS-MPI** (`WM_MPLIB=MSMPI`) so `./Allrun` and
`mpiexec … foamRun -parallel` load the **real** Pstream, not the dummy one.

**Check the active MPI/Pstream mode** any time:

```sh
of13status            # shows WM_MPLIB and FOAM_MPI (parallel-ready or serial-only)
echo $WM_MPLIB        # MSMPI = real Pstream; Dummy = serial only
which mpiexec
```

If a parallel run reports *"dummy Pstream … cannot be used in parallel mode"*,
the dummy Pstream is active (`WM_MPLIB=Dummy`): build the MS-MPI Pstream (above)
and relaunch the shell, or `export WM_MPLIB=MSMPI FOAM_MPI=msmpi`. With the dummy
Pstream active, `runParallel` now fails early with that message instead of
starting ranks that each abort.

Notes:
- `MPI_BUFFER_SIZE` must be set (the scripts set it).
- `decomposeParDict` uses standard syntax — `method scotch;` with no `libs (...)`
  entry. The port loads `lib<method>Decomp` on demand (`.so` → `.dll` mapped
  automatically), so decomposition methods behave the same as on Linux.
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
