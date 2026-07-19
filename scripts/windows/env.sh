#!/bin/bash
# OpenFOAM-13 native Windows (MinGW-w64 / MSYS2 UCRT64) build environment.
#
# Serial (dummy Pstream) by default. No `subst` drive and no case-sensitive NTFS
# attribute are required. Source this before building or running.
#
# Configurable via environment (all optional; defaults shown):
#   OF13_ROOT   base dir holding the OpenFOAM clone + the ThirdParty-13-Windows
#               sibling clone (default: /c/OF13WinNormal — an EXAMPLE path)
#   OF13_CLONE  the OpenFOAM-13-Windows working copy
#               (default: $OF13_ROOT/OpenFOAM-13-Windows)
#   OF13_THIRDPARTY  the ThirdParty-13-Windows sibling clone
#               (default: $OF13_ROOT/ThirdParty-13-Windows; override for an
#                existing tree, e.g. /c/OF13WinNormal/ThirdParty)
#   OF13_USER   WM_PROJECT_USER_DIR for user libs/apps
#               (default: /c/OF13User/of-user)
# The only hard requirement is a case-collision-free tree (audit == 0) and a
# path prefix short enough that hashed object dirs stay < MAX_PATH.
set -euo pipefail
if [ "${MSYSTEM:-}" != "UCRT64" ]; then echo "need MSYS2 UCRT64 shell (MSYSTEM=UCRT64)"; exit 1; fi
export MSYS=winsymlinks:nativestrict

OF13_ROOT="${OF13_ROOT:-/c/OF13WinNormal}"
export WM_PROJECT_DIR="${OF13_CLONE:-$OF13_ROOT/OpenFOAM-13-Windows}"
[ -d "$WM_PROJECT_DIR/etc" ] || { echo "OpenFOAM clone not found at $WM_PROJECT_DIR (set OF13_ROOT/OF13_CLONE)"; exit 1; }

export WM_PROJECT=OpenFOAM
export WM_PROJECT_VERSION=13
export WM_COMPILER=Gcc
export WM_COMPILER_TYPE=system
export WM_ARCH=mingw_w64
export WM_ARCH_OPTION=64
export WM_COMPILER_LIB_ARCH=64
export WM_PRECISION_OPTION=DP
export WM_LABEL_SIZE=32
export WM_LABEL_OPTION=Int32
export WM_COMPILE_OPTION=Opt
export WM_OSTYPE=MSwindows
# WM_MPLIB / FOAM_MPI are selected below, once FOAM_LIBBIN is known (so the real
# MS-MPI Pstream can be detected). WM_OPTIONS does not depend on WM_MPLIB.
export WM_CC=gcc; export WM_CXX=g++; export WM_LINK_LANGUAGE=c++
export WM_OPTIONS="${WM_ARCH}${WM_COMPILER}${WM_PRECISION_OPTION}${WM_LABEL_OPTION}${WM_COMPILE_OPTION}"
export WM_DIR="$WM_PROJECT_DIR/wmake"
export WM_PROJECT_INST_DIR="$OF13_ROOT"
export FOAM_SRC="$WM_PROJECT_DIR/src"
export FOAM_APP="$WM_PROJECT_DIR/applications"
export FOAM_MODULES="$FOAM_APP/modules"
export FOAM_APPBIN="$WM_PROJECT_DIR/platforms/$WM_OPTIONS/bin"
export FOAM_LIBBIN="$WM_PROJECT_DIR/platforms/$WM_OPTIONS/lib"
# ThirdParty lives in a SIBLING repo (ThirdParty-13-Windows), cloned next to the
# OpenFOAM clone -- not a sub-directory of it. Override OF13_THIRDPARTY to point at
# an existing tree, e.g.  export OF13_THIRDPARTY=/c/OF13WinNormal/ThirdParty
export OF13_THIRDPARTY="${OF13_THIRDPARTY:-$OF13_ROOT/ThirdParty-13-Windows}"
export WM_THIRD_PARTY_DIR="$OF13_THIRDPARTY"
_extArch="${WM_ARCH}${WM_COMPILER}${WM_PRECISION_OPTION}${WM_LABEL_OPTION}"
export FOAM_EXT_LIBBIN="$WM_THIRD_PARTY_DIR/platforms/$_extArch/lib"
export SCOTCH_ARCH_PATH="$WM_THIRD_PARTY_DIR/platforms/$_extArch/scotch_7.0.8"
# ThirdParty decomposition selection (upstream etc/bashrc equivalents, with
# override honoured). Scotch is the supported ThirdParty decomposition on
# Windows; Zoltan/METIS/ParMETIS are not built in the initial port, so their
# Allwmake stages skip cleanly.
export SCOTCH_TYPE="${SCOTCH_TYPE:-ThirdParty}"
export ZOLTAN_TYPE="${ZOLTAN_TYPE:-none}"
export METIS_TYPE="${METIS_TYPE:-none}"
export PARMETIS_TYPE="${PARMETIS_TYPE:-none}"
export FOAM_ETC="$WM_PROJECT_DIR/etc"
export FOAM_TUTORIALS="$WM_PROJECT_DIR/tutorials"
export FOAM_UTILITIES="$FOAM_APP/utilities"
export FOAM_SOLVERS="$FOAM_APP/solvers"

