#!/bin/bash
# OpenFOAM-13 native Windows interactive shell setup (MSYS2 UCRT64 / MinGW-w64).
#
# Sourced as the bash --rcfile by the Windows launchers
# (OpenFOAM-13-Windows-Terminal.cmd / OpenFOAM-13-Windows-Shell.cmd), or source
# it yourself. It loads the OpenFOAM environment, sets a compact modern banner
# and prompt, prepares $FOAM_RUN, and defines the of13help / of13status helpers.
#
# Independent, clean-room implementation.
#
# Configurable via environment (defaults are EXAMPLES, override freely):
#   OF13_ROOT   base dir holding the clone + ThirdParty (default /c/OF13WinNormal)
#   OF13_CLONE  the OpenFOAM-13-Windows working copy
#   OF13_WORK   where $FOAM_RUN and run logs live (default $OF13_ROOT)

# A --rcfile shell is interactive but NOT a login shell, so MSYS2's login-time
# PATH setup (/etc/profile) has not run and /usr/bin is missing -- external
# tools like dirname/cygpath/mkdir would fail with "command not found". Restore
# the MSYS2 environment for the current MSYSTEM (UCRT64) before anything else.
# ('.' and command are bash builtins, so they work without /usr/bin.)
if ! command -v dirname >/dev/null 2>&1; then
    [ -f /etc/profile ] && . /etc/profile
fi

# Give an interactive shell first (aliases, completion, ...).
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc
[ -f "$HOME/.bashrc" ]  && . "$HOME/.bashrc"

# Where this rcfile (and env.sh) live. Use bash-native expansion (no external
# 'dirname') so this still works even if PATH is not set up yet.
_OF_SELFSRC="${BASH_SOURCE[0]}"
_OF_SELFDIR="${_OF_SELFSRC%/*}"
[ "$_OF_SELFDIR" = "$_OF_SELFSRC" ] && _OF_SELFDIR="."
_OF_SELFDIR="$(cd "$_OF_SELFDIR" 2>/dev/null && pwd || echo "$_OF_SELFDIR")"

# Accept a Windows-style OF13_ROOT (C:\...) passed from the .cmd launcher.
if [ -n "${OF13_ROOT:-}" ]; then
    case "$OF13_ROOT" in
        *\\*|[A-Za-z]:*) OF13_ROOT="$(cygpath -u "$OF13_ROOT" 2>/dev/null || echo "$OF13_ROOT")";;
    esac
    export OF13_ROOT
fi

_OF_ROOT="${OF13_ROOT:-/c/OF13WinNormal}"
_OF_CLONE="${OF13_CLONE:-$_OF_ROOT/OpenFOAM-13-Windows}"

if [ ! -f "$_OF_SELFDIR/env.sh" ]; then
    echo "OpenFOAM shell: env.sh not found next to openfoam_shell.sh ($_OF_SELFDIR)."
elif [ ! -d "$_OF_CLONE/etc" ]; then
    echo "OpenFOAM shell: clone not found at $_OF_CLONE"
    echo "  Set OF13_ROOT (currently ${OF13_ROOT:-unset}) to your OpenFOAM-13-Windows base and relaunch."
