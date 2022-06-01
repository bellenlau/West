!
! Copyright (C) 2020-2021
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
! This file is part of WEST.
!
!-----------------------------------------------------------------------
MODULE west_cuda
   !-----------------------------------------------------------------------
   !
   USE kinds,       ONLY : DP,sgl
#if defined(__CUDA)
   USE becmod_gpum, ONLY : bec_type_d
   USE cublas
   USE cusolverdn
   !
   IMPLICIT NONE
   !
   ! DFPT
   !
   COMPLEX(DP), DEVICE, ALLOCATABLE :: evckmq_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: aux_r_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: aux_g_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: dpsi_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: dpsic_d(:)
   !
   ! Linsolve
   !
   INTEGER, DEVICE, ALLOCATABLE :: ibnd_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: eu_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: a_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: c_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: rho_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: rhoold_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: g_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: t_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: h_d(:,:)
   !
   ! Wstat
   !
   REAL(DP), DEVICE, ALLOCATABLE :: c_distr_r_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: c_distr_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: a_g_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: b_g_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: h_g_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: h2_g_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: amat_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: vec_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: zbraket_d(:)
   !
   ! GW
   !
   INTEGER, DEVICE, ALLOCATABLE :: l2g_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: sqvc_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: bg_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: ovlp_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: ovlp2_r_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: evckpq_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: pertg_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: pertr_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: pertr_nc_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: psick_nc_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: psick_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: ovlp_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: ovlp2_c_d(:,:)
   !
   ! W
   !
   REAL(DP), DEVICE, ALLOCATABLE :: diago_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: dmati_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: zmatr_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: zmati_q_d(:,:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: zmatr_q_d(:,:,:,:)
   !
   ! Macropol
   !
   REAL(DP), DEVICE, ALLOCATABLE :: gk_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: deff_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: phi_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: phi_tmp_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: deff_nc_d(:,:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: ps2_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: psc_d(:,:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: dvkb_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: work_d(:,:)
   REAL(DP), DEVICE, POINTER :: becp1_d_r_d(:,:)
   REAL(DP), DEVICE, POINTER :: becp2_d_r_d(:,:)
   COMPLEX(DP), DEVICE, POINTER :: becp1_d_k_d(:,:)
   COMPLEX(DP), DEVICE, POINTER :: becp2_d_k_d(:,:)
   COMPLEX(DP), DEVICE, POINTER :: becp1_d_nc_d(:,:,:)
   COMPLEX(DP), DEVICE, POINTER :: becp2_d_nc_d(:,:,:)
   TYPE(bec_type_d), TARGET :: becp1_d ! (nkb,m)
   TYPE(bec_type_d), TARGET :: becp2_d ! (nkb,m)
   !
   ! Chi invert
   !
   REAL(DP), DEVICE, ALLOCATABLE :: body_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: x_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: wh_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: wl_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: tmph_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: tmpl_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: tmpt_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: lambda_r_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: body_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: x_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: wh_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: wl_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: tmph_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: tmpl_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: tmpt_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: lambda_c_d(:,:)
   INTEGER, DEVICE, POINTER :: piv_d(:)
   !
   ! Lanczos
   !
   REAL(DP), DEVICE, ALLOCATABLE :: beta_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: brak_r_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: q_s_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: r_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: brak_c_d(:,:,:)
   !
   ! QP
   !
   REAL(DP), DEVICE, ALLOCATABLE :: d_epsm1_ifr_d(:,:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: d_epsm1_ifr_trans_d(:,:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: d_body2_ifr_d(:,:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: dtemp_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: z_epsm1_rfr_trans_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: z_epsm1_ifr_q_d(:,:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: z_epsm1_ifr_trans_q_d(:,:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: z_epsm1_rfr_trans_q_d(:,:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: z_body2_ifr_q_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: ztemp_d(:,:)
   !
   ! Workspace
   !
   INTEGER, DEVICE, ALLOCATABLE :: igq_q_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: e_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: eprec_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: ps_r_d(:,:)
   REAL(DP), DEVICE, ALLOCATABLE :: tmp_r_d(:)
   REAL(DP), DEVICE, ALLOCATABLE :: tmp_r3_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: ps_c_d(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: tmp_c_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: tmp_c3_d(:,:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: phase_d(:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: dvpsi_d(:,:)
   COMPLEX(DP), PINNED, ALLOCATABLE :: dvpsi_h(:,:)
   INTEGER, DEVICE, POINTER :: dfft_nl_d(:)
   INTEGER, DEVICE, POINTER :: dfft_nlm_d(:)
   TYPE(cusolverDnHandle) :: cusolver_h
   !
   CONTAINS
   !
   !-----------------------------------------------------------------------
   SUBROUTINE west_gpu_start()
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : use_gpu
   USE io_global,             ONLY : stdout
#if defined(__SP_FFT)
   USE control_flags,         ONLY : use_sp_fft
   USE command_line_options,  ONLY : single_precision_fft_
#endif
   !
   IMPLICIT NONE
   !
   ! Workspace
   !
   INTEGER :: istat
   !
   LOGICAL, EXTERNAL :: check_gpu_support
   !
   use_gpu = check_gpu_support
   IF(.NOT. use_gpu) CALL errore('gpu_start','use_gpu .FALSE.',1)
   !
#if defined(__SP_FFT)
   use_sp_fft = (use_gpu .AND. single_precision_fft_)
#endif
   !
   istat = cusolverDnCreate(cusolver_h)
   IF(istat /= 0) CALL errore('gpu_start','coSOLVER init failed',1)
   !
   WRITE(stdout,'(/,5X,A)') 'GPU acceleration enabled'
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE west_gpu_end()
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : use_gpu
   !
   IMPLICIT NONE
   !
   ! Workspace
   !
   INTEGER :: istat
   !
   IF(use_gpu) THEN
      istat = cusolverDnDestroy(cusolver_h)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_dfpt_gpu(q_grid_np,max_nbnd)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE fft_base,              ONLY : dffts
   USE noncollin_module,      ONLY : npol
   USE pwcom,                 ONLY : npwx
   USE westcom,               ONLY : npwqx,igq_q
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: q_grid_np
   INTEGER, INTENT(IN) :: max_nbnd
   !
   CALL allocate_linsolve_gpu(max_nbnd)
   !
   IF(.NOT. gamma_only) THEN
      ALLOCATE(evckmq_d(npwx*npol,max_nbnd))
      ALLOCATE(phase_d(dffts%nnr))
      ALLOCATE(dpsic_d(dffts%nnr))
   ENDIF
   ALLOCATE(aux_g_d(npwqx))
   ALLOCATE(aux_r_d(dffts%nnr))
   ALLOCATE(dvpsi_d(npwx*npol,max_nbnd))
   ALLOCATE(dpsi_d(npwx*npol,max_nbnd))
   ALLOCATE(e_d(max_nbnd))
   ALLOCATE(eprec_d(max_nbnd))
   ALLOCATE(igq_q_d(npwqx,q_grid_np))
   !
   igq_q_d = igq_q
   dfft_nl_d => dffts%nl_d
   dfft_nlm_d => dffts%nlm_d
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_dfpt_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   CALL deallocate_linsolve_gpu()
   !
   IF(ALLOCATED(evckmq_d)) THEN
      DEALLOCATE(evckmq_d)
   ENDIF
   IF(ALLOCATED(phase_d)) THEN
      DEALLOCATE(phase_d)
   ENDIF
   IF(ALLOCATED(dpsic_d)) THEN
      DEALLOCATE(dpsic_d)
   ENDIF
   IF(ALLOCATED(aux_g_d)) THEN
      DEALLOCATE(aux_g_d)
   ENDIF
   IF(ALLOCATED(aux_r_d)) THEN
      DEALLOCATE(aux_r_d)
   ENDIF
   IF(ALLOCATED(dvpsi_d)) THEN
      DEALLOCATE(dvpsi_d)
   ENDIF
   IF(ALLOCATED(dpsi_d)) THEN
      DEALLOCATE(dpsi_d)
   ENDIF
   IF(ALLOCATED(e_d)) THEN
      DEALLOCATE(e_d)
   ENDIF
   IF(ALLOCATED(eprec_d)) THEN
      DEALLOCATE(eprec_d)
   ENDIF
   IF(ALLOCATED(igq_q_d)) THEN
      DEALLOCATE(igq_q_d)
   ENDIF
   IF(ASSOCIATED(dfft_nl_d)) THEN
      NULLIFY(dfft_nl_d)
   ENDIF
   IF(ASSOCIATED(dfft_nlm_d)) THEN
      NULLIFY(dfft_nlm_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_linsolve_gpu(max_nbnd)
   !-----------------------------------------------------------------------
   !
   USE noncollin_module,      ONLY : npol
   USE pwcom,                 ONLY : npwx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: max_nbnd
   !
   ALLOCATE(ibnd_d(max_nbnd))
   ALLOCATE(eu_d(max_nbnd))
   ALLOCATE(a_d(max_nbnd))
   ALLOCATE(c_d(max_nbnd))
   ALLOCATE(rho_d(max_nbnd))
   ALLOCATE(rhoold_d(max_nbnd))
   ALLOCATE(g_d(npwx*npol,max_nbnd))
   ALLOCATE(t_d(npwx*npol,max_nbnd))
   ALLOCATE(h_d(npwx*npol,max_nbnd))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_linsolve_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(ibnd_d)) THEN
      DEALLOCATE(ibnd_d)
   ENDIF
   IF(ALLOCATED(eu_d)) THEN
      DEALLOCATE(eu_d)
   ENDIF
   IF(ALLOCATED(a_d)) THEN
      DEALLOCATE(a_d)
   ENDIF
   IF(ALLOCATED(c_d)) THEN
      DEALLOCATE(c_d)
   ENDIF
   IF(ALLOCATED(rho_d)) THEN
      DEALLOCATE(rho_d)
   ENDIF
   IF(ALLOCATED(rhoold_d)) THEN
      DEALLOCATE(rhoold_d)
   ENDIF
   IF(ALLOCATED(g_d)) THEN
      DEALLOCATE(g_d)
   ENDIF
   IF(ALLOCATED(t_d)) THEN
      DEALLOCATE(t_d)
   ENDIF
   IF(ALLOCATED(h_d)) THEN
      DEALLOCATE(h_d)
   ENDIF
   IF(ALLOCATED(ps_r_d)) THEN
      DEALLOCATE(ps_r_d)
   ENDIF
   IF(ALLOCATED(ps_c_d)) THEN
      DEALLOCATE(ps_c_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_gw_gpu(nglob,nlocx,nloc,q_grid_np)
   !-----------------------------------------------------------------------
   !
   USE cell_base,             ONLY : bg
   USE control_flags,         ONLY : gamma_only
   USE fft_base,              ONLY : dffts
   USE noncollin_module,      ONLY : noncolin,npol
   USE pwcom,                 ONLY : npwx,nbnd
   USE westcom,               ONLY : npwqx,igq_q,n_lanczos
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nglob
   INTEGER, INTENT(IN) :: nlocx
   INTEGER, INTENT(IN) :: nloc
   INTEGER, INTENT(IN) :: q_grid_np
   !
   CALL allocate_lanczos_gpu(nglob,nloc)
   !
   IF(.NOT. gamma_only) THEN
      ALLOCATE(evckpq_d(npwx*npol,nbnd))
      ALLOCATE(phase_d(dffts%nnr))
      IF(noncolin) THEN
         ALLOCATE(psick_nc_d(dffts%nnr,npol))
      ELSE
         ALLOCATE(psick_d(dffts%nnr))
      ENDIF
   ENDIF
   IF(gamma_only) THEN
      ALLOCATE(tmp_r3_d(nlocx,nloc,n_lanczos))
   ELSE
      ALLOCATE(tmp_c3_d(nlocx,nloc,n_lanczos))
   ENDIF
   ALLOCATE(bg_d(3,3))
   ALLOCATE(sqvc_d(npwqx))
   ALLOCATE(pertg_d(npwqx))
   ALLOCATE(pertr_d(dffts%nnr))
   ALLOCATE(dvpsi_d(npwx*npol,nlocx))
   ALLOCATE(dvpsi_h(npwx*npol,nlocx))
   ALLOCATE(l2g_d(nloc))
   ALLOCATE(igq_q_d(npwqx,q_grid_np))
   !
   bg_d = bg
   igq_q_d = igq_q
   dfft_nl_d => dffts%nl_d
   dfft_nlm_d => dffts%nlm_d
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_gw_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   CALL deallocate_lanczos_gpu()
   !
   IF(ALLOCATED(evckpq_d)) THEN
      DEALLOCATE(evckpq_d)
   ENDIF
   IF(ALLOCATED(phase_d)) THEN
      DEALLOCATE(phase_d)
   ENDIF
   IF(ALLOCATED(psick_nc_d)) THEN
      DEALLOCATE(psick_nc_d)
   ENDIF
   IF(ALLOCATED(psick_d)) THEN
      DEALLOCATE(psick_d)
   ENDIF
   IF(ALLOCATED(tmp_r3_d)) THEN
      DEALLOCATE(tmp_r3_d)
   ENDIF
   IF(ALLOCATED(tmp_c3_d)) THEN
      DEALLOCATE(tmp_c3_d)
   ENDIF
   IF(ALLOCATED(bg_d)) THEN
      DEALLOCATE(bg_d)
   ENDIF
   IF(ALLOCATED(sqvc_d)) THEN
      DEALLOCATE(sqvc_d)
   ENDIF
   IF(ALLOCATED(pertg_d)) THEN
      DEALLOCATE(pertg_d)
   ENDIF
   IF(ALLOCATED(pertr_d)) THEN
      DEALLOCATE(pertr_d)
   ENDIF
   IF(ALLOCATED(dvpsi_d)) THEN
      DEALLOCATE(dvpsi_d)
   ENDIF
   IF(ALLOCATED(dvpsi_h)) THEN
      DEALLOCATE(dvpsi_h)
   ENDIF
   IF(ALLOCATED(l2g_d)) THEN
      DEALLOCATE(l2g_d)
   ENDIF
   IF(ALLOCATED(igq_q_d)) THEN
      DEALLOCATE(igq_q_d)
   ENDIF
   IF(ALLOCATED(ps_r_d)) THEN
      DEALLOCATE(ps_r_d)
   ENDIF
   IF(ALLOCATED(ps_c_d)) THEN
      DEALLOCATE(ps_c_d)
   ENDIF
   IF(ALLOCATED(ovlp_r_d)) THEN
      DEALLOCATE(ovlp_r_d)
   ENDIF
   IF(ALLOCATED(ovlp_c_d)) THEN
      DEALLOCATE(ovlp_c_d)
   ENDIF
   IF(ASSOCIATED(dfft_nl_d)) THEN
      NULLIFY(dfft_nl_d)
   ENDIF
   IF(ASSOCIATED(dfft_nlm_d)) THEN
      NULLIFY(dfft_nlm_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_w_gpu(nglob,nloc,ifr_nloc,rfr_nloc,q_grid_np)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE westcom,               ONLY : n_lanczos
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nglob
   INTEGER, INTENT(IN) :: nloc
   INTEGER, INTENT(IN) :: ifr_nloc
   INTEGER, INTENT(IN) :: rfr_nloc
   INTEGER, INTENT(IN) :: q_grid_np
   !
   ALLOCATE(diago_d(n_lanczos,nloc))
   IF(gamma_only) THEN
      ALLOCATE(dmati_d(nglob,nloc,ifr_nloc))
      ALLOCATE(zmatr_d(nglob,nloc,rfr_nloc))
   ELSE
      ALLOCATE(zmati_q_d(nglob,nloc,ifr_nloc,q_grid_np))
      ALLOCATE(zmatr_q_d(nglob,nloc,rfr_nloc,q_grid_np))
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_w_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(diago_d)) THEN
      DEALLOCATE(diago_d)
   ENDIF
   IF(ALLOCATED(dmati_d)) THEN
      DEALLOCATE(dmati_d)
   ENDIF
   IF(ALLOCATED(zmatr_d)) THEN
      DEALLOCATE(zmatr_d)
   ENDIF
   IF(ALLOCATED(zmati_q_d)) THEN
      DEALLOCATE(zmati_q_d)
   ENDIF
   IF(ALLOCATED(zmatr_q_d)) THEN
      DEALLOCATE(zmatr_q_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_lanczos_gpu(nglob,nloc)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE noncollin_module,      ONLY : npol
   USE pwcom,                 ONLY : npwx
   USE westcom,               ONLY : n_lanczos
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nglob
   INTEGER, INTENT(IN) :: nloc
   !
   ALLOCATE(beta_d(nloc))
   ALLOCATE(q_s_d(npwx*npol,nloc,n_lanczos))
   ALLOCATE(r_d(npwx*npol,nloc))
   ALLOCATE(tmp_r_d(nloc))
   IF(.NOT. gamma_only) THEN
      ALLOCATE(tmp_c_d(nloc))
   ENDIF
   IF(gamma_only) THEN
      ALLOCATE(brak_r_d(nglob,n_lanczos,nloc))
   ELSE
      ALLOCATE(brak_c_d(nglob,n_lanczos,nloc))
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_lanczos_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(beta_d)) THEN
      DEALLOCATE(beta_d)
   ENDIF
   IF(ALLOCATED(q_s_d)) THEN
      DEALLOCATE(q_s_d)
   ENDIF
   IF(ALLOCATED(r_d)) THEN
      DEALLOCATE(r_d)
   ENDIF
   IF(ALLOCATED(tmp_r_d)) THEN
      DEALLOCATE(tmp_r_d)
   ENDIF
   IF(ALLOCATED(tmp_c_d)) THEN
      DEALLOCATE(tmp_c_d)
   ENDIF
   IF(ALLOCATED(brak_r_d)) THEN
      DEALLOCATE(brak_r_d)
   ENDIF
   IF(ALLOCATED(brak_c_d)) THEN
      DEALLOCATE(brak_c_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE reallocate_ps_gpu(nbndval,m)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nbndval
   INTEGER, INTENT(IN) :: m
   !
   IF(gamma_only) THEN
      IF(ALLOCATED(ps_r_d)) THEN
         IF(SIZE(ps_r_d,DIM=1) /= nbndval .OR. SIZE(ps_r_d,DIM=2) /= m) THEN
            DEALLOCATE(ps_r_d)
         ENDIF
      ENDIF
      IF(.NOT. ALLOCATED(ps_r_d)) THEN
         ALLOCATE(ps_r_d(nbndval,m))
      ENDIF
   ELSE
      IF(ALLOCATED(ps_c_d)) THEN
         IF(SIZE(ps_c_d,DIM=1) /= nbndval .OR. SIZE(ps_c_d,DIM=2) /= m) THEN
            DEALLOCATE(ps_c_d)
         ENDIF
      ENDIF
      IF(.NOT. ALLOCATED(ps_c_d)) THEN
         ALLOCATE(ps_c_d(nbndval,m))
      ENDIF
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE reallocate_overlap_gpu(nglob,nbndcon)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nglob
   INTEGER, INTENT(IN) :: nbndcon
   !
   IF(gamma_only) THEN
      IF(ALLOCATED(ovlp_r_d)) THEN
         IF(SIZE(ovlp_r_d,DIM=1) /= nglob .OR. SIZE(ovlp_r_d,DIM=2) /= nbndcon) THEN
            DEALLOCATE(ovlp_r_d)
         ENDIF
      ENDIF
      IF(.NOT. ALLOCATED(ovlp_r_d)) THEN
         ALLOCATE(ovlp_r_d(nglob,nbndcon))
      ENDIF
   ELSE
      IF(ALLOCATED(ovlp_c_d)) THEN
         IF(SIZE(ovlp_c_d,DIM=1) /= nglob .OR. SIZE(ovlp_c_d,DIM=2) /= nbndcon) THEN
            DEALLOCATE(ovlp_c_d)
         ENDIF
      ENDIF
      IF(.NOT. ALLOCATED(ovlp_c_d)) THEN
         ALLOCATE(ovlp_c_d(nglob,nbndcon))
      ENDIF
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_macropol_gpu()
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE ions_base,             ONLY : nat
   USE lsda_mod,              ONLY : nspin
   USE noncollin_module,      ONLY : noncolin, npol
   USE uspp,                  ONLY : nkb
   USE uspp_param,            ONLY : nhm
   USE wvfct,                 ONLY : npwx, nbnd
   USE becmod_subs_gpum,      ONLY : allocate_bec_type_gpu
   !
   IMPLICIT NONE
   !
   ALLOCATE(e_d(3))
   ALLOCATE(eprec_d(3))
   ALLOCATE(phi_d(npwx*npol,3))
   ALLOCATE(phi_tmp_d(npwx*npol,3))
   ALLOCATE(gk_d(3,npwx))
   ALLOCATE(dvkb_d(npwx,nkb))
   ALLOCATE(work_d(npwx,nkb))
   IF(noncolin) THEN
      ALLOCATE(deff_nc_d(nhm,nhm,nat,nspin))
      ALLOCATE(psc_d(nkb,npol,nbnd,2))
   ELSE
      ALLOCATE(deff_d(nhm,nhm,nat))
      ALLOCATE(ps2_d(nkb,nbnd,2))
   ENDIF
   !
   CALL allocate_bec_type_gpu(nkb,1,becp1_d)
   CALL allocate_bec_type_gpu(nkb,1,becp2_d)
   !
   IF(noncolin) THEN
      becp1_d_nc_d => becp1_d%nc_d
      becp2_d_nc_d => becp2_d%nc_d
   ELSEIF(gamma_only) THEN
      becp1_d_r_d => becp1_d%r_d
      becp2_d_r_d => becp2_d%r_d
   ELSE
      becp1_d_k_d => becp1_d%k_d
      becp2_d_k_d => becp2_d%k_d
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_macropol_gpu()
   !-----------------------------------------------------------------------
   !
   USE becmod_subs_gpum,      ONLY : deallocate_bec_type_gpu

   IMPLICIT NONE
   !
   IF(ALLOCATED(e_d)) THEN
      DEALLOCATE(e_d)
   ENDIF
   IF(ALLOCATED(eprec_d)) THEN
      DEALLOCATE(eprec_d)
   ENDIF
   IF(ALLOCATED(phi_d)) THEN
      DEALLOCATE(phi_d)
   ENDIF
   IF(ALLOCATED(phi_tmp_d)) THEN
      DEALLOCATE(phi_tmp_d)
   ENDIF
   IF(ALLOCATED(gk_d)) THEN
      DEALLOCATE(gk_d)
   ENDIF
   IF(ALLOCATED(dvkb_d)) THEN
      DEALLOCATE(dvkb_d)
   ENDIF
   IF(ALLOCATED(work_d)) THEN
      DEALLOCATE(work_d)
   ENDIF
   IF(ALLOCATED(deff_nc_d)) THEN
      DEALLOCATE(deff_nc_d)
   ENDIF
   IF(ALLOCATED(psc_d)) THEN
      DEALLOCATE(psc_d)
   ENDIF
   IF(ALLOCATED(deff_d)) THEN
      DEALLOCATE(deff_d)
   ENDIF
   IF(ALLOCATED(ps2_d)) THEN
      DEALLOCATE(ps2_d)
   ENDIF
   IF(ASSOCIATED(becp1_d_r_d)) THEN
      NULLIFY(becp1_d_r_d)
   ENDIF
   IF(ASSOCIATED(becp2_d_r_d)) THEN
      NULLIFY(becp2_d_r_d)
   ENDIF
   IF(ASSOCIATED(becp1_d_k_d)) THEN
      NULLIFY(becp1_d_k_d)
   ENDIF
   IF(ASSOCIATED(becp2_d_k_d)) THEN
      NULLIFY(becp2_d_k_d)
   ENDIF
   IF(ASSOCIATED(becp1_d_nc_d)) THEN
      NULLIFY(becp1_d_nc_d)
   ENDIF
   IF(ASSOCIATED(becp2_d_nc_d)) THEN
      NULLIFY(becp2_d_nc_d)
   ENDIF
   !
   CALL deallocate_bec_type_gpu(becp1_d)
   CALL deallocate_bec_type_gpu(becp2_d)
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_chi_gpu(l_real)
   !-----------------------------------------------------------------------
   !
   USE westcom,               ONLY : n_pdep_eigen_to_use,l_macropol
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   LOGICAL, INTENT(IN) :: l_real
   !
   ! Workspace
   !
   INTEGER :: istat
   INTEGER :: lwork
   INTEGER :: lwork2
   !
   IF(l_real) THEN
      ALLOCATE(body_r_d(n_pdep_eigen_to_use,n_pdep_eigen_to_use))
      ALLOCATE(x_r_d(n_pdep_eigen_to_use,n_pdep_eigen_to_use))
      ALLOCATE(lambda_r_d(n_pdep_eigen_to_use,n_pdep_eigen_to_use))
      IF(l_macropol) THEN
         ALLOCATE(wh_r_d(n_pdep_eigen_to_use,3))
         ALLOCATE(wl_r_d(3,n_pdep_eigen_to_use))
         ALLOCATE(tmph_r_d(n_pdep_eigen_to_use,3))
         ALLOCATE(tmpl_r_d(3,n_pdep_eigen_to_use))
         ALLOCATE(tmpt_r_d(3,3))
      ENDIF
      !
      istat = cusolverDnDgetrf_bufferSize(cusolver_h,n_pdep_eigen_to_use,n_pdep_eigen_to_use,&
      & x_r_d,n_pdep_eigen_to_use,lwork)
      istat = cusolverDnDtrtri_buffersize(cusolver_h,CUBLAS_FILL_MODE_UPPER,CUBLAS_DIAG_NON_UNIT,&
      & n_pdep_eigen_to_use,x_r_d,n_pdep_eigen_to_use,lwork2)
      !
      lwork = MAX(lwork,lwork2)
      lwork = MAX(lwork,n_pdep_eigen_to_use**2)
      !
      ALLOCATE(tmp_r_d(lwork))
   ELSE
      ALLOCATE(body_c_d(n_pdep_eigen_to_use,n_pdep_eigen_to_use))
      ALLOCATE(x_c_d(n_pdep_eigen_to_use,n_pdep_eigen_to_use))
      ALLOCATE(lambda_c_d(n_pdep_eigen_to_use,n_pdep_eigen_to_use))
      IF(l_macropol) THEN
         ALLOCATE(wh_c_d(n_pdep_eigen_to_use,3))
         ALLOCATE(wl_c_d(3,n_pdep_eigen_to_use))
         ALLOCATE(tmph_c_d(n_pdep_eigen_to_use,3))
         ALLOCATE(tmpl_c_d(3,n_pdep_eigen_to_use))
         ALLOCATE(tmpt_c_d(3,3))
      ENDIF
      !
      istat = cusolverDnZgetrf_bufferSize(cusolver_h,n_pdep_eigen_to_use,n_pdep_eigen_to_use,&
      & x_c_d,n_pdep_eigen_to_use,lwork)
      istat = cusolverDnZtrtri_buffersize(cusolver_h,CUBLAS_FILL_MODE_UPPER,CUBLAS_DIAG_NON_UNIT,&
      & n_pdep_eigen_to_use,x_c_d,n_pdep_eigen_to_use,lwork2)
      !
      lwork = MAX(lwork,lwork2)
      lwork = MAX(lwork,n_pdep_eigen_to_use**2)
      !
      ALLOCATE(tmp_c_d(lwork))
   ENDIF
   piv_d => NULL()
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_chi_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(body_r_d)) THEN
      DEALLOCATE(body_r_d)
   ENDIF
   IF(ALLOCATED(x_r_d)) THEN
      DEALLOCATE(x_r_d)
   ENDIF
   IF(ALLOCATED(lambda_r_d)) THEN
      DEALLOCATE(lambda_r_d)
   ENDIF
   IF(ALLOCATED(wh_r_d)) THEN
      DEALLOCATE(wh_r_d)
   ENDIF
   IF(ALLOCATED(wl_r_d)) THEN
      DEALLOCATE(wl_r_d)
   ENDIF
   IF(ALLOCATED(tmph_r_d)) THEN
      DEALLOCATE(tmph_r_d)
   ENDIF
   IF(ALLOCATED(tmpl_r_d)) THEN
      DEALLOCATE(tmpl_r_d)
   ENDIF
   IF(ALLOCATED(tmpt_r_d)) THEN
      DEALLOCATE(tmpt_r_d)
   ENDIF
   IF(ALLOCATED(tmp_r_d)) THEN
      DEALLOCATE(tmp_r_d)
   ENDIF
   IF(ALLOCATED(body_c_d)) THEN
      DEALLOCATE(body_c_d)
   ENDIF
   IF(ALLOCATED(x_c_d)) THEN
      DEALLOCATE(x_c_d)
   ENDIF
   IF(ALLOCATED(lambda_c_d)) THEN
      DEALLOCATE(lambda_c_d)
   ENDIF
   IF(ALLOCATED(wh_c_d)) THEN
      DEALLOCATE(wh_c_d)
   ENDIF
   IF(ALLOCATED(wl_c_d)) THEN
      DEALLOCATE(wl_c_d)
   ENDIF
   IF(ALLOCATED(tmph_c_d)) THEN
      DEALLOCATE(tmph_c_d)
   ENDIF
   IF(ALLOCATED(tmpl_c_d)) THEN
      DEALLOCATE(tmpl_c_d)
   ENDIF
   IF(ALLOCATED(tmpt_c_d)) THEN
      DEALLOCATE(tmpt_c_d)
   ENDIF
   IF(ALLOCATED(tmp_c_d)) THEN
      DEALLOCATE(tmp_c_d)
   ENDIF
   IF(ASSOCIATED(piv_d)) THEN
      NULLIFY(piv_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_exx_gpu()
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE fft_base,              ONLY : dffts
   USE gvect,                 ONLY : ngm
   USE noncollin_module,      ONLY : noncolin,npol
   USE pwcom,                 ONLY : npwx,nbnd
   !
   IMPLICIT NONE
   !
   IF(.NOT. gamma_only) THEN
      ALLOCATE(evckpq_d(npwx*npol,nbnd))
      ALLOCATE(phase_d(dffts%nnr))
   ENDIF
   ALLOCATE(sqvc_d(ngm))
   ALLOCATE(pertg_d(ngm))
   IF(noncolin) THEN
      ALLOCATE(pertr_nc_d(dffts%nnr,npol))
   ELSE
      ALLOCATE(pertr_d(dffts%nnr))
   ENDIF
   !
   dfft_nl_d => dffts%nl_d
   dfft_nlm_d => dffts%nlm_d
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_exx_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(evckpq_d)) THEN
      DEALLOCATE(evckpq_d)
   ENDIF
   IF(ALLOCATED(phase_d)) THEN
      DEALLOCATE(phase_d)
   ENDIF
   IF(ALLOCATED(sqvc_d)) THEN
      DEALLOCATE(sqvc_d)
   ENDIF
   IF(ALLOCATED(pertg_d)) THEN
      DEALLOCATE(pertg_d)
   ENDIF
   IF(ALLOCATED(pertr_nc_d)) THEN
      DEALLOCATE(pertr_nc_d)
   ENDIF
   IF(ALLOCATED(pertr_d)) THEN
      DEALLOCATE(pertr_d)
   ENDIF
   IF(ASSOCIATED(dfft_nl_d)) THEN
      NULLIFY(dfft_nl_d)
   ENDIF
   IF(ASSOCIATED(dfft_nlm_d)) THEN
      NULLIFY(dfft_nlm_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_qp_gpu(nglob,nloc,ifr_nloc,rfr_nloc,q_grid_np)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE pwcom,                 ONLY : nbnd
   USE westcom,               ONLY : n_lanczos
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nglob
   INTEGER, INTENT(IN) :: nloc
   INTEGER, INTENT(IN) :: ifr_nloc
   INTEGER, INTENT(IN) :: rfr_nloc
   INTEGER, INTENT(IN) :: q_grid_np
   !
   ALLOCATE(l2g_d(nloc))
   IF(gamma_only) THEN
      ALLOCATE(ovlp_r_d(nglob,nbnd))
      ALLOCATE(ovlp2_r_d(nloc,nbnd))
      ALLOCATE(d_epsm1_ifr_d(nglob,nloc,ifr_nloc))
      ALLOCATE(d_epsm1_ifr_trans_d(nloc,nglob,ifr_nloc))
      ALLOCATE(z_epsm1_rfr_trans_d(nloc,nglob,rfr_nloc))
      ALLOCATE(brak_r_d(nglob,n_lanczos,nloc))
      ALLOCATE(d_body2_ifr_d(n_lanczos,nloc,ifr_nloc))
   ELSE
      ALLOCATE(ovlp_c_d(nglob,nbnd))
      ALLOCATE(ovlp2_c_d(nloc,nbnd))
      ALLOCATE(z_epsm1_ifr_q_d(nglob,nloc,ifr_nloc,q_grid_np))
      ALLOCATE(z_epsm1_ifr_trans_q_d(nloc,nglob,ifr_nloc,q_grid_np))
      ALLOCATE(z_epsm1_rfr_trans_q_d(nloc,nglob,rfr_nloc,q_grid_np))
      ALLOCATE(brak_c_d(nglob,n_lanczos,nloc))
      ALLOCATE(z_body2_ifr_q_d(n_lanczos,nloc,ifr_nloc))
   ENDIF
   IF(gamma_only) THEN
      ALLOCATE(dtemp_d(nbnd,ifr_nloc))
      ALLOCATE(ztemp_d(nbnd,rfr_nloc))
   ELSE
      ALLOCATE(ztemp_d(nbnd,MAX(ifr_nloc,rfr_nloc)))
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_qp_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(l2g_d)) THEN
      DEALLOCATE(l2g_d)
   ENDIF
   IF(ALLOCATED(ovlp_r_d)) THEN
      DEALLOCATE(ovlp_r_d)
   ENDIF
   IF(ALLOCATED(ovlp2_r_d)) THEN
      DEALLOCATE(ovlp2_r_d)
   ENDIF
   IF(ALLOCATED(ovlp_c_d)) THEN
      DEALLOCATE(ovlp_c_d)
   ENDIF
   IF(ALLOCATED(ovlp2_c_d)) THEN
      DEALLOCATE(ovlp2_c_d)
   ENDIF
   IF(ALLOCATED(d_epsm1_ifr_d)) THEN
      DEALLOCATE(d_epsm1_ifr_d)
   ENDIF
   IF(ALLOCATED(d_epsm1_ifr_trans_d)) THEN
      DEALLOCATE(d_epsm1_ifr_trans_d)
   ENDIF
   IF(ALLOCATED(z_epsm1_rfr_trans_d)) THEN
      DEALLOCATE(z_epsm1_rfr_trans_d)
   ENDIF
   IF(ALLOCATED(z_epsm1_ifr_q_d)) THEN
      DEALLOCATE(z_epsm1_ifr_q_d)
   ENDIF
   IF(ALLOCATED(z_epsm1_ifr_trans_q_d)) THEN
      DEALLOCATE(z_epsm1_ifr_trans_q_d)
   ENDIF
   IF(ALLOCATED(z_epsm1_rfr_trans_q_d)) THEN
      DEALLOCATE(z_epsm1_rfr_trans_q_d)
   ENDIF
   IF(ALLOCATED(brak_r_d)) THEN
      DEALLOCATE(brak_r_d)
   ENDIF
   IF(ALLOCATED(brak_c_d)) THEN
      DEALLOCATE(brak_c_d)
   ENDIF
   IF(ALLOCATED(d_body2_ifr_d)) THEN
      DEALLOCATE(d_body2_ifr_d)
   ENDIF
   IF(ALLOCATED(z_body2_ifr_q_d)) THEN
      DEALLOCATE(z_body2_ifr_q_d)
   ENDIF
   IF(ALLOCATED(dtemp_d)) THEN
      DEALLOCATE(dtemp_d)
   ENDIF
   IF(ALLOCATED(ztemp_d)) THEN
      DEALLOCATE(ztemp_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_build_hr_gpu(nlocx,nglob,c_nloc)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE westcom,               ONLY : npwqx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nlocx
   INTEGER, INTENT(IN) :: nglob
   INTEGER, INTENT(IN) :: c_nloc
   !
   ALLOCATE(a_g_d(npwqx,nlocx))
   ALLOCATE(b_g_d(npwqx,nlocx))
   IF(gamma_only) THEN
      ALLOCATE(c_distr_r_d(nglob,c_nloc))
   ELSE
      ALLOCATE(c_distr_c_d(nglob,c_nloc))
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_build_hr_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(a_g_d)) THEN
      DEALLOCATE(a_g_d)
   ENDIF
   IF(ALLOCATED(b_g_d)) THEN
      DEALLOCATE(b_g_d)
   ENDIF
   IF(ALLOCATED(c_distr_r_d)) THEN
      DEALLOCATE(c_distr_r_d)
   ENDIF
   IF(ALLOCATED(c_distr_c_d)) THEN
      DEALLOCATE(c_distr_c_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_update_vr_gpu(nlocx)
   !-----------------------------------------------------------------------
   !
   USE westcom,               ONLY : npwqx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nlocx
   !
   ALLOCATE(a_g_d(npwqx,nlocx))
   ALLOCATE(b_g_d(npwqx,nlocx))
   ALLOCATE(h_g_d(npwqx,nlocx))
   ALLOCATE(h2_g_d(npwqx,nlocx))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_update_vr_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(a_g_d)) THEN
      DEALLOCATE(a_g_d)
   ENDIF
   IF(ALLOCATED(b_g_d)) THEN
      DEALLOCATE(b_g_d)
   ENDIF
   IF(ALLOCATED(h_g_d)) THEN
      DEALLOCATE(h_g_d)
   ENDIF
   IF(ALLOCATED(h2_g_d)) THEN
      DEALLOCATE(h2_g_d)
   ENDIF
   !
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_refresh_vr_gpu(nlocx)
   !-----------------------------------------------------------------------
   !
   USE westcom,               ONLY : npwqx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nlocx
   !
   ALLOCATE(a_g_d(npwqx,nlocx))
   ALLOCATE(h_g_d(npwqx,nlocx))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_refresh_vr_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(a_g_d)) THEN
      DEALLOCATE(a_g_d)
   ENDIF
   IF(ALLOCATED(h_g_d)) THEN
      DEALLOCATE(h_g_d)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_mgs_gpu(nlocx,nloc)
   !-----------------------------------------------------------------------
   !
   USE westcom,               ONLY : npwqx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nlocx
   INTEGER, INTENT(IN) :: nloc
   !
   ALLOCATE(amat_d(npwqx,nlocx))
   ALLOCATE(vec_d(npwqx))
   ALLOCATE(zbraket_d(nloc))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_mgs_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(amat_d)) THEN
      DEALLOCATE(amat_d)
   ENDIF
   IF(ALLOCATED(vec_d)) THEN
      DEALLOCATE(vec_d)
   ENDIF
   IF(ALLOCATED(zbraket_d)) THEN
      DEALLOCATE(zbraket_d)
   ENDIF
   !
   END SUBROUTINE
#endif
END MODULE
