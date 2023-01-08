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
! Ngoc Linh Nguyen, Victor Yu
!
!-----------------------------------------------------------------------
SUBROUTINE wbse_setup()
  !-----------------------------------------------------------------------
  !
  USE westcom,          ONLY : localization,l_local_repr,l_bisect_thr,macropol_calculation,&
                             & l_macropol,solver,l_bse_calculation,wbse_calculation,l_davidson,&
                             & l_lanczos,qp_correction,l_qp_correction,spin_excitation,&
                             & l_bse_triplet,wstat_calculation,n_pdep_times,n_pdep_eigen,&
                             & n_pdep_basis,n_pdep_maxiter,n_pdep_read_from_file,trev_pdep_rel,&
                             & trev_pdep,n_liouville_times,n_liouville_eigen,n_liouville_maxiter,&
                             & n_liouville_read_from_file,trev_liouville_rel,trev_liouville,&
                             & alphapv_dfpt,l_use_ecutrho,wbse_save_dir
  USE kinds,            ONLY : DP
  USE types_coulomb,    ONLY : pot3D
  USE wbse_dv,          ONLY : wbse_dv_setup
  !
  IMPLICIT NONE
  !
  ! Workspace
  !
  COMPLEX(DP), EXTERNAL :: get_alpha_pv
  !
  CALL do_setup()
  !
  SELECT CASE(TRIM(localization))
  CASE('N','n')
     l_local_repr = .FALSE.
     l_bisect_thr = .FALSE.
  CASE('B','b')
     l_local_repr = .TRUE.
     l_bisect_thr = .TRUE.
  END SELECT
  !
  SELECT CASE(macropol_calculation)
  CASE('c','C')
     l_macropol = .TRUE.
  END SELECT
  !
  SELECT CASE(TRIM(solver))
  CASE('BSE','bse')
     l_bse_calculation = .TRUE.
  CASE('TDDFT','tddft')
     l_bse_calculation = .FALSE.
  END SELECT
  !
  SELECT CASE(wbse_calculation)
  CASE('D','d')
     l_davidson = .TRUE.
     l_lanczos = .FALSE.
  CASE('L','l')
     l_lanczos = .TRUE.
     l_davidson = .FALSE.
  END SELECT
  !
  IF (TRIM(qp_correction) == '') THEN
     l_qp_correction = .FALSE.
  ELSE
     l_qp_correction = .TRUE.
  ENDIF
  !
  SELECT CASE(spin_excitation)
  CASE('S','s','singlet')
     l_bse_triplet = .FALSE.
  CASE('T','t','triplet')
     l_bse_triplet = .TRUE.
  END SELECT
  !
  SELECT CASE(wbse_calculation)
  CASE('l','d','r','R')
     wstat_calculation = 'R'
  CASE('L','D','s','S')
     wstat_calculation = 'S'
  CASE DEFAULT
     wstat_calculation = wbse_calculation
  END SELECT
  !
  n_pdep_times = n_liouville_times
  n_pdep_eigen = n_liouville_eigen
  n_pdep_basis = n_pdep_eigen * n_pdep_times
  n_pdep_maxiter = n_liouville_maxiter
  n_pdep_read_from_file = n_liouville_read_from_file
  trev_pdep_rel = trev_liouville_rel
  trev_pdep = trev_liouville
  !
  ! Calculate ALPHA_PV
  !
  alphapv_dfpt = get_alpha_pv()
  !
  l_use_ecutrho = .FALSE.
  !
  CALL set_npwq()
  !
  CALL pot3D%init('Rho',.FALSE.,'gb')
  !
  CALL set_nbndocc()
  !
  CALL wbse_dv_setup(l_bse_calculation)
  !
  CALL my_mkdir(wbse_save_dir)
  !
  IF (l_qp_correction) THEN
     CALL read_qp_eigs()
  ENDIF
  !
  ! read ovl_matrix and u_matrix, and compute macroscopic term, if any
  !
  IF (l_bse_calculation) THEN
     CALL bse_start()
  ENDIF
  !
