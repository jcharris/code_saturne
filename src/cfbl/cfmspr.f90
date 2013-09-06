!-------------------------------------------------------------------------------

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

subroutine cfmspr &
!================

 ( nvar   , nscal  , ncepdp , ncesmp ,                            &
   icepdc , icetsm , itypsm ,                                     &
   dt     , rtp    , rtpa   , propce , propfb ,                   &
   coefa  , coefb  , ckupdc , smacel )

!===============================================================================
! FONCTION :
! ----------

! SOLVING OF A CONVECTION-DIFFUSION EQUATION WITH SOURCE TERMS
!   FOR PRESSURE ON ONE TIME-STEP
!   (COMPRESSIBLE ALGORITHM IN P,U,E)

!-------------------------------------------------------------------------------
!ARGU                             ARGUMENTS
!__________________.____._____.________________________________________________.
! name             !type!mode ! role                                           !
!__________________!____!_____!________________________________________________!
! nvar             ! i  ! <-- ! total number of variables                      !
! nscal            ! i  ! <-- ! total number of scalars                        !
! ncepdp           ! i  ! <-- ! number of cells with head loss                 !
! ncesmp           ! i  ! <-- ! number of cells with mass source term          !
! itspdv           ! e  ! <-- ! calcul termes sources prod et dissip           !
!                  !    !     !  (0 : non , 1 : oui)                           !
! icepdc(ncelet    ! te ! <-- ! numero des ncepdp cellules avec pdc            !
! icetsm(ncesmp    ! te ! <-- ! numero des cellules a source de masse          !
! itypsm           ! te ! <-- ! type de source de masse pour les               !
! (ncesmp,nvar)    !    !     !  variables (cf. ustsma)                        !
! dt(ncelet)       ! ra ! <-- ! time step (per cell)                           !
! rtp, rtpa        ! ra ! <-- ! calculated variables at cell centers           !
!  (ncelet, *)     !    !     !  (at current and previous time steps)          !
! propce(ncelet, *)! ra ! <-- ! physical properties at cell centers            !
! propfb(nfabor, *)! ra ! <-- ! physical properties at boundary face centers   !
! tslagr           ! tr ! <-- ! terme de couplage retour du                    !
!(ncelet,*)        !    !     !     lagrangien                                 !
! coefa, coefb     ! ra ! <-- ! boundary conditions                            !
!  (nfabor, *)     !    !     !                                                !
! ckupdc           ! tr ! <-- ! work array for the head loss                   !
!  (ncepdp,6)      !    !     !                                                !
! smacel           ! tr ! <-- ! variable value associated to the mass source   !
! (ncesmp,*   )    !    !     ! term (for ivar=ipr, smacel is the mass flux    !
!                  !    !     ! \f$ \Gamma^n \f$)                              !
!__________________!____!_____!________________________________________________!

!     TYPE : E (ENTIER), R (REEL), A (ALPHANUMERIQUE), T (TABLEAU)
!            L (LOGIQUE)   .. ET TYPES COMPOSES (EX : TR TABLEAU REEL)
!     MODE : <-- donnee, --> resultat, <-> Donnee modifiee
!            --- tableau de travail
!-------------------------------------------------------------------------------
!===============================================================================

!===============================================================================
! Module files
!===============================================================================

use paramx
use numvar
use entsor
use optcal
use cstphy
use cstnum
use parall
use period
use ppppar
use ppthch
use ppincl
use mesh
use pointe, only: itypfb
use field

!===============================================================================

implicit none

! Arguments

integer          nvar   , nscal
integer          ncepdp , ncesmp

integer          icepdc(ncepdp)
integer          icetsm(ncesmp), itypsm(ncesmp,nvar)

double precision dt(ncelet), rtp(ncelet,*), rtpa(ncelet,*)
double precision propce(ncelet,*)
double precision propfb(nfabor,*)
double precision coefa(nfabor,*), coefb(nfabor,*)
double precision ckupdc(ncepdp,6), smacel(ncesmp,nvar)

! Local variables

character*80     chaine
integer          ivar
integer          ifac  , iel
integer          init  , inc   , iccocg, isqrt , ii, jj, iii
integer          iclvar, iclvaf
integer          iflmas, iflmab, ipcrom, ipbrom
integer          ippvar, ipp   , iphydp, icvflb
integer          nswrgp, imligp, iwarnp
integer          istatp, iconvp, idiffp, ireslp, ndircp, nitmap
integer          nswrsp, ircflp, ischcp, isstpp, iescap
integer          imgrp , ncymxp, nitmfp
integer          ivoid(1)
double precision epsrgp, climgp, extrap, blencp, epsilp
double precision epsrsp
double precision sclnor

integer          iccfth, imodif
integer          idimte, itenso
integer          iij
integer          imucpp, idftnp, iswdyp
integer          imvis1

double precision dijpfx, dijpfy, dijpfz
double precision diipfx, diipfy, diipfz, djjpfx, djjpfy, djjpfz
double precision diipbx, diipby, diipbz
double precision pip, pjp, thetv, relaxp, hint

double precision rvoid(1)

double precision, allocatable, dimension(:) :: viscf, viscb
double precision, allocatable, dimension(:) :: smbrs, rovsdt
double precision, allocatable, dimension(:,:) :: grad
double precision, allocatable, dimension(:) :: w1
double precision, allocatable, dimension(:) :: w7, w8, w9
double precision, allocatable, dimension(:) :: w10
double precision, allocatable, dimension(:) :: wflmas, wflmab
double precision, allocatable, dimension(:) :: wbfa, wbfb
double precision, allocatable, dimension(:) :: dpvar

double precision, allocatable, dimension(:) :: c2

double precision, dimension(:), pointer :: imasfl, bmasfl
double precision, dimension(:), pointer :: rhopre

!===============================================================================
!===============================================================================
! 1. INITIALISATION
!===============================================================================

! Allocate temporary arrays for the mass resolution
allocate(viscf(nfac), viscb(nfabor))
allocate(smbrs(ncelet), rovsdt(ncelet))
allocate(wflmas(nfac), wflmab(nfabor))

allocate(wbfa(nfabor), wbfb(nfabor))

! Allocate work arrays
allocate(w1(ncelet))
allocate(w7(ncelet), w8(ncelet), w9(ncelet))
allocate(w10(ncelet))
allocate(dpvar(ncelet))

! --- Number of computational variable and post for pressure

ivar   = ipr
ippvar = ipprtp(ivar)

! --- Number of boundary conditions
iclvar = iclrtp(ivar,icoef)
iclvaf = iclrtp(ivar,icoeff)

! --- Flux de masse associe a l'energie
call field_get_key_int(ivarfl(isca(ienerg)), kimasf, iflmas)
call field_get_key_int(ivarfl(isca(ienerg)), kbmasf, iflmab)
call field_get_val_s(iflmas, imasfl)
call field_get_val_s(iflmab, bmasfl)

ipcrom = ipproc(irom)
ipbrom = ipprob(irom)

chaine = nomvar(ippvar)

if(iwarni(ivar).ge.1) then
  write(nfecra,1000) chaine(1:8)
endif

! Coefficients for the reconstruction of the pressure gradient
! computed from the diffusion coefficient coefaf, coefbf
! (A Neumann BC has been stored in coefaf, coefbf)
do ifac = 1, nfabor
  iel = ifabor(ifac)
  hint = dt(iel) / distb(ifac)
  wbfa(ifac) = -coefa(ifac,iclvaf) / hint
  wbfb(ifac) = 1.d0
enddo

! Retrieve the density field at the previous iteration
call field_get_val_s(iprpfl(ipproc(iroma)), rhopre)

!===============================================================================
! 2. SOURCE TERMS
!===============================================================================

! --> Initialization

do iel = 1, ncel
  smbrs(iel) = 0.d0
enddo
do iel = 1, ncel
  rovsdt(iel) = 0.d0
enddo


!     MASS SOURCE TERM
!     ================

if (ncesmp.gt.0) then
  do ii = 1, ncesmp
    iel = icetsm(ii)
    smbrs(iel) = smbrs(iel) + smacel(iel,ipr)*volume(iel)
  enddo
endif


!     UNSTEADY TERM
!     =============

! --- Calculation of the square of sound velocity c2
!     Pressure is an unsteady variable in this algorithm
!     Varpos has been modified for that

allocate(c2(ncelet))
iccfth = 126
imodif = 0
call cfther                                                       &
!==========
 ( nvar   ,                                                       &
   iccfth , imodif ,                                              &
   dt     , rtp    , rtpa   , propce , propfb ,                   &
   c2     , w7     , w8     , w9     , rvoid  , rvoid )

do iel = 1, ncel
  rovsdt(iel) = rovsdt(iel) + istat(ivar)*(volume(iel)/(dt(iel)*c2(iel)))
enddo

!===============================================================================
! 3. "MASS FLUX" AND FACE "VISCOSITY" CALCULATION
!===============================================================================

!     Here VISCF et VISCB are both work arrays.
!     WFLMAS et WFLMAB are calculated

call cfmsfp                                                                     &
!==========
( nvar   , nscal  , ncepdp , ncesmp ,                                           &
  icepdc , icetsm , itypsm ,                                                    &
  dt     , rtp    , rtpa   , propce , propfb ,                                  &
  coefa  , coefb  , ckupdc , smacel ,                                           &
  wflmas , wflmab ,                                                             &
  viscf  , viscb  )

do ifac = 1, nfac
  ii = ifacel(1,ifac)
  jj = ifacel(2,ifac)
  wflmas(ifac) = -0.5d0*                                                        &
                 ( propce(ii,ipcrom)*(wflmas(ifac)+abs(wflmas(ifac)))           &
                 + propce(jj,ipcrom)*(wflmas(ifac)-abs(wflmas(ifac))))
enddo

do ifac = 1, nfabor
  iel = ifabor(ifac)
  wflmab(ifac) = -bmasfl(ifac)
enddo

init = 0
call divmas(ncelet,ncel,nfac,nfabor,init,nfecra,                                &
            ifacel,ifabor,wflmas,wflmab,smbrs)

! (Delta t)_ij is calculated as the "viscocity" associated to the pressure
imvis1 = 1

call viscfa                                                                     &
!==========
( imvis1 ,                                                                      &
  dt     ,                                                       &
  viscf  , viscb  )

!===============================================================================
! 4. SOLVING
!===============================================================================

istatp = istat (ivar)
iconvp = iconv (ivar)
idiffp = idiff (ivar)
ireslp = iresol(ivar)
ndircp = ndircl(ivar)
nitmap = nitmax(ivar)
nswrsp = nswrsm(ivar)
nswrgp = nswrgr(ivar)
imligp = imligr(ivar)
ircflp = ircflu(ivar)
ischcp = ischcv(ivar)
isstpp = isstpc(ivar)
iescap = 0
imucpp = 0
idftnp = idften(ivar)
iswdyp = iswdyn(ivar)
imgrp  = imgr  (ivar)
ncymxp = ncymax(ivar)
nitmfp = nitmgf(ivar)
ipp    = ippvar
iwarnp = iwarni(ivar)
blencp = blencv(ivar)
epsilp = epsilo(ivar)
epsrsp = epsrsm(ivar)
epsrgp = epsrgr(ivar)
climgp = climgr(ivar)
extrap = extrag(ivar)
relaxp = relaxv(ivar)
thetv  = thetav(ivar)
icvflb = 0

call codits                                                                     &
!==========
( idtvar , ivar   , iconvp , idiffp , ireslp , ndircp , nitmap ,                &
  imrgra , nswrsp , nswrgp , imligp , ircflp ,                                  &
  ischcp , isstpp , iescap , imucpp , idftnp , iswdyp ,                         &
  imgrp  , ncymxp , nitmfp , ipp    , iwarnp ,                                  &
  blencp , epsilp , epsrsp , epsrgp , climgp , extrap ,                         &
  relaxp , thetv  ,                                                             &
  rtpa(1,ivar)    , rtpa(1,ivar)    ,                                           &
  wbfa   , wbfb   ,                                                             &
  coefa(1,iclvaf) , coefb(1,iclvaf) ,                                           &
  wflmas          , wflmab          ,                                           &
  viscf  , viscb  , rvoid  , viscf  , viscb  , rvoid  ,                         &
  rvoid  , rvoid  ,                                                             &
  icvflb , ivoid  ,                                                             &
  rovsdt , smbrs  , rtp(1,ivar)     , dpvar  ,                                  &
  rvoid  , rvoid  )

!===============================================================================
! 5. PRINTINGS AND CLIPPINGS
!===============================================================================

! --- User intervention for a finer management of the bounds and possible
!       corrective treatement.

iccfth = -2
imodif = 0

call cfther                                                                     &
!==========
( nvar   ,                                                                      &
  iccfth , imodif  ,                                                            &
  dt     , rtp    , rtpa   , propce , propfb ,                                  &
  w7     , w8     , w9     , w10    , rvoid  , rvoid )


! --- Explicit balance (see codits : the increment is withdrawn)

if (iwarni(ivar).ge.2) then
  do iel = 1, ncel
    smbrs(iel) = smbrs(iel)                                                     &
                 - istat(ivar)*(volume(iel)/dt(iel))                            &
                   *(rtp(iel,ivar)-rtpa(iel,ivar))                              &
                   * max(0,min(nswrsm(ivar)-2,1))
  enddo
  isqrt = 1
  call prodsc(ncel,isqrt,smbrs,smbrs,sclnor)
  write(nfecra,1200) chaine(1:8) ,sclnor
endif

!===============================================================================
! 6. COMMUNICATION OF P
!===============================================================================

if (irangp.ge.0.or.iperio.eq.1) then
  call synsca(rtp(1,ivar))
endif

!===============================================================================
! 7. ACOUSTIC MASS FLUX CALCULATION AT THE FACES
!===============================================================================

! mass flux = [dt (grad P).n] + [rho (u + dt f)]

! Computation of [dt (grad P).n] by itrmas
init   = 1
inc    = 1
iccocg = 1
iphydp = 0
! festx,y,z    = rvoid
! viscf, viscb = arithmetic mean at faces
! viscelx,y,z  = dt
! This flux is stored as the mass flux of the energy

call itrmas                                                                     &
!==========
( init   , inc    , imrgra , iccocg , nswrgp , imligp ,                         &
  iphydp , iwarnp , nfecra ,                                                    &
  epsrgp , climgp , extrap ,                                                    &
  rvoid  ,                                                                      &
  rtp(1,ivar)     ,                                                             &
  wbfa   , wbfb   ,                                                             &
  coefa(1,iclvaf) , coefb(1,iclvaf) ,                                           &
  viscf  , viscb  ,                                                             &
  dt     , dt     , dt     ,                                                    &
  imasfl, bmasfl)

! incrementation of the flux with [rho (u + dt f)].n = wflmas
! (added with a negative sign since WFLMAS,WFLMAB was used above
!  in the right hand side).
do ifac = 1, nfac
  imasfl(ifac) = imasfl(ifac) - wflmas(ifac)
enddo
do ifac = 1, nfabor
  bmasfl(ifac) = bmasfl(ifac) - wflmab(ifac)
enddo

!===============================================================================
! 8. UPDATING OF THE DENSITY
!===============================================================================

if (igrdpp.gt.0) then

  do iel = 1, ncel
    ! Backup of the current density values
    rhopre(iel) = propce(iel,ipcrom)
    ! Update of density values
    propce(iel,ipcrom) = propce(iel,ipcrom)+(rtp(iel,ivar)-rtpa(iel,ivar))/c2(iel)
  enddo

!===============================================================================
! 9. DENSITY COMMUNICATION
!===============================================================================

  if (irangp.ge.0.or.iperio.eq.1) then
    call synsca(propce(1,ipcrom))
    call synsca(rhopre(1))
  endif

endif

! There are no clippings on density because we consider that pressure
! and energy have been checked and are correct so that the density
! is also correct through the state law or the linearized law.

deallocate(c2)
deallocate(viscf, viscb)
deallocate(smbrs, rovsdt)
deallocate(wflmas, wflmab)
deallocate(w1)
deallocate(w7, w8, w9)
deallocate(w10)
deallocate(dpvar)
deallocate(wbfa, wbfb)

!--------
! FORMATS
!--------

 1000 format(/,                                                                 &
'   ** RESOLUTION FOR THE VARIABLE ',A8                        ,/,              &
'      ---------------------------                            ',/)
 1200 format(1X,A8,' : EXPLICIT BALANCE = ',E14.5)

!----
! END
!----

return
end subroutine
