#============================================================================
#
#                    Code_Saturne version 1.3
#                    ------------------------
#
#
#     This file is part of the Code_Saturne Kernel, element of the
#     Code_Saturne CFD tool.
#
#     Copyright (C) 1998-2007 EDF S.A., France
#
#     contact: saturne-support@edf.fr
#
#     The Code_Saturne Kernel is free software; you can redistribute it
#     and/or modify it under the terms of the GNU General Public License
#     as published by the Free Software Foundation; either version 2 of
#     the License, or (at your option) any later version.
#
#     The Code_Saturne Kernel is distributed in the hope that it will be
#     useful, but WITHOUT ANY WARRANTY; without even the implied warranty
#     of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with the Code_Saturne Kernel; if not, write to the
#     Free Software Foundation, Inc.,
#     51 Franklin St, Fifth Floor,
#     Boston, MA  02110-1301  USA
#
#============================================================================
#
# Macros du Makefile Code_Saturne pour IRIX64
#############################################
#
# Macros pour BFT
#----------------

BFT_HOME       = /home/saturne/opt/bft-1.0.5/arch/IRIX64
BFT_INC        = -I$(BFT_HOME)/include
BFT_LDFLAGS    = -L$(BFT_HOME)/lib -lbft

# Macros pour FVM
#----------------

FVM_HOME       = /home/saturne/opt/fvm-0.8.0/arch/IRIX64
FVM_INC        = -I$(FVM_HOME)/include
FVM_LDFLAGS    = -L$(FVM_HOME)/lib -lfvm

# Macro pour MPI
#---------------

# Option MPI
MPI             =0
MPE             =0
MPE_COMM        =1
MPI_INC         =
MPI_LIB         =


# Macro pour XML
#---------------

# Option XML
XML             =1

XML_HOME = /home/saturne/opt/libxml2-2.6.19

XML_INC  =-I$(XML_HOME)/include/libxml2
XML_LIB  =-L$(XML_HOME)/arch/IRIX64/lib -lxml2

# Macro pour BLAS
#----------------

# Option BLAS
BLAS            =0
BLAS_INC        =
BLAS_CFLAGS     =
BLAS_LDFLAGS    =

# Macro pour Sockets
#-------------------

# Option Socket
SOCKET          =1
SOCKET_INC      =
SOCKET_LIB      =


# Preprocesseur
#--------------

PREPROC         =
PREPROCFLAGS    =

# Compilateur C natif
#--------------------
# MIPSpro Compilers: Version 7.30

CCOMP                  = $(CC) -64
CCOMPFLAGSDEF          = -ansi -woff 1521,1552,1096 -c99
CCOMPFLAGS             = $(CCOMPFLAGSDEF) -O2  
CCOMPFLAGSOPTPART1     = $(CCOMPFLAGSDEF) -O2 -INLINE:list=ON:must=Orient3D_split,Orient3D_normalize,Orient3D_set_maxvalue
CCOMPFLAGSOPTPART2     = $(CCOMPFLAGSDEF) -O2 
CCOMPFLAGSOPTPART3     = $(CCOMPFLAGSDEF) -O2 
CCOMPFLAGSLO           = $(CCOMPFLAGSDEF) -O0  
CCOMPFLAGSDBG          = $(CCOMPFLAGSDEF) -g   
CCOMPFLAGSPROF         = -fbexe
CCOMPFLAGSVERS         = -version


# Compilateur FORTRAN
#--------------------
# Option `-TARG:exc_min=UOZV' trap floating exceptions 
#              (Underflow, Overflow, divide by Zero, inValid)
#    ceci n'est cpdt pas toujours compatible avec toutes les 
#    optimisations at runtime (cf rld "aggregate IEEE exceptions")

FTNCOMP                = f77 -64
FTNCOMPFLAGSDEF        = 
FTNCOMPFLAGS           = $(FTNCOMPFLAGSDEF) -O2
FTNCOMPFLAGSOPTPART1   = $(FTNCOMPFLAGSDEF) -O2
FTNCOMPFLAGSOPTPART2   = $(FTNCOMPFLAGSDEF) -O2
FTNCOMPFLAGSOPTPART3   = $(FTNCOMPFLAGSDEF) -O2
FTNCOMPFLAGSLO         = $(FTNCOMPFLAGSDEF) -O0
FTNCOMPFLAGSDBG        = $(FTNCOMPFLAGSDEF) -g
FTNCOMPFLAGSPROF       = -fbexe
FTNCOMPFLAGSVERS       = -version

FTNPREPROCOPT          =

# Linker
#-------

# Linker


LDEDL           = $(CC) -64
LDEDLFLAGS      = -woff 85
LDEDLFLAGSLO    = -O0
LDEDLFLAGSDBG   = -g -Wl,-woff,85
LDEDLFLAGSPROF  = -fbexe
LDEDLFLAGSVERS  = -version
LDEDLRPATH      = -Wl,-rpath -Wl,

# Positionnement des variables pour le pre-processeur
#----------------------------------------------------
#
# _POSIX_SOURCE          : utilisation des fonctions standard POSIX

VARDEF          = -D_POSIX_SOURCE


# Librairies a "linker"
#----------------------

# Librairies de base toujours prises en compte

LIBBASIC = $(BFT_LDFLAGS) $(FVM_LDFLAGS) -lm -lfortran -lftn -lmalloc

# Librairies en mode sans option

LIBOPT   =

# Librairies en mode optimisation reduite

LIBLO    =

# Librairies en mode DEBUG

LIBDBG   =

# Librairie en mode ElectricFence (malloc debugger)

LIBEF    =-L/home/saturne/opt/ElectricFence-2.0.5/lib/IRIX64 -lefence

# Liste eventuelle des fichiers a compiler avec des options particulieres
#------------------------------------------------------------------------

# Sous la forme :
# LISTE_OPT_PART = fic_1.c fic_2.c \
#                fic_3.F
#
#  Pour le fichier c, il s'agit de permettre l'inline (non ansi)

LISTE_OPT_PART1 = cs_lagrang.c cs_matrix.c cs_sles.c cs_blas.c cs_benchmark.c
LISTE_OPT_PART2 =
LISTE_OPT_PART3 =

