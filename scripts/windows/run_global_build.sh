#!/bin/bash
# Full native-Windows OpenFOAM-13 build on a normal case-insensitive NTFS clone
# (no subst). Discovery mode (CONTINUE=1): records every step failure and keeps
# going. CLEAN=1 purges all lnInclude + platforms first (fully reproducible).
#
#   CLEAN=1 bash scripts/windows/run_global_build.sh
#
# Bootstraps the libOpenFOAM<->libPstream(dummy) cycle (PE has no lazy symbol
# resolution), then builds src + applications in dependency order. Ends with the
# artifact inventory (global_build_inventory.py).
set -uo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SELF_DIR/env.sh"
set +e

WORK="${OF13_WORK:-$OF13_ROOT}"
CONTINUE="${CONTINUE:-1}"
LOGD="$WORK/global-build"
mkdir -p "$LOGD"
LEDGER="$LOGD/steps.tsv"; : > "$LEDGER"
FAILED=0

if [ "${CLEAN:-0}" = "1" ]; then
    echo "=== CLEAN: purge lnInclude + platforms ==="
    ( cd "$WM_PROJECT_DIR" && find src applications -type d -name lnInclude -prune -exec rm -rf {} + 2>/dev/null )
    rm -rf "$WM_PROJECT_DIR/platforms" 2>/dev/null
fi

step() {
    local log="$1" name="$2"; shift 2
    echo "=== STEP $name ($*) ===" | tee -a "$LOGD/$log" >/dev/null
    local t0=$(date +%s)
    ( cd "$WM_PROJECT_DIR" && "$@" ) >> "$LOGD/$log" 2>&1
    local status=$?
    local dt=$(( $(date +%s) - t0 ))
    echo "=== EXIT($name)=$status ${dt}s ===" | tee -a "$LOGD/$log" >/dev/null
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$status" "$log" "$dt" "$*" >> "$LEDGER"
    if [ "$status" -ne 0 ]; then
        FAILED=$((FAILED+1)); echo "STEP FAILED: $name (exit $status, log $log)"
        [ "$CONTINUE" = "1" ] || exit "$status"
    else
        echo "STEP OK: $name (${dt}s)"
    fi
}

cd "$WM_PROJECT_DIR"

# ---------- bootstrap: wmake tools + libOpenFOAM<->libPstream two-pass
step 01-src-core.log wmake-tools bash -c 'cd wmake/src && make'
DUMMY_LIBDIR="$FOAM_LIBBIN/dummy"
step 01-src-core.log OpenFOAM-lnInclude wmakeLnInclude src/OpenFOAM
step 01-src-core.log OSspecific         wmake libo src/OSspecific/MSwindows
step 01-src-core.log Pstream-objects    bash -c 'cd src/Pstream/dummy && wmakeLnInclude . && wmake objects'
POBJDIR=$(dirname "$(find "$WM_PROJECT_DIR/platforms/$WM_OPTIONS/obj" -name UPstream.o | head -1)")
step 01-src-core.log Pstream-importlib  bash -c "mkdir -p '$DUMMY_LIBDIR' && dlltool --export-all-symbols -D libPstream.dll -l '$DUMMY_LIBDIR/libPstream.dll.a' '$POBJDIR'/*.o"
step 01-src-core.log OpenFOAM           wmake libso src/OpenFOAM
step 01-src-core.log Pstream-final      bash -c "g++ -shared -Wl,--enable-auto-import '$POBJDIR'/*.o -L'$FOAM_LIBBIN' -lOpenFOAM -lpthread -o '$DUMMY_LIBDIR/libPstream.dll'"

# ---------- 01 core
step 01-src-core.log fileFormats       wmake libso src/fileFormats
step 01-src-core.log surfMesh          wmake libso src/surfMesh
step 01-src-core.log triSurface        wmake libso src/triSurface
step 01-src-core.log meshTools         wmake libso src/meshTools
step 01-src-core.log dummy-MGridGen    wmake libso src/dummyThirdParty/MGridGen

# ---------- 03 finiteVolume
step 03-src-finiteVolume.log finiteVolume wmake libso src/finiteVolume

# ---------- 04a thermo base
step 04-src-thermo.log ODE                  wmake libso src/ODE
step 04-src-thermo.log physicalProperties   wmake libso src/physicalProperties
step 04-src-thermo.log thermophysicalModels src/thermophysicalModels/Allwmake

# ---------- 05a lagrangian base (src/Lagrangian was renamed to LagrangianFwk)
step 05-src-lagrangian.log tracking          wmake libso src/tracking
step 05-src-lagrangian.log lagrangian-basic  wmake libso src/lagrangian/basic
step 05-src-lagrangian.log Lagrangian-core   wmake libso src/LagrangianFwk/Lagrangian

