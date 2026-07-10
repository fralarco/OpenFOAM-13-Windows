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
| `OF13_ROOT` | `/c/OF13WinNormal` | base dir holding the clone + ThirdParty |
| `OF13_CLONE` | `$OF13_ROOT/OpenFOAM-13-Windows` | the OpenFOAM working copy |
| `OF13_THIRDPARTY` | `$OF13_ROOT/ThirdParty` | ThirdParty (Scotch, MS-MPI import lib) |
| `OF13_USER` | `/c/OF13User/of-user` | `WM_PROJECT_USER_DIR` |
| `OF13_WORK` | `$OF13_ROOT` | where run logs + example cases are written |
| `MSMPI_INC` | SDK Include dir | set by the MS-MPI SDK; export if not visible |
| `WM_MPLIB` | `Dummy` | `MSMPI` for the parallel Pstream |

`env.sh` is sourced by every script and exports the full `WM_*`/`FOAM_*`
environment from the above.

## Files

| File | What it does |
| --- | --- |
| `env.sh` | the shared build/run environment (source this) |
| `run_global_build.sh` | full src+apps build (`CLEAN=1` purges first) + inventory |
| `global_build_inventory.py` | per-target artifact inventory → JSON |
| `run_serial.sh` | blockMesh→checkMesh→foamRun on pitzDaily (serial smoke) |
| `build_scotch.sh` | build ThirdParty Scotch 7.0.8 (static, MinGW) |
| `scotch/Makefile.inc` | the MinGW Scotch config (copy into scotch src) |
| `run_decompose.sh` | decomposePar with the `scotch` method (2 subdomains) |
| `setup_msmpi.sh` | make `libmsmpi.a` from the MS-MPI SDK |
| `build_pstream_mpi.sh` | build `lib/msmpi/libPstream.dll` (`WM_MPLIB=MSMPI`) |
| `run_parallel.sh` | `mpiexec -n 2 foamRun -parallel` on the decomposed case |

## Typical flows

Serial build + run:
```sh
CLEAN=1 bash run_global_build.sh
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
`$FOAM_MPIRUN` override is honoured). No per-tutorial edits are needed. Set
`MPI_BUFFER_SIZE` and put `platforms/<opt>/lib/msmpi` + the MS-MPI `Bin` on
`PATH` (see `run_parallel.sh`).

Tutorials that use `writeFormat binary` (e.g. motorBike) also rely on the
binary-mode file-I/O fix in the OpenFOAM tree (`IFstream`/`OFstream` open in
`std::ios::binary` on Windows, avoiding CRLF corruption of binary data blocks).