END SUBROUTINE
!
!-----------------------------------------------------------------------
SUBROUTINE bse_start()
  !-----------------------------------------------------------------------
  !
  USE kinds,            ONLY : DP
  USE io_global,        ONLY : stdout
  USE pwcom,            ONLY : isk,nks,npwx
  USE westcom,          ONLY : l_reduce_io,tau_is_read,tau_all,n_tau,nbnd_occ,nbndval0x,&
                             & sigma_c_head,sigma_x_head,wbse_epsinfty,l_local_repr,overlap_thr,&
                             & u_matrix,ovl_matrix,n_bse_idx,idx_matrix
  USE lsda_mod,         ONLY : nspin
  USE constants,        ONLY : e2,pi
  USE cell_base,        ONLY : omega
  USE types_coulomb,    ONLY : pot3D
  USE wbse_io,          ONLY : read_umatrix_and_omatrix
  !
  IMPLICIT NONE
  !
  ! Workspace
  !
  INTEGER :: do_idx,nbndval,is
  INTEGER :: ibnd,jbnd,iks,current_spin
  REAL(DP) :: ovl_value
  !
  ! the divergence term in Fock potential
  !
  sigma_x_head = pot3D%div
  !
  ! compute macroscopic term, it needs macroscopic dielectric constant
  ! from input.
  !
  sigma_c_head = ((1._DP/wbse_epsinfty) - 1._DP) * (2._DP*e2/pi) * ((6._DP*pi*pi/omega)**(1._DP/3._DP))
  !
  WRITE(stdout,'(/,5X,"Macroscopic dielectric constant correction:",f9.5)') sigma_c_head
  !
  ! allocate and read unitary matrix and overlap matrix, if any
  !
  IF(l_local_repr) THEN
     !
     ALLOCATE(u_matrix(nbndval0x,nbndval0x,nspin))
     ALLOCATE(ovl_matrix(nbndval0x,nbndval0x,nspin))
     !
     DO is = 1,nspin
        CALL read_umatrix_and_omatrix(nbndval0x,is,u_matrix(:,:,is),ovl_matrix(:,:,is))
     ENDDO
     !
  ENDIF
  !
  !IF(.NOT. use_wstat_pdep) THEN
     !
     ! Using coupling approach, single k and q
     ! define idx_matrix
     !
     ALLOCATE(idx_matrix(nbndval0x*nbndval0x,2,nspin))
     !
     idx_matrix(:,:,:) = 0
     !
     ALLOCATE(n_bse_idx(nspin))
     !
     n_bse_idx(:) = 0
     !
     DO iks = 1,nks
        !
        nbndval = nbnd_occ(iks)
        current_spin = isk(iks)
        do_idx = 0
        !
        DO ibnd = 1,nbndval
           DO jbnd = 1,nbndval
              IF(l_local_repr) THEN
                 ovl_value = ovl_matrix(ibnd,jbnd,current_spin)
              ELSE
                 ovl_value = 0._DP
              ENDIF
              !
              IF(l_local_repr) THEN
                 IF(ovl_value >= overlap_thr) THEN
                    do_idx = do_idx + 1
                    idx_matrix(do_idx,1,current_spin) = ibnd
                    idx_matrix(do_idx,2,current_spin) = jbnd
                 ENDIF
              ELSE
                 do_idx = do_idx + 1
                 idx_matrix(do_idx,1,current_spin) = ibnd
                 idx_matrix(do_idx,2,current_spin) = jbnd
              ENDIF
           ENDDO
        ENDDO
        !
        n_bse_idx(current_spin) = do_idx
        !
     ENDDO
     !
