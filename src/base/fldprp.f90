!-------------------------------------------------------------------------------

! This file is part of Code_Saturne, a general-purpose CFD tool.
!
! Copyright (C) 1998-2014 EDF S.A.
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

!> \file fldprp.f90
!> \brief Properties definition initialization, according to calculation type
!> selected by the user.
!>
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
! Arguments
!------------------------------------------------------------------------------
!   mode          name          role
!------------------------------------------------------------------------------
!______________________________________________________________________________

subroutine fldprp

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use numvar
use optcal
use cstphy
use cstnum
use entsor
use albase
use lagpar
use lagdim
use lagran
use parall
use ppppar
use ppthch
use coincl
use cpincl
use ppincl
use radiat
use ihmpre
use mesh
use field
use cs_c_bindings

!===============================================================================

implicit none

! Arguments

! Local variables

character(len=80) :: f_label, f_name, s_label, s_name
integer           :: iscal , f_id
integer           :: ii    , jj    , kk    , ll
integer           :: iok   , ippok
integer           :: iest  , ipropp

!===============================================================================
! Interfaces
!===============================================================================

interface

  ! Interface to C function returning number of user-defined properties

  function cs_parameters_n_added_properties() result(n) &
    bind(C, name='cs_parameters_n_added_properties')
    use, intrinsic :: iso_c_binding
    implicit none
    integer(c_int)                                           :: n
  end function cs_parameters_n_added_properties

  ! Interface to C function building user-defined properties

  subroutine cs_parameters_create_added_properties() &
    bind(C, name='cs_parameters_create_added_properties')
    use, intrinsic :: iso_c_binding
    implicit none
  end subroutine cs_parameters_create_added_properties

  !=============================================================================

end interface

!===============================================================================
! 0. INITIALISATIONS
!===============================================================================

! Initialize variables to avoid compiler warnings
ippok = 0

!===============================================================================
! 1. VERIFICATIONS ET POSITIONNEMENT DES PROPRIETES PPALES
!===============================================================================

! ---> 1.1 VERIFICATIONS
!      -----------------

iok = 0

! --- ivisls(iscal) doit etre non initialise pour les variances
!     Il prend la valeur du scalaire associe
!     Tous les tests qui suivent sont utilises pour le message
!       d'erreur eventuel.

if (nscaus.gt.0) then
  do jj = 1, nscaus
    ii    = jj
    iscal = iscavr(ii)
    ! Si on a une variance avec ivisls initialise : erreur
    if ((iscal.gt.0.and.iscal.le.nscal).and.ivisls(ii).ne.-1) then
      ll = 0
      do kk = 1, nscaus
        if (kk .eq.iscal) ll = kk
      enddo
      do kk = 1, nscapp
        if (iscapp(kk).eq.iscal) ll = -kk
      enddo
      if (ll.gt.0) then
        write(nfecra,7040) ii,ii,jj,iscal,ll,jj,ivisls(iscal)
      else
        write(nfecra,7041) ii,ii,jj,iscal,-ll,jj,ivisls(iscal)
      endif
      iok = iok + 1
      !     Si on n'a pas une variance std mais que ivisls est incorrect : erreur
    else if ( (iscal.le.0 .or.iscal.gt.nscal).and.                &
             (ivisls(ii).ne.0.and.ivisls(ii).ne.1)) then
      write(nfecra,7050) ii,jj,jj,ivisls(ii)
      iok = iok + 1
    endif
  enddo
endif

