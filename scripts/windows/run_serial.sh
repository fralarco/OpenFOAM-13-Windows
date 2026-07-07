#!/bin/bash
# Serial tutorial smoke: blockMesh -> checkMesh -> foamRun on the
# incompressibleFluid/pitzDaily tutorial. Proves the native serial toolchain.
# Output dir: $OF13_WORK/run/pitzDaily (default $OF13_ROOT/run).
source "$(dirname "$0")/env.sh"
set +e
WORK="${OF13_WORK:-$OF13_ROOT}"
CASE="$WORK/run/pitzDaily"
RES="$WORK/run_serial.out"; : > "$RES"
rm -rf "$CASE"; mkdir -p "$(dirname "$CASE")"
cp -r "$WM_PROJECT_DIR/tutorials/incompressibleFluid/pitzDaily" "$CASE"
cd "$CASE"
# Strip optional post-processing function objects (need libfieldFunctionObjects,
# outside the minimal set) so the solver run is self-contained.
printf 'FoamFile { format ascii; class dictionary; location "system"; object functions; }\n' > system/functions
run() { local d="$1"; shift; echo "=== $d ===" | tee -a "$RES"; "$@" >> "$RES" 2>&1; local rc=$?; echo "=== EXIT($d)=$rc ===" | tee -a "$RES"; [ "$rc" -eq 0 ] || { echo "FAIL $d"; tail -20 "$RES"; exit "$rc"; }; }
run blockMesh blockMesh -dict "$FOAM_TUTORIALS/resources/blockMesh/pitzDaily"
run checkMesh checkMesh
foamDictionary -entry endTime -set 0.01 system/controlDict >> "$RES" 2>&1 || true
foamDictionary -entry writeInterval -set 0.01 system/controlDict >> "$RES" 2>&1 || true
run foamRun foamRun -solver incompressibleFluid
ls -d [0-9]* 2>/dev/null | tee -a "$RES"
echo "SERIAL_PITZDAILY_OK" | tee -a "$RES"
