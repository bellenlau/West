!
! Copyright (C) 2015-2022 M. Govoni
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! This file is part of WEST.
!
! Contributors to this file:
! Marco Govoni
!
!-----------------------------------------------------------------------
SUBROUTINE solve_eri(ifreq,l_isFreqReal)
  !-----------------------------------------------------------------------
  !
  USE westcom,              ONLY : n_pdep_eigen_to_use,l_macropol,d_epsm1_ifr_a,z_epsm1_rfr_a,&
                                 & imfreq_list,refreq_list,z_head_rfr_a,d_head_ifr_a,n_pairs,eri_w
  USE distribution_center,  ONLY : pert,ifr,rfr
  USE kinds,                ONLY : DP
  USE pwcom,                ONLY : nspin
  USE mp,                   ONLY : mp_bcast
  USE mp_global,            ONLY : intra_bgrp_comm,me_bgrp
  USE io_push,              ONLY : io_push_title,io_push_bar
  USE wfreq_db,             ONLY : qdet_db_write_eri
#if defined(__CUDA)
  USE west_gpu,             ONLY : allocate_gpu,deallocate_gpu
#endif
  !
  IMPLICIT NONE
  !
  INTEGER,INTENT(IN) :: ifreq
  LOGICAL,INTENT(IN) :: l_isFreqReal
  !
  INTEGER :: who, iloc
  REAL(DP) :: freq
  COMPLEX(DP) :: chi_head
  !
  REAL(DP),ALLOCATABLE :: braket(:,:,:)
  REAL(DP),ALLOCATABLE :: eri_vc(:,:,:,:)
  COMPLEX(DP),ALLOCATABLE :: chi_body(:,:)
  !
  ! Compute 4-center integrals of W (screened electron repulsion integrals, eri)
  ! (ij|W|kl) = int dx dx' f_i(x) f_j(x) W(r,r') f_k(x') f_l(x')
  ! f_i is the Fourier transform to direct space of westcom/proj_c_i
  !
  CALL io_push_title('ERI')
  !
#if defined(__CUDA)
  CALL allocate_gpu()
#endif
  !
  ALLOCATE( chi_body( pert%nglob, pert%nloc ) )
  !
  ! Load chi at given frequency (index and logical from input)
  !
  IF ( l_isFreqReal ) THEN
     !
     CALL rfr%g2l(ifreq,iloc,who)
     IF ( me_bgrp == who ) THEN
        !
        freq = refreq_list(iloc)
        chi_body(:,:) = z_epsm1_rfr_a(:,:,iloc)
        IF ( l_macropol ) chi_head = z_head_rfr_a(iloc)
        !
     ENDIF
     !
  ELSE
     !
     CALL ifr%g2l(ifreq,iloc,who)
     IF ( me_bgrp == who ) THEN
        !
        freq = imfreq_list(iloc)
        chi_body(:,:) = CMPLX(d_epsm1_ifr_a(:,:,ifreq),KIND=DP)
        IF ( l_macropol ) chi_head = CMPLX(d_head_ifr_a(ifreq),KIND=DP)
        !
     ENDIF
     !
  ENDIF
  !
  CALL mp_bcast( freq, who, intra_bgrp_comm )
  CALL mp_bcast( chi_body, who, intra_bgrp_comm )
  IF ( l_macropol ) THEN
     CALL mp_bcast( chi_head, who, intra_bgrp_comm )
  ELSE
     chi_head = (0._DP,0._DP)
  ENDIF
  !
  ! Compute ERI (Electron Repulsion Integrals)
  !
  ALLOCATE( eri_vc(n_pairs,n_pairs,nspin,nspin) )
  ALLOCATE( eri_w(n_pairs,n_pairs,nspin,nspin) )
  !
  ! 4-center integrals of Vc
  !
  CALL compute_eri_vc(eri_vc)
  !
  ! 4-center integrals of Wp
  !
  ALLOCATE( braket(n_pairs,nspin,n_pdep_eigen_to_use) )
  !
  CALL compute_braket(braket)
  CALL compute_eri_wp(braket, chi_head, chi_body, eri_w)
  !
  ! 4-center integrals of W
  !
  eri_w(:,:,:,:) = eri_vc + eri_w
  !
  CALL qdet_db_write_eri(eri_vc,eri_w)
  !
  CALL io_push_bar()
  !
#if defined(__CUDA)
  CALL deallocate_gpu()
