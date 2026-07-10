#!/bin/bash
# OpenFOAM-13 native Windows interactive shell setup (MSYS2 UCRT64 / MinGW-w64).
#
# Sourced as the bash --rcfile by OpenFOAM-13-Windows-Shell.cmd (or source it
# yourself). It loads the OpenFOAM environment, sets a visible prompt, prepares
# $FOAM_RUN, and prints how to use the standard OpenFOAM tutorial workflow.
#
# Independent, clean-room implementation.
#
# Configurable via environment (defaults are EXAMPLES, override freely):
#   OF13_ROOT   base dir holding the clone + ThirdParty (default /c/OF13WinNormal)
#   OF13_CLONE  the OpenFOAM-13-Windows working copy
#   OF13_WORK   where $FOAM_RUN and run logs live (default $OF13_ROOT)

# Give an interactive shell first (aliases, completion, ...).
[ -f /etc/bash.bashrc ] && . /etc/bash.bashrc
[ -f "$HOME/.bashrc" ]  && . "$HOME/.bashrc"

# Where this rcfile (and env.sh) live.
_OF_SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

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
    # env.sh runs with 'set -e'; keep the interactive shell alive afterwards.
    . "$_OF_SELFDIR/env.sh"
    set +e +u +o pipefail 2>/dev/null

    export MPI_BUFFER_SIZE="${MPI_BUFFER_SIZE:-20000000}"
    export FOAM_RUN="${FOAM_RUN:-${OF13_WORK:-$OF13_ROOT}/run}"
    mkdir -p "$FOAM_RUN" 2>/dev/null
    cd "$FOAM_RUN" 2>/dev/null || cd "$OF13_ROOT" 2>/dev/null

    # Visible prompt marking the OpenFOAM Windows environment.
    PS1='\[\e[1;32m\]OF13-Windows\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '

    of13help() {
        cat <<'HLP'
OpenFOAM-13 (native Windows, MinGW-w64 / MS-MPI)

Typical OpenFOAM usage (standard workflow):
  cd $FOAM_RUN
  cp -r $FOAM_TUTORIALS/incompressibleFluid/pitzDaily .
  cd pitzDaily
  ./Allrun

Manual usage:
  blockMesh
  checkMesh
  decomposePar
  mpiexec -n 2 foamRun -solver incompressibleFluid -parallel
  reconstructPar

Windows port smoke tests (NOT standard OpenFOAM scripts -- validation only):
  bash $WM_PROJECT_DIR/scripts/windows/run_serial.sh
  bash $WM_PROJECT_DIR/scripts/windows/run_parallel.sh

Notes:
  - Parallel uses Microsoft MPI (mpiexec). RunFunctions' runParallel calls
    mpiexec on Windows; Linux keeps mpirun.
  - decomposePar needs no manual turbulence libs (generic patch-field fallback);
    a decomposition method plugin (e.g. scotch) is still named via 'libs (...)'.
  - Type 'of13help' to show this again.
HLP
    }

    echo "Setting environment for OpenFOAM 13 mingw-w64 Double Precision (of13-win), using MS-MPI..."
    echo "Environment is now ready."
    echo
    of13help
fi

unset _OF_SELFDIR _OF_ROOT _OF_CLONE