!  ELSE
!     !
!     ! Using coupling approach, single k and q
!     ! define idx_matrix
!     !
!     ALLOCATE(idx_matrix(nbndval0x*nbndval0x*n_pdep_eigen,3,nspin))
!     !
!     idx_matrix(:,:,:) = 0
!     !
!     ALLOCATE(n_bse_idx(nspin))
!     !
!     n_bse_idx(:) = 0
!     !
!     DO iks = 1,nks
!        !
!        nbndval = nbnd_occ(iks)
!        current_spin = isk(iks)
!        do_idx = 0
!        !
!        DO alnd = 1,n_pdep_eigen
!           DO ibnd = 1,nbndval
!              DO jbnd = 1,nbndval
!                 IF(l_local_repr) THEN
!                    ovl_value = ovl_matrix(ibnd,jbnd,current_spin)
!                 ELSE
!                    ovl_value = 0._DP
!                 ENDIF
!                 !
!                 IF(ovl_value >= overlap_thr) THEN
!                    IF (gamma_only) THEN
!                       do_idx = do_idx + 1
!                       idx_matrix(do_idx,1,current_spin) = ibnd
!                       idx_matrix(do_idx,2,current_spin) = jbnd
!                       idx_matrix(do_idx,3,current_spin) = alnd
!                    ENDIF
!                 ELSE
!                    do_idx = do_idx + 1
!                    idx_matrix(do_idx,1,current_spin) = ibnd
!                    idx_matrix(do_idx,2,current_spin) = jbnd
!                    idx_matrix(do_idx,3,current_spin) = alnd
!                 ENDIF
!              ENDDO
!           ENDDO
!        ENDDO
!        !
!        n_bse_idx(current_spin) = do_idx
!        !
!     ENDDO
!     !
!  ENDIF
  !
  IF(l_reduce_io) THEN
     !
     do_idx = SUM(n_bse_idx)
     !
     ALLOCATE(tau_is_read(nbndval0x,nbndval0x,nspin))
     ALLOCATE(tau_all(npwx,do_idx))
     !
     tau_is_read(:,:,:) = 0
     n_tau = 0
     !
  ENDIF
  !
END SUBROUTINE
!
!-----------------------------------------------------------------------
SUBROUTINE read_qp_eigs()
  !-----------------------------------------------------------------------
  !
  ! read qp eigenvalues from JSON file
  !
  USE kinds,            ONLY : DP
  USE constants,        ONLY : RYTOEV
  USE io_global,        ONLY : ionode
  USE mp,               ONLY : mp_bcast
  USE mp_global,        ONLY : intra_image_comm
  USE westcom,          ONLY : et_qp,qp_correction
  USE pwcom,            ONLY : nspin,nbnd
  USE json_module,      ONLY : json_file
  !
  IMPLICIT NONE
  !
  ! Workspace
  !
  LOGICAL :: found
  INTEGER :: is,nspin_tmp
  CHARACTER(LEN=6) :: labels
  REAL(DP),ALLOCATABLE :: rvals(:)
  TYPE(json_file) :: json
  !
  ALLOCATE(et_qp(nbnd,nspin))
  !
  IF(ionode) THEN
     !
     CALL json%initialize()
     CALL json%load(filename=TRIM(qp_correction))
     !
     CALL json%get('system.electron.nspin',nspin_tmp,found)
     IF(.NOT. found) CALL errore('read_qp_eigs','nspin not found',1)
     IF(nspin_tmp /= nspin) CALL errore('read_qp_eigs','nspin mismatch',1)
     !
     DO is = 1,nspin
        !
        WRITE(labels,'(i6.6)') is
        !
        CALL json%get('output.Q.K'//labels//'.eqpSec',rvals,found)
        IF(.NOT. found) CALL errore('read_qp_eigs','eqpSec not found',1)
        IF(SIZE(rvals) /= nbnd) CALL errore('read_qp_eigs','nbnd mismatch',1)
        et_qp(:,is) = rvals/RYTOEV
        !
     ENDDO
     !
     CALL json%destroy()
     !
  ENDIF
  !
  CALL mp_bcast(et_qp,0,intra_image_comm)
  !
END SUBROUTINE