#endif
  !
  DEALLOCATE( chi_body )
  DEALLOCATE( braket )
  DEALLOCATE( eri_vc )
  !
END SUBROUTINE
!
!-----------------------------------------------------------------------
SUBROUTINE compute_braket(braket)
  !-----------------------------------------------------------------------
  !
  ! braket_{ij(s)m} = < ij(s) | pdep_m * V_c^0.5 >
  ! ij is a pair of functions taken from westcom/proj_c
  ! s is the spin index
  ! m is the PDEP index
  ! V_c is the bare Coulomb potential
  !
  USE kinds,                ONLY : DP
  USE pwcom,                ONLY : nspin
  USE gvect,                ONLY : gstart
  USE westcom,              ONLY : wstat_save_dir,npwq,npwqx,n_pdep_eigen_to_use,fftdriver,&
                                 & proj_c,n_pairs,pijmap
  USE mp_global,            ONLY : intra_bgrp_comm,inter_bgrp_comm,inter_image_comm
  USE fft_base,             ONLY : dffts
  USE fft_at_gamma,         ONLY : single_fwfft_gamma,double_invfft_gamma
  USE bar,                  ONLY : bar_type,start_bar_type,update_bar_type,stop_bar_type
  USE mp,                   ONLY : mp_sum
  USE types_coulomb,        ONLY : pot3D
  USE io_push,              ONLY : io_push_title
  USE distribution_center,  ONLY : macropert,bandpair
  USE pdep_db,              ONLY : generate_pdep_fname
  USE pdep_io,              ONLY : pdep_read_G_and_distribute
#if defined(__CUDA)
  USE wavefunctions_gpum,   ONLY : psic=>psic_d
  USE west_gpu,             ONLY : memcpy_H2D
#else
  USE wavefunctions,        ONLY : psic
#endif
  !
  IMPLICIT NONE
  !
  REAL(DP),INTENT(OUT) :: braket(n_pairs,nspin,n_pdep_eigen_to_use)
  !
  COMPLEX(DP),ALLOCATABLE :: phi(:)
  COMPLEX(DP),ALLOCATABLE :: rho_r(:), rho_g(:)
  REAL(DP),ALLOCATABLE :: sqvc(:)
  !$acc declare device_resident(rho_r,rho_g,sqvc)
  !
  INTEGER :: s, m, p1, p1loc, i, j, ig, ir, mloc
  INTEGER :: barra_load
  INTEGER :: dffts_nnr
  CHARACTER(LEN=25) :: filepot
  CHARACTER(LEN=:),ALLOCATABLE :: fname
  TYPE(bar_type) :: barra
  REAL(DP) :: reduce
  !
  CALL io_push_title('braket')
  !
  ! Distribute pairs over band groups
  !
  CALL bandpair%init(n_pairs,'b','n_pairs',.FALSE.)
  !
  CALL pot3D%init(fftdriver,.FALSE.,'default')
  !
  ALLOCATE( phi(npwqx) )
  !$acc enter data create(phi)
  ALLOCATE( rho_g(npwqx) )
  ALLOCATE( rho_r(dffts%nnr) )
#if defined(__CUDA)
  ALLOCATE( sqvc(npwqx) )
  CALL memcpy_H2D(sqvc,pot3D%sqvc,npwqx)
#endif
  !
  dffts_nnr = dffts%nnr
  !
  barra_load = 0
  DO mloc = 1, macropert%nloc
     m = macropert%l2g(mloc)
     IF (m > n_pdep_eigen_to_use) CYCLE
     barra_load = barra_load+1
  ENDDO
  barra_load = barra_load*nspin
  CALL start_bar_type ( barra, 'eri_brak', barra_load )
  !
  braket = 0._DP
  !
  DO s = 1, nspin
     DO mloc = 1, macropert%nloc
        !
        m = macropert%l2g(mloc)
        !
        IF (m > n_pdep_eigen_to_use) CYCLE ! skip the head, use only the body
        !
        ! Read the m-th PDEP
        !
        CALL generate_pdep_fname( filepot, m )
        fname = TRIM( wstat_save_dir ) // '/'// filepot
        CALL pdep_read_G_and_distribute(fname,phi(:))
        !$acc update device(phi)
        !
        ! Mulitply by V_c^0.5
        !
        !$acc parallel loop present(phi,sqvc)
        DO ig = 1, npwq
