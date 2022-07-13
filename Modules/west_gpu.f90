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
MODULE west_gpu
   !-----------------------------------------------------------------------
   !
   USE kinds,       ONLY : DP
#if defined(__CUDA)
   USE becmod_gpum, ONLY : bec_type_d
   USE cublas
   USE cusolverdn
   !
   IMPLICIT NONE
   !
   ! Linsolve
   !
   LOGICAL, ALLOCATABLE :: is_conv(:)
   INTEGER, ALLOCATABLE :: ibnd_todo(:)
   REAL(DP), ALLOCATABLE :: eu(:)
   REAL(DP), ALLOCATABLE :: a(:)
   REAL(DP), ALLOCATABLE :: c(:)
   REAL(DP), ALLOCATABLE :: rho(:)
   REAL(DP), ALLOCATABLE :: rhoold(:)
   COMPLEX(DP), ALLOCATABLE :: g(:,:)
   COMPLEX(DP), ALLOCATABLE :: t(:,:)
   COMPLEX(DP), ALLOCATABLE :: h(:,:)
   !$acc declare device_resident(is_conv,ibnd_todo,eu,a,c,rho,rhoold,g,t,h)
   !
   ! GW
   !
   COMPLEX(DP), DEVICE, ALLOCATABLE :: dvpsi_d(:,:)
   COMPLEX(DP), PINNED, ALLOCATABLE :: dvpsi_h(:,:)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: pertg_d(:)
   !
   ! Macropol
   !
   REAL(DP), ALLOCATABLE :: gk(:,:)
   REAL(DP), ALLOCATABLE :: deff(:,:,:)
   COMPLEX(DP), ALLOCATABLE :: deff_nc(:,:,:,:)
   COMPLEX(DP), ALLOCATABLE :: ps2(:,:,:)
   COMPLEX(DP), ALLOCATABLE :: psc(:,:,:,:)
   COMPLEX(DP), ALLOCATABLE :: dvkb(:,:)
   COMPLEX(DP), ALLOCATABLE :: work(:,:)
   !$acc declare device_resident(gk,deff,deff_nc,ps2,psc,dvkb,work)
   COMPLEX(DP), DEVICE, ALLOCATABLE :: phi_tmp_d(:,:)
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
   REAL(DP), ALLOCATABLE :: work_r(:)
   COMPLEX(DP), ALLOCATABLE :: work_c(:)
   !$acc declare device_resident(work_r,work_c)
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
   REAL(DP), ALLOCATABLE :: tmp_r(:)
   COMPLEX(DP), ALLOCATABLE :: tmp_c(:)
   COMPLEX(DP), ALLOCATABLE :: r(:,:)
   !
   ! Workspace
   !
   REAL(DP), ALLOCATABLE :: tmp_r3(:,:,:)
   REAL(DP), ALLOCATABLE :: ps_r(:,:)
   COMPLEX(DP), ALLOCATABLE :: tmp_c3(:,:,:)
   COMPLEX(DP), ALLOCATABLE :: ps_c(:,:)
   !$acc declare device_resident(tmp_r3,ps_r,tmp_c3,ps_c)
   REAL(DP), DEVICE, ALLOCATABLE :: sqvc_d(:)
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
   IMPLICIT NONE
   !
   ! Workspace
   !
   INTEGER :: istat
   !
   istat = cusolverDnDestroy(cusolver_h)
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_gpu()
   !-----------------------------------------------------------------------
   !
   USE fft_base,              ONLY : dffts
   USE westcom,               ONLY : igq_q
   !
   IMPLICIT NONE
   !
   dfft_nl_d => dffts%nl_d
   dfft_nlm_d => dffts%nlm_d
   !
   !$acc enter data copyin(igq_q)
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_gpu()
   !-----------------------------------------------------------------------
   !
   USE westcom,               ONLY : igq_q
   !
   IMPLICIT NONE
   !
   IF(ASSOCIATED(dfft_nl_d)) THEN
      NULLIFY(dfft_nl_d)
   ENDIF
   IF(ASSOCIATED(dfft_nlm_d)) THEN
      NULLIFY(dfft_nlm_d)
   ENDIF
   !
   !$acc exit data delete(igq_q)
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_dfpt_gpu(nbndloc)
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nbndloc
   !
   CALL allocate_gpu()
   CALL allocate_linsolve_gpu(nbndloc)
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_dfpt_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   CALL deallocate_gpu()
   CALL deallocate_linsolve_gpu()
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_linsolve_gpu(nbndloc)
   !-----------------------------------------------------------------------
   !
   USE noncollin_module,      ONLY : npol
   USE pwcom,                 ONLY : npwx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nbndloc
   !
   ALLOCATE(is_conv(nbndloc))
   ALLOCATE(ibnd_todo(nbndloc))
   ALLOCATE(eu(nbndloc))
   ALLOCATE(a(nbndloc))
   ALLOCATE(c(nbndloc))
   ALLOCATE(rho(nbndloc))
   ALLOCATE(rhoold(nbndloc))
   ALLOCATE(g(npwx*npol,nbndloc))
   ALLOCATE(t(npwx*npol,nbndloc))
   ALLOCATE(h(npwx*npol,nbndloc))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_linsolve_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   IF(ALLOCATED(is_conv)) THEN
      DEALLOCATE(is_conv)
   ENDIF
   IF(ALLOCATED(ibnd_todo)) THEN
      DEALLOCATE(ibnd_todo)
   ENDIF
   IF(ALLOCATED(eu)) THEN
      DEALLOCATE(eu)
   ENDIF
   IF(ALLOCATED(a)) THEN
      DEALLOCATE(a)
   ENDIF
   IF(ALLOCATED(c)) THEN
      DEALLOCATE(c)
   ENDIF
   IF(ALLOCATED(rho)) THEN
      DEALLOCATE(rho)
   ENDIF
   IF(ALLOCATED(rhoold)) THEN
      DEALLOCATE(rhoold)
   ENDIF
   IF(ALLOCATED(g)) THEN
      DEALLOCATE(g)
   ENDIF
   IF(ALLOCATED(t)) THEN
      DEALLOCATE(t)
   ENDIF
   IF(ALLOCATED(h)) THEN
      DEALLOCATE(h)
   ENDIF
   IF(ALLOCATED(ps_r)) THEN
      DEALLOCATE(ps_r)
   ENDIF
   IF(ALLOCATED(ps_c)) THEN
      DEALLOCATE(ps_c)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_gw_gpu(nlocx,nloc)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE noncollin_module,      ONLY : npol
   USE pwcom,                 ONLY : npwx
   USE westcom,               ONLY : npwqx,n_lanczos
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nlocx
   INTEGER, INTENT(IN) :: nloc
   !
   CALL allocate_gpu()
   CALL allocate_lanczos_gpu(nloc)
   !
   IF(gamma_only) THEN
      ALLOCATE(tmp_r3(nlocx,nloc,n_lanczos))
   ELSE
      ALLOCATE(tmp_c3(nlocx,nloc,n_lanczos))
   ENDIF
   ALLOCATE(sqvc_d(npwqx))
   ALLOCATE(pertg_d(npwqx))
   ALLOCATE(dvpsi_d(npwx*npol,nlocx))
   ALLOCATE(dvpsi_h(npwx*npol,nlocx))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_gw_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   CALL deallocate_gpu()
   CALL deallocate_lanczos_gpu()
   !
   IF(ALLOCATED(tmp_r3)) THEN
      DEALLOCATE(tmp_r3)
   ENDIF
   IF(ALLOCATED(tmp_c3)) THEN
      DEALLOCATE(tmp_c3)
   ENDIF
   IF(ALLOCATED(sqvc_d)) THEN
      DEALLOCATE(sqvc_d)
   ENDIF
   IF(ALLOCATED(pertg_d)) THEN
      DEALLOCATE(pertg_d)
   ENDIF
   IF(ALLOCATED(dvpsi_d)) THEN
      DEALLOCATE(dvpsi_d)
   ENDIF
   IF(ALLOCATED(dvpsi_h)) THEN
      DEALLOCATE(dvpsi_h)
   ENDIF
   IF(ALLOCATED(ps_r)) THEN
      DEALLOCATE(ps_r)
   ENDIF
   IF(ALLOCATED(ps_c)) THEN
      DEALLOCATE(ps_c)
   ENDIF
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE allocate_lanczos_gpu(nloc)
   !-----------------------------------------------------------------------
   !
   USE control_flags,         ONLY : gamma_only
   USE noncollin_module,      ONLY : npol
   USE pwcom,                 ONLY : npwx
   !
   IMPLICIT NONE
   !
   ! I/O
   !
   INTEGER, INTENT(IN) :: nloc
   !
   ALLOCATE(r(npwx*npol,nloc))
   !$acc enter data create(r)
   ALLOCATE(tmp_r(nloc))
   !$acc enter data create(tmp_r)
   IF(.NOT. gamma_only) THEN
      ALLOCATE(tmp_c(nloc))
      !$acc enter data create(tmp_c)
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
   IF(ALLOCATED(r)) THEN
      !$acc exit data delete(r)
      DEALLOCATE(r)
   ENDIF
   IF(ALLOCATED(tmp_r)) THEN
      !$acc exit data delete(tmp_r)
      DEALLOCATE(tmp_r)
   ENDIF
   IF(ALLOCATED(tmp_c)) THEN
      !$acc exit data delete(tmp_c)
      DEALLOCATE(tmp_c)
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
      IF(ALLOCATED(ps_r)) THEN
         IF(SIZE(ps_r,DIM=1) /= nbndval .OR. SIZE(ps_r,DIM=2) /= m) THEN
            DEALLOCATE(ps_r)
         ENDIF
      ENDIF
      IF(.NOT. ALLOCATED(ps_r)) THEN
         ALLOCATE(ps_r(nbndval,m))
      ENDIF
   ELSE
      IF(ALLOCATED(ps_c)) THEN
         IF(SIZE(ps_c,DIM=1) /= nbndval .OR. SIZE(ps_c,DIM=2) /= m) THEN
            DEALLOCATE(ps_c)
         ENDIF
      ENDIF
      IF(.NOT. ALLOCATED(ps_c)) THEN
         ALLOCATE(ps_c(nbndval,m))
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
   USE noncollin_module,      ONLY : noncolin,npol
   USE uspp,                  ONLY : nkb
   USE uspp_param,            ONLY : nhm
   USE wvfct,                 ONLY : npwx
   USE becmod_subs_gpum,      ONLY : allocate_bec_type_gpu
   !
   IMPLICIT NONE
   !
   CALL allocate_linsolve_gpu(3)
   !
   ALLOCATE(phi_tmp_d(npwx*npol,3))
   ALLOCATE(gk(3,npwx))
   ALLOCATE(dvkb(npwx,nkb))
   ALLOCATE(work(npwx,nkb))
   IF(noncolin) THEN
      ALLOCATE(deff_nc(nhm,nhm,nat,nspin))
      ALLOCATE(psc(nkb,npol,1,2))
   ELSE
      ALLOCATE(deff(nhm,nhm,nat))
      ALLOCATE(ps2(nkb,1,2))
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
   CALL deallocate_linsolve_gpu()
   !
   IF(ALLOCATED(phi_tmp_d)) THEN
      DEALLOCATE(phi_tmp_d)
   ENDIF
   IF(ALLOCATED(gk)) THEN
      DEALLOCATE(gk)
   ENDIF
   IF(ALLOCATED(dvkb)) THEN
      DEALLOCATE(dvkb)
   ENDIF
   IF(ALLOCATED(work)) THEN
      DEALLOCATE(work)
   ENDIF
   IF(ALLOCATED(deff_nc)) THEN
      DEALLOCATE(deff_nc)
   ENDIF
   IF(ALLOCATED(psc)) THEN
      DEALLOCATE(psc)
   ENDIF
   IF(ALLOCATED(deff)) THEN
      DEALLOCATE(deff)
   ENDIF
   IF(ALLOCATED(ps2)) THEN
      DEALLOCATE(ps2)
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
      ALLOCATE(work_r(lwork))
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
      ALLOCATE(work_c(lwork))
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
   IF(ALLOCATED(work_r)) THEN
      DEALLOCATE(work_r)
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
   IF(ALLOCATED(work_c)) THEN
      DEALLOCATE(work_c)
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
   USE gvect,                 ONLY : ngm
   !
   IMPLICIT NONE
   !
   CALL allocate_gpu()
   !
   ALLOCATE(sqvc_d(ngm))
   !
   END SUBROUTINE
   !
   !-----------------------------------------------------------------------
   SUBROUTINE deallocate_exx_gpu()
   !-----------------------------------------------------------------------
   !
   IMPLICIT NONE
   !
   CALL deallocate_gpu()
   !
   IF(ALLOCATED(sqvc_d)) THEN
      DEALLOCATE(sqvc_d)
   ENDIF
   !
   END SUBROUTINE
#endif
END MODULE