if (nscapp.gt.0) then
  do jj = 1, nscapp
    ii    = iscapp(jj)
    iscal = iscavr(ii)
    !       Si on a une variance avec ivisls initialise : erreur
    if ((iscal.gt.0.and.iscal.le.nscal).and.ivisls(ii).ne.-1) then
      ll = 0
      do kk = 1, nscaus
        if (kk .eq.iscal) ll = kk
      enddo
      do kk = 1, nscapp
        if (iscapp(kk).eq.iscal) ll = -kk
      enddo
      if (ll.gt.0) then
        write(nfecra,7042) ii,ii,jj,iscal,ll,jj,ivisls(iscal)
      else
        write(nfecra,7043) ii,ii,jj,iscal,-ll,jj,ivisls(iscal)
      endif
      iok = iok + 1
      ! Si on n'a pas une variance std mais que ivisls est incorrect : erreur
    else if ( (iscal.le.0 .or.iscal.gt.nscal).and.                &
              (ivisls(ii).ne.0.and.ivisls(ii).ne.1) ) then
      write(nfecra,7051)ii,jj,jj,ivisls(ii)
      iok = iok + 1
    endif
  enddo
endif

! On initialise les ivisls des variances
if (nscal.gt.0) then
  do ii = 1, nscal
    iscal = iscavr(ii)
    if (iscal.gt.0.and.iscal.le.nscal) then
      ivisls(ii) = ivisls(iscal)
      if (ivisls(ii).gt.0) then
        call field_set_key_int(ivarfl(isca(ii)), kivisl,    &
                               iprpfl(ivisls(iscal)))
      endif
    else if (ivisls(ii).lt.0) then
      ivisls(ii) = 0
    endif
  enddo
endif

! ---> VISCOSITE ALE
if (iale.eq.1) then
  if (iortvm.ne.0 .and. iortvm.ne.1) then
    write(nfecra,7070) iortvm
    iok = iok + 1
  endif
endif
! --- On s'arrete si quelque chose s'est mal passe

if (iok.ne.0) then
  call csexit (1)
endif


! ---> 1.2 POSITIONNEMENT DES PROPRIETES PRINCIPALES
!      --------------------------------

! --- Numerotation des proprietes presentes ici
!       Ceci depend du type de solveur branche derriere
!        (CP, Poly, Mono...)
!       Dans l'ideal, il y aurait donc plusieurs fldprp.