#if defined(__CUDA)
           phi(ig) = sqvc(ig) * phi(ig)
#else
           phi(ig) = pot3D%sqvc(ig) * phi(ig)
#endif
        ENDDO
        !$acc end parallel
        !
        ! Compute the braket for each pair of functions
        !
        DO p1loc = 1, bandpair%nloc
           !
           p1 = bandpair%l2g(p1loc)
           i = pijmap(1,p1)
           j = pijmap(2,p1)
           !
           !$acc host_data use_device(proj_c)
           CALL double_invfft_gamma(dffts,npwq,npwqx,proj_c(:,i,s),proj_c(:,j,s),psic,'Wave')
           !$acc end host_data
           !
           !$acc parallel loop present(rho_r)
           DO ir = 1, dffts_nnr
              rho_r(ir) = REAL(psic(ir),KIND=DP)*AIMAG(psic(ir))
           ENDDO
           !$acc end parallel
           !
           !$acc host_data use_device(rho_r,rho_g)
           CALL single_fwfft_gamma(dffts,npwq,npwqx,rho_r,rho_g,TRIM(fftdriver))
           !$acc end host_data
           !
           ! Assume Gamma only
           !
           reduce = 0._DP
           !$acc parallel loop reduction(+:reduce) present(rho_g,phi) copy(reduce)
           DO ig = 1, npwq
              reduce = reduce + REAL(rho_g(ig),KIND=DP)*REAL(phi(ig),KIND=DP) &
              & + AIMAG(rho_g(ig))*AIMAG(phi(ig))
           ENDDO
           !$acc end parallel
           !
           IF(gstart == 2) THEN
              !$acc serial present(rho_g,phi) copy(reduce)
              reduce = reduce - 0.5_DP*REAL(rho_g(1),KIND=DP)*REAL(phi(1),KIND=DP)
              !$acc end serial
           ENDIF
           !
           braket(p1,s,m) = 2._DP*reduce
           !
        ENDDO
        !
        CALL update_bar_type( barra,'eri_brak', 1 )
        !
     ENDDO
  ENDDO
  !
  CALL mp_sum(braket, intra_bgrp_comm)
  CALL mp_sum(braket, inter_bgrp_comm)
  CALL mp_sum(braket, inter_image_comm)
  !
  CALL stop_bar_type( barra,'eri_brak' )
  !
  !$acc exit data delete(phi)
  DEALLOCATE( phi )
  DEALLOCATE( rho_r )
  DEALLOCATE( rho_g )
#if defined(__CUDA)
  DEALLOCATE( sqvc )
#endif
  !
END SUBROUTINE
!
!-----------------------------------------------------------------------
SUBROUTINE compute_eri_vc(eri_vc)
  !-----------------------------------------------------------------------
  !
  USE kinds,                ONLY : DP
  USE pwcom,                ONLY : nspin
  USE westcom,              ONLY : l_macropol,n_pairs,pijmap,proj_c,npwq,npwqx
  USE mp_global,            ONLY : intra_bgrp_comm,inter_image_comm
  USE distribution_center,  ONLY : bandpair
  USE fft_base,             ONLY : dffts
  USE fft_at_gamma,         ONLY : single_fwfft_gamma,double_invfft_gamma
  USE bar,                  ONLY : bar_type,start_bar_type,update_bar_type,stop_bar_type
  USE mp,                   ONLY : mp_sum
  USE types_coulomb,        ONLY : pot3D
  USE io_push,              ONLY : io_push_title
  USE gvect,                ONLY : gstart,ngm
  USE cell_base,            ONLY : omega
#if defined(__CUDA)
  USE wavefunctions_gpum,   ONLY : psic=>psic_d
  USE west_gpu,             ONLY : memcpy_H2D
#else
  USE wavefunctions,        ONLY : psic
#endif
  !
  IMPLICIT NONE
  !
  REAL(DP),INTENT(OUT) :: eri_vc(n_pairs,n_pairs,nspin,nspin)
  !
  COMPLEX(DP),ALLOCATABLE :: rho_g1(:), rho_g2(:), rho_r(:)
  REAL(DP),ALLOCATABLE :: sqvc(:)
  !$acc declare device_resident(rho_g1,rho_g2,rho_r,sqvc)
  !
  INTEGER :: i, j, k, l, p1, p1loc, p2, s1, s2
  INTEGER :: ir, ig
  INTEGER :: dffts_nnr
  TYPE(bar_type) :: barra
  REAL(DP) :: reduce
  !
  CALL io_push_title('pair density')
  !
  ! Distribute pairs over images
  !
  CALL bandpair%init(n_pairs,'i','n_pairs',.FALSE.)
  !
  CALL pot3D%init('Rho',.FALSE.,'gb')
  !
  ALLOCATE( rho_r(dffts%nnr) )
  ALLOCATE( rho_g1(ngm) )
  ALLOCATE( rho_g2(ngm) )