# ---------- 02a mesh mid
step 02-src-mesh.log generic          src/generic/Allwmake
step 02-src-mesh.log sampling         wmake libso src/sampling
step 02-src-mesh.log meshCheck        wmake libso src/meshCheck
step 02-src-mesh.log topoSetSources   wmake libso src/topoSetSources
step 02-src-mesh.log fvTopoSetSources wmake libso src/fvTopoSetSources
step 02-src-mesh.log motionSolvers    wmake libso src/motionSolvers
step 02-src-mesh.log extrudeModel     wmake libso src/mesh/extrudeModel
step 02-src-mesh.log polyTopoChange   wmake libso src/polyTopoChange
step 02-src-mesh.log conversion       wmake libso src/conversion

# ---------- 07 parallel (serial/dummy path)
step 07-src-parallel.log decompositionMethods wmake libso src/parallel/decompose/decompositionMethods
step 07-src-parallel.log dummy-scotch     wmake libso src/dummyThirdParty/scotch
step 07-src-parallel.log dummy-ptscotch   wmake libso src/dummyThirdParty/ptscotch
step 07-src-parallel.log dummy-metis      wmake libso src/dummyThirdParty/metis
step 07-src-parallel.log decompose-optional-THIRDPARTY src/parallel/decompose/Allwmake
step 07-src-parallel.log parallel-parallel wmake libso src/parallel/parallel
step 07-src-parallel.log distributed       wmake libso src/parallel/distributed
step 07-src-parallel.log fvMeshStitchers   wmake libso src/fvMeshStitchers
step 07-src-parallel.log fvMeshMovers      src/fvMeshMovers/Allwmake
step 07-src-parallel.log fvMeshTopoChangers src/fvMeshTopoChangers/Allwmake
step 07-src-parallel.log fvMeshDistributors wmake libso src/fvMeshDistributors
step 07-src-parallel.log randomProcesses   wmake libso src/randomProcesses

# ---------- 04b transport/thermo family
step 04-src-thermo.log twoPhaseModels         src/twoPhaseModels/Allwmake
step 04-src-thermo.log multiphaseModels       src/multiphaseModels/Allwmake
step 04-src-thermo.log MomentumTransport      src/MomentumTransportModels/Allwmake
step 04-src-thermo.log ThermophysicalTransport src/ThermophysicalTransportModels/Allwmake
step 04-src-thermo.log radiationModels        wmake libso src/radiationModels
step 04-src-thermo.log combustionModels       wmake libso src/combustionModels

# ---------- 02b mesh final (snappy)
step 02-src-mesh.log snappyHexMesh-lib wmake libso src/mesh/snappyHexMesh
step 02-src-mesh.log blockMesh-lib     wmake libso src/mesh/blockMesh
step 02-src-mesh.log renumber          src/renumber/Allwmake
step 02-src-mesh.log fvAgglomeration   src/fvAgglomerationMethods/Allwmake
step 02-src-mesh.log fvMotionSolver    wmake libso src/fvMotionSolver

# ---------- 06 models + functionObjects
step 06-src-functionObjects.log fvConstraints   wmake libso src/fvConstraints
step 06-src-functionObjects.log fvModels        src/fvModels/Allwmake
step 06-src-functionObjects.log functionObjects src/functionObjects/Allwmake

# ---------- 05b lagrangian full
step 05-src-lagrangian.log lagrangian-all  src/lagrangian/Allwmake
step 05-src-lagrangian.log Lagrangian-all  src/LagrangianFwk/Allwmake
step 05-src-lagrangian.log rigidBodyMotion src/rigidBodyMotion/Allwmake

# ---------- 06b tail
step 06-src-functionObjects.log propellerDisk      wmake libso src/fvModels/propellerDisk
step 06-src-functionObjects.log rigidBodyPropeller wmake libso src/fvModels/rigidBodyPropellerDisk
step 06-src-functionObjects.log specieTransfer     wmake libso src/specieTransfer
step 06-src-functionObjects.log atmosphericModels  wmake libso src/atmosphericModels
step 06-src-functionObjects.log waves              wmake libso src/waves

# ---------- applications
step 09-applications-solvers.log solvers   wmake -k -all applications/solvers
step 10-modules.log             modules    applications/modules/Allwmake
step 09-applications-solvers.log legacy    wmake -k -all applications/legacy
step 08-applications-utilities.log utilities wmake -k -all applications/utilities

# ---------- summary
OF13_INVENTORY_OUT="$WORK/full_build_status.json" \
    python "$(cygpath -m "$SELF_DIR/global_build_inventory.py")" 2>&1 | tee "$LOGD/11-final-summary.log"
echo "FAILED_STEPS=$FAILED" | tee -a "$LOGD/11-final-summary.log"
echo "GLOBAL_BUILD_DONE FAILED=$FAILED"