!       Pour le moment, on fait les hypotheses suivantes :
!         Il y a toujours, pour toutes les phases,  rho, viscl, visct
!         Il y a toujours la pression totale (sauf en compressible)
!         Lorsqu'elles sont variables, on a les proprietes suivantes :
!           . cp    (par phase)
!           . visls (par scalaire)
!           . csmago (par phase) en LES dynamique
!         En ALE on a la viscosite de maillage
!         On a aussi les flux de masse porteurs :
!           . les variables u,v,w,p,turbulence sont portees par leur
!               phase (1 flux)
!           . les scalaires sont portes par leur phase (1 flux)
!           On suppose donc qu'il n'y a pas de scalaire en
!             taux de vide a convecter avec un flux particulier (ce
!             serait possible : ca rajoute un test, par exemple
!             if alpro...

!     ATTENTION : on s'arrange pour numeroter a la queue-leu-leu sans
!       trous les proprietes qui sont definies au centre des cellules
!       ceci permet ensuite de ne pas se fatiguer lors de la
!       construction de IPPPRO plus bas.
!      Cependant, pour les physiques particulieres, ce n'est pas le cas.

! Base properties, always present

call add_property_field('density', 'Density', irom)
icrom = iprpfl(irom)
if (irovar.eq.0) then
  call hide_property(irom)
endif

call add_property_field('molecular_viscosity', 'Laminar Viscosity', iviscl)

if (iturb.eq.0) then
  call add_property_field_hidden('turbulent_viscosity', 1, ivisct)
else
  call add_property_field('turbulent_viscosity', 'Turb Viscosity', ivisct)
endif

call add_property_field('courant_number', 'CFL', icour)
call add_property_field('fourier_number', 'Fourier Number', ifour)

! Pression totale stockee dans IPRTOT, si on n'est pas en compressible
! (sinon Ptot=P* !)
if (ippmod(icompf).lt.0) then
  call add_property_field('total_pressure', 'Total Pressure', iprtot)
endif

! CP when variable
if (icp.ne.0) then
  call add_property_field('specific_heat', 'Specific Heat', icp)
endif

! Density at the second previous time step for cavitation algorithm
if (icavit.ge.0.or.idilat.eq.4) then
  call add_property_field('density_old', 'Density Old', iromaa)
  icroaa = iprpfl(iromaa)
endif

! Cs^2 si on est en LES dynamique
if (iturb.eq.41) then
  call add_property_field('smagorinsky_constant^2', 'Csdyn2', ismago)
else
  ismago = 0
endif

! Viscosite de maillage en ALE
if (iale.eq.1) then
  call add_property_field('mesh_viscosity_1', 'Mesh ViscX', ivisma(1))
  ! si la viscosite est isotrope, les trois composantes pointent
  !  au meme endroit
  if (iortvm.eq.0) then
    ivisma(2) = ivisma(1)
    ivisma(3) = ivisma(1)
  else
    call add_property_field('mesh_viscosity_2', 'Mesh ViscY', ivisma(2))
    call add_property_field('mesh_viscosity_3', 'Mesh ViscZ', ivisma(3))
  endif
endif

! Estimateurs d'erreur
do iest = 1, nestmx
  iestim(iest) = -1
enddo

if (iescal(iespre).gt.0) then
  write(f_name,  '(a14,i1)') 'est_error_pre_', iescal(iespre)
  write(f_label, '(a5,i1)') 'EsPre', iescal(iespre)
  call add_property_field(f_name, f_label, iestim(iespre))
endif
if (iescal(iesder).gt.0) then
  write(f_name,  '(a14,i1)') 'est_error_der_', iescal(iesder)
  write(f_label, '(a5,i1)') 'EsDer', iescal(iesder)
  call add_property_field(f_name, f_label, iestim(iesder))
endif
if (iescal(iescor).gt.0) then
  write(f_name,  '(a14,i1)') 'est_error_cor_', iescal(iescor)
  write(f_label, '(a5,i1)') 'EsCor', iescal(iescor)
  call add_property_field(f_name, f_label, iestim(iescor))
endif
if (iescal(iestot).gt.0) then
  write(f_name,  '(a14,i1)') 'est_error_tot_', iescal(iestot)
  write(f_label, '(a5,i1)') 'EsTot', iescal(iestot)
  call add_property_field(f_name, f_label, iestim(iestot))
endif

!   Proprietes des scalaires : viscls si elle est variable
!     On utilisera ivisls comme suit :
!       Pour le scalaire II
!         si ivisls(ii) = 0    : visc = visls0(ii)
!         si ivisls(ii) .gt. 0 : visc = propce(iel ,ipproc(ivisls(ii)))
!     Ceci permet de ne pas reserver des tableaux vides pour les
!       scalaires a viscosite constante

! Add a scalar diffusivity when defined as variable

if (nscal.ge.1) then
  do ii = 1, nscal
    if (ivisls(ii).ne.0 .and. iscavr(ii).le.0) then
      ! Build name and label, using a general rule, with a
      ! fixed name for temperature or enthalpy
      f_id = ivarfl(isca(ii))
      call field_get_name(f_id, s_name)
      call field_get_label(f_id, s_label)
      if (ii.eq.iscalt) then
        s_name = 'thermal'
        s_label = 'Th'
      endif
      if (iscacp(ii).gt.0) then
        f_name  = trim(s_name) // '_conductivity'
        f_label = trim(s_label) // ' Cond'
      else
        f_name  = trim(s_name) // '_diffusivity'
        f_label = trim(s_label) // ' Diff'
      endif
      ! Special case for electric arcs: real and imaginary electric
      ! conductivity is the same (and ipotr < ipoti)
      if (ippmod(ieljou).eq.2 .or. ippmod(ieljou).eq.4) then
        if (ii.eq.ipotr) then
          f_name = 'elec_sigma'
          f_label = 'Sigma'
        else if (ii.eq.ipoti) then
          ivisls(ipoti) = ivisls(ipotr)
          cycle ! go to next scalar in loop, avoid creating property
        endif
      endif
      ! Now create matching property
      call add_property_field(f_name, f_label, ivisls(ii))
      call field_set_key_int(ivarfl(isca(ii)), kivisl, iprpfl(ivisls(ii)))
    endif
  enddo
endif

!  Pour les fluctuations, le pointeur de la diffusivite
!    envoie directement sur la diffusivite du scalaire associe.

do ii = 1, nscal
  if (ivisls(ii).gt.0) then
    if (iscavr(ii).gt.0) then
      ivisls(ii) = ivisls(iscavr(ii))
      if (ivisls(ii).gt.0) then
        call field_set_key_int(ivarfl(isca(ii)), kivisl,    &
                               iprpfl(ivisls(iscavr(ii))))
      endif
    endif
  endif
enddo

!     Numero max des proprietes ; ressert plus bas pour
!       ajouter celles relatives a la physique particuliere

! --- Modifications pour la physique particuliere
!      des entiers NPROCE

!      Sauvegarde pour la physique particuliere de IPROP
!      afin d'initialiser les positions des variables d'etat
!      Attention IPROPP est le dernier numero affecte pour les proprietes.
ipropp = nproce

call ppprop
!==========

! --- Verification de NPROCE

if (nproce.gt.npromx) then
  write(nfecra,7200)nproce, npromx, nproce
  call csexit (1)
  !==========
endif

return

!===============================================================================
! 2. Formats
!===============================================================================

#if defined(_CS_LANG_FR)

 7040 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    SCALAIRE ',i10                                           ,/,&
'@                                                            ',/,&
'@  Le scalaire ',i10                                          ,/,&
'@    (scalaire utilisateur           ',i10   ,') represente  ',/,&
'@    la variance des fluctuations du scalaire ',i10           ,/,&
'@    (scalaire utilisateur           ',i10   ,')             ',/,&
'@    d''apres la valeur du mot cle first_moment_id           ',/,&
'@                                                            ',/,&
'@  L''indicateur de diffusivite ivisls(',i10  ,')            ',/,&
'@    ne doit pas etre renseigne.                             ',/,&
'@  Il sera pris automatiquement egal a celui du scalaire     ',/,&
'@    associe, soit ',i10                                      ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7041 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    SCALAIRE ',i10                                           ,/,&
'@                                                            ',/,&
'@  Le scalaire ',i10                                          ,/,&
'@    (scalaire utilisateur           ',i10   ,') represente  ',/,&
'@    la variance des fluctuations du scalaire ',i10           ,/,&
'@    (scalaire physique particuliere ',i10   ,')             ',/,&
'@    d''apres la valeur du mot cle first_moment_id           ',/,&
'@                                                            ',/,&
'@  L''indicateur de diffusivite ivisls(',i10  ,')            ',/,&
'@    ne doit pas etre renseigne.                             ',/,&
'@  Il sera pris automatiquement egal a celui du scalaire     ',/,&
'@    associe, soit ',i10                                      ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7042 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    SCALAIRE ',i10                                           ,/,&
'@                                                            ',/,&
'@  Le scalaire ',i10                                          ,/,&
'@    (scalaire physique particuliere ',i10   ,') represente  ',/,&
'@    la variance des fluctuations du scalaire ',i10           ,/,&
'@    (scalaire utilisateur           ',i10   ,')             ',/,&
'@    d''apres la valeur du mot cle first_moment_id           ',/,&
'@                                                            ',/,&
'@  L''indicateur de diffusivite ivisls(iscapp(',i10  ,'))    ',/,&
'@    ne doit pas etre renseigne.                             ',/,&
'@  Il sera pris automatiquement egal a celui du scalaire     ',/,&
'@    associe, soit ',i10                                      ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7043 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    SCALAIRE ',i10                                           ,/,&
'@                                                            ',/,&
'@  Le scalaire ',i10                                          ,/,&
'@    (scalaire physique particuliere ',i10   ,') represente  ',/,&
'@    la variance des fluctuations du scalaire ',i10           ,/,&
'@    (scalaire physique particuliere ',i10   ,')             ',/,&
'@    d''apres la valeur du mot cle first_moment_id           ',/,&
'@                                                            ',/,&
'@  L''indicateur de diffusivite ivisls(iscapp(',i10  ,'))    ',/,&
'@    ne doit pas etre renseigne.                             ',/,&
'@  Il sera pris automatiquement egal a celui du scalaire     ',/,&
'@    associe, soit ',i10                                      ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7050 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    SCALAIRE ',i10                                           ,/,&
'@                                                            ',/,&
'@  L''indicateur de diffusivite variable                     ',/,&
'@    du scalaire utilisateur           ',i10                  ,/,&
'@    ivisls(',i10   ,')                                      ',/,&
'@    doit etre un entier egal a 0 ou 1.                      ',/,&
'@    Il vaut ici ',i10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7051 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    SCALAIRE ',i10                                           ,/,&
'@                                                            ',/,&
'@  L''indicateur de diffusivite variable                     ',/,&
'@    du scalaire physique particuliere ',i10                  ,/,&
'@    ivisls(iscapp(',i10   ,'))                              ',/,&
'@    doit etre un entier egal a 0 ou 1.                      ',/,&
'@    Il vaut ici ',i10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7070 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@    L''INDICATEUR IORTVM NE PEUT PRENDRE QUE LES VALEURS    ',/,&
'@      0 OU 1.                                               ',/,&
'@    IL VAUT ICI ',i10                                        ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier usalin.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7200 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ATTENTION : ARRET A L''ENTREE DES DONNEES               ',/,&
'@    =========                                               ',/,&
'@     NOMBRE DE PROPRIETES TROP GRAND                        ',/,&
'@                                                            ',/,&
'@  Le type de calcul defini                                  ',/,&
'@    correspond aux nombres de proprietes suivants           ',/,&
'@      au centre des cellules       : NPROCE = ',i10          ,/,&
'@  Le nombre de proprietes maximal prevu                     ',/,&
'@                      dans paramx.h est NPROMX = ',i10       ,/,&
'@                                                            ',/,&
'@  Le calcul ne sera pas execute.                            ',/,&
'@                                                            ',/,&
'@  Verifier les parametres.                                  ',/,&
'@                                                            ',/,&
'@  NPROMX doit valoir au moins ',i10                          ,/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#else

 7040 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    SCALAR   ',i10                                           ,/,&
'@                                                            ',/,&
'@  The scalar  ',i10                                          ,/,&
'@    (user scalar                    ',i10   ,') represents  ',/,&
'@    the variance of fluctuations of a scalar ',i10           ,/,&
'@    (user scalar                    ',i10   ,')             ',/,&
'@    according to value of keyword first_moment_id           ',/,&
'@                                                            ',/,&
'@  The diffusivity index        ivisls(',i10  ,')            ',/,&
'@    has not been set.                                       ',/,&
'@  It will be automatically set equal to that of the         ',/,&
'@    associated scalar ',i10                                  ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7041 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    SCALAR   ',i10                                           ,/,&
'@                                                            ',/,&
'@  The scalar  ',i10                                          ,/,&
'@    (user scalar                    ',i10   ,') represents  ',/,&
'@    the variance of fluctuations of a scalar ',i10           ,/,&
'@    (scalar of a specific physics ',i10   ,')               ',/,&
'@    according to value of keyword first_moment_id           ',/,&
'@                                                            ',/,&
'@  The diffusivity index        ivisls(',i10  ,')            ',/,&
'@    has not been set.                                       ',/,&
'@  It will be automatically set equal to that of the         ',/,&
'@    associated scalar ',i10                                  ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7042 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    SCALAR   ',i10                                           ,/,&
'@                                                            ',/,&
'@  The scalar  ',i10                                          ,/,&
'@    (scalar of a specific physics ',i10   ,') represents    ',/,&
'@    the variance of fluctuations of a scalar ',i10           ,/,&
'@    (user scalar                    ',i10   ,')             ',/,&
'@    according to value of keyword first_moment_id           ',/,&
'@                                                            ',/,&
'@  The diffusivity index        ivisls(iscapp(',i10  ,'))    ',/,&
'@    has not been set.                                       ',/,&
'@  It will be automatically set equal to that of the         ',/,&
'@    associated scalar ',i10                                  ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7043 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    SCALAR   ',i10                                           ,/,&
'@                                                            ',/,&
'@  The scalar  ',i10                                          ,/,&
'@    (scalar of a specific physics ',i10   ,') represents    ',/,&
'@    the variance of fluctuations of a scalar ',i10           ,/,&
'@    (scalar of a specific physics ',i10   ,')               ',/,&
'@    according to value of keyword first_moment_id           ',/,&
'@                                                            ',/,&
'@  The diffusivity index        ivisls(iscapp(',i10  ,'))    ',/,&
'@    has not been set.                                       ',/,&
'@  It will be automatically set equal to that of the         ',/,&
'@    associated scalar ',i10                                  ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7050 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    SCALAR   ',i10                                           ,/,&
'@                                                            ',/,&
'@  The variable diffusivity index of the                     ',/,&
'@    user scalar                       ',i10                  ,/,&
'@    ivisls(',i10   ,')                                      ',/,&
'@    must be set equal to 0 or 1.                            ',/,&
'@    Here it is  ',i10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7051 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    SCALAR   ',i10                                           ,/,&
'@                                                            ',/,&
'@  The variable diffusivity index of the                     ',/,&
'@    scalar of a specific physics    ',i10                    ,/,&
'@    ivisls(iscapp(',i10   ,'))                              ',/,&
'@    must be set equal to 0 or 1.                            ',/,&
'@    Here it is  ',i10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   ivisls.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7070 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@    THE INDEX  IORTVM    CANNOT HAVE VALUES OTHER THAN      ',/,&
'@      0 OR 1.                                               ',/,&
'@    HERE IT IS  ',i10                                        ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   usalin.                                          ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
 7200 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ WARNING   : STOP AT THE INITIAL DATA VERIFICATION       ',/,&
'@    =========                                               ',/,&
'@     NUMBER OF VARIABLES TOO LARGE                          ',/,&
'@                                                            ',/,&
'@  The type of calculation defined                           ',/,&
'@    corresponds  to the following number of properties      ',/,&
'@      at the cell centres          : NPROCE = ',i10          ,/,&
'@  The maximum number of properties allowed                  ',/,&
'@                      in   paramx   is  NPROMX = ',i10       ,/,&
'@                                                            ',/,&
'@  The calculation cannot be executed                        ',/,&
'@                                                            ',/,&
'@  Verify   parameters.                                      ',/,&
'@                                                            ',/,&
'@  NPROMX must be at least     ',i10                          ,/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)