#if defined(__CUDA)
  ALLOCATE( sqvc(ngm) )
  CALL memcpy_H2D(sqvc,pot3D%sqvc,ngm)
#endif
  !
  dffts_nnr = dffts%nnr
  !
  eri_vc(:,:,:,:) = 0._DP
  !
  ! eri_vc with SAME SPIN --> compute only p2>=p1, obtain p2<p1 by symmetry
  !
  CALL start_bar_type ( barra, 'eri_vc_s1s1', nspin*bandpair%nloc )
  !
  DO s1 = 1, nspin
     DO p1loc = 1, bandpair%nloc
        !
        p1 = bandpair%l2g(p1loc)
        i = pijmap(1,p1)
        j = pijmap(2,p1)
        !
        !$acc host_data use_device(proj_c)
        CALL double_invfft_gamma(dffts,npwq,npwqx,proj_c(:,i,s1),proj_c(:,j,s1),psic,'Wave')
        !$acc end host_data
        !
        !$acc parallel loop present(rho_r)
        DO ir = 1, dffts_nnr
           rho_r(ir) = REAL(psic(ir),KIND=DP)*AIMAG(psic(ir))
        ENDDO
        !$acc end parallel
        !
        !$acc host_data use_device(rho_r,rho_g1)
        CALL single_fwfft_gamma(dffts,ngm,ngm,rho_r,rho_g1,'Rho')
        !$acc end host_data
        !
        !$acc parallel loop present(rho_g1,sqvc)
        DO ig = 1, ngm
#if defined(__CUDA)
           rho_g1(ig) = sqvc(ig) * rho_g1(ig)
#else
           rho_g1(ig) = pot3D%sqvc(ig) * rho_g1(ig)
#endif
        ENDDO
        !$acc end parallel
        !
        ! (s1 = s2); (p2 = p1)
        !
        reduce = 0._DP
        !$acc parallel loop reduction(+:reduce) present(rho_g1) copy(reduce)
        DO ig = gstart, ngm
           reduce = reduce + REAL(rho_g1(ig),KIND=DP)**2 + AIMAG(rho_g1(ig))**2
        ENDDO
        !$acc end parallel
        !
        eri_vc(p1,p1,s1,s1) = eri_vc(p1,p1,s1,s1) + 2._DP*reduce/omega
        IF(i==j .AND. gstart==2) THEN
           eri_vc(p1,p1,s1,s1) = eri_vc(p1,p1,s1,s1) + pot3D%div
        ENDIF
        !
        ! (s1 = s2); (p2 > p1)
        !
        DO p2 = p1+1, n_pairs
           !
           k = pijmap(1,p2)
           l = pijmap(2,p2)
           !
           !$acc host_data use_device(proj_c)
           CALL double_invfft_gamma(dffts,npwq,npwqx,proj_c(:,k,s1),proj_c(:,l,s1),psic,'Wave')
           !$acc end host_data
           !
           !$acc parallel loop present(rho_r)
           DO ir = 1, dffts_nnr
              rho_r(ir) = REAL(psic(ir),KIND=DP)*AIMAG(psic(ir))
           ENDDO
           !$acc end parallel
           !
           !$acc host_data use_device(rho_r,rho_g2)
           CALL single_fwfft_gamma(dffts,ngm,ngm,rho_r,rho_g2,'Rho')
           !$acc end host_data
           !
           !$acc parallel loop present(rho_g2,sqvc)
           DO ig = 1, ngm
#if defined(__CUDA)
              rho_g2(ig) = sqvc(ig) * rho_g2(ig)
#else
              rho_g2(ig) = pot3D%sqvc(ig) * rho_g2(ig)
