!===============================================================================
! User synthetic turbulence inlet definition.
!
! 1) Global caracteristics of synthetic turbulence inlets
! 2) Caracteristics of one specific inlet
! 3) Accurate specification of target statistics at inlet
!===============================================================================

!-------------------------------------------------------------------------------

!VERS

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2012 EDF S.A.
!
! This program is free software; you can redistribute it and/or modify it under
! the terms of the GNU General Public License as published by the Free Software
! Foundation; either version 2 of the License, or (at your option) any later
! version.
!
! This program is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
! FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
! details.
!
! You should have received a copy of the GNU General Public License along with
! this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
! Street, Fifth Floor, Boston, MA 02110-1301, USA.

!-------------------------------------------------------------------------------

subroutine cs_user_les_inflow_init (nent)
!=================================

!===============================================================================
! Purpose :
! --------

! Generation of synthetic turbulence at LES inlets

! Definition of global caracteristics of synthetic turbulence inlets

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
!    nom           !type!mode !                   role                         !
!__________________!____!_____!________________________________________________!
! nent             ! i  ! <-- ! number of synthetic turbulence inlets          !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================


!===============================================================================
! Module files
!===============================================================================

use optcal

!===============================================================================

implicit none

! Arguments

integer nent

! Local variables

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if (1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!     Number of inlets

nent = 1

!     Reading of the LES inflow module restart file

!       ISUISY = 0 ------> not activated (synthetic turbulence reinitialized)
!       ISUISY = 1 ------> activated

isuisy = isuite

!--------
! Formats
!--------

!----
! End
!----

return
end subroutine

!===============================================================================

subroutine cs_user_les_inflow_define &
!===================================
( nument, typent, nelent, iverbo,                                             &
  nfbent, lfbent,                                                             &
  vitent, enrent, dspent                                                      &
)

!===============================================================================
! Purpose :
! --------

! Generation of synthetic turbulence at LES inlets

! Definition of the caracteristics of the synthetic turbulence inlet 'nument'

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
!    nom           !type!mode !                   role                         !
!__________________!____!_____!________________________________________________!
! nument           ! i  ! --> ! id of the inlet                                !
! typent           ! i  ! <-- ! type of inflow method at the inlet             !
! nelent           ! i  ! <-- ! numb. of entities of the inflow meth           !
! iverbo           ! i  ! <-- ! verbosity level                                !
! nfbent           ! i  ! <-- ! numb. of bound. faces of the inlet             !
! lfbent           ! ra ! <-- ! list of bound. faces of the inlet              !
! vitent           ! ra ! <-- ! ref. mean velocity at the inlet                !
! enrent           ! r  ! <-- ! ref. turb. kin. ener. at the inlet             !
! dspent           ! r  ! <-- ! ref. turb. dissipation at the inlet            !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use entsor
use mesh
use cstnum
use cstphy
use parall

!===============================================================================

implicit none

! Arguments

integer          nument, iverbo
integer          nfbent, typent, nelent
integer          lfbent(nfabor)

double precision vitent(3), enrent, dspent

! Local variables

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if (1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

if (nument.eq.1) then

!  - Data relatve to the method employed

!       typent indicates the synthetic turbulence method:

!         0 : laminar, no turbulent fluctations
!         1 : random gaussian noise
!         2 : Batten method, based on Fourier mode decomposition
!         3 : Synthetic Eddy Method (SEM)

!       nelent indicates the number of "entities" relative to the method
!       (usefull only for the Batten method and the SEM):

!         for Batten : number of Fourier modes of the turbulent fluctuations
!         for SEM    : number of synthetic eddies building the fluctuations

!       iverbo indicates the verbosity level (listing)

!          0  no specific output
!         > 0 additionnal output (only for SEM)

  typent = 3
  nelent = 2000
  iverbo = iwarni(iu)

!  - Data relative to the LES inflow boundary faces

!       nfbent: number of boundary faces of the LES inflow
!       lfbent: list of boundary faces of the LES inflow

  call getfbr('1 and x < 0.1',nfbent,lfbent)
  !==========

!  - Data relative to the flow

!       vitent(3): reference mean velocity vector
!       enrent   : reference turbulent kinetic energy
!       dspent   : reference dissipation rate

!       Note :
!       ----
!       - dspent usefull only for typent = 2 (Batten) or typent = 3 (SEM).
!       - Strictly positive values are required for enrent and dspent.
!       - Accurate specification of the statistics of the flow at LES inlet
!         can be made via the user subroutine cs_user_les_inflow_advanced.

  vitent(1) = 18.d0
  vitent(2) = 0.d0
  vitent(3) = 0.d0

  enrent = 4.d0
  dspent = 4.d0

endif

!--------
! Formats
!--------

!----
! End
!----

return
end subroutine

!===============================================================================

subroutine cs_user_les_inflow_advanced &
!=====================================

 ( nument , nfbent ,                                              &
   nvar   , nscal ,                                               &
   lfbent ,                                                       &
   dt     , rtpa   , rtp    , propce , propfa , propfb ,          &
   coefa  , coefb  ,                                              &
   uvwent , rijent , epsent )

!===============================================================================
! Purpose :
! --------

!    User subroutine.

!    Generation of synthetic turbulence at LES inlets

!    Accurate definition of mean velocity, Reynolds stresses and dissipation
!    rate for each boundary faces of the synthetic turbulence inlet 'nument'

! Usage
! -----
!     uvwent(ndim,nfbent) : mean velocity vector
!     rijent(   6,nfbent) : Reynolds stresses!
!     epsent(     nfbent) : dissipation rate

!    rijent components are ordonned as follow : 11, 22, 33, 12, 13, 23

!    Arrays are initialized before this subroutine is called by
!    (see the user subroutine cs_user_les_inflow_define):

!       uvwent(idim,ifac) = vitent(idim)

!       rijent(1,ifac)    = 2.d0/3.d0*enrent
!       rijent(2,ifac)    = 2.d0/3.d0*enrent
!       rijent(3,ifac)    = 2.d0/3.d0*enrent
!       rijent(4,ifac)    = 0.d0
!       rijent(5,ifac)    = 0.d0
!       rijent(6,ifac)    = 0.d0

!       epsent(ifac)      = dspent

!-------------------------------------------------------------------------------
! Arguments
!__________________.____._____.________________________________________________.
!    nom           !type!mode !                   role                         !
!__________________!____!_____!________________________________________________!
! nument           ! i  ! --> ! id of the inlet                                !
! nfbent           ! i  ! --> ! numb. of bound. faces of the inlet             !
! nvar             ! i  ! --> ! number of variables                            !
! nscal            ! i  ! --> ! number of scalars                              !
! lfbent           ! i  ! --> ! list of bound. faces of the inlet              !
! dt               ! r  ! --> ! time step                                      !
! rtpa             ! ra ! --> ! variables at cells (previous)                  !
! rtp              ! ra ! --> ! variables at cells                             !
! propce           ! ra ! --> ! physical properties at cells                   !
! propfa           ! ra ! --> ! physical properties at faces                   !
! propfb           ! ra ! --> ! physical properties at bound. faces            !
! coefa            ! ra ! --> ! boundary conditions array                      !
! coefb            ! ra ! --> ! boundary conditions array                      !
! uent             ! ra ! <-- ! mean velocity at the inlet faces               !
! rijent           ! ra ! <-- ! turb. kin. ener. at the inlet faces            !
! epsent           ! ra ! <-- ! turb. dissipation at the inlet faces           !
!__________________!____!_____!________________________________________________!

!     Type: i (integer), r (real), s (string), a (array), l (logical),
!           and composite types (ex: ra real array)
!     mode: <-- input, --> output, <-> modifies data, --- work array
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use optcal
use entsor
use cstphy
use cstnum
use mesh

!===============================================================================

implicit none

! Arguments

integer          nument , nfbent
integer          nvar   , nscal
integer          lfbent(nfbent)
integer          iutile

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfa(nfac,*), propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision uvwent(ndim,nfbent), rijent(6,nfbent)
double precision epsent(nfbent)

! Local variables

integer          ii, ifac, iel
integer          ipcvis
double precision d2s3
double precision utau, href, reyfro, yy, yplus, uplus, kplus, eplus
double precision uref2, xdh, xitur, xkent, xeent

!===============================================================================

! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_START
!===============================================================================

if (1.eq.1) return

!===============================================================================
! TEST_TO_REMOVE_FOR_USE_OF_SUBROUTINE_END

!===============================================================================
! 1.  Various initializations
!===============================================================================

d2s3 = 2.d0/3.d0
ipcvis = ipproc(iviscl)

! Approximation of the friction velocity
utau = uref/20.d0

! Reference length scale
href = 1.d0

!===============================================================================
! 2.  Arrays definition
!===============================================================================

if (nument.eq.1) then

  ! Example 1 : mean velocity, Reynolds stresses an dissipation are deduced
  !==========   from a wall law.

  iutile = 0
  if (iutile.eq.1) then

    do ii = 1, nfbent

      ifac = lfbent(ii)
      iel  = ifabor(ifac)

      reyfro = utau*href/propce(iel,ipcvis)

      ! Dimensionless wall distance
      yy = 1.d0-abs(cdgfbo(2,ifac))
      yplus = yy/href*reyfro

      ! Reichart laws (dimensionless)
      uplus = log(1.d0+0.4d0*yplus)/xkappa                          &
            + 7.8d0*( 1.d0 - exp(-yplus/11.d0)                      &
                    - yplus/11.d0*exp(-0.33d0*yplus))
      kplus = 0.07d0*yplus*yplus*exp(-yplus/8.d0)                   &
            + (1.d0 - exp(-yplus/20.d0))*4.5d0                      &
              / (1.d0 + 4.d0*yplus/reyfro)
      eplus = (1.d0/xkappa)                                        &
            / (yplus**4+15.d0**4)**(0.25d0)

      uvwent(1,ii) = uplus*utau
      uvwent(2,ii) = 0.d0
      uvwent(3,ii) = 0.d0

      rijent(1,ii) = d2s3*kplus*utau**2
      rijent(2,ii) = d2s3*kplus*utau**2
      rijent(3,ii) = d2s3*kplus*utau**2
      rijent(4,ii) = 0.d0
      rijent(5,ii) = 0.d0
      rijent(6,ii) = 0.d0

      epsent(ii) = eplus*utau**4/propce(iel,ipcvis)

    enddo

  endif

  ! Example 2 : Reynolds stresses and dissipation at the inlet are computed
  !==========   using the turbulence intensity and standard laws for
  !             a circular pipe.

  iutile = 0
  if (iutile.eq.1) then

    do ii = 1, nfbent

      ifac = lfbent(ii)
      iel  = ifabor(ifac)

      uvwent(1,ii) = 1.1d0
      uvwent(2,ii) = 1.1d0
      uvwent(3,ii) = 1.1d0

      uref2 = uvwent(1,ii)**2   &
            + uvwent(2,ii)**2   &
            + uvwent(3,ii)**2
      uref2 = max(uref2,1.d-12)

      ! Hydraulic diameter
      xdh = 0.075d0

      ! Turbulence intensity
      xitur = 0.02d0

      xkent = epzero
      xeent = epzero

      call keenin &
      !==========
    ( uref2, xitur, xdh, cmu, xkappa, xkent, xeent )

      rijent(1,ii) = d2s3*xkent
      rijent(2,ii) = d2s3*xkent
      rijent(3,ii) = d2s3*xkent
      rijent(4,ii) = 0.d0
      rijent(5,ii) = 0.d0
      rijent(6,ii) = 0.d0
      epsent(ii)   = xeent

    enddo

  endif

endif
! End of the test on the LES inflow number

!--------
! Formats
!--------

!----
! End
!----

return
end subroutine
