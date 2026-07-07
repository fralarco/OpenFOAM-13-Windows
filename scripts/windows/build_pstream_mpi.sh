#!/bin/bash
# Build the real (MS-MPI) Pstream: platforms/<opt>/lib/msmpi/libPstream.dll.
# Run after setup_msmpi.sh (libmsmpi.a) and with MSMPI_INC pointing at the SDK
# Include dir. libOpenFOAM must already be built (serial pass).
WM_MPLIB=MSMPI FOAM_MPI=msmpi source "$(dirname "$0")/env.sh"
set +e
export MSMPI_INC="${MSMPI_INC:-/c/Program Files (x86)/Microsoft SDKs/MPI/Include}"
WORK="${OF13_WORK:-$OF13_ROOT}"
RES="$WORK/build_pstream_mpi.out"; : > "$RES"
[ -f "$WM_THIRD_PARTY_DIR/msmpi/lib/libmsmpi.a" ] || { echo "FAIL: run setup_msmpi.sh first (libmsmpi.a missing)"; exit 1; }
cd "$WM_PROJECT_DIR"
rm -rf src/Pstream/mpi/lnInclude
( cd src/Pstream/mpi && wmakeLnInclude . )
wmake libso src/Pstream/mpi >> "$RES" 2>&1
rc=$?; echo "Pstream/mpi rc=$rc" | tee -a "$RES"
[ "$rc" -eq 0 ] && [ -e "$FOAM_LIBBIN/msmpi/libPstream.dll" ] && echo "PSTREAM_MSMPI_BUILT_OK" | tee -a "$RES" || { echo "FAIL: lib/msmpi/libPstream.dll not built"; tail -25 "$RES"; exit 1; }
