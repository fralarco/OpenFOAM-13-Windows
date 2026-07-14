# scripts/windows — native Windows (MinGW-w64) build & run helpers

Reproducible helpers for building and running OpenFOAM-13 natively on Windows
with MSYS2 UCRT64 (no WSL, no Cygwin target). Run them from an **MSYS2 UCRT64**
shell. They do **not** require a case-sensitive NTFS directory or a `subst`
drive — only a case-collision-free clone with a reasonably short path prefix.

## Configuration (environment variables)

All paths are parametrised; defaults point at an **example** location and are
not required to be `C:\OF13WinNormal`:

| Var | Default | Meaning |
| --- | --- | --- |
| `OF13_ROOT` | `/c/OF13WinNormal` | base dir holding the OpenFOAM clone + the `ThirdParty-13-Windows` sibling clone |
| `OF13_CLONE` | `$OF13_ROOT/OpenFOAM-13-Windows` | the OpenFOAM working copy |
| `OF13_THIRDPARTY` | `$OF13_ROOT/ThirdParty-13-Windows` | companion repo (Scotch, MS-MPI import lib); override for an existing tree, e.g. `/c/OF13WinNormal/ThirdParty` |
| `OF13_USER` | `/c/OF13User/of-user` | `WM_PROJECT_USER_DIR` |
| `OF13_WORK` | `$OF13_ROOT` | where run logs + example cases are written |
| `MSMPI_INC` | SDK Include dir | set by the MS-MPI SDK; export if not visible |
| `WM_MPLIB` | `Dummy` | `MSMPI` for the parallel Pstream |

`env.sh` is sourced by every script and exports the full `WM_*`/`FOAM_*`
environment from the above.

## The OpenFOAM 13 Windows Terminal (day-to-day use)

For interactive use, don't source scripts by hand — launch the ready-made
environment. Double-click **`OpenFOAM-13-Windows-Terminal.cmd`** (preferred): it
opens the environment in **Windows Terminal** (`wt.exe`) when available and
falls back to the MinTTY launcher **`OpenFOAM-13-Windows-Shell.cmd`** otherwise
(`OpenFOAM-13-Windows-Shell.ps1` is the PowerShell equivalent). Each opens an
MSYS2 **UCRT64** shell that loads OpenFOAM, sets the MS-MPI variables, starts in
`$FOAM_RUN`, and shows a compact banner and a modern prompt. Override
`MSYS2_ROOT` (default `C:\msys64`) and `OF13_ROOT` (default `C:\OF13WinNormal`)
before launching. Inside, `of13help` prints the workflow and `of13status` the
environment; run a case the standard OpenFOAM way:

```sh
cd $FOAM_RUN
cp -r $FOAM_TUTORIALS/incompressibleFluid/pitzDaily .
cd pitzDaily && ./Allrun
```

**Terminal appearance (optional).** For the nicest look under Windows Terminal,
copy the `scheme` and `profile` blocks from `windows-terminal-profile.json` into
your Windows Terminal `settings.json`. The MinTTY fallback already applies
matching dark colours. The theme is optional (OpenFOAM runs the same without it)
and bundles **no font files** — Cascadia Mono ships with Windows Terminal and the
default font is used if it is missing.

## Files

| File | What it does |
| --- | --- |
| `OpenFOAM-13-Windows-Terminal.cmd` | **preferred** launcher: Windows Terminal (`wt.exe`), MinTTY fallback |
| `OpenFOAM-13-Windows-Shell.cmd` | MinTTY fallback launcher (UCRT64 shell, OpenFOAM environment ready) |
| `OpenFOAM-13-Windows-Shell.ps1` | PowerShell equivalent of the `.cmd` launcher |
| `openfoam_shell.sh` | rcfile the launchers source (loads `env.sh`, banner, prompt, `of13help`/`of13status`) |
| `windows-terminal-profile.json` | optional Windows Terminal profile + `OpenFOAM Dark` colour scheme |
| `env.sh` | the shared build/run environment (source this) |
| `run_serial.sh` | **validation smoke test**: blockMesh→checkMesh→foamRun on pitzDaily |
| `build_scotch.sh` | build ThirdParty Scotch 7.0.8 (static, MinGW) |
| `scotch/Makefile.inc` | the MinGW Scotch config (copy into scotch src) |
| `run_decompose.sh` | decomposePar with the `scotch` method (2 subdomains) |
| `setup_msmpi.sh` | make `libmsmpi.a` from the MS-MPI SDK |
| `build_pstream_mpi.sh` | build `lib/msmpi/libPstream.dll` (`WM_MPLIB=MSMPI`) |
| `run_parallel.sh` | **validation smoke test**: `mpiexec -n 2 foamRun -parallel` on the decomposed case |

> `run_serial.sh` and `run_parallel.sh` are **Windows-port validation smoke
> tests**, not the standard way to run OpenFOAM. They exercise the toolchain
> end-to-end and print an `..._OK` marker. For real cases use the standard
> `./Allrun` workflow (below).

## Typical flows

Serial build + run:
```sh
( cd "$WM_PROJECT_DIR" && ./Allwmake )   # standard OpenFOAM build
bash run_serial.sh
```

Scotch decomposition:
```sh
cp scotch/Makefile.inc "$OF13_THIRDPARTY/scotch_7.0.8/src/"   # once
bash build_scotch.sh
wmake libso "$OF13_CLONE/src/parallel/decompose/scotch"       # real scotchDecomp
bash run_decompose.sh
```

Parallel (needs the MS-MPI SDK installed):
```sh
export MSMPI_INC='/c/Program Files (x86)/Microsoft SDKs/MPI/Include'
bash setup_msmpi.sh
bash build_pstream_mpi.sh
bash run_parallel.sh
```

The canonical, guarded (`ifeq ($(WM_ARCH),mingw_w64)`) build-system changes live
in the OpenFOAM tree itself (`wmake/makefiles/general`, `wmake/rules/mingw_w64Gcc/`),
not here — these scripts only orchestrate.

## Running the standard tutorials (`Allrun` / `RunFunctions`)

OpenFOAM tutorials drive parallel steps through `runParallel` in
`bin/tools/RunFunctions`, which on Linux calls `mpirun -np N`. Native Windows
uses **Microsoft MPI**, which ships `mpiexec` (there is no `mpirun`). The port
adapts `RunFunctions` so that `runParallel` uses **`mpiexec -n N`** when
`WM_ARCH = mingw_w64` (Linux/OpenMPI keeps `mpirun -np`; an explicit
`$FOAM_MPIRUN` override is honoured). No per-tutorial edits are needed.

**MPI/Pstream mode.** A parallel run needs the **real** MS-MPI Pstream
(`platforms/<opt>/lib/msmpi/libPstream.dll`); the dummy Pstream aborts under
`mpiexec`. `env.sh` **auto-selects MS-MPI** (`WM_MPLIB=MSMPI`, and puts the
`msmpi` lib dir before `dummy` on `PATH`) when that DLL exists and `mpiexec` is
available, and puts MS-MPI's `Bin` on `PATH`; otherwise it stays serial
(`WM_MPLIB=Dummy`). Build scripts pin `WM_MPLIB=Dummy` to keep the serial
bootstrap. Check the active mode with `of13status` / `echo $WM_MPLIB`. When the
dummy Pstream is active, `runParallel` fails early with a clear message instead
of starting ranks that each abort.

Tutorials that use `writeFormat binary` (e.g. motorBike) also rely on the
binary-mode file-I/O fix in the OpenFOAM tree (`IFstream`/`OFstream` open in
`std::ios::binary` on Windows, avoiding CRLF corruption of binary data blocks).