#endif

!===============================================================================
! 5. End
!===============================================================================

return
end subroutine fldprp

!===============================================================================

!> \function add_property_field_nd
!
!> \brief add field defining a property field defined on cells,
!>        with default options
!
!> It is recommended not to define property names of more than 16
!> characters, to get a clear execution listing (some advanced writing
!> levels take into account only the first 16 characters).
!
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     name          field name
!> \param[in]     label         field default label, or empty
!> \param[in]     dim           field dimension
!> \param[out]    iprop         matching field property id
!_______________________________________________________________________________

subroutine add_property_field_nd &
 ( name, label, dim, iprop )

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use entsor
use numvar
use field

!===============================================================================

implicit none

! Arguments

character(len=*), intent(in) :: name, label
integer, intent(in)          :: dim
integer, intent(out)         :: iprop

! Local variables

integer  type_flag, location_id, ii, keyprp, f_id
logical  has_previous, interleaved

!===============================================================================

type_flag = FIELD_INTENSIVE + FIELD_PROPERTY
location_id = 1 ! variables defined on cells
has_previous = .false.
interleaved = .false. ! TODO set to .true. once PROPCE mapping is removed

call field_get_key_id("property_id", keyprp)

! Test if the field has already been defined
call field_get_id_try(trim(name), f_id)
if (f_id .ge. 0) then
  write(nfecra,1000) trim(name)
  call csexit (1)
