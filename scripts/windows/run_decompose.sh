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
# Standard decomposeParDict: only the method is named, exactly as on Linux.
# No `libs (...)` entry is needed -- the scotch plugin is loaded on demand by
# decompositionMethod::New (the OpenFOAM plugin mechanism), and turbulence/model
# libs are not needed either (decomposePar reads unknown BCs such as
# nutkWallFunction through the generic patch-field fallback).
cat > system/decomposeParDict <<'EOF'
FoamFile { format ascii; class dictionary; location "system"; object decomposeParDict; }
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
