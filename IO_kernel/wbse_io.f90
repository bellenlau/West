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
MODULE wbse_io
  !----------------------------------------------------------------------------
  !
  IMPLICIT NONE
  !
  CONTAINS
  !
  SUBROUTINE read_bse_pots_g2g(rhog,fixed_band_i,fixed_band_j,ispin)
    !
    USE kinds,          ONLY : DP
    USE pdep_io,        ONLY : pdep_read_G_and_distribute
    USE westcom,        ONLY : wbse_init_save_dir,l_reduce_io,tau_is_read,tau_all,n_tau
    USE pwcom,          ONLY : npwx
    !
    IMPLICIT NONE
    !
    ! I/O
    !
    COMPLEX(DP), INTENT(OUT) :: rhog(npwx)
    INTEGER, INTENT(IN) :: fixed_band_i,fixed_band_j,ispin
    !
    ! Workspace
    !
    INTEGER :: band_i,band_j,iread
    CHARACTER :: my_spin
    CHARACTER(LEN=6) :: my_labeli,my_labelj
    CHARACTER(LEN=256) :: fname
    !
    band_i = MIN(fixed_band_i,fixed_band_j)
    band_j = MAX(fixed_band_i,fixed_band_j)
    !
    IF(l_reduce_io) THEN
       !
       iread = tau_is_read(band_i,band_j,ispin)
       IF(iread > 0) THEN
          rhog(:) = tau_all(:,iread)
          RETURN
       ENDIF
       !
    ENDIF
    !
    WRITE(my_labeli,'(i6.6)') band_i
    WRITE(my_labelj,'(i6.6)') band_j
    WRITE(my_spin,'(i1)') ispin
    !
    fname = TRIM(wbse_init_save_dir)//'/E'//my_labeli//'_'//my_labelj//'_'//my_spin//'.dat'
    CALL pdep_read_G_and_distribute(fname,rhog)
    !
    IF(l_reduce_io) THEN
       !
       n_tau = n_tau+1
       tau_is_read(band_i,band_j,ispin) = n_tau
       tau_all(:,n_tau) = rhog
       !
    ENDIF
    !
  END SUBROUTINE
  !
  SUBROUTINE read_bse_pots_g2r(rhor,fixed_band_i,fixed_band_j,ispin)
    !
    USE kinds,          ONLY : DP
    USE control_flags,  ONLY : gamma_only
    USE fft_base,       ONLY : dffts
    USE pwcom,          ONLY : npw,npwx
    USE fft_at_gamma,   ONLY : single_invfft_gamma
    USE fft_at_k,       ONLY : single_invfft_k
#if defined(__CUDA)
    USE west_gpu,       ONLY : gaux,tmp_c
#endif
    !
    IMPLICIT NONE
    !
    ! I/O
    !
    REAL(DP), INTENT(OUT) :: rhor(dffts%nnr)
    INTEGER, INTENT(IN) :: fixed_band_i,fixed_band_j,ispin
    !
    ! Workspace
    !
    INTEGER :: dffts_nnr,ir
#if !defined(__CUDA)
    COMPLEX(DP), ALLOCATABLE :: gaux(:),tmp_c(:)
#endif
    !
#if !defined(__CUDA)
    ALLOCATE(gaux(npwx))
    ALLOCATE(tmp_c(dffts%nnr))
#endif
    !
    CALL read_bse_pots_g2g(gaux,fixed_band_i,fixed_band_j,ispin)
    !
    !$acc update device(gaux)
    !
    ! G -> R
    !
    !$acc host_data use_device(gaux,tmp_c)
    IF(gamma_only) THEN
       CALL single_invfft_gamma(dffts,npw,npwx,gaux,tmp_c,'Wave')
    ELSE
       CALL single_invfft_k(dffts,npw,npwx,gaux,tmp_c,'Wave') ! no igk
    ENDIF
    !$acc end host_data
    !
    dffts_nnr = dffts%nnr
    !
    !$acc parallel loop present(rhor,tmp_c)
    DO ir = 1,dffts_nnr
       rhor(ir) = REAL(tmp_c(ir),KIND=DP)
    ENDDO
    !$acc end parallel
    !
