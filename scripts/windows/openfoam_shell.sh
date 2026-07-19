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

# Accept Windows-style paths (C:\...) passed from the .cmd/.ps1 launchers, which
# derive them from their own location so the clone can live anywhere.
for _ofVar in OF13_ROOT OF13_CLONE OF13_THIRDPARTY OF13_WORK; do
    eval "_ofVal=\${$_ofVar:-}"
    case "${_ofVal}" in
        '') continue;;
        *\\*|[A-Za-z]:*)
            _ofVal="$(cygpath -u "$_ofVal" 2>/dev/null || echo "$_ofVal")"
            eval "export $_ofVar=\"\$_ofVal\"";;
        *) eval "export $_ofVar=\"\$_ofVal\"";;
    esac
done
unset _ofVar _ofVal

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

    # (env.sh already put MS-MPI's mpiexec on PATH and auto-selected WM_MPLIB.)

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

${_ofD}Build from source (needed once, in this same shell):${_ofR}
  cd \$WM_PROJECT_DIR
  ./Allwmake               # -j N to limit parallel compilation, e.g. ./Allwmake -j 4
  Requires the MSYS2 UCRT64 toolchain:
      pacman -S mingw-w64-ucrt-x86_64-gcc make flex bison
  Scotch is built automatically from the sibling ThirdParty-13-Windows clone
  when it is present; it is skipped cleanly when it is not.

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
        local _mpiexec _foamrun _pathsum _gcc _missing _t _built
        _mpiexec="$(command -v mpiexec 2>/dev/null || echo '(not found)')"
        _foamrun="$(command -v foamRun 2>/dev/null || echo '(not found)')"
        _gcc="$(gcc -dumpversion 2>/dev/null || echo '(not found)')"
        _missing=
        for _t in gcc g++ make flex bison; do
            command -v "$_t" >/dev/null 2>&1 || _missing="$_missing $_t"
        done
        _built="$(ls "${FOAM_LIBBIN:-/nonexistent}"/*.dll 2>/dev/null | wc -l) libs, $(ls "${FOAM_APPBIN:-/nonexistent}"/*.exe 2>/dev/null | wc -l) apps"
        local _cases _mpicc _mpirun _tp
        _cases="$(command -v bc >/dev/null 2>&1 && echo 'bc: yes' || echo 'bc: MISSING (pacman -S bc)')"
        if [ -f "${MSMPI_INC:-/nonexistent}/mpi.h" ]; then _mpicc='SDK mpi.h: yes'
        else _mpicc='SDK mpi.h: MISSING (install msmpisdk.msi)'; fi
        if [ -f "${WM_THIRD_PARTY_DIR:-/nonexistent}/msmpi/lib/libmsmpi.a" ]; then
            _mpicc="$_mpicc, libmsmpi.a: yes"
        else _mpicc="$_mpicc, libmsmpi.a: MISSING (run setup_msmpi.sh)"; fi
        _mpirun="$(command -v mpiexec >/dev/null 2>&1 && echo 'mpiexec: yes' || echo 'mpiexec: MISSING (install msmpisetup.exe)')"
        _tp="$([ -d "${WM_THIRD_PARTY_DIR:-/nonexistent}" ] && echo 'present' || echo 'MISSING (Scotch skipped; set OF13_THIRDPARTY)')"
        _pathsum="$(printf '%s' "$PATH" | tr ':' '\n' | grep -iE 'platforms|Microsoft MPI|ucrt64/bin' | head -6 | tr '\n' ' ')"
        printf '%sOpenFOAM 13 Windows -- environment%s\n\n' "$_ofC" "$_ofR"
        printf '  %-18s %s\n' "WM_PROJECT_DIR"    "${WM_PROJECT_DIR:-(unset)}"
        printf '  %-18s %s\n' "WM_THIRD_PARTY_DIR" "${WM_THIRD_PARTY_DIR:-(unset)}"
        printf '  %-18s %s\n' "FOAM_RUN"          "${FOAM_RUN:-(unset)}"
        printf '  %-18s %s\n' "FOAM_APPBIN"       "${FOAM_APPBIN:-(unset)}"
        printf '  %-18s %s\n' "FOAM_LIBBIN"       "${FOAM_LIBBIN:-(unset)}"
        printf '  %-18s %s\n' "WM_OPTIONS"        "${WM_OPTIONS:-(unset)}"
        printf '  %-18s %s\n' "WM_MPLIB"          "${WM_MPLIB:-(unset)}"
        printf '  %-18s %s%s\n' "FOAM_MPI (Pstream)" "${FOAM_MPI:-(unset)}" \
            "$([ "${WM_MPLIB:-Dummy}" = "Dummy" ] && echo '  -> serial only, parallel unavailable' || echo '  -> parallel-ready')"
        printf '  %-18s %s\n' "MSYSTEM"           "${MSYSTEM:-(unset)}"
        printf '  %-18s %s\n' "MPI_BUFFER_SIZE"   "${MPI_BUFFER_SIZE:-(unset)}"
        printf '  %-18s %s\n' "which foamRun"     "$_foamrun"
        printf '  %-18s %s\n' "which mpiexec"     "$_mpiexec"
        printf '  %-18s %s\n' "gcc version"       "$_gcc"
        printf '  %-18s %s\n' "built"             "$_built"
        printf '  %-18s %s\n' "ThirdParty"        "$_tp"
        printf '  %-18s %s\n' "PATH (OF/MPI)"     "${_pathsum:-(none)}"
        printf '\n%sPrerequisites by capability%s\n' "$_ofC" "$_ofR"
        printf '  %-22s %s\n' "serial build" \
            "${_missing:+MISSING:$_missing}${_missing:-gcc g++ make flex bison: yes}"
        printf '  %-22s %s\n' "tutorial scripts"  "$_cases"
        printf '  %-22s %s\n' "MS-MPI compilation" "$_mpicc"
        printf '  %-22s %s\n' "parallel execution" "$_mpirun"
    }

    # --- compact startup banner ------------------------------------------
    # Report the ACTUAL Pstream mode from WM_MPLIB (not just mpiexec presence),
    # so the banner never claims MS-MPI while the dummy Pstream is active.
    case "${WM_MPLIB:-Dummy}" in
        MSMPI*) _ofMPI="MS-MPI (mpiexec)"; _ofReady="Native MinGW-w64 / MS-MPI environment ready";;
        *)      _ofMPI="serial only - dummy Pstream (parallel unavailable)"
                _ofReady="Native MinGW-w64 environment ready (serial - dummy Pstream)";;
    esac
    printf '%sOpenFOAM 13 for Windows%s\n' "$_ofC" "$_ofR"
    printf '%s%s%s\n\n' "$_ofD" "$_ofReady" "$_ofR"
    printf '%s%-8s%s%s\n' "$_ofD" "Project" "$_ofR" "${WM_PROJECT_DIR}"
    printf '%s%-8s%s%s\n' "$_ofD" "Run dir" "$_ofR" "${FOAM_RUN}"
    printf '%s%-8s%s%s\n' "$_ofD" "MPI" "$_ofR" "${_ofMPI}"
    printf '%s%-8s%s%s\n\n' "$_ofD" "Options" "$_ofR" "${WM_OPTIONS}"

    # ThirdParty is a SIBLING repository, not part of this clone. Validate the
    # resolved directory (OF13_THIRDPARTY override honoured by env.sh) and, when
    # absent, print the exact path expected and how to point elsewhere.
    if [ ! -d "$WM_THIRD_PARTY_DIR" ]; then
        printf '%sThirdParty not found:%s %s\n' "$_ofC" "$_ofR" "$WM_THIRD_PARTY_DIR"
        printf '  Scotch decomposition will be skipped by ./Allwmake. Either clone it\n'
        printf '  beside this repository, or point at an existing tree and relaunch:\n'
        printf '    export OF13_THIRDPARTY=/d/path/to/ThirdParty-13-Windows\n\n'
    fi

    # Prerequisites, reported per capability (see BUILD_WINDOWS.md). This shell
    # configures the environment only -- it never installs anything.
    _ofBuild= ; _ofCase=
    for _ofTool in gcc g++ make flex bison; do
        command -v "$_ofTool" >/dev/null 2>&1 || _ofBuild="$_ofBuild $_ofTool"
    done
    command -v bc >/dev/null 2>&1 || _ofCase=" bc"
    if [ -n "$_ofBuild" ]; then
        printf '%sMissing for a serial build:%s%s\n' "$_ofC" "$_ofR" "$_ofBuild"
        printf '  pacman -S mingw-w64-ucrt-x86_64-gcc make flex bison\n'
    fi
    if [ -n "$_ofCase" ]; then
        printf '%sMissing for tutorial scripts:%s%s   (pacman -S bc)\n' "$_ofC" "$_ofR" "$_ofCase"
    fi
    [ -n "$_ofBuild$_ofCase" ] && printf '\n'
    if command -v foamRun >/dev/null 2>&1; then
        printf '%sTypical workflow%s\n' "$_ofD" "$_ofR"
        printf '  cd $FOAM_RUN\n'
        printf '  cp -r $FOAM_TUTORIALS/incompressibleFluid/pitzDaily .\n'
        printf '  cd pitzDaily\n'
        printf '  ./Allrun\n\n'
    else
        printf '%sNot built yet -- build first (this takes a while)%s\n' "$_ofD" "$_ofR"
        printf '  cd $WM_PROJECT_DIR\n'
        printf '  ./Allwmake            # add -j N to limit parallel compilation\n\n'
    fi
    printf "Type '%sof13help%s' for help \xc2\xb7 '%sof13status%s' for diagnostics\n" \
        "$_ofC" "$_ofR" "$_ofC" "$_ofR"
    unset _ofMPI _ofReady _ofMissing _ofTool
fi

unset _OF_SELFSRC _OF_SELFDIR _OF_ROOT _OF_CLONE
