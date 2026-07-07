#!/bin/bash
# Validate a native multi-rank foamRun -parallel using the real MS-MPI Pstream.
# Requires build_pstream_mpi.sh (lib/msmpi/libPstream.dll) and Scotch.
WM_MPLIB=MSMPI FOAM_MPI=msmpi source "$(dirname "$0")/env.sh"
set +e
export MSMPI_INC="${MSMPI_INC:-/c/Program Files (x86)/Microsoft SDKs/MPI/Include}"
export MPI_BUFFER_SIZE="${MPI_BUFFER_SIZE:-20000000}"   # OpenFOAM MPI Pstream requires it
MSMPI_BIN="${MSMPI_BIN:-/c/Program Files/Microsoft MPI/Bin}"
# lib/msmpi FIRST so exes load the MPI libPstream.dll (env.sh already prepends
# lib/$FOAM_MPI = lib/msmpi); add mpiexec.
export PATH="$MSMPI_BIN:$PATH"
WORK="${OF13_WORK:-$OF13_ROOT}"
RES="$WORK/run_parallel.out"; : > "$RES"
[ -e "$FOAM_LIBBIN/msmpi/libPstream.dll" ] || { echo "FAIL: build lib/msmpi/libPstream.dll first (build_pstream_mpi.sh)"; exit 1; }

echo "=== decompose (scotch, 2) ===" | tee -a "$RES"
bash "$(dirname "$0")/run_decompose.sh" >> "$RES" 2>&1
CASE="$WORK/run/pitzDecomp"; cd "$CASE" || { echo "no case"; exit 1; }
foamDictionary -entry endTime -set 0.005 system/controlDict >> "$RES" 2>&1 || true
foamDictionary -entry writeInterval -set 0.005 system/controlDict >> "$RES" 2>&1 || true
echo "=== mpiexec -n 2 foamRun -parallel ===" | tee -a "$RES"
mpiexec -n 2 foamRun -solver incompressibleFluid -parallel >> "$RES" 2>&1
rc=$?; echo "parallel foamRun rc=$rc" | tee -a "$RES"
{ [ "$rc" -eq 0 ] && ls processor0/0.005 >/dev/null 2>&1; } && echo "FOAMRUN_PARALLEL_OK" | tee -a "$RES" || { echo "PARALLEL_FAILED"; tail -30 "$RES"; exit 1; }
