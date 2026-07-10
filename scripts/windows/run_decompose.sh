#!/bin/bash
# Decomposition smoke: blockMesh + decomposePar (scotch method) on pitzDaily.
# Requires ThirdParty Scotch built (build_scotch.sh) so libscotchDecomp exists.
# Output dir: $OF13_WORK/run/pitzDecomp.
source "$(dirname "$0")/env.sh"
set +e
WORK="${OF13_WORK:-$OF13_ROOT}"
CASE="$WORK/run/pitzDecomp"
RES="$WORK/run_decompose.out"; : > "$RES"
rm -rf "$CASE"; mkdir -p "$(dirname "$CASE")"
cp -r "$WM_PROJECT_DIR/tutorials/incompressibleFluid/pitzDaily" "$CASE"
cd "$CASE"
printf 'FoamFile { format ascii; class dictionary; location "system"; object functions; }\n' > system/functions
# scotch is a runtime-loaded decomposition-method plugin, so it is named via
# libs (as on any platform). Turbulence-model libs are NOT needed: decomposePar
# links genericFvFields and reads unknown BCs (e.g. nutkWallFunction) with the
# generic patch-field fallback -- the whole-archive EXE_LIBS fix makes that DLL
# actually load on Windows, matching Linux (no manual model libs required).
cat > system/decomposeParDict <<'EOF'
FoamFile { format ascii; class dictionary; location "system"; object decomposeParDict; }
libs            ("libscotchDecomp.so");
numberOfSubdomains 2;
method          scotch;
EOF
run() { local d="$1"; shift; echo "=== $d ===" | tee -a "$RES"; "$@" >> "$RES" 2>&1; local rc=$?; echo "=== EXIT($d)=$rc ===" | tee -a "$RES"; [ "$rc" -eq 0 ] || { echo "FAIL $d"; tail -25 "$RES"; exit "$rc"; }; }
run blockMesh blockMesh -dict "$FOAM_TUTORIALS/resources/blockMesh/pitzDaily"
run decomposePar decomposePar
for p in processor0 processor1; do
    [ -f "$p/constant/polyMesh/owner" ] && echo "  $p mesh OK" | tee -a "$RES" || { echo "  $p mesh MISSING"; exit 1; }
done
echo "DECOMPOSE_SCOTCH_OK" | tee -a "$RES"