# The MS-MPI installers export MSMPI_INC/MSMPI_BIN in WINDOWS form with a
# trailing backslash (e.g. C:\Program Files\Microsoft MPI\Bin\). Normalise both
# to POSIX form without the trailing slash: a drive-letter path cannot be used
# in a colon-separated PATH, and a trailing backslash escapes the closing quote
# of the -isystem "$(MSMPI_INC)" argument in wmake's mplibMSMPI rule, so the
# compiler never receives the SDK include directory.
for _v in MSMPI_INC MSMPI_BIN; do
    eval "_msmpiVal=\${$_v:-}"
    if [ -n "$_msmpiVal" ]; then
        _msmpiVal="$(cygpath -u "$_msmpiVal" 2>/dev/null || echo "$_msmpiVal")"
        eval "export $_v=\"\${_msmpiVal%/}\""
    fi
done
unset _v _msmpiVal

# Put MS-MPI's mpiexec on PATH if present (installer default or $MSMPI_BIN) so
# parallel launches -- and the MS-MPI auto-detection just below -- work out of
# the box. Harmless for serial builds.
_msmpiBin="${MSMPI_BIN:-/c/Program Files/Microsoft MPI/Bin}"
if [ -x "$_msmpiBin/mpiexec.exe" ]; then
    case ":$PATH:" in
        *":$_msmpiBin:"*) ;;
        *) PATH="$_msmpiBin:$PATH"; export PATH ;;
    esac
fi
unset _msmpiBin

# --- MPI library (Pstream) selection ----------------------------------------
# Parallel runs need the REAL MS-MPI Pstream ($FOAM_LIBBIN/msmpi/libPstream.dll);
# the dummy Pstream aborts under mpiexec ("cannot be used in parallel mode"),
# once per rank. Serial work can use the dummy. When the caller has NOT pinned
# WM_MPLIB, auto-select MS-MPI for a parallel-ready shell if the real Pstream has
# been built AND the MS-MPI runtime (mpiexec) is on PATH; otherwise stay serial.
# Build scripts set WM_MPLIB=Dummy explicitly to keep the serial bootstrap
# regardless of what is installed. (Set WM_MPLIB=MSMPI to force MS-MPI.)
if [ -z "${WM_MPLIB:-}" ]; then
    if [ -f "$FOAM_LIBBIN/msmpi/libPstream.dll" ] && command -v mpiexec >/dev/null 2>&1; then
        WM_MPLIB=MSMPI
    else
        WM_MPLIB=Dummy
    fi
fi
export WM_MPLIB
# FOAM_MPI selects the Pstream sub-directory; follow WM_MPLIB unless overridden.
if [ -z "${FOAM_MPI:-}" ]; then
    case "$WM_MPLIB" in
        MSMPI*) FOAM_MPI=msmpi ;;
        *)      FOAM_MPI=dummy ;;
    esac
fi
export FOAM_MPI
export WM_PROJECT_USER_DIR="${OF13_USER:-/c/OF13User/of-user}"
export FOAM_USER_LIBBIN="$WM_PROJECT_USER_DIR/platforms/$WM_OPTIONS/lib"
export FOAM_USER_APPBIN="$WM_PROJECT_USER_DIR/platforms/$WM_OPTIONS/bin"
# $WM_PROJECT_DIR/bin holds the OpenFOAM driver scripts (foamRunTutorials,
# foamCleanTutorials, foamLog, ...) that Allrun/Alltest call -- on Linux the etc
# bashrc puts it on PATH; do the same here.
export PATH="$WM_PROJECT_DIR/bin:$WM_DIR:$WM_DIR/platforms/${WM_ARCH}${WM_COMPILER}:$FOAM_APPBIN:$FOAM_USER_APPBIN:$PATH"
# $FOAM_LIBBIN first so real plugin DLLs win; $FOAM_LIBBIN/dummy last as the
# fallback for stub decomposition plugins (e.g. scotch/metis when ThirdParty is
# not built), mirroring the dummy entry on Linux LD_LIBRARY_PATH.
export PATH="$FOAM_LIBBIN:$FOAM_LIBBIN/$FOAM_MPI:$FOAM_USER_LIBBIN:$FOAM_LIBBIN/dummy:$PATH"
export WM_NCOMPPROCS="${WM_NCOMPPROCS:-$(nproc 2>/dev/null || echo 4)}"
export WM_SCHEDULER=
# Windows form of THIS MSYS2 bash, for OpenFOAM's run-time Foam::system() calls
# (#codeStream/#calc -> wmake, foamJob, the 'system' function object). A native
# process must launch this bash EXPLICITLY: a bare "bash" PATH search from a
# native/cmd context resolves to C:\Windows\System32\bash.exe (WSL), a separate
# Linux environment with no /c mounts, no OpenFOAM and no wmake.
export FOAM_BASH="$(cygpath -w "$(command -v bash)" 2>/dev/null || echo 'C:\msys64\usr\bin\bash.exe')"
echo "OF13 Windows env: WM_PROJECT_DIR=$WM_PROJECT_DIR (prefix $(printf '%s' "$WM_PROJECT_DIR" | wc -c) chars, no subst); WM_OPTIONS=$WM_OPTIONS WM_MPLIB=$WM_MPLIB"
