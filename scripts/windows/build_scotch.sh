#!/bin/bash
# Compatibility wrapper: Scotch is built by the sibling ThirdParty repository's
# own Allwmake (ThirdParty-13-Windows), which ./Allwmake already invokes
# automatically, exactly as on Linux. This helper reruns just that stage, for
# debugging or for a ThirdParty clone added after the main build.
source "$(dirname "$0")/env.sh"
set +e
if [ ! -d "$WM_THIRD_PARTY_DIR" ]
then
    echo "FAIL: no ThirdParty tree at $WM_THIRD_PARTY_DIR"
    echo "      Clone ThirdParty-13-Windows as a sibling of the OpenFOAM clone,"
    echo "      or point OF13_THIRDPARTY at an existing tree."
    exit 1
fi
if [ ! -x "$WM_THIRD_PARTY_DIR/Allwmake" ]
then
    echo "FAIL: $WM_THIRD_PARTY_DIR/Allwmake not found or not executable"
    exit 1
fi
"$WM_THIRD_PARTY_DIR/Allwmake"
rc=$?
if [ -e "$FOAM_EXT_LIBBIN/libscotch.a" ] || [ -e "$FOAM_EXT_LIBBIN/libscotch.dll" ]
then
    echo "SCOTCH_BUILT_OK"
else
    echo "SCOTCH_BUILD_INCOMPLETE"
    [ "$rc" -eq 0 ] && rc=1
fi
exit $rc
