#!/bin/bash
# Build the real MS-MPI Pstream library:
#   platforms/<WM_OPTIONS>/lib/msmpi/libPstream.dll
#
# Prerequisites:
#   1. MS-MPI runtime installed.
#   2. MS-MPI SDK installed.
#   3. scripts/windows/setup_msmpi.sh already executed.
#   4. libOpenFOAM already built during the serial bootstrap.

# Resolve this script's directory so it works regardless of the current cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Export before sourcing env.sh. An assignment prefix on `source` (a regular
# builtin) is reverted when it returns, so
#   WM_MPLIB=MSMPI FOAM_MPI=msmpi source env.sh
# would leave WM_MPLIB empty for the wmake call below: mplibType would then
# include mplib<empty> and the MS-MPI include/libraries would be dropped.
export WM_MPLIB=MSMPI
export FOAM_MPI=msmpi

# MS-MPI SDK include directory. It may be overridden by the caller; env.sh
# normalises it (the installer exports it in Windows form with a trailing
# backslash, which the compiler cannot consume).
export MSMPI_INC="${MSMPI_INC:-/c/Program Files (x86)/Microsoft SDKs/MPI/Include}"

# Load the native Windows OpenFOAM environment.
source "$SCRIPT_DIR/env.sh"

# env.sh enables `set -euo pipefail`.
# Disable only automatic exit so we can capture wmake's return code and report
# the relevant log tail on failure.
set +e

echo "MS-MPI Pstream build environment:"
echo "  WM_PROJECT_DIR=$WM_PROJECT_DIR"
echo "  WM_OPTIONS=$WM_OPTIONS"
echo "  WM_MPLIB=$WM_MPLIB"
echo "  FOAM_MPI=$FOAM_MPI"
echo "  MSMPI_INC=$MSMPI_INC"
echo "  WM_THIRD_PARTY_DIR=$WM_THIRD_PARTY_DIR"
echo "  FOAM_LIBBIN=$FOAM_LIBBIN"

# ---------------------------------------------------------------------------
# Early validation
# ---------------------------------------------------------------------------

if [ "$WM_MPLIB" != "MSMPI" ]; then
    echo "FAIL: WM_MPLIB must be MSMPI, got: $WM_MPLIB"
    exit 1
fi

if [ "$FOAM_MPI" != "msmpi" ]; then
    echo "FAIL: FOAM_MPI must be msmpi, got: $FOAM_MPI"
    exit 1
fi

if [ ! -f "$MSMPI_INC/mpi.h" ]; then
    echo "FAIL: mpi.h not found:"
    echo "  $MSMPI_INC/mpi.h"
    echo
    echo "Install the MS-MPI SDK or set MSMPI_INC explicitly."
    exit 1
fi

MSMPI_IMPORT_LIB="$WM_THIRD_PARTY_DIR/msmpi/lib/libmsmpi.a"

if [ ! -f "$MSMPI_IMPORT_LIB" ]; then
    echo "FAIL: MS-MPI import library not found:"
    echo "  $MSMPI_IMPORT_LIB"
    echo
    echo "Run first:"
    echo "  bash scripts/windows/setup_msmpi.sh"
    exit 1
fi

MPLIB_RULE="$WM_PROJECT_DIR/wmake/rules/mingw_w64Gcc/mplibMSMPI"

if [ ! -f "$MPLIB_RULE" ]; then
    echo "FAIL: MS-MPI wmake rule not found:"
    echo "  $MPLIB_RULE"
    exit 1
fi

if [ ! -f "$FOAM_LIBBIN/libOpenFOAM.dll.a" ]; then
    echo "FAIL: libOpenFOAM is not built yet:"
    echo "  $FOAM_LIBBIN/libOpenFOAM.dll.a"
    echo
    echo "Run the serial bootstrap first:"
    echo "  ./Allwmake"
    exit 1
fi

if ! command -v wmake >/dev/null 2>&1; then
    echo "FAIL: wmake is not available on PATH"
    exit 1
fi

if ! command -v wmakeLnInclude >/dev/null 2>&1; then
    echo "FAIL: wmakeLnInclude is not available on PATH"
    exit 1
fi

echo "  mpi.h: OK"
echo "  libmsmpi.a: OK"
echo "  mplibMSMPI: OK"
echo "  libOpenFOAM: OK"

# ---------------------------------------------------------------------------
# Log location
# ---------------------------------------------------------------------------

WORK="${OF13_WORK:-$OF13_ROOT}"
RES="$WORK/build_pstream_mpi.out"

mkdir -p "$WORK"
: > "$RES"

echo "Build log:"
echo "  $RES"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

cd "$WM_PROJECT_DIR" || {
    echo "FAIL: cannot enter WM_PROJECT_DIR=$WM_PROJECT_DIR"
    exit 1
}

echo "Rebuilding src/Pstream/mpi lnInclude..."

rm -rf src/Pstream/mpi/lnInclude

(
    cd src/Pstream/mpi || exit 1
    wmakeLnInclude .
) >> "$RES" 2>&1

ln_rc=$?

if [ "$ln_rc" -ne 0 ]; then
    echo "FAIL: wmakeLnInclude returned rc=$ln_rc"
    tail -40 "$RES"
    exit 1
fi

echo "Building MS-MPI Pstream..."

wmake libso src/Pstream/mpi >> "$RES" 2>&1
rc=$?

echo "Pstream/mpi rc=$rc" | tee -a "$RES"

PSTREAM_DLL="$FOAM_LIBBIN/msmpi/libPstream.dll"

if [ "$rc" -eq 0 ] && [ -f "$PSTREAM_DLL" ]; then
    echo "PSTREAM_MSMPI_BUILT_OK"
    echo "  $PSTREAM_DLL"
    exit 0
fi

echo "FAIL: MS-MPI Pstream was not built"
echo "Expected:"
echo "  $PSTREAM_DLL"
echo
echo "Last 50 log lines:"
tail -50 "$RES"

exit 1
