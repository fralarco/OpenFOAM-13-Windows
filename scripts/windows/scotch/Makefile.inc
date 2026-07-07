## Scotch 7.0.8 Makefile.inc for native Windows MinGW-w64 (UCRT64), serial.
## Copy this to $WM_THIRD_PARTY_DIR/scotch_7.0.8/src/Makefile.inc before running
## scripts/windows/build_scotch.sh.
##
## Adapted from etc/wmakeFiles/scotch/Makefile.inc.i686_pc_linux2.shlib-OpenFOAM:
##  - Static libraries (.a): a PE/COFF shared lib cannot carry the unresolved
##    SCOTCH_errorPrint references (those live in libscotcherr[exit]); static
##    archives can, and OpenFOAM's scotchDecomp links -lscotch -lscotcherrexit
##    together into its own DLL, resolving them there.
##  - No -DCOMMON_FILE_COMPRESS_GZ: transparent .gz I/O uses fork()/waitpid()
##    (POSIX, absent on MinGW) and is not needed for decomposition.
##  - -DCOMMON_PTHREAD_FILE: the file-(de)compress helper then uses
##    pthread_join/create instead of fork/waitpid (MinGW UCRT64 has winpthreads).
##  - -DCOMMON_OS_WINDOWS for scotch's Windows portability paths.
EXE		=
LIB		= .a
OBJ		= .o

MAKE		= make
AR		= ar
ARFLAGS		= -ruv
CAT		= cat
CCS		= gcc
CCP		= gcc
CCD		= gcc
CFLAGS		= -O3 -fPIC -DCOMMON_RANDOM_FIXED_SEED -DCOMMON_OS_WINDOWS -DCOMMON_PTHREAD_FILE -DSCOTCH_RENAME -Drestrict=__restrict -DIDXSIZE32

ifeq ($(WM_LABEL_OPTION),Int64)
CFLAGS		+= -DINTSIZE64
endif

CLIBFLAGS	= -shared
LDFLAGS		= -lm -lpthread
CP		= cp
LEX		= flex -Pscotchyy -olex.yy.c
FLEX		= $(LEX)
LN		= cp
MKDIR		= mkdir -p
MV		= mv
RANLIB		= ranlib
YACC		= bison -pscotchyy -y -b y
BISON		= $(YACC)
