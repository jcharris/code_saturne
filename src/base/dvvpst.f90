!-------------------------------------------------------------------------------

! This file is part of code_saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2022 EDF S.A.
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

!> \file dvvpst.f90
!> \brief Standard output of variables on post-processing meshes
!> (called after \ref cs_user_extra_operations).
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!> \param[in]     nummai        post-processing mesh number
!> \param[in]     numtyp        post-processing type number
!>                               - -1: volume
!>                               - -2: edge
!>                               - default: nummai
!> \param[in]     nvar          total number of variables
!> \param[in]     nfbrps        number of boundary faces
!> \param[in]     lstfbr        post-processing mesh boundary faces numbers
!> \param[in,out] trafbr        post processing boundary faces real values
!______________________________________________________________________________

subroutine dvvpst &
 (nummai, numtyp, nvar, nfbrps, lstfbr, trafbr)

!===============================================================================
! Module files
!===============================================================================

use paramx
use entsor
use cstnum
use optcal
use numvar
use mesh
use field
use post
use cs_f_interfaces

!===============================================================================

implicit none

! Arguments

integer          nummai , numtyp
integer          nvar
integer          nfbrps

integer          lstfbr(nfbrps)

double precision trafbr(nfbrps*3)

! Local variables

character(len=80) :: name80

logical          ientla, ivarpr
integer          ifac  , iloc  , ivar
integer          idimt , kk   , ll, iel
integer          fldid, fldprv, keycpl, iflcpl
integer          iflpst

double precision rbid(1)

double precision, dimension(:), pointer :: valsp, coefap, coefbp
double precision, dimension(:,:), pointer :: valvp, cofavp, cofbvp
double precision, dimension(:,:,:), pointer :: cofbtp

!===============================================================================

if (numtyp .eq. -2) then

  !  Projection of variables at boundary with no reconstruction
  !  ----------------------------------------------------------

  call field_get_key_id('coupled', keycpl)

  fldprv = -1

  do ivar = 1, nvar  ! Loop on main cell-based variables

    fldid = ivarfl(ivar)

    if (fldid .eq. fldprv) cycle ! already output for multiple components

    fldprv = fldid

    call field_get_key_int(fldid, keyvis, iflpst)

    if (iand(iflpst, POST_BOUNDARY_NR) .eq. 0) cycle ! nothing to do

    call field_get_dim (fldid, idimt)
    call field_get_name(fldid, name80(4:80))
    name80(1:3) = 'bc_'

    !  Compute non-reconstructed values at boundary faces

    if (idimt.ne.1) then
      call field_get_key_int(fldid, keycpl, iflcpl)
    else
      iflcpl = 0
    endif

    if (idimt.eq.1) then  ! Scalar

      call field_get_val_s(fldid, valsp)
      call field_get_coefa_s(fldid, coefap)
      call field_get_coefb_s(fldid, coefbp)

      do iloc = 1, nfbrps

        ifac = lstfbr(iloc)
        iel = ifabor(ifac)

        trafbr(iloc) =   coefap(ifac) + coefbp(ifac)*valsp(iel)

      enddo

    else if (iflcpl.eq.0) then  ! Uncoupled vector or tensor

      call field_get_val_v(fldid, valvp)
      call field_get_coefa_v(fldid, cofavp)
      call field_get_coefb_uv(fldid, cofbvp)

      do kk = 0, idimt-1

        do iloc = 1, nfbrps

          ifac = lstfbr(iloc)
          iel = ifabor(ifac)

          trafbr(kk + (iloc-1)*idimt + 1)                      &
               =   cofavp(kk+1,ifac)                           &
                 + cofbvp(kk+1,ifac)*valvp(kk+1,iel)

        enddo

      enddo

    else ! Coupled vector or tensor

      call field_get_val_v(fldid, valvp)
      call field_get_coefa_v(fldid, cofavp)
      call field_get_coefb_v(fldid, cofbtp)

      do kk = 0, idimt-1

        do iloc = 1, nfbrps

          ifac = lstfbr(iloc)
          iel = ifabor(ifac)

          trafbr(kk + (iloc-1)*idimt + 1) = cofavp(kk+1,ifac)

          do ll = 1, idimt
            trafbr(kk + (iloc-1)*idimt + 1)                    &
               =   trafbr(kk + (iloc-1)*idimt + 1)             &
                 + cofbtp(kk+1,ll,ifac)*valvp(ll,iel)
          enddo

        enddo

      enddo

    endif ! test on field dimension and interleaving

    ientla = .true.  ! interleaved result values
    ivarpr = .false. ! defined on work array

    call post_write_var(nummai, trim(name80), idimt, ientla, ivarpr,  &
                        ntcabs, ttcabs, rbid, rbid, trafbr)

  enddo ! End of loop on variables

endif ! end of test on postprocessing mesh number

!----
! End
!----

return
end subroutine