#endif
           ENDDO
           !$acc end parallel
           !
           reduce = 0._DP
           !$acc parallel loop reduction(+:reduce) present(rho_g1,rho_g2) copy(reduce)
           DO ig = gstart, ngm
              reduce = reduce + REAL(rho_g1(ig),KIND=DP)*REAL(rho_g2(ig),KIND=DP) &
              & + AIMAG(rho_g1(ig))*AIMAG(rho_g2(ig))
           ENDDO
           !$acc end parallel
           !
           eri_vc(p1,p2,s1,s1) = eri_vc(p1,p2,s1,s1) + 2._DP*reduce/omega
           IF(i==j .AND. k==l .AND. gstart==2) THEN
              eri_vc(p1,p2,s1,s1) = eri_vc(p1,p2,s1,s1) + pot3D%div
           ENDIF
           !
           ! Apply symmetry
           !
           eri_vc(p2,p1,s1,s1) = eri_vc(p1,p2,s1,s1)
           !
        ENDDO
        !
        CALL update_bar_type ( barra, 'eri_vc_s1s1', 1 )
        !
     ENDDO
  ENDDO
  !
  CALL stop_bar_type ( barra, 'eri_vc_s1s1' )
  !
  ! eri_vc with DIFFERENT SPIN --> compute only s2>s1, obtain s2<s1 by symmetry
  !
  IF (nspin==2) THEN
     !
     CALL start_bar_type ( barra, 'eri_vc_s1s2', bandpair%nloc )
     !
     s1 = 1
     s2 = 2
     !
     DO p1loc = 1, bandpair%nloc
        !
        p1 = bandpair%l2g(p1loc)
        i = pijmap(1,p1)
        j = pijmap(2,p1)
        !
        !$acc host_data use_device(proj_c)
        CALL double_invfft_gamma(dffts,npwq,npwqx,proj_c(:,i,s1),proj_c(:,j,s2),psic,'Wave')
        !$acc end host_data
        !
        !$acc parallel loop present(rho_r)
        DO ir = 1, dffts_nnr
           rho_r(ir) = REAL(psic(ir),KIND=DP)*AIMAG(psic(ir))
        ENDDO
        !$acc end parallel
        !
        !$acc host_data use_device(rho_r,rho_g1)
        CALL single_fwfft_gamma(dffts,ngm,ngm,rho_r,rho_g1,'Rho')
        !$acc end host_data
        !
        !$acc parallel loop present(rho_g1,sqvc)
        DO ig = 1, ngm
#if defined(__CUDA)
           rho_g1(ig) = sqvc(ig) * rho_g1(ig)
#else
           rho_g1(ig) = pot3D%sqvc(ig) * rho_g1(ig)
#endif
        ENDDO
        !$acc end parallel
        !
        ! (s1 < s2)
        !
        DO p2 = 1, n_pairs
           !
           k = pijmap(1,p2)
           l = pijmap(2,p2)
           !
           !$acc host_data use_device(proj_c)
           CALL double_invfft_gamma(dffts,npwq,npwqx,proj_c(:,k,s1),proj_c(:,l,s2),psic,'Wave')
           !$acc end host_data
           !
           !$acc parallel loop present(rho_r)
           DO ir = 1, dffts_nnr
              rho_r(ir) = REAL(psic(ir),KIND=DP)*AIMAG(psic(ir))
           ENDDO
           !$acc end parallel
           !
           !$acc host_data use_device(rho_r,rho_g2)
           CALL single_fwfft_gamma(dffts,ngm,ngm,rho_r,rho_g2,'Rho')
           !$acc end host_data
           !
           !$acc parallel loop present(rho_g2,sqvc)
           DO ig = 1, ngm
#if defined(__CUDA)
              rho_g2(ig) = sqvc(ig) * rho_g2(ig)
#else
              rho_g2(ig) = pot3D%sqvc(ig) * rho_g2(ig)
#endif
           ENDDO
           !$acc end parallel
           !
           reduce = 0._DP
           !$acc parallel loop reduction(+:reduce) present(rho_g1,rho_g2) copy(reduce)
           DO ig = gstart, ngm
              reduce = reduce + REAL(rho_g1(ig),KIND=DP)*REAL(rho_g2(ig),KIND=DP) &
              & + AIMAG(rho_g1(ig))*AIMAG(rho_g2(ig))
           ENDDO
           !$acc end parallel
           !
           eri_vc(p1,p2,s1,s2) = eri_vc(p1,p2,s1,s2) + 2._DP*reduce/omega
           IF(i==j .AND. k==l .AND. gstart==2) THEN
              eri_vc(p1,p2,s1,s2) = eri_vc(p1,p2,s1,s2) + pot3D%div
           ENDIF
           !
           ! Apply symmetry
           !
           eri_vc(p2,p1,s2,s1) = eri_vc(p1,p2,s1,s2)
           !
        ENDDO
        !
        CALL update_bar_type ( barra, 'eri_vc_s1s2', 1 )
        !
     ENDDO
     !
     CALL stop_bar_type ( barra, 'eri_vc_s1s2' )
     !
  ENDIF
  !
  CALL mp_sum( eri_vc, intra_bgrp_comm )
  CALL mp_sum( eri_vc, inter_image_comm )
  !
  DEALLOCATE( rho_r )
  DEALLOCATE( rho_g1 )
  DEALLOCATE( rho_g2 )
