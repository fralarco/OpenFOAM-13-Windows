#!/bin/bash
# Build the Windows-viable ThirdParty package: Scotch 7.0.8 (serial libscotch)
# natively with MinGW-w64, as STATIC .a libraries, and install headers+libs to
# SCOTCH_ARCH_PATH + FOAM_EXT_LIBBIN. Requires a MinGW Makefile.inc in
# $WM_THIRD_PARTY_DIR/scotch_7.0.8/src (see scripts/windows/scotch/Makefile.inc).
source "$(dirname "$0")/env.sh"
set +e
WORK="${OF13_WORK:-$OF13_ROOT}"
RES="$WORK/build_scotch.out"; : > "$RES"
SRC="$WM_THIRD_PARTY_DIR/scotch_7.0.8/src"
echo "SCOTCH_ARCH_PATH=$SCOTCH_ARCH_PATH" | tee -a "$RES"
[ -f "$SRC/Makefile.inc" ] || { echo "FAIL: no $SRC/Makefile.inc (copy scripts/windows/scotch/Makefile.inc there)"; exit 1; }
mkdir -p "$SCOTCH_ARCH_PATH/include" "$SCOTCH_ARCH_PATH/lib" "$FOAM_EXT_LIBBIN"
cd "$SRC" || { echo "no scotch src at $SRC"; exit 1; }
make realclean >/dev/null 2>&1
( cd libscotch && make VERSION=7 RELEASE=0 PATCHLEVEL=8 scotch ) >> "$RES" 2>&1
echo "make libscotch rc=$?" | tee -a "$RES"
for h in scotch.h scotchf.h; do f=$(find "$SRC/.." -name "$h" 2>/dev/null | head -1); [ -n "$f" ] && cp "$f" "$SCOTCH_ARCH_PATH/include/"; done
for l in libscotch libscotcherr libscotcherrexit; do for ext in .dll .dll.a .a; do f=$(find "$SRC/.." -name "$l$ext" 2>/dev/null | head -1); [ -n "$f" ] && { cp "$f" "$SCOTCH_ARCH_PATH/lib/"; cp "$f" "$FOAM_EXT_LIBBIN/"; }; done; done
{ [ -e "$FOAM_EXT_LIBBIN/libscotch.a" ] || [ -e "$FOAM_EXT_LIBBIN/libscotch.dll" ]; } && echo "SCOTCH_BUILT_OK" | tee -a "$RES" || echo "SCOTCH_BUILD_INCOMPLETE" | tee -a "$RES"
