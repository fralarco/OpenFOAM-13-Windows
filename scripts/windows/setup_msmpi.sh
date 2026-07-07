#!/bin/bash
# Prepare MS-MPI for the native MinGW-w64 build: produce a MinGW import library
# libmsmpi.a from the MS-MPI SDK. Prereq: install the MS-MPI SDK (msmpisdk.msi).
#
# MinGW-w64 GCC/ld links the x64 MSVC import library (msmpi.lib) directly, so
# the simplest reliable path is to use it as libmsmpi.a (validated with a
# minimal MPI_Init/Comm_rank program under mpiexec -n 2). Falls back to
# dlltool+msmpi.def / gendef if msmpi.lib is absent.
source "$(dirname "$0")/env.sh"
set +e
INC="${MSMPI_INC:-/c/Program Files (x86)/Microsoft SDKs/MPI/Include}"
LIB="${MSMPI_LIB64:-/c/Program Files (x86)/Microsoft SDKs/MPI/Lib/x64}"
OUT="$WM_THIRD_PARTY_DIR/msmpi/lib"
echo "MSMPI_INC=$INC"
[ -f "$INC/mpi.h" ] || { echo "FAIL: mpi.h not under \$MSMPI_INC ($INC). Install msmpisdk.msi and set MSMPI_INC."; exit 1; }
mkdir -p "$OUT"
if [ -f "$LIB/msmpi.lib" ]; then
    echo "=== using SDK msmpi.lib as libmsmpi.a (x64 COFF import lib) ==="
    cp "$LIB/msmpi.lib" "$OUT/libmsmpi.a"
elif [ -f "$LIB/msmpi.def" ]; then
    dlltool -d "$LIB/msmpi.def" -D msmpi.dll -l "$OUT/libmsmpi.a"
elif command -v gendef >/dev/null 2>&1; then
    ( cd "$OUT" && gendef /c/Windows/System32/msmpi.dll && dlltool -d msmpi.def -D msmpi.dll -l libmsmpi.a )
else
    echo "FAIL: no msmpi.lib / msmpi.def and no gendef under $LIB."; exit 1
fi
[ -f "$OUT/libmsmpi.a" ] && echo "MSMPI_IMPORTLIB_OK: $OUT/libmsmpi.a" || { echo "FAIL: libmsmpi.a not produced"; exit 1; }