else
    # env.sh runs with 'set -e' and prints its own status line; keep the
    # interactive shell alive afterwards and silence its stdout so startup
    # shows only the compact banner below (exports still take effect).
    . "$_OF_SELFDIR/env.sh" >/dev/null
    set +e +u +o pipefail 2>/dev/null

    export MPI_BUFFER_SIZE="${MPI_BUFFER_SIZE:-20000000}"
    export FOAM_RUN="${FOAM_RUN:-${OF13_WORK:-$OF13_ROOT}/run}"
    mkdir -p "$FOAM_RUN" 2>/dev/null
    cd "$FOAM_RUN" 2>/dev/null || cd "$OF13_ROOT" 2>/dev/null

    # Put MS-MPI's mpiexec on PATH if present (installer default location or
    # $MSMPI_BIN) so parallel runs work out of the box.
    _ofMPIbin="${MSMPI_BIN:-/c/Program Files/Microsoft MPI/Bin}"
    if [ -x "$_ofMPIbin/mpiexec.exe" ]; then
        case ":$PATH:" in
            *":$_ofMPIbin:"*) ;;
            *) export PATH="$_ofMPIbin:$PATH";;
        esac
    fi
    unset _ofMPIbin

    # --- ANSI colours (only when writing to a terminal) -------------------
    if [ -t 1 ]; then
        _ofC=$'\e[1;36m'   # bold cyan  (title / accent)
        _ofB=$'\e[1;34m'   # bold blue  (paths)
        _ofD=$'\e[0;90m'   # dim grey   (labels/help)
        _ofR=$'\e[0m'      # reset
    else
        _ofC='' ; _ofB='' ; _ofD='' ; _ofR=''
    fi

    # --- Modern two-line prompt (dark- and light-terminal readable) -------
    PS1="\[${_ofC}\]OF13-Windows\[${_ofR}\] \[${_ofB}\]\w\[${_ofR}\]\n\$ "

    # --- help ------------------------------------------------------------
    of13help() {
        cat <<HLP
${_ofC}OpenFOAM 13 Windows -- help${_ofR}

${_ofD}Standard OpenFOAM workflow (recommended):${_ofR}
  cd \$FOAM_RUN
  cp -r \$FOAM_TUTORIALS/incompressibleFluid/pitzDaily .
  cd pitzDaily
  ./Allrun                 # Allclean to reset the case

${_ofD}Manual commands:${_ofR}
  blockMesh                # or: blockMesh -dict <path>
  checkMesh
  decomposePar             # standard decomposeParDict (see below)
  mpiexec -n 2 foamRun -solver incompressibleFluid -parallel
  reconstructPar

${_ofD}Decomposition (scotch):${_ofR}
  system/decomposeParDict needs only the standard entries, e.g.:
      numberOfSubdomains 2;
      method          scotch;
  No 'libs (...)' entry is required -- the scotch plugin loads on demand,
  exactly as on Linux. Wall-function BCs (nutkWallFunction, ...) are read
  through the generic patch-field fallback, so no model libs are needed either.
  (Case function objects may still use the normal OpenFOAM 'libs (...)'.)

${_ofD}Parallel (MS-MPI):${_ofR}
  Uses Microsoft MPI: 'mpiexec -n N'. RunFunctions' runParallel calls mpiexec
  on Windows (mpirun on Linux; override with \$FOAM_MPIRUN). MPI_BUFFER_SIZE is
  set for you.

${_ofD}Windows-port validation scripts (NOT the standard workflow):${_ofR}
  bash \$WM_PROJECT_DIR/scripts/windows/run_serial.sh     # serial smoke test
  bash \$WM_PROJECT_DIR/scripts/windows/run_parallel.sh   # parallel smoke test
  These only exercise the toolchain end-to-end; use ./Allrun for real cases.

Type 'of13status' for environment details.
HLP
    }

    # --- status ----------------------------------------------------------
    of13status() {
        local _mpiexec _foamrun _pathsum
        _mpiexec="$(command -v mpiexec 2>/dev/null || echo '(not found)')"
        _foamrun="$(command -v foamRun 2>/dev/null || echo '(not found)')"
        _pathsum="$(printf '%s' "$PATH" | tr ':' '\n' | grep -iE 'platforms|Microsoft MPI|ucrt64/bin' | head -6 | tr '\n' ' ')"
        printf '%sOpenFOAM 13 Windows -- environment%s\n\n' "$_ofC" "$_ofR"
        printf '  %-18s %s\n' "WM_PROJECT_DIR"    "${WM_PROJECT_DIR:-(unset)}"
        printf '  %-18s %s\n' "WM_THIRD_PARTY_DIR" "${WM_THIRD_PARTY_DIR:-(unset)}"
        printf '  %-18s %s\n' "FOAM_RUN"          "${FOAM_RUN:-(unset)}"
        printf '  %-18s %s\n' "FOAM_APPBIN"       "${FOAM_APPBIN:-(unset)}"
        printf '  %-18s %s\n' "FOAM_LIBBIN"       "${FOAM_LIBBIN:-(unset)}"
        printf '  %-18s %s\n' "WM_OPTIONS"        "${WM_OPTIONS:-(unset)}"
        printf '  %-18s %s\n' "WM_MPLIB"          "${WM_MPLIB:-(unset)}"
        printf '  %-18s %s\n' "MSYSTEM"           "${MSYSTEM:-(unset)}"
        printf '  %-18s %s\n' "MPI_BUFFER_SIZE"   "${MPI_BUFFER_SIZE:-(unset)}"
        printf '  %-18s %s\n' "which foamRun"     "$_foamrun"
        printf '  %-18s %s\n' "which mpiexec"     "$_mpiexec"
        printf '  %-18s %s\n' "PATH (OF/MPI)"     "${_pathsum:-(none)}"
    }

    # --- compact startup banner ------------------------------------------
    if command -v mpiexec >/dev/null 2>&1; then _ofMPI="MS-MPI via mpiexec"
    else _ofMPI="serial (mpiexec not on PATH)"; fi
    printf '%sOpenFOAM 13 for Windows%s\n' "$_ofC" "$_ofR"
    printf '%sNative MinGW-w64 / MS-MPI environment ready%s\n\n' "$_ofD" "$_ofR"
    printf '%s%-8s%s%s\n' "$_ofD" "Project" "$_ofR" "${WM_PROJECT_DIR}"
    printf '%s%-8s%s%s\n' "$_ofD" "Run dir" "$_ofR" "${FOAM_RUN}"
    printf '%s%-8s%s%s\n' "$_ofD" "MPI" "$_ofR" "${_ofMPI}"
    printf '%s%-8s%s%s\n\n' "$_ofD" "Options" "$_ofR" "${WM_OPTIONS}"
    printf '%sTypical workflow%s\n' "$_ofD" "$_ofR"
    printf '  cd $FOAM_RUN\n'
    printf '  cp -r $FOAM_TUTORIALS/incompressibleFluid/pitzDaily .\n'
    printf '  cd pitzDaily\n'
    printf '  ./Allrun\n\n'
    printf "Type '%sof13help%s' for help \xc2\xb7 '%sof13status%s' for diagnostics\n" \
        "$_ofC" "$_ofR" "$_ofC" "$_ofR"
    unset _ofMPI
fi

unset _OF_SELFSRC _OF_SELFDIR _OF_ROOT _OF_CLONE
