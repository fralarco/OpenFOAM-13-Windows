# Third-Party Notices

This project builds on OpenFOAM-13 and a small number of third-party components.
No third-party **binaries** are redistributed in this repository.

## OpenFOAM-13

- Upstream: OpenFOAM Foundation, <https://openfoam.org>.
- License: **GPL-3.0** (see `COPYING`). This repository is a fork with
  Windows/MinGW build changes; the full corresponding source is published here.
- OpenFOAM is a registered trademark of OpenCFD Ltd. This project is not
  approved or endorsed by OpenCFD Ltd or the OpenFOAM Foundation.

## Scotch 7.0.8 (optional — graph partitioning)

- Upstream: <https://gitlab.inria.fr/scotch/scotch>.
- License: **CeCILL-C** (LGPL-compatible).
- Integration: built from its own upstream source with an added MinGW
  `Makefile.inc` (`scripts/windows/scotch/Makefile.inc`); linked **statically**
  into OpenFOAM's `libscotchDecomp`. **No Scotch binaries are shipped here.**

## MS-MPI (optional — parallel)

- Upstream: Microsoft, <https://learn.microsoft.com/message-passing-interface/microsoft-mpi>.
- License: Microsoft's MS-MPI EULA (freely redistributable runtime).
- Integration: **not redistributed**. The user installs the MS-MPI runtime and
  SDK; the build only generates a local MinGW import library from the installed
  SDK. No Microsoft binaries, headers, or installers are included here.

## FlexLexer.h (build convenience)

- From the **flex** project (<https://github.com/westes/flex>), BSD-style license.
- A single header vendored under `wmake/rules/mingw_w64Gcc/include/` because the
  `chemkinReader` utility includes `<FlexLexer.h>`, which is not on the UCRT64
  default include path.

## Toolchain

The MinGW-w64 GCC toolchain (via MSYS2 UCRT64) is installed by the user and is
not redistributed here. GCC runtime libraries carry the GCC Runtime Library
Exception.

## Not derived from blueCFD

blueCFD-Core was consulted only as prior art demonstrating the feasibility of a
Windows-native OpenFOAM. **No blueCFD source, scripts, patches, or binaries are
used or included.**
