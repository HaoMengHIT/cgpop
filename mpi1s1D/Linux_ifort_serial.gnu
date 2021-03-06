#
# File:  ibm_serial.gnu
#
# The commenting in this file is intended for occasional maintainers who 
# have better uses for their time than learning "make", "awk", etc.  There 
# will someday be a file which is a cookbook in Q&A style: "How do I do X?" 
# is followed by something like "Go to file Y and add Z to line NNN."
#
FC = ifort
LD = ifort
CC = cc
Cp = /bin/cp
Cpp = /usr/bin/cpp -P -traditional
AWK = /usr/bin/awk
ABI = 
COMMDIR = serial
 

NETCDFINC = -I/opt/netcdf.ifort/include
NETCDFLIB = -L/opt/netcdf.ifort/lib

#  Disable SERIAL library for parallel code, yes/no.

MPI = no

#  Enable trapping and traceback of floating point exceptions, yes/no.
#  Note - Requires 'setenv TRAP_FPE "ALL=ABORT,TRACE"' for traceback.

TRAP_FPE = no

#------------------------------------------------------------------
#  precompiler options
#------------------------------------------------------------------

#DCOUPL              = -Dcoupled

Cpp_opts =   \
      $(DCOUPL) -D_R8 -I../../libtfs

Cpp_opts := $(Cpp_opts) -DPOSIX $(NETCDFINC)
 
#----------------------------------------------------------------------------
#
#                           C Flags
#
#----------------------------------------------------------------------------
 
CFLAGS = $(ABI)

ifeq ($(OPTIMIZE),yes)
  CFLAGS := $(CFLAGS) -O
else
  CFLAGS := $(CFLAGS) -g
endif
 
#----------------------------------------------------------------------------
#
#                           FORTRAN Flags
#
#----------------------------------------------------------------------------
 
FBASE = $(ABI) -nothreads -w90 -Vaxlib $(NETCDFINC) -I$(ObjDepDir)

ifeq ($(TRAP_FPE),yes)
  FBASE := $(FBASE) -qflttrap=overflow:zerodivide:enable -qspillsize=32704
endif

ifeq ($(OPTIMIZE),yes)
#  FFLAGS = $(FBASE) -g -pg -O4 -qnoipa -qmaxmem=-1 -qstrict
  FFLAGS = $(FBASE) -O2
else
  FFLAGS := $(FBASE) -g 
# below does bounds checking
# FFLAGS := $(FBASE) -g -C
endif
 
#----------------------------------------------------------------------------
#
#                           Loader Flags and Libraries
#
#----------------------------------------------------------------------------
 
LDFLAGS = $(FFLAGS)
 
#LIBS = $(NETCDFLIB) -lnetcdf -lX11
LIBS = $(NETCDFLIB) -lnetcdf
 
ifeq ($(MPI),yes)
#  LIBS := $(LIBS) -lmpi
endif

ifeq ($(TRAP_FPE),yes)
  LIBS := $(LIBS) 
endif
 
#LDLIBS = $(TARGETLIB) $(LIBRARIES) $(LIBS)
LDLIBS = $(LIBS)
 
#----------------------------------------------------------------------------
#
#                           Explicit Rules for Compilation Problems
#
#----------------------------------------------------------------------------

#----------------------------------------------------------------------------
#
#                           Implicit Rules for Compilation
#
#----------------------------------------------------------------------------
 
# Cancel the implicit gmake rules for compiling
%.o : %.f
%.o : %.f90
%.o : %.c

%.o: %.f
	@echo IBM Compiling with implicit rule $<
	@$(FC) $(FFLAGS) -c $<
	@if test -f *.mod; then mv -f *.mod $(ObjDepDir); fi
 
%.o: %.f90
	@echo IBM Compiling with implicit rule $<
	$(FC) $(FFLAGS) -c $<
	@if test -f *.mod; then mv -f *.mod $(ObjDepDir); fi
 
%.o: %.c
	@echo IBM Compiling with implicit rule $<
	@$(CC) $(Cpp_opts) $(CFLAGS) -c $<

#----------------------------------------------------------------------------
#
#                           Implicit Rules for Dependencies
#
#----------------------------------------------------------------------------
 
ifeq ($(OPTIMIZE),yes)
  DEPSUF = .do
else
  DEPSUF = .d
endif

# Cancel the implicit gmake rules for preprocessing

%.c : %.C
%.o : %.C

%.f90 : %.F90
%.o : %.F90

%.f : %.F
%.o : %.F

%.h : %.H
%.o : %.H

# Preprocessing  dependencies are generated for Fortran (.F, F90) and C files
$(SrcDepDir)/%$(DEPSUF): %.F
	@echo 'IBM Making depends for preprocessing' $<
	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.f
	@echo '$(*).f: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

$(SrcDepDir)/%$(DEPSUF): %.F90
	@echo 'IBM Making depends for preprocessing' $<
	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.f90
	@echo '$(*).f90: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

$(SrcDepDir)/%$(DEPSUF): %.C
	@echo 'IBM Making depends for preprocessing' $<
#  For some reason, our current Cpp options are incorrect for C files.
#  Therefore, let the C compiler take care of #ifdef's, etc.  Just copy.
#	@$(Cpp) $(Cpp_opts) $< >$(TOP)/compile/$*.c
	@$(Cp) $< $(TOP)/compile/$*.c
	@echo '$(*).c: $(basename $<)$(suffix $<)' > $(SrcDepDir)/$(@F)

# Compiling dependencies are generated for all normal .f files
$(ObjDepDir)/%$(DEPSUF): %.f
	@if test -f $(TOP)/compile/$*.f;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.f; fi
	@echo 'IBM Making depends for compiling' $<
	@$(AWK) -f $(TOP)/fdepends.awk -v NAME=$(basename $<) -v ObjDepDir=$(ObjDepDir) -v SUF=$(suffix $<) -v DEPSUF=$(DEPSUF) $< > $(ObjDepDir)/$(@F)

# Compiling dependencies are generated for all normal .f90 files
$(ObjDepDir)/%$(DEPSUF): %.f90
	@if test -f $(TOP)/compile/$*.f90;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.f90; fi
	@echo 'IBM Making depends for compiling' $<
	@$(AWK) -f $(TOP)/fdepends.awk -v NAME=$(basename $<) -v ObjDepDir=$(ObjDepDir) -v SUF=$(suffix $<) -v DEPSUF=$(DEPSUF) $< > $(ObjDepDir)/$(@F)

# Compiling dependencies are also generated for all .c files, but 
# locally included .h files are not treated.  None exist at this 
# time.  The two .c files include only system .h files with names 
# delimited by angle brackets, "<...>"; these are not, and should 
# not, be analyzed.  If the c programming associated with this code 
# gets complicated enough to warrant it, the file "cdepends.awk" 
# will need to test for includes delimited by quotes.
$(ObjDepDir)/%$(DEPSUF): %.c
	@if test -f $(TOP)/compile/$*.c;  \
       then : ; \
       else $(Cp) $< $(TOP)/compile/$*.c; fi
	@echo 'IBM Making depends for compiling' $<
	@echo '$(*).o $(ObjDepDir)/$(*)$(DEPSUF): $(basename $<)$(suffix $<)' > $(ObjDepDir)/$(@F)