endif

! Create field

call field_create(name, type_flag, location_id, dim, interleaved, has_previous, &
                  f_id)

call field_set_key_int(f_id, keyvis, 1)
call field_set_key_int(f_id, keylog, 1)

if (len(trim(label)).gt.0) then
  call field_set_key_str(f_id, keylbl, trim(label))
endif

! Property number and mapping to field

iprop = nproce + 1
nproce = nproce + dim

call fldprp_check_nproce

do ii = 1, dim
  iprpfl(iprop + ii -1) = f_id
  ipproc(iprop + ii - 1) = iprop + ii - 1
enddo

! Postprocessing slots

ipppro(iprop) = field_post_id(f_id)
do ii = 2, dim
  ipppro(iprop+ii-1) = ipppro(iprop) -1 + ii
enddo

call field_set_key_int(f_id, keyipp, ipppro(iprop))

! Mapping

call field_set_key_int(f_id, keyprp, iprop)

return

!---
! Formats
!---

#if defined(_CS_LANG_FR)
 1000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ERREUR :    ARRET A L''ENTREE DES DONNEES               ',/,&
'@    ========                                                ',/,&
'@     LE CHAMP : ', a, 'EST DEJA DEFINI.                     ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
#else
 1000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ERROR:      STOP AT THE INITIAL DATA SETUP              ',/,&