#if defined(__CUDA)
  DEALLOCATE( sqvc )
#endif
  !
END SUBROUTINE
!
!-----------------------------------------------------------------------
SUBROUTINE compute_eri_wp(braket, chi_head, chi_body, eri_wp)
  !-----------------------------------------------------------------------
  !
  USE kinds,                ONLY : DP
  USE distribution_center,  ONLY : pert,macropert,bandpair
  USE pwcom,                ONLY : nspin
  USE westcom,              ONLY : n_pdep_eigen_to_use,fftdriver,n_pairs,pijmap,l_macropol
  USE types_coulomb,        ONLY : pot3D
  USE mp_global,            ONLY : inter_bgrp_comm,inter_image_comm
  USE bar,                  ONLY : bar_type,start_bar_type,update_bar_type,stop_bar_type
  USE mp,                   ONLY : mp_sum
  USE io_push,              ONLY : io_push_title
  USE cell_base,            ONLY : omega
  !
  IMPLICIT NONE
  !
  REAL(DP),INTENT(IN) :: braket(n_pairs,nspin,n_pdep_eigen_to_use)
  COMPLEX(DP),INTENT(IN) :: chi_head, chi_body(pert%nglob,pert%nloc)
  COMPLEX(DP),INTENT(OUT) :: eri_wp(n_pairs,n_pairs,nspin,nspin)
  !
  INTEGER :: s1, s2, p1, p2, p2loc, i, j, k, l, m, n, nloc, nloc_max
  TYPE(bar_type) :: barra
  !
  CALL io_push_title('Wp Integrals (PDEP)')
  !
  DO nloc = 1, macropert%nloc
     n = macropert%l2g(nloc)
     IF (n > n_pdep_eigen_to_use) EXIT
     nloc_max = nloc
  ENDDO
  !
  ! Distribute pairs over band groups
  !
  CALL bandpair%init(n_pairs,'b','n_pairs',.FALSE.)
  !
  ! Workload too small for progress bar
  !
  CALL start_bar_type(barra, 'Wp', 1)
  !
  IF (l_macropol) CALL pot3D%compute_divergence('default')
  !
  eri_wp(:,:,:,:) = 0._DP
  !
  DO nloc = 1, nloc_max ! iterate over m, n
     !
     n = macropert%l2g(nloc)
     !
     DO m = 1, n_pdep_eigen_to_use
        DO s2 = 1, nspin
           DO s1 = 1, nspin
              DO p2loc = 1, bandpair%nloc
                 !
                 p2 = bandpair%l2g(p2loc)
                 k = pijmap(1,p2)
                 l = pijmap(2,p2)
                 !
                 DO p1 = 1, n_pairs
                    !
                    i = pijmap(1,p1)
                    j = pijmap(2,p1)
                    !
                    eri_wp(p1,p2,s1,s2) = eri_wp(p1,p2,s1,s2) &
                    & + braket(p1,s1,m)*chi_body(m,nloc)*braket(p2,s2,n)/omega
                    IF(l_macropol .AND. i==j .AND. k==l) THEN
                       eri_wp(p1,p2,s1,s2) = eri_wp(p1,p2,s1,s2) + chi_head*pot3D%div
                    ENDIF
                    !
                 ENDDO
              ENDDO
           ENDDO
        ENDDO
     ENDDO
     !
  ENDDO ! iterate over m, n
  !
  CALL mp_sum(eri_wp, inter_bgrp_comm)
  CALL mp_sum(eri_wp, inter_image_comm)
  !
  CALL update_bar_type(barra, 'Wp', 1)
  CALL stop_bar_type(barra, 'Wp')
  !
END SUBROUTINE