#if !defined(__CUDA)
    DEALLOCATE(gaux)
    DEALLOCATE(tmp_c)
#endif
    !
  END SUBROUTINE
  !
  SUBROUTINE write_umatrix_and_omatrix(oumat_dim,ispin,umatrix,omatrix)
    !
    USE kinds,          ONLY : DP,i8b
    USE mp_world,       ONLY : world_comm
    USE io_global,      ONLY : stdout
    USE mp,             ONLY : mp_barrier
    USE mp_world,       ONLY : mpime,root
    USE westcom,        ONLY : wbse_init_save_dir
    USE west_io,        ONLY : HD_LENGTH,HD_VERSION,HD_ID_VERSION,HD_ID_LITTLE_ENDIAN,HD_ID_DIMENSION
    USE base64_module,  ONLY : islittleendian
    !
    IMPLICIT NONE
    !
    ! I/O
    !
    INTEGER, INTENT(IN) :: oumat_dim,ispin
    REAL(DP), INTENT(IN) :: omatrix(oumat_dim,oumat_dim)
    COMPLEX(DP), INTENT(IN) :: umatrix(oumat_dim,oumat_dim)
    !
    ! Workspace
    !
    INTEGER :: iun
    CHARACTER(LEN=256) :: fname
    CHARACTER :: my_spin
    INTEGER :: header(HD_LENGTH)
    INTEGER(i8b) :: offset
    !
    WRITE(my_spin,'(i1)') ispin
    fname = TRIM(wbse_init_save_dir)//'/o_and_u.'//my_spin//'.dat'
    !
    WRITE(stdout,'(/,5X,"Writing overlap and rotation matrices to ",A)') TRIM(fname)
    !
    ! Resume all components
    !
    IF(mpime == root) THEN
       !
       header = 0
       header(HD_ID_VERSION) = HD_VERSION
       header(HD_ID_DIMENSION) = oumat_dim
       IF(islittleendian()) THEN
          header(HD_ID_LITTLE_ENDIAN) = 1
       ENDIF
       !
       OPEN(NEWUNIT=iun,FILE=TRIM(fname),ACCESS='STREAM',FORM='UNFORMATTED')
       offset = 1
       WRITE(iun,POS=offset) header
       offset = offset+HD_LENGTH*SIZEOF(header(1))
       WRITE(iun,POS=offset) umatrix(1:oumat_dim,1:oumat_dim)
       offset = offset+SIZE(umatrix)*SIZEOF(umatrix(1,1))
       WRITE(iun,POS=offset) omatrix(1:oumat_dim,1:oumat_dim)
       CLOSE(iun)
       !
    ENDIF
    !
    ! BARRIER
    !
    CALL mp_barrier(world_comm)
    !
  END SUBROUTINE
  !
  SUBROUTINE read_umatrix_and_omatrix(oumat_dim,ispin,umatrix,omatrix)
    !
    USE kinds,          ONLY : DP,i8b
    USE io_global,      ONLY : stdout,ionode
    USE mp_world,       ONLY : world_comm
    USE mp,             ONLY : mp_bcast,mp_barrier
    USE mp_global,      ONLY : intra_image_comm
    USE westcom,        ONLY : wbse_init_save_dir
    USE west_io,        ONLY : HD_LENGTH,HD_VERSION,HD_ID_VERSION,HD_ID_LITTLE_ENDIAN,HD_ID_DIMENSION
    USE base64_module,  ONLY : islittleendian
    !
    IMPLICIT NONE
    !
    ! I/O
    !
    INTEGER, INTENT(IN) :: oumat_dim,ispin
    REAL(DP), INTENT(OUT) :: omatrix(oumat_dim,oumat_dim)
    COMPLEX(DP), INTENT(OUT) :: umatrix(oumat_dim,oumat_dim)
    !
    ! Workspace
    !
    INTEGER :: ierr,iun
    INTEGER :: oumat_dim_tmp
    CHARACTER(LEN=256) :: fname
    CHARACTER :: my_spin
    INTEGER :: header(HD_LENGTH)
    INTEGER(i8b) :: offset
    REAL(DP), ALLOCATABLE :: omatrix_tmp(:,:)
    COMPLEX(DP), ALLOCATABLE :: umatrix_tmp(:,:)
    !
    ! BARRIER
    !
    CALL mp_barrier(world_comm)
    !
    WRITE(my_spin,'(i1)') ispin
    fname = TRIM(wbse_init_save_dir)//'/o_and_u.'//my_spin//'.dat'
    !
    WRITE(stdout,'(/,5X,"Reading overlap and rotation matrices from ",A)') TRIM(fname)
    !
    IF(ionode) THEN
       !
       OPEN(NEWUNIT=iun,FILE=TRIM(fname),ACCESS='STREAM',FORM='UNFORMATTED',STATUS='OLD',IOSTAT=ierr)
       IF(ierr /= 0) THEN
          CALL errore('read_umatrix_and_omatrix','Cannot read file: '//TRIM(fname),1)
       ENDIF
       !
       offset = 1
       READ(iun,POS=offset) header
       IF(HD_VERSION /= header(HD_ID_VERSION)) THEN
          CALL errore('read_umatrix_and_omatrix','Unknown file format: '//TRIM(fname),1)
       ENDIF
       IF((islittleendian() .AND. (header(HD_ID_LITTLE_ENDIAN) == 0)) &
          .OR. (.NOT. islittleendian() .AND. (header(HD_ID_LITTLE_ENDIAN) == 1))) THEN
          CALL errore('read_umatrix_and_omatrix','Endianness mismatch: '//TRIM(fname),1)
       ENDIF
       oumat_dim_tmp = header(HD_ID_DIMENSION)
       !
    ENDIF
    !
    CALL mp_bcast(oumat_dim_tmp,0,intra_image_comm)
    !
    ALLOCATE(umatrix_tmp(oumat_dim_tmp,oumat_dim_tmp))
    ALLOCATE(omatrix_tmp(oumat_dim_tmp,oumat_dim_tmp))
    !
    IF(ionode) THEN
       !
       offset = offset+HD_LENGTH*SIZEOF(header(1))
       READ(iun,POS=offset) umatrix_tmp(1:oumat_dim_tmp,1:oumat_dim_tmp)
       offset = offset+SIZE(umatrix_tmp)*SIZEOF(umatrix(1,1))
       READ(iun,POS=offset) omatrix_tmp(1:oumat_dim_tmp,1:oumat_dim_tmp)
       CLOSE(iun)
       !
    ENDIF
    !
    CALL mp_bcast(umatrix_tmp,0,intra_image_comm)
    CALL mp_bcast(omatrix_tmp,0,intra_image_comm)
    !
    umatrix(:,:) = 0._DP
    omatrix(:,:) = 0._DP
    umatrix(1:oumat_dim_tmp,1:oumat_dim_tmp) = umatrix_tmp(1:oumat_dim_tmp,1:oumat_dim_tmp)
    omatrix(1:oumat_dim_tmp,1:oumat_dim_tmp) = omatrix_tmp(1:oumat_dim_tmp,1:oumat_dim_tmp)
    !
    DEALLOCATE(umatrix_tmp)
    DEALLOCATE(omatrix_tmp)
    !
  END SUBROUTINE
  !
  !SUBROUTINE read_pwscf_wannier_orbs(ne,npw,c_emp,fname)
  !  !
  !  USE kinds,          ONLY : DP
  !  USE io_global,      ONLY : stdout
  !  USE gvect,          ONLY : ig_l2g
  !  USE mp_wave,        ONLY : splitwf
  !  USE mp,             ONLY : mp_get,mp_size,mp_rank,mp_bcast,mp_max
  !  USE mp_global,      ONLY : me_bgrp,root_bgrp,nproc_bgrp,intra_bgrp_comm,my_pool_id,my_bgrp_id,&
  !                           & inter_bgrp_comm,inter_pool_comm
  !  USE klist,          ONLY : ngk,igk_k
  !  USE wvfct,          ONLY : npwx
  !  !
  !  IMPLICIT NONE
  !  !
  !  INTEGER, INTENT(IN) :: npw,ne
  !  COMPLEX(DP), INTENT(INOUT) :: c_emp(npw,ne)
  !  CHARACTER(LEN=*), INTENT(IN):: fname
  !  !
  !  INTEGER :: ierr,iun,ig,i
  !  INTEGER :: ngw_l,ngw_g
  !  COMPLEX(DP), ALLOCATABLE :: ctmp(:)
  !  INTEGER, ALLOCATABLE :: igk_l2g(:)
  !  !
  !  ALLOCATE(igk_l2g(npwx))
  !  !
  !  ! ... the igk_l2g_kdip local-to-global map is needed to read wfcs
  !  !
  !  igk_l2g = 0
  !  DO ig = 1,ngk(1)
  !     igk_l2g(ig) = ig_l2g(igk_k(ig,1))
  !  ENDDO
  !  !
  !  WRITE(stdout,'(/,5X,"Reading Wannier orbitals from ",A)') TRIM(fname)
  !  !
  !  ngw_l = npw
  !  ngw_g = MAXVAL(igk_l2g(:))
  !  CALL mp_max(ngw_g,intra_bgrp_comm)
  !  !
  !  ALLOCATE(ctmp(ngw_g))
  !  !
  !  IF(my_pool_id == 0 .AND. my_bgrp_id == 0) THEN
  !     !
  !     ! ONLY ROOT W/IN BGRP READS
  !     !
  !     IF(me_bgrp == root_bgrp) THEN
  !        CALL iotk_free_unit(iun,ierr)
  !        CALL iotk_open_read(iun,FILE=TRIM(fname),BINARY=.TRUE.,IERR=ierr)
  !     ENDIF
  !     !
  !  ENDIF
  !  !
  !  CALL mp_bcast(ierr,0,inter_bgrp_comm)
  !  !
  !  IF(my_pool_id == 0 .AND. my_bgrp_id == 0) THEN
  !     !
  !     ! ONLY ROOT W/IN BGRP READS
  !     !
  !     IF(me_bgrp == root_bgrp) THEN
  !        CALL iotk_scan_begin(iun,'WANWFC_GSPACE')
  !     ENDIF
  !     !
  !  ENDIF
  !  !
  !  DO i = 1,ne
  !     IF(my_pool_id == 0 .AND. my_bgrp_id == 0) THEN
  !        !
  !        ! ONLY ROOT W/IN BGRP READS
  !        !
  !        IF(me_bgrp == root_bgrp) THEN
  !           CALL iotk_scan_dat(iun,'wfc'//iotk_index(i),ctmp(:))
  !        ENDIF
  !        !
  !        CALL splitwf(c_emp(:,i),ctmp,ngw_l,igk_l2g,me_bgrp,nproc_bgrp,root_bgrp,intra_bgrp_comm)
  !        !
  !     ENDIF
  !  ENDDO
  !  !
  !  IF(my_pool_id == 0 .AND. my_bgrp_id == 0) THEN
  !     !
  !     ! ONLY ROOT W/IN BGRP READS
  !     !
  !     IF(me_bgrp == root_bgrp) THEN
  !        CALL iotk_scan_end(iun,'WANWFC_GSPACE')
  !        CALL iotk_close_read(iun)
  !     ENDIF
  !     !
  !  ENDIF
  !  !
  !  DEALLOCATE(ctmp,igk_l2g)
  !  !
  !  CALL mp_bcast(c_emp,0,inter_bgrp_comm)
  !  CALL mp_bcast(c_emp,0,inter_pool_comm)
  !  !
  !END SUBROUTINE
  !
END MODULE