'@    ======                                                  ',/,&
'@     FIELD: ', a, 'HAS ALREADY BEEN DEFINED.                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
#endif

end subroutine add_property_field_nd

!===============================================================================

!> \fn add_property_field_hidden
!
!> \brief add field defining a hidden property field defined on cells
!
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     name          field name
!> \param[in]     dim           field dimension
!> \param[out]    iprop         matching field property id
!_______________________________________________________________________________

subroutine add_property_field_hidden &
 ( name, dim, iprop )

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use entsor
use numvar
use field

!===============================================================================

implicit none

! Arguments

character(len=*), intent(in) :: name
integer, intent(in)          :: dim
integer, intent(out)         :: iprop

! Local variables

integer  id, type_flag, location_id, ii, keyprp
logical  has_previous, interleaved

!===============================================================================

type_flag = FIELD_INTENSIVE + FIELD_PROPERTY
location_id = 1 ! variables defined on cells
has_previous = .false.
interleaved = .true.

call field_get_key_id("property_id", keyprp)

! Test if the field has already been defined
call field_get_id_try(trim(name), id)
if (id .ge. 0) then
  write(nfecra,1000) trim(name)
  call csexit (1)
endif

! Create field

call field_create(name, type_flag, location_id, dim, interleaved, has_previous, &
                  id)

call field_set_key_int(id, keyvis, 0)
call field_set_key_int(id, keylog, 0)

! Property number and mapping to field

iprop = nproce + 1
nproce = nproce + dim

call fldprp_check_nproce

do ii = 1, dim
  iprpfl(iprop + ii -1) = id
  ipproc(iprop + ii - 1) = iprop + ii - 1
enddo

! Postprocessing slots

do ii = 1, dim
  ipppro(iprop+ii-1) = 1
enddo

! Mapping

call field_set_key_int(id, keyprp, iprop)

return

!---
! Formats
!---

#if defined(_CS_LANG_FR)
 1000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ERREUR :    ARRET A L''ENTREE DES DONNEES               ',/,&
'@    ========                                                ',/,&
'@     LE CHAMP : ', a, 'EST DEJA DEFINI.                     ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
#else
 1000 format(                                                     &
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/,&
'@ @@ ERROR:      STOP AT THE INITIAL DATA SETUP              ',/,&
'@    ======                                                  ',/,&
'@     FIELD: ', a, 'HAS ALREADY BEEN DEFINED.                ',/,&
'@                                                            ',/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@                                                            ',/)
#endif

end subroutine add_property_field_hidden

!===============================================================================

!> \function add_property_field
!
!> \brief add field defining a property field defined on cells,
!>        with default options
!
!> It is recommended not to define property names of more than 16
!> characters, to get a clear execution listing (some advanced writing
!> levels take into account only the first 16 characters).
!
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     name          field name
!> \param[in]     label         field default label, or empty
!> \param[out]    iprop         matching field property id
!_______________________________________________________________________________

subroutine add_property_field &
 ( name, label, iprop )

!===============================================================================
! Module files
!===============================================================================

use field

!===============================================================================

implicit none

! Arguments

character(len=*), intent(in) :: name, label
integer, intent(out)         :: iprop

!===============================================================================

call add_property_field_nd(name, label, 1, iprop)

return

end subroutine add_property_field

!===============================================================================

!> \function hide_property
!
!> \brief disable logging and postprocessing for a property
!
!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!> \param[in]     iprop         property id
!_______________________________________________________________________________

subroutine hide_property &
 ( iprop )

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use entsor
use numvar
use field

!===============================================================================

implicit none

! Arguments

integer, intent(in) :: iprop

! Local variables

integer  id, ipp

!===============================================================================

id = iprpfl(iprop)
call field_set_key_int(id, keyvis, 0)
call field_set_key_int(id, keylog, 0)

ipp = ipppro(ipproc(iprop))
if (ipp .gt. 1) then
  ihisvr(ipp,1) = 0
endif

return

end subroutine hide_property

!===============================================================================

!> \function fldprp_check_nproce

!> \brief check npromx is sufficient for the required number of properties.

!-------------------------------------------------------------------------------
! Arguments
!______________________________________________________________________________.
!  mode           name          role                                           !
!______________________________________________________________________________!
!_______________________________________________________________________________

subroutine fldprp_check_nproce

!===============================================================================
! Module files
!===============================================================================

use paramx
use dimens
use entsor
use numvar

!===============================================================================

implicit none

! Arguments

! Local variables

if (nproce .gt. npromx) then
  write(nfecra,1000) nproce, npromx
  call csexit (1)
endif

return

!---
! Formats
!---

#if defined(_CS_LANG_FR)

 1000 format(                                                     &
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ ERREUR :    ARRET A L''ENTREE DES DONNEES'               ,/,&
'@    ========'                                                ,/,&
'@     NOMBRE DE PROPRIETES TROP GRAND'                        ,/,&
'@'                                                            ,/,&
'@  Le type de calcul defini'                                  ,/,&
'@    correspond a un nombre de proprietes NPROCE >= ', i10    ,/,&
'@  Le nombre de proprietes maximal prevu'                     ,/,&
'@                      dans paramx    est NPROMX  = ', i10    ,/,&
'@'                                                            ,/,&
'@  Le calcul ne sera pas execute.'                            ,/,&
'@'                                                            ,/,&
'@  Verifier les parametres'                                   ,/,&
'@'                                                            ,/,&
'@  Si NPROMX est augmente, le code doit etre reinstalle.'     ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/)

#else

 1000 format(                                                     &
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/,&
'@ @@ ERROR:      STOP AT THE INITIAL DATA SETUP'              ,/,&
'@    ======'                                                  ,/,&
'@     NUMBER OF PROPERTIES TOO LARGE'                         ,/,&
'@'                                                            ,/,&
'@  The type of calculation defined'                           ,/,&
'@    corresponds to a number of properties NPROCE >= ', i10   ,/,&
'@  The maximum number of properties allowed'                  ,/,&
'@                      in   paramx     is  NPROMX  = ', i10   ,/,&
'@'                                                            ,/,&
'@  The calculation cannot be executed'                        ,/,&
'@'                                                            ,/,&
'@  Verify   parameters.'                                      ,/,&
'@'                                                            ,/,&
'@  If NVARMX is increased, the code must be reinstalled.'     ,/,&
'@'                                                            ,/,&
'@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',/,&
'@'                                                            ,/)

#endif

end subroutine fldprp_check_nproce

!===============================================================================
